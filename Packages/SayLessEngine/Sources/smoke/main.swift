// CI smoke test on the macOS runner: real models, real pipeline.
//   smoke <wav 16k mono> <gguf...>
// 1. Each GGUF: load (CPU), print the chat template, self-test "Where is the train station?" → Spanish.
// 2. Whisper (variant from $WHISPER_VARIANT): transcribe the wav, translate the transcript.
import Foundation
import SayLessEngine

@main
struct Smoke {
    static func main() async {
        let args = CommandLine.arguments.dropFirst()
        guard let wav = args.first else { print("usage: smoke <wav> <gguf...>"); exit(2) }
        let ggufs = Array(args.dropFirst())
        var failed = false
        var working: LlamaTranslator?
        print("loaded llama: \(LlamaTranslator.systemInfo)")

        for path in ggufs {
            let name = (path as NSString).lastPathComponent
            print("=== MT \(name)")
            do {
                let t0 = Date()
                let t = try LlamaTranslator(modelPath: path, gpu: false, greedy: true)
                print("loaded in \(Int(Date().timeIntervalSince(t0) * 1000)) ms")
                print("template: \(t.templatePreview.replacingOccurrences(of: "\n", with: "⏎"))")
                let (ok, out) = PackInstaller.selfTest(t)
                print("self-test → \(out)   [\(ok ? "PASS" : "FAIL")] prompt via \(t.templateName)")
                for code in ["fr", "ja", "ar", "de", "zh"] {
                    let lang = Language.named(code)!
                    let r = try t.translate("Excuse me, how much is a ticket to the old town?", to: lang, maxTokens: 64)
                    print("  en→\(code): \(r.text)  (\(r.tokens) tok, \(r.ms) ms total; prompt \(r.promptTokens) tok in \(r.promptMs) ms; gen \(String(format: "%.1f", r.genTokensPerSecond)) tok/s)")
                }
                if ok && working == nil { working = t }
            } catch {
                print("FAIL load: \(error.localizedDescription)")
            }
        }
        if working == nil { print("::error::no translation model passed"); failed = true }

        // Speed bisect: one sentence per config on the first model (llama-bench gets ~84 pp / ~33 tg t/s here).
        if let path = ggufs.first {
            let configs: [(String, LlamaTranslator.Tuning)] = [
                ("plain t2 ctx1024", .init(threads: 2, plainDefaults: true)),
                ("plain t2 ctx128", .init(threads: 2, plainDefaults: true, contextLength: 128)),
                ("app t1", .init(threads: 1)),
                ("app t3", .init(threads: 3)),
            ]
            for (name, tuning) in configs {
                do {
                    let t = try LlamaTranslator(modelPath: path, gpu: false, greedy: true, tuning: tuning)
                    _ = try t.translate("Hello.", to: Language.named("fr")!, maxTokens: 4)   // warm-up
                    let r = try t.translate("Excuse me, how much is a ticket to the old town?", to: Language.named("fr")!, maxTokens: 32)
                    let pp = r.promptMs > 0 ? Double(r.promptTokens) * 1000 / Double(r.promptMs) : 0
                    print("bisect \(name): pp \(String(format: "%.1f", pp)) t/s, tg \(String(format: "%.1f", r.genTokensPerSecond)) t/s")
                } catch {
                    print("bisect \(name): FAIL \(error.localizedDescription)")
                }
            }
        }

        let variant = ProcessInfo.processInfo.environment["WHISPER_VARIANT"] ?? "openai_whisper-base"
        print("=== STT \(variant)")
        do {
            let t0 = Date()
            let folder = try await WhisperRecognizer.download(variant: variant, repo: "argmaxinc/whisperkit-coreml") { _ in }
            print("downloaded in \(Int(Date().timeIntervalSince(t0))) s → \(folder.lastPathComponent)")
            let t1 = Date()
            let rec = try await WhisperRecognizer(folder: folder.path)
            print("loaded in \(Int(Date().timeIntervalSince(t1) * 1000)) ms")
            let samples = try readWav16k(wav)
            let t2 = Date()
            let text = try await rec.transcribe(samples, language: "en")
            print("transcript (\(Int(Date().timeIntervalSince(t2) * 1000)) ms): \(text)")
            if !text.lowercased().contains("station") { print("::error::transcript missing 'station'"); failed = true }
            if let working {
                let es = try working.translate(text, to: Language.named("es")!)
                print("pipeline → es: \(es.text)")
            }
        } catch {
            print("::error::STT failed: \(error)")
            failed = true
        }
        print(failed ? "SMOKE FAILED" : "SMOKE OK")
        exit(failed ? 1 : 0)
    }

    /// Minimal WAV reader: 16-bit PCM mono 16 kHz (made in CI with `say` + `afconvert`).
    static func readWav16k(_ path: String) throws -> [Float] {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard let range = data.range(of: Data("data".utf8)) else { throw EngineError.failed("no data chunk") }
        let start = range.upperBound + 4
        let pcm = data[start...]
        var out = [Float]()
        out.reserveCapacity(pcm.count / 2)
        pcm.withUnsafeBytes { raw in
            let p = raw.bindMemory(to: Int16.self)
            for s in p { out.append(Float(Int16(littleEndian: s)) / 32768) }
        }
        return out
    }
}
