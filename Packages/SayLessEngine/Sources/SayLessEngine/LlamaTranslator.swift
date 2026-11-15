import Foundation
import llama

public struct TranslationOutput: Sendable {
    public var text: String
    public var tokens: Int
    public var ms: Int
    /// Breakdown from llama's own counters: prompt tokens and time, generation-only time.
    public var promptTokens = 0
    public var promptMs = 0
    public var genMs = 0
    public var genTokensPerSecond: Double { genMs > 0 ? Double(tokens) * 1000 / Double(genMs) : 0 }
    public var tokensPerSecond: Double { ms > 0 ? Double(tokens) * 1000 / Double(ms) : 0 }
}

public enum EngineError: LocalizedError {
    case loadFailed(String)
    case notLoaded(String)
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .loadFailed(let s): "Could not load \(s)"
        case .notLoaded(let s): "\(s) is not loaded"
        case .failed(let s): s
        }
    }
}

/// Hy-MT (Tencent) translation through llama.cpp. One instance owns one model + context.
/// All calls must be serialized (the engine actor does that).
public final class LlamaTranslator: @unchecked Sendable {
    public let modelPath: String
    public let greedy: Bool
    private var model: OpaquePointer?
    private var ctx: OpaquePointer?
    private var vocab: OpaquePointer?
    private var template: String?
    public private(set) var templateName = "raw"

    private static let backendOnce: Void = {
        // Only warnings and errors: llama's debug log (one line per tensor) slows loading.
        llama_log_set({ level, text, _ in
            guard level == GGML_LOG_LEVEL_WARN || level == GGML_LOG_LEVEL_ERROR, let text else { return }
            fputs(String(cString: text), stderr)
        }, nil)
        llama_backend_init()
    }()

    /// llama.cpp build and CPU features, for diagnostics.
    public static var systemInfo: String {
        _ = backendOnce
        return llama_print_system_info().map { String(cString: $0) } ?? "?"
    }

    /// Overrides for speed experiments (CI bisect). nil = the app's normal choice.
    public struct Tuning: Sendable {
        public var threads: Int32?
        /// Use llama's default model/context params except threads and context size.
        public var plainDefaults = false
        public var contextLength: Int32 = 1024
        public init(threads: Int32? = nil, plainDefaults: Bool = false, contextLength: Int32 = 1024) {
            self.threads = threads; self.plainDefaults = plainDefaults; self.contextLength = contextLength
        }
    }

    public convenience init(modelPath: String, gpu: Bool, greedy: Bool = false, contextLength: Int32 = 1024) throws {
        try self.init(modelPath: modelPath, gpu: gpu, greedy: greedy, tuning: Tuning(contextLength: contextLength))
    }

    /// - Parameters:
    ///   - gpu: offload layers to Metal (off on simulators / CI VMs).
    ///   - greedy: deterministic decoding (CI); otherwise Tencent's recommended sampling.
    public init(modelPath: String, gpu: Bool, greedy: Bool = false, tuning: Tuning) throws {
        let contextLength = tuning.contextLength
        _ = Self.backendOnce
        self.modelPath = modelPath
        self.greedy = greedy
        var mp = llama_model_default_params()
        mp.n_gpu_layers = gpu ? 99 : 0
        if !tuning.plainDefaults { mp.load_mode = LLAMA_LOAD_MODE_MMAP }
        guard let m = llama_model_load_from_file(modelPath, mp) else {
            throw EngineError.loadFailed((modelPath as NSString).lastPathComponent)
        }
        model = m
        var cp = llama_context_default_params()
        cp.n_ctx = UInt32(contextLength)
        cp.n_batch = UInt32(contextLength)
        let threads = tuning.threads ?? Int32(max(2, min(6, ProcessInfo.processInfo.activeProcessorCount - 1)))
        cp.n_threads = threads
        cp.n_threads_batch = threads
        if !gpu && !tuning.plainDefaults {
            // Keep everything on the CPU: by default the KV cache and big host ops still go to Metal.
            cp.offload_kqv = false
            cp.op_offload = false
        }
        cp.no_perf = false
        guard let c = llama_init_from_model(m, cp) else {
            llama_model_free(m)
            throw EngineError.loadFailed("translation context")
        }
        ctx = c
        vocab = llama_model_get_vocab(m)
        if let t = llama_model_chat_template(m, nil) { template = String(cString: t) }
    }

    deinit {
        if let ctx { llama_free(ctx) }
        if let model { llama_model_free(model) }
    }

    /// Tencent's prompt for Hy-MT. Chinese targets use the Chinese instruction.
    public static func prompt(_ text: String, to target: Language) -> String {
        if target.code == "zh" {
            return "将以下文本翻译为中文，注意只需要输出翻译后的结果，不要额外解释：\n\n\(text)"
        }
        return "Translate the following text into \(target.englishName). Note that you should only output the translated result without any additional explanation:\n\n\(text)"
    }

