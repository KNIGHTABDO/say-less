import Foundation
import WhisperKit
import TTSKit

/// Speech → text with WhisperKit (Core ML, Neural Engine). The spoken language is known
/// (push-to-talk per half), so language detection is off.
public final class WhisperRecognizer: @unchecked Sendable {
    private let kit: WhisperKit

    public init(folder: String) async throws {
        let config = WhisperKitConfig(modelFolder: folder, tokenizerFolder: EnginePaths.whisperBase,
                                      verbose: false, logLevel: .error, prewarm: false, load: true, download: false)
        kit = try await WhisperKit(config)
    }

    public func transcribe(_ samples: [Float], language: String) async throws -> String {
        guard samples.count > 1600 else { return "" }   // < 0.1 s
        let options = DecodingOptions(task: .transcribe, language: language, temperature: 0,
                                      usePrefillPrompt: true, detectLanguage: false,
                                      skipSpecialTokens: true, withoutTimestamps: true)
        let results = try await kit.transcribe(audioArray: samples, decodeOptions: options)
        return results.map(\.text).joined(separator: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func unload() async { await kit.unloadModels() }

    /// Download the model files (and tokenizer) into the app's model folder.
    public static func download(variant: String, repo: String, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        // Parallel fetch first; the kit then only checks each file against the server.
        let prefetched = await prefetch("speech") {
            try await HubPrefetch.fetch(repo: repo, base: EnginePaths.whisperBase,
                                        include: { $0.hasPrefix(variant + "/") }) { progress($0 * 0.97) }
        }
        let url = try await WhisperKit.download(variant: variant, downloadBase: EnginePaths.whisperBase, from: repo) { p in
            progress(prefetched ? 0.97 + 0.03 * p.fractionCompleted : p.fractionCompleted)
        }
        EnginePaths.excludeFromBackup(EnginePaths.whisperBase)
        return url
    }
}

/// Text → speech with Qwen3-TTS 0.6B via TTSKit (10 languages).
public final class QwenVoice: @unchecked Sendable {
    private let kit: TTSKit

    public init(folder: URL) async throws {
        kit = try await TTSKit(model: .qwen3TTS_0_6b, modelFolder: folder, downloadBase: EnginePaths.ttsBase,
                               verbose: false, logLevel: .error, prewarm: false, load: true, download: false)
    }

    public static func speaker(for language: String) -> Qwen3Speaker {
        switch language {
        case "japanese": .onoAnna
        case "korean": .sohee
        case "chinese": .vivian
        default: .ryan
        }
    }

    public static func qwenLanguage(_ id: String) -> Qwen3Language? {
        switch id {
        case "english": .english
        case "chinese": .chinese
        case "japanese": .japanese
        case "korean": .korean
        case "german": .german
        case "french": .french
        case "russian": .russian
        case "portuguese": .portuguese
        case "spanish": .spanish
        case "italian": .italian
        default: nil
        }
    }

    /// Synthesize the whole utterance (returned so the app can replay it, or replay it slower).
    public func synthesize(_ text: String, voice id: String) async throws -> (samples: [Float], sampleRate: Int) {
        guard let lang = Self.qwenLanguage(id) else { throw EngineError.failed("no voice for \(id)") }
        var options = GenerationOptions()
        options.chunkingStrategy = .sentence
        let result = try await kit.generate(text: text, speaker: Self.speaker(for: id), language: lang, options: options)
        return (result.audio, result.sampleRate)
    }

    public func unload() async { await kit.unloadModels() }

    /// Files and bytes the voice prefetch would fetch (CI check that the kit's patterns match the repo).
    public static func prefetchPlan() async throws -> (files: Int, bytes: Int64) {
        let config = TTSKitConfig(model: .qwen3TTS_0_6b)
        let patterns = config.downloadPatterns + config.downloadAdditionalPatterns
        return try await HubPrefetch.plan(repo: config.modelRepo, endpoint: config.modelEndpoint,
                                          include: { name in patterns.contains { globMatch($0, name) } })
    }

    public static func download(progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let config = TTSKitConfig(model: .qwen3TTS_0_6b)
        let patterns = config.downloadPatterns + config.downloadAdditionalPatterns
        let prefetched = await prefetch("voice") {
            try await HubPrefetch.fetch(repo: config.modelRepo, endpoint: config.modelEndpoint, base: EnginePaths.ttsBase,
                                        include: { name in patterns.contains { globMatch($0, name) } }) { progress($0 * 0.97) }
        }
        let url = try await TTSKit.download(variant: .qwen3TTS_0_6b, downloadBase: EnginePaths.ttsBase) { p in
            progress(prefetched ? 0.97 + 0.03 * p.fractionCompleted : p.fractionCompleted)
        }
        EnginePaths.excludeFromBackup(EnginePaths.ttsBase)
        return url
    }
}

/// Runs a parallel prefetch; a failure is only logged because the kit's own download follows.
func prefetch(_ name: String, _ work: () async throws -> Void) async -> Bool {
    let t0 = Date()
    do {
        try await work()
        Breadcrumbs.note("prefetch \(name) ok in \(Int(Date().timeIntervalSince(t0))) s")
        return true
    } catch is CancellationError {
        return false
    } catch {
        Breadcrumbs.note("prefetch \(name) failed: \(error.localizedDescription)")
        return false
    }
}
