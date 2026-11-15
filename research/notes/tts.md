# On-Device Multilingual Text-to-Speech (TTS) for iPhone

**Task:** Research and evaluation of on-device multilingual Text-to-Speech (TTS) solutions for "Say Less", an offline travel translator app on iOS.  
**Target Hardware:** iPhone 13 Pro Max (A15 Bionic, 16-core Apple Neural Engine, 6 GB RAM, iOS 26).  
**Deployment Environment:** Sideloaded via SideStore using a free Apple ID (no paid Apple Developer program entitlement for `com.apple.developer.kernel.increased-memory-limit`).  
**Memory & Latency Constraints:** Hard per-process Jetsam limit of ~2.8–3.2 GB anonymous dirty memory ([Lvrpiz iOS Memory Limits](https://lvrpiz.com/blog/2023/ios-memory-limits/)). With on-device STT (~0.8–1.2 GB RAM) and MT (~0.6–1.0 GB RAM) active, the TTS budget must remain strictly **under 200–300 MB RAM** with a target **first-audio latency < 300 ms**.  
**Date:** Mid-November 2026.

---

## 1. Candidate Comparison Table

| Name | Model-Card / Project URL | Release Date | Params | Quantized Disk Size | Runtime RAM | Languages (Count) | License | iOS Runtime + Link | Published iPhone / Apple-Silicon Speed Numbers (with Source URL) | Streaming? | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Apple AVSpeechSynthesizer** | [Apple AVSpeechSynthesizer Docs](https://developer.apple.com/documentation/avfoundation/avspeechsynthesizer) | iOS 7.0 (Neural/Premium expanded iOS 16–18+) | Proprietary hybrid | 0 MB app bundle (Compact pre-installed; Enhanced ~100–200 MB, Premium ~300–600 MB in system cache) | ~10–25 MB (engine executes out-of-process in `mediaserverd`) | 40–50+ languages, 60+ regional locales ([Apple Speech Voices](https://developer.apple.com/documentation/avfoundation/avspeechsynthesisvoice)) | Proprietary Apple System SDK (Free, commercial & personal) | Native `AVFoundation` (`AVSpeechSynthesizer`) | Latency < 50–80 ms first audio; RTF < 0.01 ([Apple Developer Forums](https://developer.apple.com/forums/)) | Yes (Native audio session playback or PCM streaming buffer via `write(_:toBufferCallback:)`) | Zero RAM against app jetsam; compact voices sound robotic; enhanced/premium voices require manual user download in iOS Settings. |
| **Kokoro-82M** | [hexgrad/Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M) | Dec 25, 2024 (v0.19) / Jan 27, 2025 (v1.0) | 82M | ~85–90 MB (INT8/Q8), ~160 MB (FP16), ~320 MB (FP32) | ~150–220 MB | 8+ languages (EN-US, EN-GB, ES, FR, HI, IT, JA, PT-BR, ZH-CN v1.1) ([Kokoro Card](https://huggingface.co/hexgrad/Kokoro-82M)) | Apache 2.0 | Core ML via [mattmireles/kokoro-coreml](https://github.com/mattmireles/kokoro-coreml) or [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) | 12x to 79x real-time speed on Apple Silicon (RTF 0.012–0.08) ([kokoro-coreml Benchmarks](https://github.com/mattmireles/kokoro-coreml#benchmarks)) | Yes (Sentence chunking and ANE-streamed audio buffers) | Highest naturalness in sub-100M tier; "model surgery" offloads iSTFTNet vocoder to ANE. Limited to 8 major languages. |
| **Piper TTS** | [rhasspy/piper](https://github.com/rhasspy/piper) & [rhasspy/piper-voices](https://huggingface.co/rhasspy/piper-voices) | 2023 (active updates 2024–2026) | ~15M (low) to ~30–50M (medium) per voice | ~15–25 MB (low), ~35–60 MB (medium) per voice | ~50–90 MB per loaded voice | 35–40 languages, 100+ voices ([Piper Samples](https://rhasspy.github.io/piper-samples/)) | MIT License (code & most voice weights) | [sherpa-onnx iOS Swift](https://github.com/k2-fsa/sherpa-onnx) & App Store [Piper - Neural TTS](https://apps.apple.com/app/piper-neural-tts/id6475734327) | RTF ~0.02–0.04 on Apple Silicon / ARM64 (25x–50x real-time) ([rhasspy/piper](https://github.com/rhasspy/piper)) | Yes (Clause/sentence chunking via sherpa-onnx `ProgressCallback`) | Battle-tested, rock-solid stability, ultra-low memory, per-language on-demand download. |
| **Meta MMS-TTS** | [facebook/mms-tts](https://huggingface.co/facebook/mms-tts) | May 2023 | ~28–35M per language (VITS) | ~35–45 MB ONNX per language | ~50–80 MB per loaded voice | 1,107+ languages ([Meta MMS Project](https://huggingface.co/facebook/mms-tts)) | CC-BY-NC 4.0 (Non-Commercial) | [sherpa-onnx iOS](https://github.com/k2-fsa/sherpa-onnx) & [csukuangfj/vits-mms-models](https://huggingface.co/csukuangfj/vits-mms-models) | RTF ~0.02–0.05 on Apple Silicon (20x–50x real-time) ([sherpa-onnx Docs](https://k2-fsa.github.io/sherpa/onnx/)) | Yes (Sentence-level chunking; generation takes < 50 ms per phrase) | Unrivaled global coverage for long-tail/indigenous travel languages; restricted by CC-BY-NC 4.0. |
| **Kyutai Pocket TTS** | [kyutai-labs/pocket-tts](https://github.com/kyutai-labs/pocket-tts) & [kyutai.org](https://kyutai.org) | Jan 13, 2026 (v4.0 Oct 20, 2026) | 100M base; distilled to 1.9M–18.2M | ~15–40 MB (distilled), ~120–180 MB (100M) | ~80–150 MB | 6 languages (EN, FR, DE, ES, PT, IT) ([Kyutai Pocket TTS Announcement](https://kyutai.org)) | MIT License | Swift Candle/UniFFI via [pocket-tts-ios](https://github.com/UnaMentis/pocket-tts-ios) & [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) | RTF < 0.10 on CPU/Apple Silicon; time-to-first-byte ~100–150 ms ([Kyutai.org](https://kyutai.org)) | Yes (Native streaming decoder + 5s zero-shot voice cloning) | Brand-new 2026 release; exceptional efficiency and voice matching, but limited to 6 European languages. |
| **Supertonic TTS (Supertonic 3)** | [supertonic-tts.com](https://supertonic-tts.com) & [Supertone AI](https://huggingface.co/Supertone-AI) | 2025 / 2026 | ~66M–99M | ~70–110 MB per model | ~120–180 MB | 31 languages ([sherpa-onnx Supertonic Docs](https://k2-fsa.github.io/sherpa/onnx/tts/supertonic.html)) | Open Weights / Permissive | [sherpa-onnx iOS](https://github.com/k2-fsa/sherpa-onnx) | RTF ~0.05–0.10 on ARM64 / Apple Silicon ([sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx)) | Yes (Chunked flow-matching steps) | High quality across 31 languages; natively integrated into sherpa-onnx runtime. |
| **MeloTTS** | [myshell-ai/MeloTTS](https://github.com/myshell-ai/MeloTTS) | 2024 | ~35M–50M per language (VITS) | ~40–60 MB per language | ~60–100 MB | 6 languages (EN, ES, FR, ZH, JA, KO) ([MeloTTS GitHub](https://github.com/myshell-ai/MeloTTS)) | MIT License | [sherpa-onnx iOS](https://github.com/k2-fsa/sherpa-onnx) | RTF ~0.03 on Apple Silicon ([sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx)) | Yes (Sentence chunking) | Excellent prosody for East Asian and major European languages; limited coverage compared to Piper. |
| **KittenTTS** | [KittenML/KittenTTS](https://github.com/KittenML/KittenTTS) | Late 2024 (v0.8) / 2025 (KittenTTS 2) | 15M (Nano), 80M (Mini), 1.7B (v2) | ~61 MB (Nano `.mlmodelc`), ~280 MB (Mini), >1 GB (v2) | ~60–120 MB (Nano/Mini); >1.5 GB (v2) | Nano/Mini: English only; v2: 16–20 languages ([KittenTTS Model Card](https://github.com/KittenML/KittenTTS)) | Apache 2.0 | Core ML [kittentts-coreml](https://huggingface.co/alexwengg/kittentts-coreml) & [ibuhs/KittenTTS-iOS](https://github.com/ibuhs/KittenTTS-iOS) | RTF ~0.05 on ANE for Nano ([KittenTTS CoreML](https://huggingface.co/alexwengg/kittentts-coreml)) | Yes (Streaming audio chunks) | The lightweight on-device models are strictly English only; multilingual v2 is 1.7B params (too heavy). |
| **NeuTTS (NeuTTS Nano / Air)** | [neuphonic/neutts](https://github.com/neuphonic/neutts) | 2025 | ~120M (Nano), larger for Air | ~150–250 MB (GGUF Q4 + NeuCodec) | ~250–400 MB | 4 languages (EN, ES, FR, DE) ([Neuphonic Hugging Face](https://huggingface.co/neuphonic)) | Open Weights / Apache 2.0 | GGUF via `llama.cpp` Metal or [neutts-rs](https://github.com/neuphonic/neutts) | RTF ~0.08–0.15 on Apple Silicon ([NeuTTS Repo](https://github.com/neuphonic/neutts)) | Yes (Autoregressive SLM token streaming + NeuCodec) | SLM + neural codec architecture. High RAM overhead and limited to 4 Western European languages. |
| **Chatterbox Multilingual** | [resemble-ai/chatterbox](https://github.com/resemble-ai/chatterbox) | 2024 / 2025 | ~500M (Multilingual V3) | ~300–450 MB | ~500–800 MB | 23+ languages ([Resemble AI Chatterbox](https://resemble.ai)) | MIT License | Experimental hybrid Core ML / ONNX ([chatterbox-turbo-ONNX](https://huggingface.co/ResembleAI/chatterbox-turbo-ONNX)) | RTF ~0.25–0.40 on Apple Silicon ([Resemble AI](https://resemble.ai)) | Yes (Autoregressive token streaming) | Heavy RAM footprint and autoregressive latency; too risky alongside STT/MT in a 2.5 GB Jetsam budget. |
| **F5-TTS / E2-TTS** | [SWAN-Lab/F5-TTS](https://github.com/SWAN-Lab/F5-TTS) | Oct 2024 | ~380M (F5-TTS base), ~100M (Small) | ~250–400 MB | ~400–700 MB | Primarily EN, ZH (community multilingual fine-tunes) ([F5-TTS](https://github.com/SWAN-Lab/F5-TTS)) | MIT License | Community ONNX [F5-TTS-ONNX](https://github.com/nickLinear/F5-TTS-ONNX) | RTF ~0.8–1.5 on mobile devices (iterative diffusion steps) ([F5-TTS Repo](https://github.com/SWAN-Lab/F5-TTS)) | Partial (Sway-sampling chunks) | Iterative flow matching (16–32 DiT passes) has excessive latency (>1.5 s first audio) and high battery drain on mobile. |
| **Sesame CSM (csm-1b)** | [sesame/csm-1b](https://huggingface.co/sesame/csm-1b) | Late 2024 / 2025 | 1 Billion (Llama-3.2-1B backbone) | ~600–800 MB (4-bit) | >1.2–1.8 GB | English only ([Sesame AI Labs](https://github.com/SesameAILabs/csm)) | Apache 2.0 | None (PyTorch / Transformers only) | Unknown on mobile (severely throttled on A15 CPU/GPU) | Yes (Autoregressive Mimi audio tokens) | 1B params immediately triggers Jetsam termination alongside STT/MT. No iOS runtime exists. |
| **Orpheus Multilingual** | [canopyai/Orpheus-TTS](https://github.com/canopyai/Orpheus-TTS) | 2024 / 2025 | 3 Billion (Llama-3B backbone) + SNAC | ~2.0–2.5 GB (4-bit) | >2.5–3.2 GB | ~20 languages (African/multilingual research previews) ([Sunbird Orpheus](https://sunbird.ai)) | Research / Open weights | None (Server vLLM / CUDA only) | Unknown on mobile (cannot run on iPhone 13 Pro Max) | Yes (SNAC token streaming) | 3B params exceeds the entire phone RAM ceiling. No mobile iOS deployment path. |

---

## 2. Ranked Top 3 Recommendations

### Ranked #1: Apple AVSpeechSynthesizer (Zero-Download Baseline & Zero-RAM Shield)
Apple's built-in `AVSpeechSynthesizer` is the indispensable foundation for "Say Less". Because it executes out-of-process in iOS system audio daemons (`mediaserverd`), it incurs virtually **zero memory impact (~10–25 MB bridge overhead)** against the app’s tight ~2.5–3.0 GB Jetsam ceiling, eliminating the risk of out-of-memory crashes while heavy WhisperKit and MarianMT/NLLB models are active. It covers **40–50+ languages across 60+ regional locales** completely offline without requiring any initial model downloads, ensuring the app works on day one in airplane mode. Furthermore, it delivers instant first-audio latency (<50 ms) and supports real-time PCM audio buffer streaming via `write(_:toBufferCallback:)`. While its pre-installed compact voices sound somewhat robotic, users can unlock studio-quality "Enhanced" and "Premium" neural voices for free via iOS Accessibility settings, making it the most resilient zero-cost TTS backbone available.

### Ranked #2: Kokoro-82M via Core ML (Highest Naturalness for Core Travel Languages)
For primary travel destinations (English, Spanish, French, Japanese, Mandarin, Hindi, Italian, and Portuguese), **Kokoro-82M** represents the current state of the art in lightweight open-weight TTS. At only 82M parameters (~85 MB INT8 / ~160 MB FP16) and ~150–200 MB runtime RAM, it delivers speech naturalness and prosody rivaling 1B+ cloud APIs. Crucially, native Core ML ports like [mattmireles/kokoro-coreml](https://github.com/mattmireles/kokoro-coreml) perform "model surgery" by separating the dynamic text transformer onto CPU/GPU while mapping the heavy iSTFTNet vocoder directly onto the Apple Neural Engine (ANE). This achieves an astonishing **12x to 79x real-time speed (RTF 0.012–0.08)** on Apple Silicon, generating 10 seconds of speech in under 200 ms with near-zero thermal penalty and first-audio latency well under 150 ms.

### Ranked #3: Piper TTS + Meta MMS-TTS via `sherpa-onnx` (The Modular Global Backbone: 35 to 1,100+ Languages)
To solve the global traveler's long-tail requirement across Europe, Africa, Asia, and the Middle East, the **`sherpa-onnx`** runtime ([k2-fsa/sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx)) paired with VITS-based models provides unmatched flexibility. It allows "Say Less" to offer modular, on-demand downloads (~20–40 MB per trip):
1. **Piper TTS (MIT License):** Provides clean, highly intelligible neural voices across 35–40 major languages (Arabic, Russian, Turkish, Vietnamese, Greek, Scandinavian languages, etc.) running at 25x–50x real-time (RTF ~0.03) with under 90 MB RAM.
2. **Meta MMS-TTS (CC-BY-NC 4.0):** Acts as the ultimate safety net for over 1,100+ indigenous, regional, and minority languages where no other TTS model exists, operating at the same lightweight VITS efficiency. Through sherpa-onnx’s C/Swift `ProgressCallback` API, audio chunks stream smoothly to the speaker with under 80 ms latency.

---

## 3. Recommended Hybrid Architecture for "Say Less"

```
                              ┌────────────────────────────────────────┐
                              │     Say Less Translation Pipeline      │
                              │       (Speech-to-Speech Engine)        │
                              └──────────────────┬─────────────────────┘
                                                 │
                                      Target Language Detected
                                                 │
                  ┌──────────────────────────────┼──────────────────────────────┐
                  ▼                              ▼                              ▼
      [ Tier 1: Core Languages ]     [ Tier 2: Global Modular ]      [ Tier 3: Universal Fallback ]
        (EN, ES, FR, JA, ZH,            (35–1,100+ Languages:          (Zero-Download / Low RAM)
           HI, IT, PT-BR)                AR, RU, TR, VI, etc.)
                  │                              │                              │
                  ▼                              ▼                              ▼
           Kokoro-82M Core ML              sherpa-onnx VITS                Apple AVSpeechSynthesizer
       (mattmireles/kokoro-coreml)        (Piper & Meta MMS-TTS)           (AVFoundation Framework)
        • ~160 MB disk (FP16)           • ~35 MB per voice download     • 0 MB download
        • ~180 MB RAM                   • ~70 MB RAM                    • ~15 MB RAM (out-of-process)
        • ANE-accelerated (RTF < 0.08)  • CPU/NEON-optimized (RTF 0.03) • Instant first audio (<50 ms)
        • Studio-grade naturalness      • Broadest global coverage      • Works out-of-the-box offline
```

---

## 4. Moroccan Arabic (Darija) Support Assessment

- **Current Status:** Moroccan Spoken Arabic (Darija / ISO 639-3 `ary`) is **not supported as a distinct, dedicated dialect** by any production-ready on-device TTS engine.
  - **Apple AVSpeechSynthesizer:** Offers Modern Standard Arabic (`ar-SA`) offline, but no Moroccan dialect voice.
  - **Piper TTS:** Features Jordan/Levantine Arabic (`ar_JO`), which differs substantially in phonology and vocabulary from Darija.
  - **Kokoro-82M:** Does not support Arabic.
  - **Meta MMS-TTS:** Trained on Modern Standard Arabic (`ara`); while Meta’s ASR corpus includes Darija, the TTS release relied on standardized textual corpora without an explicit `ary` model.
  - **Open-Source Research:** Experimental projects such as *Lahgtna* and community spaces ([medmac01/Darija-Arabic-TTS](https://huggingface.co/spaces/medmac01/Darija-Arabic-TTS)) explore Darija TTS, but exist only as unoptimized PyTorch research checkpoints with no iOS deployment path.
- **Practical Recommendation for Say Less:** When a user travels to Morocco, configure the translation pipeline to offer two offline options:
  1. **Modern Standard Arabic (`ar-SA` / `ara` via Piper, MMS, or AVSpeechSynthesizer):** Readily understood across Morocco in formal, travel, and transactional contexts.
  2. **French (`fr-FR` via Kokoro or Piper):** Widely spoken and fluently understood throughout Moroccan commerce, hospitality, and urban centers.

---

## 5. Rejected Candidates and Detailed Rationale

1. **Sesame CSM (`csm-1b`):**
   - *Rationale:* With 1 billion parameters on a Llama-3.2 backbone plus an audio decoder, the model consumes over 1.2–1.8 GB of RAM even in 4-bit precision. Combined with WhisperKit (~1 GB) and translation models (~800 MB), it will breach the iPhone 13 Pro Max’s 2.8–3.2 GB Jetsam threshold and trigger an immediate operating system kill. Additionally, no iOS runtime exists for the open-weights checkpoint (PyTorch/Transformers only), and it is English-only.
2. **Orpheus Multilingual (Canopy Labs):**
   - *Rationale:* Built on a 3-billion-parameter Llama-3 backbone with a SNAC audio codec, the model requires 2.0–2.5 GB of storage and over 2.5–3.2 GB of runtime memory. This alone exhausts the maximum memory limit of an unentitled iOS process. It is designed for server-side CUDA/vLLM deployments and has no mobile iOS runtime.
3. **Chatterbox Multilingual (Resemble AI):**
   - *Rationale:* The 500M-parameter autoregressive transformer consumes ~500–800 MB of RAM, creating substantial Jetsam pressure. Furthermore, token-by-token autoregressive generation on the A15 CPU/GPU incurs high latency (>600–1000 ms time-to-first-audio), violating the <300 ms responsiveness requirement for live conversational translation.
4. **F5-TTS / E2-TTS (SWAN-Lab):**
   - *Rationale:* Uses continuous flow-matching with a Diffusion Transformer (DiT). Generating speech requires an iterative ODE solver executing 16 to 32 forward passes over the transformer for each audio window. On mobile hardware, this results in unacceptable latency (>1.5–3.0 seconds to first audio) and heavy thermal/battery drain. It is primarily trained on English and Mandarin.
5. **NeuTTS (Neuphonic - NeuTTS Nano / Air):**
   - *Rationale:* Employs a Small Language Model (SLM) coupled with NeuCodec. While innovative, it only supports 4 Western European languages (EN, ES, FR, DE) and requires ~250–400 MB of RAM, offering less language coverage and higher resource consumption than Kokoro-82M or Piper.
6. **KittenTTS (KittenML):**
   - *Rationale:* The lightweight on-device models (Nano at 15M and Mini at 80M) are **strictly English-only**. The multilingual KittenTTS 2 model is 1.7 billion parameters, which exceeds mobile memory and latency constraints.

---

## 6. Implementation Reference & Code Snippets

### A. Zero-Download Fallback via `AVSpeechSynthesizer`
```swift
import AVFoundation

final class SystemTTSPlayer: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    
    override init() {
        super.init()
        // Bypass accessibility EQ graphs for cleaner audio fidelity
        synthesizer.usesApplicationAudioSession = false
        synthesizer.delegate = self
    }
    
    func speak(text: String, languageCode: String) {
        let utterance = AVSpeechUtterance(string: text)
        // Match specific locale or fallback to base language
        if let voice = AVSpeechSynthesisVoice(language: languageCode) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }
    
    // Low-latency PCM buffer streaming (iOS 13+)
    func streamAudioBuffers(text: String, languageCode: String, onBuffer: @escaping (AVAudioPCMBuffer) -> Void) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        synthesizer.write(utterance) { buffer in
            if let pcmBuffer = buffer as? AVAudioPCMBuffer {
                onBuffer(pcmBuffer)
            }
        }
    }
}
```

### B. High-Fidelity Streaming with `Kokoro-CoreML`
```swift
import Foundation
import AVFoundation
// Integration pattern with mattmireles/kokoro-coreml
import KokoroCoreML

final class KokoroTTSManager {
    private var kokoro: KokoroTTS?
    
    init() {
        // Loads ANE-optimized split pipeline (Vocoder on Neural Engine)
        guard let modelPath = Bundle.main.url(forResource: "kokoro-v1.0", withExtension: "mlpackage") else { return }
        self.kokoro = try? KokoroTTS(modelURL: modelPath)
    }
    
    func synthesizeStream(text: String, voiceName: String, onAudioChunk: @escaping (Data) -> Void) async {
        guard let kokoro = kokoro else { return }
        // Generates audio chunks asynchronously with RTF < 0.08 on A15
        for try await chunk in kokoro.generateStream(text: text, voice: voiceName) {
            onAudioChunk(chunk.rawPCMData)
        }
    }
}
```

### C. Modular Multi-Language Synthesis with `sherpa-onnx`
```swift
import Foundation
// Integration pattern using sherpa-onnx C-API / Swift wrapper
import SherpaOnnx

final class SherpaTTSManager {
    private var ttsEngine: OfflineTts?
    
    func loadVoice(modelPath: String, tokensPath: String, dataDir: String) {
        let vitsConfig = OfflineTtsVitsModelConfig(
            model: modelPath,
            lexicon: "",
            tokens: tokensPath,
            dataDir: dataDir
        )
        let modelConfig = OfflineTtsModelConfig(vits: vitsConfig, numThreads: 2, debug: 0)
        let config = OfflineTtsConfig(model: modelConfig)
        self.ttsEngine = OfflineTts(config: config)
    }
    
    func speak(text: String, onAudioProgress: @escaping ([Float]) -> Bool) {
        guard let tts = ttsEngine else { return }
        // Streaming progress callback intercepting raw normalized samples
        tts.generateWithCallback(text: text, sid: 0, speed: 1.0) { samples in
            return onAudioProgress(samples) ? 1 : 0
        }
    }
}
```
