// CI smoke test on the macOS runner: real models, real pipeline.
//   smoke <wav 16k mono> <gguf...>
// 1. Each GGUF: load (CPU), print the chat template, self-test "Where is the train station?" → Spanish.
// 2. Whisper (variant from $WHISPER_VARIANT): transcribe the wav, translate the transcript.
import Foundation
import SayLessEngine
import CryptoKit

@main
struct Smoke {
    static func main() async {
        let args = CommandLine.arguments.dropFirst()
        guard let wav = args.first else { print("usage: smoke <wav> <gguf...>"); exit(2) }
        let ggufs = Array(args.dropFirst())
        var failed = false
        var working: LlamaTranslator?

        // Model paths must survive an app update (new container path).
        let newRoot = "/var/mobile/Containers/Data/Application/NEW/Library/Application Support/SayLess"
        let cases: [(String, String)] = [
            ("/var/mobile/Containers/Data/Application/OLD/Library/Application Support/SayLess/Models/gguf/a.gguf", newRoot + "/Models/gguf/a.gguf"),
            ("Models/tts/x/y", newRoot + "/Models/tts/x/y"),
            ("/elsewhere/file", "/elsewhere/file"),
        ]
        for (stored, want) in cases {
            let got = InstalledManifest.reroot(stored, root: newRoot)
            print(got == want ? "self-test reroot OK \(stored.suffix(20))" : "::error::reroot \(stored) → \(got), want \(want)")
            if got != want { failed = true }
        }
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

        // Fast downloads: the chunked GGUF must match the curl copy byte for byte.
        if let path = ggufs.first {
            print("=== chunked download")
            let name = (path as NSString).lastPathComponent
            let src = URL(string: "https://huggingface.co/tencent/Hy-MT2-1.8B-GGUF/resolve/main/\(name)")!
            let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
            let dest = FileManager.default.temporaryDirectory.appending(path: "chunked-\(name)")
            try? FileManager.default.removeItem(at: dest)
            let t0 = Date()
            do {
                _ = try await ChunkedDownloader().download(src, to: dest, expectedBytes: size, connections: 6) { _ in }
                let s = Date().timeIntervalSince(t0)
                let same = sha256(dest.path) == sha256(path)
                print("chunked \(size / 1_000_000) MB in \(String(format: "%.1f", s)) s (\(String(format: "%.0f", Double(size) / 1e6 / s)) MB/s) identical=\(same)")
                if !same { print("::error::chunked download differs from curl copy"); failed = true }
            } catch {
                print("::error::chunked download failed: \(error)"); failed = true
            }
            try? FileManager.default.removeItem(at: dest)
        }

        let variant = ProcessInfo.processInfo.environment["WHISPER_VARIANT"] ?? "openai_whisper-base"
        print("=== STT \(variant)")
        do {
            // Prefetch then the kit: the kit must accept the prefetched files without rewriting them.
            let repo = "argmaxinc/whisperkit-coreml"
            let tp = Date()
            try await HubPrefetch.fetch(repo: repo, base: EnginePaths.whisperBase, include: { $0.hasPrefix(variant + "/") }) { _ in }
            print("prefetch in \(String(format: "%.1f", Date().timeIntervalSince(tp))) s")
            let weights = EnginePaths.whisperBase.appending(path: "models/\(repo)/\(variant)/AudioEncoder.mlmodelc/weights/weight.bin")
            let before = (try? FileManager.default.attributesOfItem(atPath: weights.path)[.modificationDate] as? Date) ?? nil
            let t0 = Date()
            let folder = try await WhisperRecognizer.download(variant: variant, repo: "argmaxinc/whisperkit-coreml") { _ in }
            print("downloaded in \(Int(Date().timeIntervalSince(t0))) s → \(folder.lastPathComponent)")
            let after = (try? FileManager.default.attributesOfItem(atPath: weights.path)[.modificationDate] as? Date) ?? nil
            if before == nil || before != after { print("::error::kit re-downloaded prefetched weights (\(String(describing: before)) → \(String(describing: after)))"); failed = true }
            else { print("self-test prefetch reused by kit OK") }
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

    static func sha256(_ path: String) -> String {
        guard let h = FileHandle(forReadingAtPath: path) else { return "" }
        var hasher = SHA256()
        while let d = try? h.read(upToCount: 8 << 20), !d.isEmpty { hasher.update(data: d) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
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
