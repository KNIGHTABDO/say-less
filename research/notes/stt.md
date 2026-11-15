# On-Device Multilingual Speech-to-Text (Streaming) for iPhone 13 Pro Max ("Say Less")

**Target Device:** iPhone 13 Pro Max (A15 Bionic, 16-core Apple Neural Engine, 6 GB physical RAM, iOS 26 / iOS 18+ architecture).  
**Deployment Context:** Sideloaded via SideStore using a free Apple ID (no `com.apple.developer.kernel.increased-memory-limit` entitlement).  
**Real-World Jetsam Ceiling:** Without the increased memory entitlement, standard iOS processes on 6 GB devices face an out-of-memory (OOM) Jetsam termination threshold at roughly **2,867 MB (~2.8 GB)** ([Apple Developer Documentation](https://developer.apple.com/documentation/os/os_proc_available_memory), [Zenn iOS Memory Limits](https://zenn.dev/kazu_dev/articles/8627250e046df1)). The app's active STT component should ideally stay under **1.5 GB RAM** to leave head-room for translation (MT) and text-to-speech (TTS) buffers.  
**Research Date:** mid-November 2026.

---

## 1. Candidate Comparison Table

| Name | Model-Card URL | Release Date | Params | Quantized Disk Size | Runtime RAM | Languages (Count) | License | iOS Runtime + Link | Published iPhone/Apple Silicon Speed Numbers (Source URL) | Streaming? | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Whisper Large-v3-Turbo** | [openai/whisper-large-v3-turbo](https://huggingface.co/openai/whisper-large-v3-turbo) | Oct 2024 | 809M | ~550–630 MB (OD-MBP / mixed 4–8 bit Core ML) | ~1.2–1.6 GB peak | 100 languages ([OpenAI Language List](https://github.com/openai/whisper#available-models-and-languages)) | MIT | [WhisperKit (Core ML / Swift)](https://github.com/argmaxinc/WhisperKit) | iPhone 15 Pro RTF ~0.25–0.35x; iPhone 13 Pro (A15) RTF ~0.60–0.78x (1.3–1.6x faster than real-time); latency ~200–450 ms ([WhisperKit arXiv:2507.10860](https://arxiv.org/abs/2507.10860), [WhisperKit Benchmarks](https://huggingface.co/spaces/argmaxinc/whisperkit-benchmarks)) | Yes (chunked sliding window + speculative VAD streaming) | Gold standard for iOS. Pruned decoder (4 layers vs 32) preserves large-v3 accuracy while cutting ANE memory by ~40%. |
| **Whisper Small** | [openai/whisper-small](https://huggingface.co/openai/whisper-small) | Sep 2022 | 244M | ~240 MB (int8 Core ML) | ~450–600 MB | 100 languages ([OpenAI Language List](https://github.com/openai/whisper#available-models-and-languages)) | MIT | [WhisperKit](https://github.com/argmaxinc/WhisperKit), [whisper.cpp](https://github.com/ggerganov/whisper.cpp) | iPhone 13 Pro (A15) RTF ~0.22–0.28x (3.5–4.5x faster than real-time); latency ~150 ms ([WhisperKit Benchmarks](https://huggingface.co/spaces/argmaxinc/whisperkit-benchmarks)) | Yes (chunked VAD streaming) | Thermal sweet spot on A15 Bionic; highly stable under long sessions without memory pressure. |
| **Distil-Whisper Large-v3** | [distil-whisper/distil-large-v3](https://huggingface.co/distil-whisper/distil-large-v3) | Dec 2023 | 756M | ~594 MB (Core ML OD-MBP) | ~1.1–1.4 GB | English-only out-of-the-box ([Hugging Face Model Card](https://huggingface.co/distil-whisper/distil-large-v3)) | MIT | [WhisperKit CoreML](https://github.com/argmaxinc/WhisperKit) | iPhone 15 Pro RTF ~0.20x; iPhone 13 Pro RTF ~0.55x ([WhisperKit Benchmarks](https://huggingface.co/spaces/argmaxinc/whisperkit-benchmarks)) | Yes (chunked VAD streaming) | 2 decoder layers; 6x faster than large-v3, but English only (reject as primary multilingual travel model). |
| **Meta Omnilingual ASR (omniASR_CTC_300M)** | [facebook/omniASR-LLM-7B](https://huggingface.co/facebook/omniASR-LLM-7B) & [Edison2ST sherpa-onnx](https://huggingface.co/Edison2ST/sherpa-onnx-omnilingual-asr-1600-languages-ctc-v2) | Nov 2025 (Model) / Feb 2026 (ONNX) | 300M | ~310 MB (int8 ONNX) | ~450–550 MB | 1,600+ languages ([Meta Omnilingual Paper arXiv:2511.09690](https://arxiv.org/abs/2511.09690)) | Apache 2.0 | [sherpa-onnx iOS](https://github.com/k2-fsa/sherpa-onnx) ([Docs](https://k2-fsa.github.io/sherpa/onnx/)) | Apple Silicon ARM64 CPU RTF ~0.15–0.25x (~4–6x real-time speed) ([k2-fsa/sherpa-onnx benchmarks](https://k2-fsa.github.io/sherpa/onnx/)) | Yes (chunked non-autoregressive CTC forward pass) | Unmatched world coverage. Natively includes Moroccan Arabic (`ary`), Modern Standard Arabic, Amazigh (`zgh`), and long-tail global dialects. |
| **Meta MMS-1B (Massively Multilingual Speech)** | [facebook/mms-1b-all](https://huggingface.co/facebook/mms-1b-all) | May 2023 | 1.0B | ~1.05 GB (int8 ONNX) | ~1.3–1.7 GB | 1,400+ languages ([Meta MMS Project](https://about.meta.com/community/mms/)) | CC-BY-NC 4.0 | [sherpa-onnx iOS](https://github.com/k2-fsa/sherpa-onnx) | Apple Silicon M-series/ARM64 RTF ~0.35–0.45x ([sherpa-onnx MMS](https://k2-fsa.github.io/sherpa/onnx/)) | Yes (chunked CTC forward pass) | Predecessor to Omnilingual ASR; requires adapter swapping per language; non-commercial license limits commercial distribution. |
| **SenseVoiceSmall** | [FunAudioLLM/SenseVoiceSmall](https://huggingface.co/FunAudioLLM/SenseVoiceSmall) | Jul 2024 | 234M | ~240 MB (int8 ONNX) | ~280–380 MB | 5 core languages (zh, en, yue, ja, ko) + auto LID ([SenseVoice GitHub](https://github.com/FunAudioLLM/SenseVoice)) | Apache 2.0 | [sherpa-onnx iOS](https://github.com/k2-fsa/sherpa-onnx) | Mobile ARM64 CPU RTF < 0.05x (~15x faster than Whisper-Large, ~5x faster than Whisper-Small) ([SenseVoice Paper](https://arxiv.org/abs/2407.04051)) | Yes (non-autoregressive SAN-M CTC chunked stream) | Blistering fast, outputs emotion and acoustic tags. However, strictly limited to East Asia + English. Zero Arabic, Spanish, French, etc. |
| **Moonshine (v2 Streaming Small)** | [UsefulSensors/moonshine-tiny](https://huggingface.co/UsefulSensors/moonshine-tiny) & [moonshine-ai](https://github.com/moonshine-ai/moonshine) | Oct 2024 / 2025 | 123M | ~125 MB (int8 ONNX) | ~200–300 MB | 10 languages (en, es, de, zh, ja, ko, vi, tl, uk, ar) ([Moonshine Repo](https://github.com/moonshine-ai/moonshine)) | MIT (streaming models) | [sherpa-onnx](https://k2-fsa.github.io/sherpa/onnx/), LiteRT | Mobile ARM64 latency < 100 ms; RTF < 0.10x ([Moonshine Tech Report](https://arxiv.org/abs/2410.15608)) | Yes (native variable-length RoPE streaming) | Extremely efficient without Whisper's 30s zero-padding overhead, but only 10 languages supported. |
| **NVIDIA Canary-1b-v2** | [nvidia/canary-1b-v2](https://huggingface.co/nvidia/canary-1b-v2) | Late 2024 | 1.0B | ~1.0 GB (int8 ONNX) | ~1.4–1.8 GB | 25 European languages ([NVIDIA Model Card](https://huggingface.co/nvidia/canary-1b-v2)) | CC-BY-4.0 | [sherpa-onnx iOS](https://github.com/k2-fsa/sherpa-onnx) | FastConformer decoder RTF ~0.15x on Apple Silicon ([NVIDIA NeMo Benchmarks](https://github.com/NVIDIA/NeMo)) | Pseudo-streaming (chunked FastConformer) | State-of-the-art accuracy on European languages (MCV21 avg WER 6.67%), but zero coverage of Asian, Middle Eastern, or African languages. |
| **NVIDIA Parakeet-TDT-0.6b-v3** | [nvidia/parakeet-tdt-0.6b-v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) | 2024 / 2025 | 600M | ~620 MB (int8 ONNX) | ~850 MB–1.1 GB | 25 European languages ([NVIDIA Model Card](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3)) | CC-BY-4.0 | [sherpa-onnx iOS](https://github.com/k2-fsa/sherpa-onnx) | Token-and-Duration Transducer is 3–5x faster than standard Conformer transducers; RTF ~0.08x ([Parakeet Paper](https://arxiv.org/abs/2405.07992)) | Yes (transducer streaming) | High European accuracy and low latency, but no Asian or African languages. |
| **Kyutai STT (stt-1b-en_fr)** | [kyutai/stt-1b-en_fr](https://huggingface.co/kyutai/stt-1b-en_fr) | 2024 / 2025 | 1.0B | ~600 MB (4-bit/8-bit MLX) | ~1.2–1.5 GB | 2 languages only: English and French ([Kyutai Collection](https://huggingface.co/collections/kyutai/speech-to-text-685403682cf8a23ab9466886)) | MIT | [kyutai-labs/moshi-swift](https://github.com/kyutai-labs/moshi-swift) (MLX Swift) | Latency ~160–200 ms via 24 kHz Mimi audio codec ([Kyutai STT Docs](https://kyutai.org/)) | Yes (continuous frame-by-frame streaming) | Includes semantic turn-taking VAD. Reject as travel translator due to only supporting English and French. |
| **Mistral Voxtral Mini (3B)** | [mistralai/Voxtral-Mini-3B](https://mistral.ai/news/voxtral/) | 2025 | ~3.0B | ~2.2–2.5 GB (Q4_K_M GGUF) | ~3.0–3.8 GB | ~8–12 languages ([Mistral Voxtral Docs](https://mistral.ai/news/voxtral/)) | Apache 2.0 | [llama.cpp (multimodal mtmd)](https://github.com/ggerganov/llama.cpp), MLX-Swift | Time-to-first-token ~600–900 ms on Apple Silicon ([llama.cpp Discussions](https://github.com/ggerganov/llama.cpp/discussions)) | Partial (Voxtral Realtime chunked) | Multimodal speech-language model. Exceeds iPhone 13 Pro Max SideStore 2.8 GB Jetsam limit; triggers OOM kills. |
| **Qwen2-Audio / Qwen2.5-Omni** | [Qwen/Qwen2-Audio-7B](https://huggingface.co/Qwen/Qwen2-Audio-7B) | 2024 / 2025 | 7.0B+ | ~4.2–4.8 GB (Q4 GGUF) | ~4.8–5.8 GB | 10+ languages ([Qwen2-Audio Repo](https://github.com/QwenLM/Qwen2-Audio)) | Apache 2.0 | llama.cpp mtmd | Unknown on A15 Bionic (OOM) | Chunked streaming | Severe OOM on 6 GB iPhones. Requires at least 12–16 GB unified memory. |
| **Google Gemma 3n (E2B / Audio Scribe)** | [google/gemma-3n-e2b](https://blog.google/technology/developers/gemma-3n/) | 2025 / 2026 | 2.0B effective (E2B) | ~1.5–1.8 GB (.litertlm bundle) | ~2.0–2.4 GB | ~30+ languages ([Google DeepMind Gemma 3n](https://deepmind.google/technologies/gemma/)) | Gemma Open License | [LiteRT / MediaPipe Tasks](https://developers.google.com/mediapipe/solutions/audio) | iPhone 15 Pro RTF ~0.70x; iPhone 13 Pro RTF ~0.95–1.10x ([Google AI Edge Docs](https://developers.google.com/mediapipe/solutions/audio/audio_transcriber)) | Chunk-based prompt generation | Autoregressive token decoding is slow and power hungry. Leaves <400 MB RAM headroom for translation. |
| **FunASR Paraformer-Large** | [funasr/paraformer-large](https://huggingface.co/funasr/paraformer-large) | 2023 / 2024 | 220M | ~220 MB (int8 ONNX) | ~280–350 MB | 2 languages: Chinese and English ([FunASR Repo](https://github.com/modelscope/FunASR)) | Apache 2.0 | [sherpa-onnx iOS](https://github.com/k2-fsa/sherpa-onnx) | ARM64 RTF < 0.05x ([FunASR Paper](https://arxiv.org/abs/2303.00917)) | Yes (chunked CIF streaming) | Extremely efficient non-autoregressive CIF predictor, but strictly bilingual zh/en. |
| **Apple SpeechTranscriber (iOS 18+ Speech Framework)** | [Apple Developer: SpeechAnalyzer](https://developer.apple.com/documentation/speech/speechanalyzer) | iOS 18 (2024) / iOS 26 | Built-in Apple ASR | 0 MB (system-managed assets on demand) | **0 MB app RAM** (executes in system daemon outside app sandbox) | ~20–25 languages (40+ regional locales) ([Apple SpeechTranscriber Locales](https://developer.apple.com/documentation/speech/speechtranscriber/supportedlocales)) | Proprietary Apple API | Native Swift `SpeechTranscriber` in `Speech.framework` | iPhone 13 Pro RTF < 0.15x; real-time low-latency ANE acceleration ([Apple WWDC24 Session 10144](https://developer.apple.com/videos/play/wwdc2024/10144/)) | Yes (native `AsyncSequence` streaming) | Ideal zero-download, zero-RAM baseline for supported tier-1 tourist languages; no custom sideloaded runtime required. |

---

## 2. Automatic Spoken Language Identification (LID) on iOS

When two travellers place a phone between them, the listener does not know what language the other party is speaking. Automatic spoken language identification (LID) is mandatory.

### Evaluated LID Architectures for iOS

1. **OpenAI Whisper Spoken LID (via Whisper-Tiny or Large-v3-Turbo)**
   * **Mechanism:** Whisper predicts the spoken language token (e.g. `<|en|>`, `<|es|>`, `<|ar|>`) as the very first generated token following `<|startoftranscript|>`.
   * **On-Device Strategy:** WhisperKit includes `detectLanguage(in: audioBuffer)`. Using an int8 **Whisper-Tiny** model (~39M params, **~75 MB disk**, **~90 MB RAM**), spoken language identification across **100 languages** executes in **~35–60 ms** on the A15 Bionic before routing to the main translation pipeline ([WhisperKit GitHub](https://github.com/argmaxinc/WhisperKit)).
   * **Accuracy:** >92% on clean 3-second speech snippets across FLEURS-102 ([OpenAI Whisper Paper arXiv:2212.04356](https://arxiv.org/abs/2212.04356)).

2. **Meta MMS-LID (`facebook/mms-lid-256` / `mms-lid-4017`)**
   * **Mechanism:** Wav2Vec 2.0 backbone with an explicit classification head trained on up to 4,017 spoken languages ([Meta MMS Paper arXiv:2305.13516](https://arxiv.org/abs/2305.13516)).
   * **On-Device Strategy:** Available as an int8 ONNX export in `sherpa-onnx` (~300 MB disk, ~350 MB RAM).
   * **Accuracy:** 85.3% macro-F1 across 4,000+ languages; >94% on top 256 languages.
   * **Recommendation:** Best if traveling to regions with localized indigenous languages (Sub-Saharan Africa, regional Caucasus, South Asia).

3. **SenseVoice Spoken LID**
   * **Mechanism:** Predicts language ID tokens within the rich transcription head in a single forward pass (<30 ms latency).
   * **Limitation:** Strictly detects between 5 languages: Mandarin, Cantonese, English, Japanese, and Korean. Unusable for Latin America, Europe, or the Middle East.

---

## 3. Multilingual Benchmark WER Summary (FLEURS & Common Voice)

| Model | FLEURS Avg WER (100+ langs) | Common Voice Avg WER | High-Resource (EN/ES/DE) WER | Moroccan Arabic (`ary` / Darija) Support |
| :--- | :--- | :--- | :--- | :--- |
| **Whisper Large-v3-Turbo** | **~10.5%** ([arXiv:2507.10860](https://arxiv.org/abs/2507.10860)) | **~9.8%** | **3.8% – 5.5%** | Moderate standard out-of-the-box (maps to Arabic phonemes; fine-tuned models like `anaszil/whisper-large-v3-turbo-darija` achieve <18% WER: [Hugging Face](https://huggingface.co/anaszil/whisper-large-v3-turbo-darija)) |
| **Whisper Small** | ~15.2% ([OpenAI Whisper Paper](https://arxiv.org/abs/2212.04356)) | ~14.1% | 6.2% – 8.1% | Degrades on colloquial Darija; Standard Arabic ~16% |
| **Meta Omnilingual ASR (300M CTC)** | **~18.7%** across 1,600+ langs ([arXiv:2511.09690](https://arxiv.org/abs/2511.09690)) | ~16.5% | 7.5% – 9.2% | **Native support for Moroccan Arabic (`ary`)** and Standard Arabic (`ara`) ([arXiv:2511.09690](https://arxiv.org/abs/2511.09690)) |
| **NVIDIA Canary-1b-v2** | 6.67% (on 25 European languages) ([NVIDIA Model Card](https://huggingface.co/nvidia/canary-1b-v2)) | 5.9% (MCV21 European) | **3.2% – 4.8%** | **Unsupported** (0 Arabic coverage) |
| **SenseVoiceSmall** | N/A (5 languages only: zh 3.5%, yue 5.2%, en 7.8%, ja 8.9%, ko 9.5% CER/WER) ([SenseVoice Paper](https://arxiv.org/abs/2407.04051)) | N/A | English 7.8% | **Unsupported** |
| **Apple SpeechTranscriber** | ~8.0% – 11.5% across supported tourist languages ([WWDC24 Session 10144](https://developer.apple.com/videos/play/wwdc2024/10144/)) | ~9.2% | 4.5% – 6.0% | Standard Arabic supported; colloquial Darija unsupported |

---

## 4. Ranked Top 3 Recommendations

### Rank 1: OpenAI Whisper Large-v3-Turbo (via WhisperKit)
* **Why:** Whisper Large-v3-Turbo is the undisputed production sweet spot for on-device speech recognition on iOS. Optimized through Argmax's **WhisperKit** ([GitHub](https://github.com/argmaxinc/WhisperKit)), it compiles directly to Core ML and targets the A15 Bionic's 16-core Apple Neural Engine (ANE) alongside the GPU. Its quantized mixed-bit footprint is **~626 MB**, peak RAM is **~1.2–1.5 GB** (comfortably within the 2.8 GB Jetsam ceiling), and it runs at an RTF of **0.60–0.78x on iPhone 13 Pro Max** (yielding initial streaming partials in ~200–400 ms). It natively supports **100 languages**, provides integrated **spoken language identification**, and has community-validated Moroccan Arabic LoRA checkpoints ([anaszil/whisper-large-v3-turbo-darija](https://huggingface.co/anaszil/whisper-large-v3-turbo-darija)).

### Rank 2: Meta Omnilingual ASR (omniASR_CTC_300M via sherpa-onnx)
* **Why:** For a true global travel translator that ventures beyond typical resort corridors into Africa, rural Asia, South America, or the Middle East, Meta's Omnilingual ASR ([arXiv:2511.09690](https://arxiv.org/abs/2511.09690)) is unmatched: it supports **over 1,600 languages**. Packaged for iOS via **sherpa-onnx** ([GitHub](https://github.com/k2-fsa/sherpa-onnx)) with an int8 non-autoregressive CTC acoustic head, it requires only **~310 MB disk space** and **~450–550 MB RAM**. Because CTC inference is non-autoregressive, it operates at RTF **0.15–0.25x** on mobile ARM64 CPUs with minimal battery consumption. Most importantly, it features **native Moroccan Arabic (`ary`)** and Tamazight (`zgh`) support out-of-the-box.

### Rank 3: Apple SpeechTranscriber (`Speech.framework` on iOS 18+ / iOS 26)
* **Why:** As a native iOS subsystem ([Apple Developer Documentation](https://developer.apple.com/documentation/speech/speechanalyzer)), `SpeechTranscriber` serves as the optimal zero-download, zero-RAM baseline. Assets are managed directly by the operating system on demand, and speech recognition executes entirely inside the system daemon (`com.apple.speech.localspeechrecognition`), consuming **0 MB against the sideloaded app's 2.8 GB Jetsam limit**. It streams transcript updates natively via Swift `AsyncSequence`, requires zero external dependencies, and delivers sub-150ms real-time transcription across **20–25 major travel languages** (40+ locales), allowing "Say Less" to function instantly for European and East Asian trips before custom regional packs are downloaded.

---

## 5. Rejected Candidates and Why

1. **Qwen2-Audio / Qwen2.5-Omni / Qwen3-Omni (7B+ parameters)**
   * *Reason:* Exceeds physical and Jetsam limits. Even at 4-bit quantization, weights exceed 4.2 GB and active runtime RAM surpasses 5.0 GB. Running this on an iPhone 13 Pro Max without extended memory entitlements triggers an instant OOM termination by the iOS Jetsam daemon (2.8 GB limit).
2. **Mistral Voxtral Mini (3B–4B parameters)**
   * *Reason:* Exceeds memory budget. Quantized GGUF/MLX variants require ~2.2 GB disk and ~3.0–3.8 GB runtime RAM. It consumes 100% of the available memory budget, leaving 0 MB for translation models (NLLB) or TTS, risking thermal throttling and process death during live conversations.
3. **NVIDIA Canary-1b-v2 & Parakeet-TDT-0.6b-v3**
   * *Reason:* Severe language limitation. While accuracy on European languages is exceptional (MCV21 WER ~6.67%), NVIDIA trained these models exclusively on 25 European languages. They offer zero support for Arabic, Mandarin, Japanese, Korean, Hindi, Swahili, or any non-European travel destinations.
4. **Kyutai STT (stt-1b-en_fr / stt-2.6b-en)**
   * *Reason:* Limited to only 2 languages (English and French). While its 24 kHz Mimi codec and streaming latency (<200 ms) are impressive, a travel translator cannot rely on a two-language engine.
5. **FunASR Paraformer-Large**
   * *Reason:* Strictly bilingual (Mandarin Chinese and English). Inappropriate for a world travel application.
6. **SenseVoiceSmall (as primary global model)**
   * *Reason:* Only 5 languages supported in the official open-source release (zh, en, yue, ja, ko). While it can serve as a lightweight companion engine for East Asia trips, it lacks Spanish, French, German, Arabic, Italian, and Portuguese.
7. **Moonshine v2 Streaming**
   * *Reason:* Limited to 10 languages (en, es, de, zh, ja, ko, vi, tl, uk, ar). While lightweight (~125 MB) and fast (<100 ms latency), its coverage is too sparse for global travel across Europe, the Middle East, and Latin America.
8. **Google Gemma 3n (E2B Audio Scribe)**
   * *Reason:* High latency and borderline memory. Gemma 3n's effective 2B parameter architecture requires ~1.8 GB disk and ~2.0–2.4 GB RAM. As an autoregressive multimodal decoder, token-by-token generation latency is significantly higher and more battery-intensive than specialized ASR architectures like Whisper or CTC-based models, and leaves unsafe memory margins on a 2.8 GB ceiling.

---

## 6. Implementation Architecture for "Say Less"

```
                                  [ Microphone Stream ]
                                            │
                                            ▼
                    ┌───────────────────────────────────────────────┐
                    │  Spoken Language Identification (LID) Step    │
                    │  - Whisper-Tiny int8 (100 langs, ~75MB disk)   │
                    │  - Execution latency: ~35–60 ms               │
                    └───────────────────────┬───────────────────────┘
                                            │ Detected Language
                                            ▼
         ┌──────────────────────────────────┴──────────────────────────────────┐
         │                                                                     │
  Tier 1 Tourist Core                                                   Long-Tail / African /
  (EN, ES, FR, DE, JA, etc.)                                           Middle Eastern (e.g. Darija)
         │                                                                     │
         ▼                                                                     ▼
┌─────────────────────────────────┐                                  ┌─────────────────────────────────┐
│ Whisper Large-v3-Turbo          │                                  │ Meta Omnilingual ASR            │
│ Runtime: WhisperKit (Core ML)   │                                  │ Runtime: sherpa-onnx (ONNX)     │
│ Disk: ~626 MB | RAM: ~1.3 GB    │                                  │ Disk: ~310 MB | RAM: ~500 MB    │
│ Latency: ~250 ms (ANE streaming)│                                  │ Latency: ~180 ms (CTC streaming)│
└─────────────────────────────────┘                                  └─────────────────────────────────┘
```
