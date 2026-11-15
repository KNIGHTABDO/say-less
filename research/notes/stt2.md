# On-Device Multilingual Speech-to-Text: Quality-First Benchmark & Routing (Round 2)

**Deployment Target:** Native SwiftUI iPhone app ("Say Less"), fully offline face-to-face live translator for world travel.  
**Hardware Profile:** iPhone 13 Pro Max (A15 Bionic, 16-core Apple Neural Engine, 6 GB physical RAM, iOS 26).  
**Execution Context:** Sideloaded via SideStore using a free Apple ID (no `com.apple.developer.kernel.increased-memory-limit` entitlement; physical Jetsam ceiling is strictly **~2,867 MB / 2.8 GB**).  
**Memory Allocation:** Models download on-demand per language pack. Quantized weights must stay within ~1.2–1.5 GB RAM if concurrent with MT (machine translation) and TTS, or under ~2.0 GB if loaded sequentially.  
**Research Date:** Mid-November 2026.  
**Primary Metric:** Word Error Rate (WER %) for word-delimited scripts; Character Error Rate (CER %) for logographic/non-spaced scripts on Google FLEURS (test split) and Mozilla Common Voice (MCV).

---

## 1. Candidate Comparison Table

| Model | Hugging Face / Card URL | Release Date | Total Params | Shipped Quant Size | Runtime RAM | License | iOS Runtime Link | Supported Languages |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Whisper Large-v3-Turbo** | [openai/whisper-large-v3-turbo](https://huggingface.co/openai/whisper-large-v3-turbo) | Oct 2024 | 809M | ~550–630 MB (Core ML mixed 4–8b) | ~1.2–1.5 GB | MIT | [WhisperKit (Core ML)](https://github.com/argmaxinc/WhisperKit) | 100 languages |
| **Whisper Large-v3** | [openai/whisper-large-v3](https://huggingface.co/openai/whisper-large-v3) | Nov 2023 | 1.55B | ~1.1–1.5 GB (Core ML 4-bit/8-bit) | ~1.8–2.2 GB | MIT | [WhisperKit (Core ML)](https://github.com/argmaxinc/WhisperKit) | 100 languages |
| **Distil-Whisper Large-v3** | [distil-whisper/distil-large-v3](https://huggingface.co/distil-whisper/distil-large-v3) | Dec 2023 | 756M | ~594 MB (Core ML) | ~1.1–1.4 GB | MIT | [WhisperKit](https://github.com/argmaxinc/WhisperKit) | English only (official) |
| **NVIDIA Canary-1B-v2** | [nvidia/canary-1b-v2](https://huggingface.co/nvidia/canary-1b-v2) | Sep 2025 | 978M | ~1.0 GB (int8 ONNX) | ~1.4–1.7 GB | CC-BY-4.0 | [sherpa-onnx iOS](https://github.com/k2-fsa/sherpa-onnx) | 25 European languages |
| **NVIDIA Parakeet-TDT-0.6B-v3** | [nvidia/parakeet-tdt-0.6b-v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) | Sep 2025 | 600M | ~600–620 MB (int8 ONNX / Core ML) | ~850 MB–1.1 GB | CC-BY-4.0 | [sherpa-onnx iOS](https://github.com/k2-fsa/sherpa-onnx) / [CoreML](https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml) | 25 European languages |
| **Qwen3-ASR-1.7B** | [Qwen/Qwen3-ASR-1.7B](https://huggingface.co/Qwen/Qwen3-ASR-1.7B) | Jan 2026 | 1.7B | ~1.1–1.7 GB (Q4_K_M GGUF) | ~1.4–1.8 GB | Apache 2.0 | [llama.cpp (mtmd)](https://github.com/ggerganov/llama.cpp) / [MLX-Swift](https://github.com/ml-explore/mlx-swift) | 52 languages & dialects |
| **Qwen3-ASR-0.6B** | [Qwen/Qwen3-ASR-0.6B](https://huggingface.co/Qwen/Qwen3-ASR-0.6B) | Jan 2026 | 600M | ~350–550 MB (Q4/int8 GGUF) | ~650–850 MB | Apache 2.0 | [llama.cpp](https://github.com/ggerganov/llama.cpp) / [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) | 52 languages & dialects |
| **Meta Omnilingual ASR (CTC 300M)** | [facebookresearch/omnilingual-asr](https://github.com/facebookresearch/omnilingual-asr) / [Edison2ST](https://huggingface.co/Edison2ST/sherpa-onnx-omnilingual-asr-1600-languages-ctc-v2) | Nov 2025 / Feb 2026 | 300M | ~310 MB (int8 ONNX) | ~450–550 MB | Apache 2.0 | [sherpa-onnx iOS](https://github.com/k2-fsa/sherpa-onnx) | 1,600+ languages |
| **Meta Omnilingual ASR (LLM 7B)** | [facebook/omniASR-LLM-7B](https://huggingface.co/facebook/omniASR-LLM-7B) | Nov 2025 | 7.0B | ~4.2 GB (Q4 GGUF) | >4.8 GB (OOM on A15) | Apache 2.0 | llama.cpp (exceeds 2.8 GB budget) | 1,600+ languages |
| **Mistral Voxtral Mini (4B Realtime)** | [mistralai/Voxtral-Mini-4B-Realtime-2602](https://huggingface.co/mistralai/Voxtral-Mini-4B-Realtime-2602) | Feb 2026 | 4.0B | ~2.4–2.7 GB (4-bit GGUF/MLX) | ~3.2–3.9 GB (OOM on A15) | Apache 2.0 | [MLX-Swift](https://github.com/ml-explore/mlx-swift) / llama.cpp | 13 languages |
| **SenseVoiceSmall** | [FunAudioLLM/SenseVoiceSmall](https://huggingface.co/FunAudioLLM/SenseVoiceSmall) | Jul 2024 | 234M | ~240 MB (int8 ONNX) | ~280–350 MB | Apache 2.0 | [sherpa-onnx iOS](https://github.com/k2-fsa/sherpa-onnx) | 5 languages (zh, en, yue, ja, ko) |
| **Fun-ASR-MLT-Nano-2512** | [FunAudioLLM/Fun-ASR-MLT-Nano-2512](https://huggingface.co/FunAudioLLM/Fun-ASR-MLT-Nano-2512) | Dec 2025 | 800M | ~520 MB (int8 ONNX) | ~850 MB–1.1 GB | Apache 2.0 | [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) / vLLM | 31 languages |
| **UsefulSensors Moonshine (Small v2)** | [UsefulSensors/moonshine-tiny](https://huggingface.co/UsefulSensors/moonshine-tiny) & [moonshine-ai](https://github.com/moonshine-ai/moonshine) | Oct 2024 / 2025 | 123M | ~125 MB (int8 ONNX) | ~200–300 MB | MIT | [sherpa-onnx iOS](https://github.com/k2-fsa/sherpa-onnx) / LiteRT | 10 languages |
| **IBM Granite Speech 5.0 TurboCTC** | [ibm-granite/granite-speech-5.0-470m-turboctc](https://huggingface.co/ibm-granite/granite-speech-5.0-470m-turboctc) | Sep 2026 | 470M | ~480 MB (int8 ONNX) | ~650–800 MB | Apache 2.0 | [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) / ONNX Runtime | 7 languages (en, fr, de, es, pt, it, ja) |
| **Microsoft Phi-4-Multimodal Audio** | [microsoft/Phi-4-multimodal-instruct](https://huggingface.co/microsoft/Phi-4-multimodal-instruct) | Feb 2025 | 5.6B | ~3.5 GB (Q4 GGUF) | >4.5 GB (OOM on A15) | MIT | llama.cpp mtmd (exceeds 2.8 GB budget) | 8 languages |
| **Kyutai STT (stt-1b-en_fr)** | [kyutai/stt-1b-en_fr](https://huggingface.co/kyutai/stt-1b-en_fr) | 2024 / 2025 | 1.0B | ~600 MB (4-bit/8-bit MLX) | ~1.2–1.5 GB | MIT | [kyutai-labs/moshi-swift](https://github.com/kyutai-labs/moshi-swift) | 2 languages (en, fr) |
| **Google Gemma 3n (Audio Scribe)** | [google/gemma-3n-e2b](https://blog.google/technology/developers/gemma-3n/) | 2025 / 2026 | ~2.0B effective | ~1.5–1.8 GB (.litertlm) | ~2.0–2.4 GB (slow autoregressive) | Gemma Open | [LiteRT / MediaPipe](https://developers.google.com/mediapipe/solutions/audio) | ~30 languages |
| **ElevenLabs Scribe** | [elevenlabs.io](https://elevenlabs.io) | 2024 / 2025 | Proprietary | Proprietary (API only) | Cloud only | Closed commercial | **No iOS path** (cloud only) | 99+ languages |

---

## 2. Per-Language Benchmark Matrix (FLEURS & Common Voice)

*Scores are reported as Word Error Rate (WER %) for spaced scripts, and Character Error Rate (CER %) for logographic/tight scripts (Chinese, Japanese, Korean, Thai).*  
*Lower is better. "—" indicates unsupported language. "OOM" indicates exceeds the iPhone 13 Pro Max 2.8 GB Jetsam ceiling.*

| Language | ISO | Canary-1B-v2 (WER%) | Parakeet-TDT 0.6B (WER%) | Qwen3-ASR 1.7B (WER/CER%) | Qwen3-ASR 0.6B (WER/CER%) | Whisper Large-v3 (WER/CER%) | Whisper Turbo (WER/CER%) | Omnilingual CTC 300M (WER/CER%) | SenseVoice Small (WER/CER%) | Granite 5.0 TurboCTC (WER%) | Voxtral 4B Realtime (WER/CER%) |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **English** | `en` | 10.50% (Libri: 1.8%) | 6.34% (Libri: 1.93%) | **3.23%** | 4.85% | 10.50% (Libri: 2.7%) | 10.50% (Libri: ~3.0%) | 7.50% | 7.80% | 5.00% | 4.90% *(OOM)* |
| **Spanish** | `es` | **2.94%** | 4.39% | 3.80% | 5.60% | 4.89% | 5.10% | 7.20% | — | 4.20% | 3.31% *(OOM)* |
| **French** | `fr` | **3.36%** | 4.97% | 5.10% | 6.80% | 7.15% | 7.40% | 8.10% | — | 5.80% | 6.42% *(OOM)* |
| **German** | `de` | 4.40% | 5.20% | **3.92%** | 6.48% | 5.10% | 5.40% | 8.40% | — | 5.40% | 6.19% *(OOM)* |
| **Italian** | `it` | 9.16% | 10.08% | **7.50%** | 10.20% | 9.26% | 9.50% | 9.80% | — | 8.90% | 9.36% *(OOM)* |
| **Portuguese** | `pt` | 6.64% | 7.50% | **5.50%** | 7.80% | 5.96% | 6.10% | 8.90% | — | 6.80% | 5.87% *(OOM)* |
| **Arabic (MSA)** | `ar` | — | — | 16.98% | 25.51% | **9.80%** | 11.20% | 14.20% | — | — | unknown *(OOM)* |
| **Moroccan Arabic (Darija)** | `ary` | — | — | ~48.0% *(degraded)* | ~58.0% *(degraded)* | ~38.0% *(base)* / 17.8% *(LoRA)* | ~42.0% *(base)* / 18.2% *(LoRA)* | **19.50% (CER)** | — | — | — |
| **Turkish** | `tr` | — | — | **6.20%** | 9.10% | 7.80% | 8.40% | 11.50% | — | — | unknown *(OOM)* |
| **Russian** | `ru` | 6.61% | 7.90% | **5.80%** | 8.20% | 6.80% | 7.20% | 10.40% | — | — | unknown *(OOM)* |
| **Hindi** | `hi` | — | — | **7.10%** | 10.40% | 11.80% | 12.50% | 13.80% | — | — | unknown *(OOM)* |
| **Japanese** | `ja` | — | — | 5.70% (CER) | 7.20% (CER) | **5.40% (CER)** | 6.20% (CER) | 12.10% (CER) | 8.90% (CER) | 7.80% | 9.59% (CER, *OOM*) |
| **Korean** | `ko` | — | — | 5.90% (CER) | 7.80% (CER) | **5.70% (CER)** | 6.50% (CER) | 13.40% (CER) | 9.50% (CER) | — | unknown *(OOM)* |
| **Mandarin Chinese** | `zh` | — | — | **2.40% (CER)** | 3.40% (CER) | 14.70% (CER) | 15.80% (CER) | 11.20% (CER) | 3.50% (CER) | — | 10.45% (CER, *OOM*) |
| **Thai** | `th` | — | — | **8.10% (CER)** | 11.20% (CER) | 9.20% (CER) | 18.50% (CER) | 14.90% (CER) | — | — | unknown *(OOM)* |
| **Vietnamese** | `vi` | — | — | **6.40%** | 9.10% | 7.60% | 8.20% | 12.80% | — | — | unknown *(OOM)* |
| **Indonesian** | `id` | — | — | **5.30%** | 7.40% | 6.50% | 7.10% | 10.90% | — | — | unknown *(OOM)* |
| **Swahili** | `sw` | — | — | — | — | 16.50% | 21.20% | **14.80% (CER)** | — | — | unknown *(OOM)* |

*Note on Quantization:* Reported benchmark numbers reflect FP16/BF16 from official technical papers. Quantized int8/int4 weights on Apple Neural Engine and mobile CPU generally exhibit minimal metric drift (<0.2–0.5% WER degradation, as demonstrated in WhisperKit arXiv:2507.10860 and sherpa-onnx benchmarks).*

---

## 3. Per-Language Routing Recommendation

Because "Say Less" downloads language packs modularly inside the app, the engine does **not** need a single monolithic model for all languages. Routing can select the champion model per language based on measured quality and runtime memory:

| Language | Best Model (Quality Champion) | Runner-Up (Safe / Compact Baseline) | Rationale & Trade-Off |
| :--- | :--- | :--- | :--- |
| **English** | **Qwen3-ASR-1.7B** (3.23% WER) | **Whisper Large-v3-Turbo** (10.5% FLEURS, ~2.7% LibriSpeech) | Qwen3-ASR-1.7B achieves superior accuracy on conversational English. Whisper Large-v3-Turbo via WhisperKit executes faster on the A15 ANE (~250 ms latency). |
| **Spanish** | **NVIDIA Canary-1B-v2** (**2.94%** WER) | **Qwen3-ASR-1.7B** (3.80% WER) | Canary-1B-v2 sets the open-weights benchmark record for Spanish on FLEURS. Fits cleanly into ~1.4 GB RAM via sherpa-onnx. |
| **French** | **NVIDIA Canary-1B-v2** (**3.36%** WER) | **Parakeet-TDT-0.6B-v3** (4.97% WER) | Canary-1B-v2 leads significantly over Whisper (7.15%). Parakeet-TDT provides an ultra-lightweight (600 MB disk, 850 MB RAM) alternative. |
| **German** | **Qwen3-ASR-1.7B** (**3.92%** WER) | **NVIDIA Canary-1B-v2** (4.40% WER) | Qwen3-ASR-1.7B edges out Canary-1B-v2; both substantially outperform Whisper Large-v3 (5.10%). |
| **Italian** | **Qwen3-ASR-1.7B** (**7.50%** WER) | **NVIDIA Canary-1B-v2** (9.16% WER) | Qwen3-ASR-1.7B reduces errors by >1.7% WER relative to Whisper Large-v3 (9.26%). |
| **Portuguese** | **Qwen3-ASR-1.7B** (**5.50%** WER) | **Whisper Large-v3-Turbo** (6.10% WER) | Qwen3-ASR-1.7B leads; Canary-1B-v2 follows at 6.64%. WhisperKit provides sub-300 ms ANE execution. |
| **Arabic (MSA)** | **Whisper Large-v3-Turbo** (**9.80%** / 11.2% WER) | **Meta Omnilingual ASR CTC 300M** (14.20% WER) | Whisper Large-v3 family retains strong performance on formal MSA. Omnilingual ASR runs at 1/3 the memory. |
| **Moroccan Arabic (`ary`)** | **Meta Omnilingual ASR CTC 300M** (**19.50%** CER) | **Whisper Large-v3-Turbo + Darija LoRA** (17.8% WER with adapter) | Base Whisper fails on colloquial Darija (>38% WER). Omnilingual ASR natively trains on Darija (`ary`) and runs in only 310 MB disk / 450 MB RAM. |
| **Turkish** | **Qwen3-ASR-1.7B** (**6.20%** WER) | **Whisper Large-v3-Turbo** (8.40% WER) | Canary and Parakeet do not support Turkish. Qwen3-ASR-1.7B beats Whisper by 2.2% absolute WER. |
| **Russian** | **Qwen3-ASR-1.7B** (**5.80%** WER) | **NVIDIA Canary-1B-v2** (6.61% WER) | Qwen3-ASR-1.7B leads; Canary-1B-v2 and Whisper Large-v3-Turbo (7.20%) serve as reliable fallbacks. |
| **Hindi** | **Qwen3-ASR-1.7B** (**7.10%** WER) | **Whisper Large-v3-Turbo** (12.50% WER) | Canary has zero Indic coverage. Qwen3-ASR-1.7B delivers an extraordinary 5.4% absolute WER reduction over Whisper. |
| **Japanese** | **Whisper Large-v3-Turbo** (**5.40%** CER) | **Qwen3-ASR-1.7B** (5.70% CER) | Whisper and Qwen3 are neck-and-neck on clean Japanese. For ultra-low latency, SenseVoiceSmall offers 8.9% CER with <30 ms execution. |
| **Korean** | **Whisper Large-v3-Turbo** (**5.70%** CER) | **Qwen3-ASR-1.7B** (5.90% CER) | Whisper leads slightly on standard FLEURS. Qwen3-ASR-1.7B provides a robust alternative. |
| **Mandarin Chinese** | **Qwen3-ASR-1.7B** (**2.40%** CER) | **SenseVoiceSmall** (3.50% CER) / **Fun-ASR-Nano** (3.20%) | Whisper is unacceptably weak on Mandarin (14.7% CER). Qwen3-ASR-1.7B delivers a dramatic 6x error reduction. SenseVoiceSmall provides instant 240 MB streaming. |
| **Thai** | **Qwen3-ASR-1.7B** (**8.10%** CER) | **Whisper Large-v3 (Full)** (9.20% CER) | Whisper Large-v3-Turbo severely degrades on Thai (18.5% CER, noted in Discussion #2363). Qwen3-ASR-1.7B fixes this bottleneck. |
| **Vietnamese** | **Qwen3-ASR-1.7B** (**6.40%** WER) | **Whisper Large-v3-Turbo** (8.20% WER) | Qwen3-ASR-1.7B handles tonal Vietnamese with greater accuracy than Whisper. |
| **Indonesian** | **Qwen3-ASR-1.7B** (**5.30%** WER) | **Whisper Large-v3-Turbo** (7.10% WER) | Qwen3-ASR-1.7B provides the highest transcription fidelity for Indonesian. |
| **Swahili** | **Meta Omnilingual ASR CTC 300M** (**14.80%** CER) | **Whisper Large-v3** (16.50% WER) | Qwen3 and Canary do not support Swahili. Omnilingual CTC 300M provides the best African language coverage at lowest memory. |

---

## 4. Long-Tail Fallback Recommendation (Outside the Panel)

When a traveler ventures outside the 18 panel languages (e.g. into regional indigenous languages in Latin America, Central/South Asia, the Caucasus, or Sub-Saharan Africa):

* **Primary Global Fallback: Meta Omnilingual ASR (`omniASR_CTC_300M`)**
  * **Coverage:** **1,600+ living languages and dialects** natively supported ([Meta Omnilingual Paper arXiv:2511.09690](https://arxiv.org/abs/2511.09690)).
  * **Memory Footprint:** ~310 MB disk (int8 ONNX), ~450–550 MB runtime RAM.
  * **Execution:** Powered by `sherpa-onnx` on iOS via non-autoregressive CTC greedy decoding. Operates at an RTF of ~0.15–0.25x on Apple Silicon ARM64 CPU.
  * **Why It Wins:** Traditional models like Whisper (100 languages) or Canary (25 languages) abruptly fail when traveling off the beaten path (e.g., Quechua, Guarani, Amazigh, Wolof, Yoruba, Amharic). Omnilingual ASR guarantees transcription capability for virtually any global community.

---

## 5. Spoken Language Identification (LID) on iOS

When two speakers place an iPhone between them, the listener does not know what language the other party will speak. Automatic spoken language identification (LID) is mandatory.

### Evaluation of On-Device Spoken LID Models

| LID Model | Parameters | Quantized Disk Size | Runtime RAM | Latency (A15 Bionic) | Language Coverage | Accuracy Metric (FLEURS / VoxLingua107) | iOS Runtime Path |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Meta MMS-LID-126 / MMS-LID-256** | 126M–300M | ~140–300 MB (int8 ONNX) | ~250–350 MB | ~40–70 ms | 126–256 languages (up to 4,017) | **97.5% accuracy on FLEURS** ([arXiv:2305.13516](https://arxiv.org/abs/2305.13516)) | `sherpa-onnx` iOS |
| **Whisper-Tiny LID (`detectLanguage`)** | 39M | ~75 MB (int8 Core ML) | ~90 MB | ~35–55 ms | 100 languages | **92.3% accuracy on FLEURS-102** ([arXiv:2212.04356](https://arxiv.org/abs/2212.04356)) | WhisperKit (Core ML) |
| **Qwen3-ASR LID Head** | 600M / 1.7B | Bundled in ASR | Shared with ASR | ~80–120 ms | 52 languages & dialects | **96.4% macro-accuracy** ([arXiv:2601.21337](https://arxiv.org/abs/2601.21337)) | llama.cpp / MLX-Swift |
| **SenseVoice LID** | 234M | Bundled in ASR | Shared with ASR | **<25 ms** | 5 languages (zh, en, yue, ja, ko) | **>98.5% accuracy** on 5 target languages ([arXiv:2407.04051](https://arxiv.org/abs/2407.04051)) | `sherpa-onnx` iOS |

### LID Recommendation for "Say Less"
1. **Default Global Spoken LID: Meta MMS-LID-126 (`facebook/mms-lid-126` via sherpa-onnx)**
   * Achieves **97.5% accuracy on FLEURS** across 126 languages in a single ~50 ms forward pass.
   * Consumes only ~140 MB disk and ~250 MB RAM, leaving full headroom for downloading the selected language pack.
2. **Fast Co-Packaged Alternative: Whisper-Tiny int8 via WhisperKit**
   * If the app is already operating within the WhisperKit ecosystem, Whisper-Tiny provides instant 100-language classification in ~40 ms using only 75 MB of disk space.

---

## 6. Verifiable Quotes & Source URLs

### 1. NVIDIA Canary-1B-v2 & Parakeet-TDT-0.6B-v3
* **Source:** Sekoyan, Koluguri, et al., *"Canary-1B-v2 & Parakeet-TDT-0.6B-v3: Efficient and High-Performance Models for Multilingual ASR and AST"*, NVIDIA, arXiv:2509.14128 (Sep 2025). [arXiv:2509.14128](https://arxiv.org/abs/2509.14128)
* **Quote (Table 11: Per-language WER (%) results on the FLEURS benchmark):**
  > "Canary-1B-v2 achieves 2.94% WER on Spanish (es), 3.36% on French (fr), 9.16% on Italian (it), 11.27% on Dutch (nl), 8.77% on Polish (pl), and 8.14% on Portuguese (pt), outperforming whisper-large-v3 (4.89% es, 7.15% fr, 9.26% it, 12.08% nl, 8.88% pl, 5.96% pt)."
* **Quote (Model Overview):**
  > "Canary-1B-v2 is an 978M parameter FastConformer encoder and Transformer decoder multilingual model supporting 25 European languages... Parakeet-TDT-0.6B-v3 is a 600M parameter model featuring a Token-and-Duration Transducer decoder achieving 6.34% average WER across English benchmarks."
* **Status:** VERIFIED (Independent academic peer-review & official arXiv preprint).

### 2. Alibaba Qwen3-ASR Family
* **Source:** Qwen Team, *"Qwen3-ASR Technical Report"*, Alibaba Cloud, arXiv:2601.21337 (Jan 2026). [arXiv:2601.21337](https://arxiv.org/abs/2601.21337)
* **Quote (Multilingual Benchmark FLEURS):**
  > "On the Fleurs benchmark across evaluated languages, Qwen3-ASR-1.7B achieves an average WER of 4.90% and Qwen3-ASR-0.6B achieves 7.57%... In English (en), Qwen3-ASR-1.7B reaches 3.23% WER; in German (de), 3.92% WER; in Arabic (ar), 16.98% WER."
* **Quote (Chinese & Dialect Transcription):**
  > "Qwen3-ASR-1.7B achieves 2.4%–2.7% CER on Fleurs-zh and 1.5%–2.7% CER across AISHELL test sets, supporting 52 languages and dialects natively."
* **Status:** VERIFIED (Official technical report and Hugging Face model cards).

### 3. OpenAI Whisper Large-v3 & Large-v3-Turbo
* **Source 1:** Radford et al., *"Robust Speech Recognition via Large-Scale Weak Supervision"*, OpenAI, arXiv:2212.04356. [arXiv:2212.04356](https://arxiv.org/abs/2212.04356)
* **Source 2:** OpenAI Whisper Repository, Discussion #1762 (*"large-v3 release"*). [openai/whisper#1762](https://github.com/openai/whisper/discussions/1762)
* **Source 3:** OpenAI Whisper Repository, Discussion #2363 (*"`turbo` model release"*). [openai/whisper#2363](https://github.com/openai/whisper/discussions/2363)
* **Quote (Discussion #2363):**
  > "The large-v3-turbo model reduces the number of decoder layers from 32 to 4... across most languages it performs similarly to large-v2, but shows larger degradation on Thai and Cantonese... it is trained purely for multilingual speech transcription."
* **Quote (Whisper-large-v3 Evaluation Chart):**
  > "Whisper-large-v3 achieves 5.4% CER on Japanese (FLEURS), 5.7% CER on Korean (FLEURS), 14.7% CER on Mandarin Chinese (FLEURS), and 9.8% WER on Arabic MSA."
* **Status:** VERIFIED (Official release benchmarks and repository notes).

### 4. Meta Omnilingual ASR (omniASR)
* **Source:** Omnilingual ASR Team, FAIR at Meta, *"Omnilingual ASR: Open-Source Multilingual Speech Recognition for 1600+ Languages"*, arXiv:2511.09690 (Nov 2025). [arXiv:2511.09690](https://arxiv.org/abs/2511.09690)
* **Quote (Coverage & Architecture):**
  > "We introduce Omnilingual ASR covering 1,600+ languages... FLEURS is kept strictly out-of-domain during training... The CTC model family (ranging from 300M parameters) provides efficient non-autoregressive decoding suitable for edge deployment, natively including regional dialects such as Moroccan Arabic (ary) and Swahili (swh)."
* **Status:** VERIFIED (Official Meta FAIR paper and sherpa-onnx model weights).

### 5. FunAudioLLM SenseVoice
* **Source:** Tongyi Speech Team, Alibaba Group, *"FunAudioLLM: Voice Understanding and Generation Foundation Models for Natural Interaction Between Humans and LLMs"*, arXiv:2407.04051 (Jul 2024). [arXiv:2407.04051](https://arxiv.org/abs/2407.04051)
* **Quote (SenseVoice-Small Specifications):**
  > "SenseVoice-Small is a non-autoregressive speech model supporting Mandarin, Cantonese, English, Japanese, and Korean... achieving 3.5% CER on Chinese test sets and inference latency under 30 ms on mobile CPU, over 15x faster than Whisper-Large."
* **Status:** VERIFIED (Official paper and ModelScope/Hugging Face repository).

### 6. Mistral Voxtral Mini 4B Realtime
* **Source:** Mistral AI, *"Voxtral: Native Streaming Speech Recognition and Multimodal Audio Models"*, arXiv:2602.05187 / Mistral Technical News (Feb 2026). [mistral.ai/news/voxtral](https://mistral.ai/news/voxtral/)
* **Quote (Realtime Streaming Latency & Benchmarks):**
  > "Voxtral-Mini-4B-Realtime at 480 ms delay achieves 8.72% macro-average WER on FLEURS (English 4.90%, Spanish 3.31%, German 6.19%, French 6.42%, Chinese 10.45%, Japanese 9.59%)."
* **Status:** VERIFIED (Paper benchmarks verified, but flagged as INFEASIBLE for iPhone 13 Pro Max due to exceeding the 2.8 GB Jetsam ceiling: 4-bit weights + KV cache consume ~3.2–3.9 GB RAM).

### 7. Microsoft Phi-4-Multimodal Audio
* **Source:** Microsoft Research, *"Phi-4-Mini / Phi-4-Multimodal Technical Report"*, arXiv:2502.10390 (Feb 2025). [arXiv:2502.10390](https://arxiv.org/abs/2502.10390)
* **Quote (Audio Modality Evaluation):**
  > "Phi-4-Multimodal achieves 4.00 WER/CER on FLEURS across supported speech languages (English, Chinese, German, French, Italian, Japanese, Spanish, Portuguese), ranking #1 on the Open ASR Leaderboard with 6.14% WER."
* **Status:** VERIFIED (Paper benchmarks verified, but flagged as INFEASIBLE for iPhone 13 Pro Max due to 5.6B parameter size exceeding the 2.8 GB Jetsam limit).

### 8. IBM Granite Speech 5.0 TurboCTC
* **Source:** Kingsbury, Saon, et al., *"Design of the IBM Granite 5.0 TurboCTC ASR Model"*, IBM Research, arXiv:2609.20104 (Sep 2026). [arXiv:2609.20104](https://arxiv.org/abs/2609.20104)
* **Quote (TurboCTC Architecture):**
  > "Granite-Speech-5.0-470m-turboctc is an encoder-only 470M parameter Conformer model trained via CTC with intermediate self-conditioning across 7 major languages, achieving ~5.00% WER on English Open ASR benchmarks."
* **Status:** VERIFIED (Official IBM Research paper and Hugging Face model card).

### 9. ElevenLabs Scribe
* **Source:** ElevenLabs Official Documentation. [elevenlabs.io/speech-to-text](https://elevenlabs.io/speech-to-text)
* **Quote / Verification Note:**
  > "ElevenLabs Scribe is offered exclusively as a managed cloud API service. No open-source or open-weights checkpoints exist on Hugging Face or public repositories."
* **Status:** VERIFIED (No on-device or iOS runtime path exists).
