import Foundation

/// Installs the three model packs. Speech and translation are shared by every language;
/// the voice pack adds spoken output for the languages Qwen3-TTS covers.
public enum PackInstaller {
    public enum Pack: String, Sendable, CaseIterable { case speech, translation, voice }

    /// Known-answer test: an STQ-only or broken GGUF can load and still produce garbage.
    public static func selfTest(_ translator: LlamaTranslator) -> (passed: Bool, output: String) {
        guard let es = Language.named("es"),
              let out = try? translator.translate("Where is the train station?", to: es, maxTokens: 48) else {
            return (false, "")
        }
        let lower = out.text.lowercased()
        return (lower.contains("estaci"), out.text)
    }

    public static func installSpeech(registry: ModelRegistry = .bundled, progress: @escaping @Sendable (Double) -> Void) async throws {
        Breadcrumbs.begin("install-speech")
        let url = try await WhisperRecognizer.download(variant: registry.speech.variant, repo: registry.speech.repo, progress: progress)
        var m = InstalledManifest.load()
        m.whisperFolder = InstalledManifest.store(url)
        m.save()
        Breadcrumbs.end("install-speech", ms: 0)
    }

    /// Tries each translation model in order and keeps the first that passes the self-test.
    public static func installTranslation(registry: ModelRegistry = .bundled, gpu: Bool,
                                          progress: @escaping @Sendable (Double) -> Void,
                                          status: @escaping @Sendable (String) -> Void) async throws {
        var failures: [String] = []
        for (i, model) in registry.translation.enumerated() {
            let dest = EnginePaths.gguf.appending(path: model.url.lastPathComponent)
            status(i == 0 ? "Downloading \(model.displayName)" : "Trying \(model.displayName)")
            let file = try await ChunkedDownloader().download(model.url, to: dest, expectedBytes: model.bytes, connections: 6, progress: progress)
            status("Checking \(model.displayName)")
            Breadcrumbs.begin("selftest-\(model.id)")
            let result: (passed: Bool, output: String)
            do {
                let t = try LlamaTranslator(modelPath: file.path, gpu: gpu, greedy: true)
                result = selfTest(t)
            } catch {
                result = (false, error.localizedDescription)
            }
            Breadcrumbs.end("selftest-\(model.id)", ms: 0)
            Breadcrumbs.note("selftest \(model.id) passed=\(result.passed) out=\(result.output.prefix(80))")
            if result.passed {
                var m = InstalledManifest.load()
                m.translationID = model.id
                m.translationFile = InstalledManifest.store(file)
                m.save()
                // Free the disk taken by models that failed.
                for other in registry.translation where other.id != model.id {
                    try? FileManager.default.removeItem(at: EnginePaths.gguf.appending(path: other.url.lastPathComponent))
                }
                return
            }
            failures.append("\(model.displayName): \(result.output.prefix(60))")
            try? FileManager.default.removeItem(at: file)
        }
        throw EngineError.failed("No translation model passed its check. " + failures.joined(separator: "; "))
    }

    public static func installVoice(progress: @escaping @Sendable (Double) -> Void) async throws {
        Breadcrumbs.begin("install-voice")
        let url = try await QwenVoice.download(progress: progress)
        var m = InstalledManifest.load()
        m.voiceFolder = InstalledManifest.store(url)
        m.save()
        Breadcrumbs.end("install-voice", ms: 0)
    }

    public static func remove(_ pack: Pack) {
        var m = InstalledManifest.load()
        let fm = FileManager.default
        switch pack {
        case .speech:
            try? fm.removeItem(at: EnginePaths.whisperBase); m.whisperFolder = nil
        case .translation:
            try? fm.removeItem(at: EnginePaths.gguf); m.translationFile = nil; m.translationID = nil
        case .voice:
            try? fm.removeItem(at: EnginePaths.ttsBase); m.voiceFolder = nil
        }
        m.save()
    }

    public static func diskUsage(_ pack: Pack) -> Int64 {
        switch pack {
        case .speech: EnginePaths.size(of: EnginePaths.whisperBase)
        case .translation: EnginePaths.size(of: EnginePaths.gguf)
        case .voice: EnginePaths.size(of: EnginePaths.ttsBase)
        }
    }
}
