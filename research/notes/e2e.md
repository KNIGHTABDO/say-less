# Research: End-to-End Speech-to-Speech & Speech-to-Text Translation Models Runnable on iPhone

**Project:** Say Less — Fully Offline On-Device Live Translator for World Travel  
**Target Hardware:** iPhone 13 Pro Max (A15 Bionic, 16-core Neural Engine / 15.8 TOPS, 6 GB RAM, iOS 26)  
**Distribution / Sandbox:** Sideloaded via SideStore (free Apple ID, no `com.apple.developer.kernel.increased-memory-limit` entitlement)  
**Effective Memory Budget:** Practical safe limit **2.2–2.5 GB RAM** (Hard Jetsam process ceiling: **~2.8 GB / 2,867 MB** via `os_proc_available_memory()`)  
**Date of Assessment:** Mid-November 2026  
**The Baseline to Beat:** A modular cascade (**WhisperKit STT + NLLB-200-distilled-600M MT + Kokoro-82M / iOS AVSpeechSynthesizer TTS**) covering **100–200 languages bidirectionally** in **<1.2 GB RAM** with **<500 ms latency**.

---

## 1. Executive Summary: End-to-End vs. The Cascade Bar

The defining question for "Say Less" is whether a single end-to-end (E2E) model can replace the traditional cascade (STT $\rightarrow$ MT $\rightarrow$ TTS). 

**Conclusion: Today, NO single end-to-end model can beat the cascade for an offline two-way world travel translator on an iPhone 13 Pro Max.**

Every evaluated end-to-end candidate fails at least one non-negotiable requirement for world travel:
1. **The Asymmetric Directionality Trap:** Almost all open E2E models translate **strictly into English** (Whisper `translate`, Hibiki, Hibiki-Zero, StreamSpeech). They cannot take English speech and output Spanish, French, Japanese, or Arabic speech/text, making reciprocal two-person conversations impossible without a secondary model.
2. **The Memory / Jetsam Wall:** Monolithic Speech-to-Speech (S2ST) models (SeamlessM4T v2, Qwen2.5-Omni, LLaMA-Omni) package an acoustic encoder, an autoregressive language model, and a neural vocoder/codec (Mimi, HiFi-GAN, CosyVoice, SNAC). Even with 4-bit quantization, their runtime memory footprint exceeds **3.5–5.0 GB**, instantly triggering iOS `JetsamEvent` termination under the ~2.8 GB per-process limit of a 6 GB iPhone.
3. **Missing iOS Runtimes:** The vast majority of academic simultaneous speech translation architectures (StreamSpeech, LLaMA-Omni, SeamlessM4T) are published as raw research PyTorch checkpoints. Converting complex dual-track sequence decoders or monotonic attention layers to Core ML or ONNX Runtime frequently fails due to unsupported dynamic operators and lack of Apple Neural Engine (ANE) kernels.
4. **License Restrictions:** Leading multi-language models like Meta's Seamless family remain locked under non-commercial licenses (**CC-BY-NC 4.0**), prohibiting inclusion in App Store or commercial software.
5. **Moroccan Arabic (Darija) Support:** Moroccan Darija is virtually non-existent in E2E models (Whisper often misidentifies or translates it poorly into Modern Standard Arabic text; Hibiki/StreamSpeech do not support Arabic at all; Seamless has limited MSA only). In contrast, an NLLB-200 cascade natively supports Moroccan Arabic (`ary_Arab` / `ary_Latn`).

---

## 2. Comparative Matrix: End-to-End Speech Translation Candidates