    public func translate(_ text: String, to target: Language, maxTokens: Int = 256, onPartial: ((String) -> Void)? = nil) throws -> TranslationOutput {
        guard let ctx, let vocab else { throw EngineError.notLoaded("translator") }
        let start = Date()
        llama_memory_clear(llama_get_memory(ctx), true)
        llama_perf_context_reset(ctx)

        let user = Self.prompt(text, to: target)
        let formatted = applyTemplate(user)
        var tokens = tokenize(formatted)
        guard !tokens.isEmpty else { throw EngineError.failed("empty prompt") }
        if tokens.count > 900 { tokens = Array(tokens.suffix(900)) }

        let sampler = makeSampler()
        defer { llama_sampler_free(sampler) }

        var rc = tokens.withUnsafeMutableBufferPointer { buf in
            llama_decode(ctx, llama_batch_get_one(buf.baseAddress, Int32(buf.count)))
        }
        guard rc == 0 else { throw EngineError.failed("decode failed (\(rc))") }

        var bytes: [UInt8] = []
        var produced = 0
        while produced < maxTokens {
            var tok = llama_sampler_sample(sampler, ctx, -1)
            if llama_vocab_is_eog(vocab, tok) { break }
            bytes += piece(tok)
            produced += 1
            if let onPartial, produced % 2 == 0 {
                onPartial(String(decoding: bytes, as: UTF8.self))
            }
            rc = llama_decode(ctx, llama_batch_get_one(&tok, 1))
            if rc != 0 { break }
        }
        let out = Self.clean(String(decoding: bytes, as: UTF8.self))
        let perf = llama_perf_context(ctx)
        var result = TranslationOutput(text: out, tokens: produced, ms: Int(Date().timeIntervalSince(start) * 1000))
        result.promptTokens = Int(perf.n_p_eval)
        result.promptMs = Int(perf.t_p_eval_ms)
        result.genMs = Int(perf.t_eval_ms)
        return result
    }

    // MARK: - helpers

    private func makeSampler() -> UnsafeMutablePointer<llama_sampler> {
        let chain = llama_sampler_chain_init(llama_sampler_chain_default_params())!
        if greedy {
            llama_sampler_chain_add(chain, llama_sampler_init_greedy())
        } else {
            // Tencent's recommended settings: top_k 20, top_p 0.6, repetition 1.05, temperature 0.7.
            llama_sampler_chain_add(chain, llama_sampler_init_top_k(20))
            llama_sampler_chain_add(chain, llama_sampler_init_penalties(llama_vocab_n_tokens(vocab), 64, 1.05, 0, 0))
            llama_sampler_chain_add(chain, llama_sampler_init_top_p(0.6, 1))
            llama_sampler_chain_add(chain, llama_sampler_init_temp(0.7))
            llama_sampler_chain_add(chain, llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))
        }
        return chain
    }

    private func applyTemplate(_ user: String) -> String {
        guard let template else { return user }
        let role = strdup("user")!, content = strdup(user)!
        defer { free(role); free(content) }
        var msg = llama_chat_message(role: role, content: content)
        var buf = [CChar](repeating: 0, count: user.utf8.count * 2 + 1024)
        var n = llama_chat_apply_template(template, &msg, 1, true, &buf, Int32(buf.count))
        if n > buf.count {
            buf = [CChar](repeating: 0, count: Int(n) + 1)
            n = llama_chat_apply_template(template, &msg, 1, true, &buf, Int32(buf.count))
        }
        guard n > 0 else { templateName = "raw (template unsupported)"; return user }
        templateName = "model template"
        return String(decoding: buf.prefix(Int(n)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private func tokenize(_ text: String) -> [llama_token] {
        let utf8 = Array(text.utf8CString)
        let len = Int32(utf8.count - 1)
        var tokens = [llama_token](repeating: 0, count: Int(len) + 16)
        var n = llama_tokenize(vocab, utf8, len, &tokens, Int32(tokens.count), true, true)
        if n < 0 {
            tokens = [llama_token](repeating: 0, count: Int(-n))
            n = llama_tokenize(vocab, utf8, len, &tokens, Int32(tokens.count), true, true)
        }
        return n > 0 ? Array(tokens.prefix(Int(n))) : []
    }

    private func piece(_ tok: llama_token) -> [UInt8] {
        var buf = [CChar](repeating: 0, count: 64)
        var n = llama_token_to_piece(vocab, tok, &buf, Int32(buf.count), 0, false)
        if n < 0 {
            buf = [CChar](repeating: 0, count: Int(-n))
            n = llama_token_to_piece(vocab, tok, &buf, Int32(buf.count), 0, false)
        }
        return n > 0 ? buf.prefix(Int(n)).map { UInt8(bitPattern: $0) } : []
    }

    static func clean(_ s: String) -> String {
        var t = s
        // Drop any reasoning block a model might emit.
        if let r = t.range(of: "</think>") { t = String(t[r.upperBound...]) }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// First 400 characters of the model's chat template (for diagnostics).
    public var templatePreview: String { String((template ?? "none").prefix(400)) }
}
