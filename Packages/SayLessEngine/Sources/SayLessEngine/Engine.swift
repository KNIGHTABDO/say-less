import Foundation

/// Per-stage timing for diagnostics.
public struct StageTiming: Sendable, Codable {
    public var stage: String
    public var ms: Int
    public var detail: String
    public var date: Date
}

/// Owns the three models and keeps them inside the app's memory budget.
/// Loads lazily, evicts the least-recently-used model when free memory is short,
/// and writes a breadcrumb before every load.
public actor Engine {
    public enum Component: String, Sendable, CaseIterable { case speech, translation, voice }

    public let registry: ModelRegistry
    private var recognizer: WhisperRecognizer?
    private var translator: LlamaTranslator?
    private var voice: QwenVoice?
    private var lastUsed: [Component: Date] = [:]
    public private(set) var timings: [StageTiming] = []
    public private(set) var activeTranslationName = "none"
    /// Safety margin kept free on top of a model's resident size.
    public var marginMB = 350

    public nonisolated let useGPU: Bool

    public init(registry: ModelRegistry = .bundled) {
        self.registry = registry
        #if targetEnvironment(simulator)
        useGPU = false
        #else
        useGPU = true
        #endif
    }

    public func isLoaded(_ c: Component) -> Bool {
        switch c {
        case .speech: recognizer != nil
        case .translation: translator != nil
        case .voice: voice != nil
        }
    }

    // MARK: - Pipeline

    public func transcribe(_ samples: [Float], language: String) async throws -> String {
        try await ensure(.speech)
        guard let recognizer else { throw EngineError.notLoaded("speech") }
        let t = Date()
        let text = try await recognizer.transcribe(samples, language: language)
        record("speech", t, "\(String(format: "%.1f", Double(samples.count) / 16000))s audio")
        return text
    }

    public func translate(_ text: String, to target: Language, onPartial: (@Sendable (String) -> Void)? = nil) async throws -> TranslationOutput {
        try await ensure(.translation)
        guard let translator else { throw EngineError.notLoaded("translation") }
        let out = try translator.translate(text, to: target, onPartial: onPartial)
        timings.append(StageTiming(stage: "translation", ms: out.ms,
                                   detail: "prompt \(out.promptTokens) tok \(out.promptMs) ms · gen \(out.tokens) tok \(String(format: "%.1f", out.genTokensPerSecond)) tok/s", date: Date()))
        trimTimings()
        return out
    }

    public func speak(_ text: String, voiceID: String) async throws -> (samples: [Float], sampleRate: Int) {
        try await ensure(.voice)
        guard let voice else { throw EngineError.notLoaded("voice") }
        let t = Date()
        let out = try await voice.synthesize(text, voice: voiceID)
        record("voice", t, "\(String(format: "%.1f", Double(out.samples.count) / Double(max(out.sampleRate, 1))))s audio")
        return out
    }

    // MARK: - Residency

    public func ensure(_ c: Component) async throws {
        lastUsed[c] = Date()
        if isLoaded(c) { return }
        let need = residentMB(c)
        while MemoryProbe.availableMB() < need + marginMB, let victim = lruVictim(excluding: c) {
            Breadcrumbs.note("evict \(victim.rawValue) to load \(c.rawValue) avail=\(MemoryProbe.availableMB())MB")
            await unload(victim)
        }
        let manifest = InstalledManifest.load()
        let stage = "load-\(c.rawValue)"
        Breadcrumbs.begin(stage)
        let t = Date()
        switch c {
        case .speech:
            guard let folder = manifest.whisperFolder else { throw EngineError.notLoaded("speech pack") }
            recognizer = try await WhisperRecognizer(folder: folder)
        case .translation:
            guard let file = manifest.translationFile else { throw EngineError.notLoaded("translation pack") }
            translator = try LlamaTranslator(modelPath: file, gpu: useGPU)
            activeTranslationName = registry.translation.first { $0.id == manifest.translationID }?.displayName ?? "custom"
        case .voice:
            guard let folder = manifest.voiceFolder else { throw EngineError.notLoaded("voice pack") }
            voice = try await QwenVoice(folder: URL(fileURLWithPath: folder))
        }
        let ms = Int(Date().timeIntervalSince(t) * 1000)
        Breadcrumbs.end(stage, ms: ms)
        record(stage, t, "avail \(MemoryProbe.availableMB())MB after")
    }

    public func unload(_ c: Component) async {
        switch c {
        case .speech: await recognizer?.unload(); recognizer = nil
        case .translation: translator = nil
        case .voice: await voice?.unload(); voice = nil
        }
        lastUsed[c] = nil
    }

    public func unloadAll() async {
        for c in Component.allCases { await unload(c) }
    }

    private func lruVictim(excluding c: Component) -> Component? {
        Component.allCases.filter { $0 != c && isLoaded($0) }
            .min { (lastUsed[$0] ?? .distantPast) < (lastUsed[$1] ?? .distantPast) }
    }

    private func residentMB(_ c: Component) -> Int {
        switch c {
        case .speech: registry.speech.residentMB
        case .translation: registry.translation.first?.residentMB ?? 1250
        case .voice: registry.voice.residentMB
        }
    }

    private func record(_ stage: String, _ start: Date, _ detail: String) {
        timings.append(StageTiming(stage: stage, ms: Int(Date().timeIntervalSince(start) * 1000), detail: detail, date: Date()))
        trimTimings()
    }

    private func trimTimings() { if timings.count > 60 { timings.removeFirst(timings.count - 60) } }
}