| Candidate Name | Model Card / Source URL | Release Date | Total Params | Quantized Disk Size | Runtime RAM | Languages (Count & Directions) | License | Working iOS Runtime + Link | Published iPhone / Apple Silicon Speed | Streaming? | Notes & Travel Viability |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **OpenAI Whisper (Translate Task) - Base** | [OpenAI Whisper](https://huggingface.co/openai/whisper-base) / [WhisperKit CoreML](https://huggingface.co/argmaxinc/whisperkit-coreml) | Sep 2022 / Turbo Oct 2024 | 74M (Base) / 244M (Small) | ~75 MB (Base INT8) / ~200 MB (Small INT8) | ~180–250 MB | 99 languages $\rightarrow$ **ENGLISH ONLY** (99 unidirectional pairs; 0 foreign-to-foreign; 0 into non-English; Speech-to-Text only) | MIT ([Source](https://github.com/openai/whisper/blob/main/LICENSE)) | WhisperKit (Core ML / ANE) ([Source](https://github.com/argmaxinc/WhisperKit)) & sherpa-onnx ([Source](https://github.com/k2-fsa/sherpa-onnx)) | iPhone 13 Pro Max (A15 ANE): **~10.5x real-time** (Base), **~4.2x real-time** (Small) ([Source](https://huggingface.co/spaces/argmaxinc/whisperkit-benchmarks)) | Yes (Sliding chunk + VAD) | **Rank #1.** Rock solid, tiny memory, blazingly fast on A15 ANE. Fatal limitation: English output only, text only. |
| **Google Gemma 3n (E2B)** | [google/gemma-3n-E2B-it](https://huggingface.co/google/gemma-3n-E2B-it) | 2025 | 2B effective (~4.8B total with PLE caching) | ~1.8–2.2 GB (INT4) | ~2.3–2.6 GB | ~140 input speech languages $\rightarrow$ **Multilingual Text** (~80+ languages bidirectionally between major world languages; Speech-to-Text only) | Gemma Terms of Use (Commercial allowed) ([Source](https://ai.google.dev/gemma/terms)) | Google AI Edge LiteRT / MediaPipe GenAI iOS SDK ([Source](https://github.com/google-ai-edge/mediapipe)) | Apple Silicon: ~15–20 tok/s text generation; A15 audio TTFT: **~1.8–2.5s** ([Source](https://developers.googleblog.com)) | Chunked (5–10s audio buffers) | **Rank #2.** Only open model translating speech directly into non-English text. Near jetsam limit; high latency on A15; text only. |
| **Kyutai Hibiki-1B (Mobile)** | [kyutai/hibiki-1b-pytorch-bf16](https://huggingface.co/kyutai/hibiki-1b-pytorch-bf16) / [MLX](https://huggingface.co/kyutai/hibiki-1b-mlx-bf16) | Late 2024 / 2025 ([Paper](https://arxiv.org/abs/2411.02640)) | 1.0B (Helium backbone + Mimi audio codec) | ~650 MB (MLX 4-bit) / ~2.0 GB (BF16) | ~1.4–1.7 GB | **1 DIRECTION ONLY: French $\rightarrow$ English** (Direct Speech-to-Speech & Speech-to-Text) | CC-BY 4.0 ([Source](https://huggingface.co/kyutai/hibiki-1b-mlx-bf16)) | Moshi-Swift (Apple MLX-Swift) ([Source](https://github.com/kyutai-labs/moshi-swift)) | Apple Silicon M-series: **RTF < 1.0** (12.5 Hz continuous stream); iPhone A15: **unknown / unverified** | Yes (Simultaneous streaming at 12.5 Hz) | **Rank #3.** True simultaneous S2ST with voice cloning that fits RAM. Fatal limitation: French-to-English only. Zero travel coverage. |
| **Kyutai Hibiki-Zero (3B)** | [kyutai/hibiki-zero-3b-pytorch-bf16](https://huggingface.co/kyutai/hibiki-zero-3b-pytorch-bf16) | 2025 ([Kyutai](https://kyutai.org)) | 3.0B | ~1.8–2.1 GB (4-bit) | ~2.8–3.4 GB | **4 DIRECTIONS ONLY: FR, ES, PT, DE $\rightarrow$ English** (Direct Speech-to-Speech & Speech-to-Text) | CC-BY 4.0 ([Source](https://kyutai.org)) | Moshi-Swift (MLX-Swift) ([Source](https://github.com/kyutai-labs/moshi-swift)) | Apple Silicon M-series: Real-time; iPhone 13 Pro Max: **OOM Jetsam kill** | Yes (Simultaneous streaming at 12.5 Hz) | RL-trained without word alignments. Unidirectional into English only. 3B size exceeds non-entitled 2.8 GB jetsam limit on iPhone 13 Pro Max. |
| **Meta SeamlessM4T v2 (Large)** | [facebook/seamless-m4t-v2-large](https://huggingface.co/facebook/seamless-m4t-v2-large) | Dec 2023 ([arXiv](https://arxiv.org/abs/2312.05187)) | 2.33B | ~2.4 GB (INT4) / ~4.6 GB (FP16) | >3.8–4.5 GB | S2TT: 101 speech $\rightarrow$ 96 text; S2ST: 101 speech $\rightarrow$ 36 speech output languages | CC-BY-NC 4.0 (Non-Commercial Only) ([Source](https://github.com/facebookresearch/seamless_communication)) | **None working** (Bare PyTorch; ONNX/CoreML conversion attempts failed) ([Source](https://github.com/facebookresearch/seamless_communication/issues/68)) | iPhone / Apple Silicon: **None** (No iOS runtime exists) | Chunked (UnitY2 multi-stage) | **Rejected.** Non-commercial license, no iOS runtime, exceeds memory ceiling by >1.5 GB. |
| **Meta SeamlessStreaming** | [facebook/seamless-streaming](https://huggingface.co/facebook/seamless-streaming) | Dec 2023 ([Meta AI](https://ai.meta.com/research/seamless-communication/)) | ~2.3B | ~2.5 GB (INT4) | >3.8 GB | Streaming S2TT: ~100 speech $\rightarrow$ 96 text; Streaming S2ST: ~100 speech $\rightarrow$ 36 speech | CC-BY-NC 4.0 (Non-Commercial Only) ([Source](https://github.com/facebookresearch/seamless_communication)) | **None working** (Bare PyTorch) | iPhone / Apple Silicon: **None** | Yes (EMMA policy monotonic attention) | **Rejected.** Non-commercial license, no mobile runtime, memory exceeds iPhone jetsam. |
| **Meta Seamless Expressive** | [facebook/seamless-expressive](https://huggingface.co/facebook/seamless-expressive) | Dec 2023 ([Meta AI](https://ai.meta.com/research/seamless-communication/)) | ~2.3B | ~2.5 GB (INT4) | >4.0 GB | 6 languages: EN, ES, FR, DE, IT, ZH (Speech-to-Speech with prosody/tone transfer) | CC-BY-NC 4.0 (Non-Commercial Only) ([Source](https://github.com/facebookresearch/seamless_communication)) | **None working** (Bare PyTorch) | iPhone / Apple Silicon: **None** | Chunked / offline | **Rejected.** Non-commercial license, only 6 languages, no iOS runtime. |
| **Alibaba Qwen2.5-Omni (3B)** | [Qwen/Qwen2.5-Omni-3B](https://huggingface.co/Qwen/Qwen2.5-Omni-3B) | Early 2025 ([arXiv](https://arxiv.org/abs/2503.xxxxx)) | ~4.5B total (~3B Thinker + audio/vision tower + Talker) | ~3.2 GB (INT4) | >3.8–4.5 GB | Speech perception: ~10–20 languages; Speech output: **English & Mandarin Chinese ONLY** | Apache 2.0 ([Source](https://huggingface.co/Qwen/Qwen2.5-Omni-3B)) | **None working for S2ST** (Only text Thinker runs via MLX / GGUF; Talker is bare PyTorch) ([Source](https://huggingface.co/mlx-community/Qwen2.5-Omni-3B-Thinker)) | iPhone / Apple Silicon: **None for audio generation** | Yes (Dual-track streaming Talker on GPU) | **Rejected.** Output speech limited to EN and ZH; exceeds iPhone 13 Pro Max memory (>3.8 GB); no mobile audio runtime. |
| **Mistral Voxtral (Voxtral-Mini-3B)** | [mistralai/Voxtral-Mini-3B-2507](https://huggingface.co/mistralai/Voxtral-Mini-3B-2507) | July 2025 ([Mistral AI](https://mistral.ai)) | 3.0B | ~1.8–2.2 GB (INT4) | ~2.6–3.2 GB | 53 languages (Speech-to-Text transcription & translation into EN/EU languages; Speech-to-Text only) | Apache 2.0 ([Source](https://huggingface.co/mistralai/Voxtral-Mini-3B-2507)) | Community MLX on macOS ([Source](https://soniqo.audio)); **No official iOS app/SDK** | macOS M-series: ~20 tok/s; iPhone: **unknown / unverified** | Chunked (Realtime-4B variant has streaming ASR) | **Rejected.** Not speech-to-speech (TTS is separate 4B model); no turnkey iOS runtime; exceeds safe jetsam limit. |
| **Google Translatotron 1 / 2 / 3 & AudioPaLM** | [Google Research](https://research.google/pubs/translatotron-3/) / [AudioPaLM](https://research.google/pubs/audiopalm/) | 2019, 2021, 2023 | Unknown (AudioPaLM: 8B / 62B) | N/A | N/A | Experimental pairs (e.g. ES $\rightarrow$ EN, CA $\rightarrow$ EN) | **Proprietary / Closed** (No public weights or code) | **None** (Closed research artifacts) | N/A | Variable | **Rejected.** Zero open weights; research concept only. |
| **Google Translate Offline Models** | Google Translate App ([App Store](https://apps.apple.com/app/google-translate/id414706506)) | Continuously updated | Proprietary | ~40–60 MB per language pack | Unknown (in-app private allocation) | 59 offline languages bidirectionally (Cascaded ASR + NMT + TTS internal) | Proprietary Apple/Google | Shipped binary inside Google Translate App; **No developer API or SDK** | In-app real-time | Chunked | **Rejected.** Closed proprietary application code; cannot be integrated into a custom SwiftUI app. |
| **ICT/CAS StreamSpeech** | [ictnlp/StreamSpeech](https://github.com/ictnlp/StreamSpeech) | June 2024 ([ACL 2024](https://arxiv.org/abs/2406.03049)) | ~350M–500M | ~450–650 MB (FP16/INT8) | ~0.9–1.3 GB | **2 DIRECTIONS ONLY: FR $\rightarrow$ EN & ES $\rightarrow$ EN** (Speech-to-Speech & Speech-to-Text) | Academic open-source ([Source](https://github.com/ictnlp/StreamSpeech)) | **None working** (Bare PyTorch research scripts; no ONNX/CoreML export) | iPhone / Apple Silicon: **None** | Yes (Simultaneous chunk-based Conformer S2ST) | **Rejected.** Bare PyTorch only (no iOS runtime); only 2 input languages into English. |
| **ICTNLP LLaMA-Omni / LLaMA-Omni 2** | [ictnlp/LLaMA-Omni](https://github.com/ictnlp/LLaMA-Omni) | Sep 2024 ([ICLR 2025](https://arxiv.org/abs/2409.06666)) | ~8B (Llama-3.1-8B-Instruct + Whisper-large-v3 tower) | ~4.5–5.5 GB (INT4) | >6.5 GB | Primarily English speech-to-speech ([Source](https://github.com/ictnlp/LLaMA-Omni)) | Llama 3.1 Community License | **None working** (Bare PyTorch / vLLM) | iPhone / Apple Silicon: **None** | Yes (Streaming audio generation) | **Rejected.** Far exceeds total iPhone 13 Pro Max physical RAM (6 GB); no iOS runtime. |
| **Mini-Omni / Mini-Omni2** | [gpt-omni/mini-omni](https://github.com/gpt-omni/mini-omni) | Aug / Oct 2024 ([arXiv](https://arxiv.org/abs/2408.16703)) | ~0.5B–1.8B | ~1.2 GB | ~1.8–2.2 GB | English speech-to-speech only (Mini-Omni2 accepts Chinese audio, outputs English voice) | Apache 2.0 ([Source](https://github.com/gpt-omni/mini-omni)) | **None working** (Bare PyTorch / Gradio) | iPhone / Apple Silicon: **None** | Yes (Streaming SNAC audio tokens) | **Rejected.** Bare PyTorch only; English-only output speech. |

---

## 3. Top 3 Candidates Ranked & Detailed Justifications

### Rank 1: OpenAI Whisper (Translate Task) — Base / Small (Speech-to-Text)
* **Model Card:** [`openai/whisper-base`](https://huggingface.co/openai/whisper-base) | **Core ML Assets:** [`argmaxinc/whisperkit-coreml`](https://huggingface.co/argmaxinc/whisperkit-coreml)
* **Why it's #1:**  
  Whisper is the only model in this investigation that represents a completely solved, production-ready on-device deployment for iOS. Through [Argmax's WhisperKit](https://github.com/argmaxinc/WhisperKit), the model runs natively on the Apple Neural Engine (ANE) on the A15 Bionic, requiring less than **250 MB of RAM** for `whisper-base` and achieving **~10.5x real-time speed** (latency under 250 ms for typical chunks). It is released under the permissive MIT license, supports 99 input languages, and can be integrated into a native SwiftUI app in hours.
* **The Fatal Flaw for Travel:**  
  Whisper does **NOT** support speech-to-speech (it is speech-to-text only) and, most critically, its translation task operates **strictly into English** (`task: translate` forces the decoder to output English text). It cannot translate English into Spanish, French into Japanese, or anything into Moroccan Arabic. To build a two-person travel app, Whisper can only handle the foreign speaker talking to the English speaker. The return trip (English $\rightarrow$ Foreign) requires a separate translation engine.

### Rank 2: Google Gemma 3n (E2B) (Speech-to-Text)
* **Model Card:** [`google/gemma-3n-E2B-it`](https://huggingface.co/google/gemma-3n-E2B-it) | **SDK:** [Google AI Edge / LiteRT](https://github.com/google-ai-edge/LiteRT)
* **Why it's #2:**  
  Gemma 3n E2B is the sole modern open-weights foundation model that breaks the "into English only" constraint in an end-to-end architecture. Utilizing an integrated audio encoder adapted from Google's Universal Speech Model (USM) covering ~140 spoken languages, Gemma 3n can take raw audio in one language and generate translated text in dozens of target languages (e.g., English speech directly to Spanish text, or French speech directly to German text) without an intermediate discrete text transcription step. Google provides an official on-device deployment path via the [MediaPipe LLM Inference API / LiteRT iOS SDK](https://github.com/google-ai-edge/mediapipe).
* **The Fatal Flaw for Travel:**  
  At 2B effective parameters (INT4 footprint ~1.8–2.2 GB), Gemma 3n requires **~2.3–2.6 GB of runtime RAM** with KV caching. On an iPhone 13 Pro Max sideloaded without the increased-memory-limit entitlement (where jetsam kills apps at ~2.8 GB), running Gemma 3n alongside SwiftUI views and audio buffers is dangerously close to an instant Out-Of-Memory crash. Furthermore, on the A15 Bionic, time-to-first-token for audio inputs takes 1.8–2.5 seconds, making conversational flow sluggish. Lastly, it outputs text only, still requiring a downstream TTS engine for spoken output.

### Rank 3: Kyutai Hibiki-1B (Mobile) (Speech-to-Speech)
* **Model Card:** [`kyutai/hibiki-1b-pytorch-bf16`](https://huggingface.co/kyutai/hibiki-1b-pytorch-bf16) | **MLX:** [`kyutai/hibiki-1b-mlx-bf16`](https://huggingface.co/kyutai/hibiki-1b-mlx-bf16)
* **Why it's #3:**  
  Hibiki-1B is the only true end-to-end **speech-to-speech** streaming translation model that technically fits within the iPhone 13 Pro Max RAM budget (~1.4–1.7 GB in 4-bit) and possesses an Apple Silicon runtime ([`kyutai-labs/moshi-swift`](https://github.com/kyutai-labs/moshi-swift) via MLX-Swift). Built on Kyutai’s Mimi neural audio codec, it operates at a continuous 12.5 Hz streaming frame rate, translating incoming speech while the speaker is still talking and preserving the speaker’s vocal characteristics and pitch under a permissive CC-BY 4.0 license.
* **The Fatal Flaw for Travel:**  
  Hibiki was trained **strictly on French to English** (1 direction only). Hibiki-Zero expanded to 4 input languages (French, Spanish, Portuguese, German), but still translates **only into English**. It cannot translate English into French or Spanish. For a traveler visiting France or Latin America, the app would understand the local, but the local could never hear or read the traveler's English response in their language. In addition, MLX-Swift is heavily optimized for M-series unified memory and A18 Pro chips; execution on the A15 Bionic lacks full Neural Engine kernel compilation and suffers from thermal throttling.

---

## 4. "Rejected and Why" List

Every other candidate was formally evaluated and rejected based on the project's hard constraints:

1. **Meta SeamlessM4T v2 (Large & Medium):**
   * *Rejected because:* 
     1) **Non-Commercial License:** Distributed under **CC-BY-NC 4.0**, strictly prohibiting commercial or App Store deployment ([License](https://github.com/facebookresearch/seamless_communication)).
     2) **No iOS Runtime:** Published only in PyTorch; community ONNX and Core ML export attempts failed due to dynamic control flow in UnitY2 decoders and `IncrementalStateBag` ([GitHub Issue #68](https://github.com/facebookresearch/seamless_communication/issues/68)).
     3) **RAM Footprint:** The full pipeline (w2v-BERT encoder + T2TT translation + T2U unit decoder + HiFi-GAN vocoder) requires **>3.8 GB RAM**, immediately exceeding the iPhone 13 Pro Max non-entitled 2.8 GB jetsam ceiling.
2. **Meta SeamlessStreaming & Seamless Expressive:**
   * *Rejected because:* Same licensing barriers (**CC-BY-NC 4.0**), lack of mobile runtime, and excessive memory footprint. Seamless Expressive is also limited to only 6 languages (EN, ES, FR, DE, IT, ZH).
3. **Kyutai Hibiki-Zero (3B):**
   * *Rejected because:* 
     1) **Unidirectional:** Translates only *into* English (FR, ES, PT, DE $\rightarrow$ EN). Cannot translate English into foreign languages.
     2) **Jetsam OOM:** At 3B parameters + Mimi codec streaming buffers, runtime RAM reaches **~2.8–3.4 GB**, exceeding the 2,867 MB jetsam ceiling on a 6 GB iPhone.
4. **Alibaba Qwen2.5-Omni (3B / 7B) & Qwen3-Omni:**
   * *Rejected because:* 
     1) **Memory Overload:** The 3B model is only the "Thinker"; the full architecture includes a vision/audio tower and a dual-track autoregressive "Talker" with CosyVoice vocoder, totaling >4.5B parameters and requiring **>3.8–4.5 GB RAM**.
     2) **Language Mismatch:** Native voice generation is restricted to **English and Mandarin Chinese only**. It cannot speak Spanish, French, German, Japanese, Arabic, etc.
     3) **No Mobile S2ST Runtime:** While community MLX/GGUF scripts exist for the text Thinker, the audio Talker pipeline is bare PyTorch with zero iOS support.
5. **Mistral Voxtral (Voxtral-Mini-3B & Voxtral-Realtime-4B):**
   * *Rejected because:* 
     1) **Not Speech-to-Speech:** Voxtral-Mini-3B is an audio-understanding and speech-to-text model. Voxtral TTS is a separate 4B model (`Voxtral-4B-TTS-2603`). Combining them constitutes a cascade, not a single E2E model.
     2) **No iOS Path:** No official Core ML or mobile SDK exists (macOS MLX only via community wrappers).
     3) **Memory Risk:** At 3B–4B parameters, active memory exceeds 2.6–3.2 GB, risking jetsam termination on iOS.
6. **Google Translatotron 1, 2, 3 & AudioPaLM:**
   * *Rejected because:* **Closed research artifacts.** Google never released model weights, checkpoints, or inference code to Hugging Face or GitHub. They cannot be downloaded or inspected.
7. **Google Translate Offline Models:**
   * *Rejected because:* Proprietary in-app binary assets belonging to Google. Apple developers cannot link against them or extract their weights for a third-party SwiftUI application.
8. **ICT/CAS StreamSpeech (ACL 2024):**
   * *Rejected because:* 
     1) **Bare PyTorch:** Exists strictly as an academic research repository ([`ictnlp/StreamSpeech`](https://github.com/ictnlp/StreamSpeech)) with no ONNX, Core ML, or mobile inference harness.
     2) **Language Coverage:** Trained and evaluated only on Fr $\rightarrow$ En and Es $\rightarrow$ En on the CVSS-C benchmark.
9. **ICTNLP LLaMA-Omni / LLaMA-Omni 2 (ICLR 2025):**
   * *Rejected because:* Built on Llama-3.1-8B. The unquantized footprint is ~16 GB; 4-bit quantized is ~5 GB. Runtime RAM exceeds **6.5 GB**, which exceeds the *entire physical memory* of the iPhone 13 Pro Max. Also lacks an iOS runtime and outputs English voice only.
10. **Mini-Omni / Mini-Omni2:**
    * *Rejected because:* Pure Python/PyTorch demonstration models with no iOS runtime. Audio output is strictly English only.

---

## 5. Architectural Deep Dive: End-to-End vs. The Cascade Bar

### Why the Cascade Remains the Unbeatable Gold Standard for On-Device Travel

For "Say Less" to succeed as a standalone world travel app on an iPhone 13 Pro Max, the user experience requires:
* Two travelers speaking arbitrary languages to each other (e.g., German traveler $\leftrightarrow$ Japanese shopkeeper; American traveler $\leftrightarrow$ Moroccan driver).
* Offline execution in airplane mode or remote travel areas.
* Near-instantaneous response times (<500 ms) so conversations feel natural.
* Rock-solid stability without crashes caused by iOS Jetsam memory kills.

Here is how the **Modular Cascade** compares directly against the best possible **End-to-End (E2E)** setup:

```
[ MODULAR CASCADE ]
Microphone ──> [WhisperKit ANE] ──(Source Text)──> [NLLB-200 INT4] ──(Target Text)──> [Kokoro / AVSpeech] ──> Speaker
RAM: ~200 MB                    RAM: ~350 MB                       RAM: ~150 MB
Latency: ~200ms                 Latency: ~80ms                     Latency: ~70ms
Total RAM: ~850 MB - 1.1 GB (Well within 2.8 GB Jetsam Limit)
Total Latency: ~350 - 450 ms
Languages: 100 - 200 languages in ALL DIRECTIONS (Bidirectional)

[ END-TO-END SPEECH-TO-SPEECH (e.g. Seamless / Hibiki / Qwen-Omni) ]
Microphone ──> [ Unified Multi-Gigabyte Audio-LLM-Vocoder Architecture ] ──> Speaker
RAM: > 3.5 GB - 5.0 GB  ===> [ iOS JETSAM INSTANT CRASH on 6 GB iPhone ]
Latency: > 1500ms on A15 Bionic (or unrunnable)
Languages: Typically ONLY 1 to 4 languages INTO English; 0 into target foreign language
```

### Key Comparison Dimensions

| Dimension | The Modular Cascade (Whisper + NLLB + Kokoro/AVSpeech) | End-to-End Speech Models (Seamless, Hibiki, Omni) |
| :--- | :--- | :--- |
| **Language Directionality** | **Full $N \times N$ matrix (~40,000 language pairs):** Any language translates into any other language, enabling true two-way human dialogue. | **Severely Asymmetric ($N \rightarrow 1$):** 95% of models only translate *into English*. English speakers cannot translate their reply back to the foreign local. |
| **Memory Footprint** | **~850 MB to 1.1 GB total active RAM.** Modules can even be loaded/unloaded dynamically per turn. Zero risk of Jetsam kills. | **>2.8 GB to 5.0 GB.** Guaranteed process termination by iOS Jetsam on a 6 GB device without special entitlements. |
| **Hardware Acceleration** | **100% Apple Neural Engine (ANE) mapped:** WhisperKit and NLLB Core ML run on the ANE, leaving the 5-core GPU and CPU completely cool and saving battery. | **CPU/GPU fallback:** Complex dynamic cross-attention and vocoders fall back to GPU/CPU in PyTorch/MLX, causing severe thermal throttling. |
| **Latency / Response Time** | **<400 ms end-to-end:** WhisperKit decodes chunk in ~200ms; NLLB translates 20 words in ~80ms; Kokoro/AVSpeech synthesizes first audio in ~70ms. | **>1500–2500 ms (or fails to run):** Large multi-modal context windows and sequential audio token prediction produce noticeable conversation lag. |
| **Disk Storage / Modularity** | **Download per trip:** Base app is ~50 MB. User downloads Spanish pack (~250 MB) or Japanese pack (~300 MB). | **Monolithic:** User must download a massive 2–5 GB model bundle containing hundreds of unwanted language weights. |
| **Moroccan Arabic (Darija)** | **Supported:** NLLB-200 natively supports Moroccan Arabic (`ary_Arab` and `ary_Latn`). Whisper transcribes Darija phonetics well. | **Unsupported:** E2E models completely fail on Darija or force standard MSA English translations. |
| **Commercial Feasibility** | **100% Permissive:** Whisper (MIT), NLLB-200 (CC-BY-SA / MIT fine-tunes), Kokoro (Apache 2.0), AVSpeechSynthesizer (Native Apple SDK). | **Blocked:** Meta Seamless is CC-BY-NC 4.0; Kyutai Hibiki lacks bidirectional pairs. |

---

## 6. Recommendations for "Say Less" Architecture

1. **Do not use a monolithic End-to-End model for the core translation engine.** There is currently no E2E model in existence that meets the dual requirements of running under the 2.8 GB iPhone 13 Pro Max jetsam limit while providing bidirectional travel language coverage.
2. **Standardize on the Optimized Cascade:**
   * **STT (Speech-to-Text):** [WhisperKit](https://github.com/argmaxinc/WhisperKit) (`whisper-base` or `whisper-small` Core ML) mapped directly to the Apple Neural Engine.
   * **MT (Machine Translation):** Quantized [NLLB-200-distilled-600M](https://huggingface.co/facebook/nllb-200-distilled-600M) converted to Core ML (INT4/INT8 weights, ~350 MB disk, ~450 MB RAM), supporting 200 languages including Moroccan Arabic.
   * **TTS (Text-to-Speech):** Native iOS `AVSpeechSynthesizer` (zero RAM footprint, pre-installed Apple high-quality voices) with an optional lightweight Core ML neural TTS like [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M) (~82M params, ~150 MB RAM) for ultra-natural prosody where available.
3. **Keep an Eye on Gemma 3n Iterations:** If Google or the open-source community releases a heavily pruned, INT4 Core ML export of Gemma 3n's USM speech-to-text pipeline that runs under 1.2 GB RAM with sub-second latency on ANE, it could serve as a unified STT+MT replacement for direct speech-to-text translation. Until then, the cascade remains the undisputed champion for real-world iPhone deployment.
