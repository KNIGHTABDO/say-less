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
        let url = try await WhisperKit.download(variant: variant, downloadBase: EnginePaths.whisperBase, from: repo) { p in
            progress(p.fractionCompleted)
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

    public static func download(progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let url = try await TTSKit.download(variant: .qwen3TTS_0_6b, downloadBase: EnginePaths.ttsBase) { p in
            progress(p.fractionCompleted)
        }
        EnginePaths.excludeFromBackup(EnginePaths.ttsBase)
        return url
    }
}
