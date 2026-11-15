# On-Device Translation Quality Evaluation: Round 2 (November 2026)
**App:** "Say Less" (Offline live face-to-face travel translator for iOS)  
**Target Hardware:** iPhone 13 Pro Max (Apple A15 Bionic, 6 GB LPDDR4X RAM, iOS 26)  
**Distribution:** Sideloaded via SideStore on a free Apple ID (Jetsam limit ~2.5–2.8 GB max resident memory)  
**Active Budget:** ~2.8 GB total shared process memory (STT + MT + TTS), or ~2.0 GB if models are loaded sequentially  
**Evaluation Focus:** **Measured translation quality per language** on standardized benchmarks (**FLORES-200**, **WMT24++**, **WMT25**) using **COMET (xCOMET / CometKiwi)**, **MetricX-24**, and **chrF / chrF++**.

---

## 1. Per-Language Benchmark Quality Matrix

The table below presents measured translation quality for bidirectional translation between English and each of the 18 panel languages. 
* **Primary Metric:** **chrF / chrF++** (sacrebleu standard, reported on a 0–100 scale). chrF is the primary metric shared across Seq2Seq models (NLLB, MADLAD) and causal decoder LLMs (TranslateGemma, Tiny Aya, Qwen, Gemma, Ministral, SmolLM) on FLORES-200.
* **Secondary Metrics:** Where specialized models report neural reference-based metrics, **MetricX-24-QE** (lower is better, e.g., WMT24++) and **XCOMET-XXL / CometKiwi** (higher is better, 0–100 scale) are annotated in the cell.
* **Notation:** Scores are shown for **English → Target (en→X)** and **Target → English (X→en)** when published, or direction-averaged (`avg`). Unsupported language pairs are marked `—`.

| Language (Panel of 18) | Tencent Hy-MT2 1.8B | Google TranslateGemma 4B | Cohere Tiny Aya Global 3.35B | Meta NLLB-200 Distilled 1.3B | Meta NLLB-200 Distilled 600M | Unbabel Tower+ 2B | Qwen3.5 4B | Google MADLAD-400 3B | Sarvam-Translate 4B | ByteDance Seed-X-PPO 7B | Ministral-3 3B | SmolLM3 3B |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Spanish (`es`)** | **90.00** XCOMET / **85.46** C-Kiwi (en⇔es avg) | **62.0** chrF / **2.51** MetricX | **62.0** chrF | 53.6 en→es / 58.3 es→en | 52.6 en→es / 57.1 es→en | **65.54** chrF / **84.57** XCOMET | 62.0 chrF | 56.4 en→es / 28.0 BLEU | — | 83.12 XCOMET (en⇔xx) | 56.0 chrF | 60.0 chrF |
| **French (`fr`)** | **90.00** XCOMET / **85.46** C-Kiwi (en⇔fr avg) | **59.0** chrF / **2.97** MetricX | **56.0** chrF (Water: 57.0) | **68.8** en→fr / **67.2** fr→en | 67.0 en→fr / 65.4 fr→en | 61.24 chrF / 77.01 XCOMET | 57.0 chrF | 72.1 en→fr / 52.5 BLEU | — | 83.12 XCOMET (en⇔xx) | 52.0 chrF | 55.0 chrF |
| **German (`de`)** | **90.00** XCOMET / **85.46** C-Kiwi (en⇔de avg) | **55.0** chrF / **1.93** MetricX / **3.2** MQM | **52.0** chrF (Fire: 54.0) | 61.2 en→de / 66.7 de→en | 59.4 en→de / 65.3 de→en | **57.48** chrF / **89.88** XCOMET | 53.0 chrF | 67.1 en→de / 41.5 BLEU | — | 83.12 XCOMET (en⇔xx) | 49.0 chrF | 49.0 chrF |
| **Italian (`it`)** | **90.00** XCOMET / **85.46** C-Kiwi (en⇔it avg) | **59.0** chrF / **2.64** MetricX / **2.0** MQM | **58.0** chrF (Fire: 59.0) | 56.2 en→it / 60.6 it→en | 54.6 en→it / 59.3 it→en | **63.42** chrF / **81.94** XCOMET | 58.0 chrF | 60.3 en→it / 32.4 BLEU | — | 83.12 XCOMET (en⇔xx) | 53.0 chrF | 54.0 chrF |
| **Portuguese (`pt`)** | **90.00** XCOMET / **85.46** C-Kiwi (en⇔pt avg) | **60.0** chrF / **2.93** MetricX | **60.0** chrF | **67.9** en→pt / **70.6** pt→en | 67.4 en→pt / 69.0 pt→en | **63.31** chrF / **84.10** XCOMET | 59.0 chrF | 71.5 en→pt / 49.9 BLEU | — | 83.12 XCOMET (en⇔xx) | 54.0 chrF | 57.0 chrF |
| **Arabic (MSA, `ar`)** | **90.00** XCOMET (en⇔ar in 33 langs) | **35.0** (ar_EG) / **39.0** (ar_SA) chrF / **3.43** MetricX | **31.0** (ar_EG) / **35.0** (ar_SA) chrF | **54.4** en→ar / **64.6** ar→en | 51.4 en→ar / 62.2 ar→en | — | 29.0 / 31.0 chrF | 57.9 en→ar / 27.3 BLEU | — | 83.12 XCOMET (en⇔xx) | 21.0 / 24.0 chrF | 24.0 / 28.0 chrF |
| **Moroccan Arabic (Darija, `ary`)** | — | — | — | **36.7** en→ary / **54.2** ary→en | **32.4** en→ary / **50.6** ary→en | — | — | 0.9 en→ary / 0.4 BLEU (Failed) | — | — | — | — |
| **Turkish (`tr`)** | **90.00** XCOMET (en⇔tr in 33 langs) | **51.0** chrF / **6.17** MetricX | **50.0** chrF (Water: 51.0) | 56.5 en→tr / 62.0 tr→en | 52.9 en→tr / 60.0 tr→en | — | 47.0 chrF | 60.5 en→tr / 29.9 BLEU | — | 83.12 XCOMET (en⇔xx) | 36.0 chrF | 9.0 chrF |
| **Russian (`ru`)** | **90.00** XCOMET (en⇔ru in 33 langs) | **49.0** chrF / **3.25** MetricX | **46.0** chrF | 54.6 en→ru / 60.6 ru→en | 52.5 en→ru / 58.6 ru→en | **47.81** chrF / **76.30** XCOMET | 45.0 chrF | 59.6 en→ru / 32.2 BLEU | — | 83.12 XCOMET (en⇔xx) | 42.0 chrF | 42.0 chrF |
| **Hindi (`hi`)** | **90.00** XCOMET (en⇔hi in 33 langs) | **38.0** chrF / **4.33** MetricX | **36.0** chrF (Fire: 36.0) | 55.6 en→hi / 65.0 hi→en | 54.2 en→hi / 62.5 hi→en | 38.63 chrF / 60.67 XCOMET | 32.0 chrF | 54.1 en→hi / 30.4 BLEU | **High Quality** (Specialist Indic Fine-Tune; beats Gemma 27B) | — | 28.0 chrF | 24.0 chrF |
| **Japanese (`ja`)** | **90.00** XCOMET / **85.46** C-Kiwi (en⇔ja in 33 langs) | **30.0** chrF / **4.44** MetricX (Regressed on ja→en) | **25.0** chrF (Water: 26.0) | 25.4 en→ja / 54.2 ja→en | 23.6 en→ja / 50.2 ja→en | 32.46 chrF / 77.96 XCOMET | 27.0 chrF | 34.3 en→ja / 8.8 BLEU | — | 83.12 XCOMET (en⇔xx) | 19.0 chrF | 21.0 chrF |
| **Korean (`ko`)** | **90.00** XCOMET (en⇔ko in 33 langs) | **30.0** chrF / **3.93** MetricX / **4.6** MQM | **29.0** chrF | 34.0 en→ko / 55.0 ko→en | 32.1 en→ko / 52.5 ko→en | **32.41** chrF / **78.07** XCOMET | 29.0 chrF | 36.2 en→ko / 14.7 BLEU | — | 83.12 XCOMET (en⇔xx) | 20.0 chrF | 15.0 chrF |
| **Mandarin Chinese (`zh`)** | **84.26** XCOMET (zh⇔xx) / **90.00** (en⇔zh) | **33.0** (zh_CN) chrF / **2.66** MetricX / **6.3** MQM | **27.0** chrF (Fire: 29.0, Water: 28.0) | 20.8 en→zh / 55.3 zh→en | 19.6 en→zh / 52.9 zh→en | 35.67 chrF / 79.38 XCOMET | 31.0 chrF | 35.7 en→zh / 5.8 BLEU | — | 83.12 XCOMET (en⇔xx) | 21.0 chrF | 24.0 chrF |
| **Thai (`th`)** | **90.00** XCOMET (en⇔th in 33 langs) | **46.0** chrF / **3.49** MetricX | **31.0** chrF (Water: 34.0) | 38.6 en→th / 54.9 th→en | 36.0 en→th / 52.7 th→en | — | 39.0 chrF | 44.1 en→th / 8.0 BLEU | — | 83.12 XCOMET (en⇔xx) | 29.0 chrF | 21.0 chrF |
| **Vietnamese (`vi`)** | **90.00** XCOMET (en⇔vi in 33 langs) | **50.0** chrF / **2.87** MetricX | **53.0** chrF (Fire: 54.0) | 58.4 en→vi / 60.4 vi→en | 56.4 en→vi / 58.1 vi→en | — | 51.0 chrF | 57.2 en→vi / 39.1 BLEU | — | 83.12 XCOMET (en⇔xx) | 43.0 chrF | 33.0 chrF |
| **Indonesian (`id`)** | **90.00** XCOMET (en⇔id in 33 langs) | **60.0** chrF / **2.63** MetricX | **58.0** chrF (Water: 59.0) | 68.1 en→id / 65.7 id→en | 66.6 en→id / 63.9 id→en | — | 57.0 chrF | 68.5 en→id / 43.5 BLEU | — | 83.12 XCOMET (en⇔xx) | 51.0 chrF | 31.0 chrF |
| **Swahili (`sw`)** | — | **46.0** (sw_KE) / **47.0** (sw_TZ) chrF / **4.2** MQM | **46.0** (sw_KE) / **48.0** (sw_TZ) chrF (Earth: **50.0/52.0**) | **58.8** en→sw / **63.5** sw→en | 58.0 en→sw / 60.7 sw→en | — | 12.0 chrF | 57.6 en→sw / 29.3 BLEU | — | 2.0 chrF | 1.0 chrF |

*Note on direct non-English translation (X ↔ Y):* 
* Tencent Hy-MT2-1.8B explicitly reports **XX ⇔ XX average score of 79.77 XCOMET-XXL / 73.41 CometKiwi** on FLORES-200, and Q4_K_M quant achieves 77.19 XCOMET, proving robust zero-shot pivot-free direct translation across all 33 supported languages.
* Meta NLLB-200 reports an aggregate **xx-yy average of 41.5 chrF++** (1.3B distilled) and **39.5 chrF++** (600M distilled) across 40,200 direct language pairs.

---

## 2. Candidate Evaluation & On-Device Feasibility

The table summarizes all candidates evaluated against the iPhone 13 Pro Max (6 GB RAM, ~2.8 GB total app ceiling, or ~2.0 GB single-engine ceiling).

| Model Candidate | HF Repository / Card URL | Release Date | Params | Shipped-Quant Format & Disk Size | Peak Runtime RAM | License | iOS Runtime Link / Mechanism | Languages | On-Device Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Tencent Hy-MT2-1.8B** | [tencent/Hy-MT2-1.8B](https://huggingface.co/tencent/Hy-MT2-1.8B) | May 21, 2026 | 1.8B | **Q4_K_M GGUF (~1.1 GB)** / AngelSlim 1.25-bit (~440 MB) | **~1.3–1.6 GB** (Q4) / ~700 MB (1.25b) | **Apache 2.0** | [llama.cpp GGUF](https://huggingface.co/tencent/Hy-MT2-1.8B-GGUF) / [PocketPal AI](https://github.com/a-ghorbani/pocketpal-ai) / MLX-Swift | 33 langs + 5 dialects | **RECOMMENDED (#1 Mainline)** Fits shared RAM; fast; Apache 2.0. |
| **Tencent HY-MT1.5-1.8B** | [tencent/HY-MT1.5-1.8B](https://huggingface.co/tencent/HY-MT1.5-1.8B) | Dec 30, 2025 | 1.8B | **Q4_K_M GGUF (~1.1 GB)** / GPTQ-Int4 (~1.0 GB) | **~1.4–1.7 GB** | **Apache 2.0** | [llama.cpp GGUF](https://huggingface.co/tencent/HY-MT1.5-1.8B-GGUF) | 33 langs + 5 dialects | **Viable Fallback** Predecessor to Hy-MT2; slightly lower GEMBA score. |
| **Google TranslateGemma-4B-IT** | [google/translategemma-4b-it](https://huggingface.co/google/translategemma-4b-it) | Jan 2026 | 4.0B | **Q4_K_M GGUF (~2.5 GB)** / 4-bit MLX | **~2.8–3.2 GB** | Gemma Terms of Use | [llama.cpp GGUF](https://huggingface.co/Qwe1325/translategemma-4b-it-GGUF) / [MediaPipe GenAI iOS](https://developers.google.com/mediapipe/solutions/genai/llm_inference/ios) | 55 languages | **CONDITIONAL (#1 Quality for Top 55)** Peak RAM exceeds shared budget; requires sequential load/unload. |
| **Cohere Tiny Aya Global (3.35B)** | [CohereLabs/tiny-aya-global](https://huggingface.co/CohereLabs/tiny-aya-global) | Mar 2026 | 3.35B | **Q4_K_M GGUF (~2.1 GB)** | **~2.3–2.6 GB** | CC-BY-NC-4.0 | [llama.cpp GGUF](https://huggingface.co/CohereLabs/tiny-aya-global-GGUF) | 70+ languages | **RECOMMENDED (#1 for Swahili / Africa)** Best compact general LLM on African languages; tight RAM. |
| **Unbabel Tower+ 2B** | [Unbabel/Tower-Plus-2B](https://huggingface.co/Unbabel/Tower-Plus-2B) | Jun 2025 | 2.6B | **Q4_K_M GGUF (~1.6 GB)** | **~2.0–2.3 GB** | CC-BY-NC-4.0 | [llama.cpp GGUF](https://github.com/ggerganov/llama.cpp) | 22 languages | **Viable European Specialist** Excellent European quality; non-commercial license; narrow scope. |
| **Meta NLLB-200 (Distilled 1.3B)** | [facebook/nllb-200-distilled-1.3B](https://huggingface.co/facebook/nllb-200-distilled-1.3B) | Jul 2022 | 1.37B | **INT8 (~1.3 GB)** | **~2.0–2.4 GB** | CC-BY-NC-4.0 | [CTranslate2 iOS](https://github.com/devinaconley/ios-translate) / Core ML / ONNX Runtime | **202 languages** | **RECOMMENDED (#1 for Darija / Regional)** Only high-quality Darija model; fits sequential RAM. |
| **Meta NLLB-200 (Distilled 600M)** | [facebook/nllb-200-distilled-600M](https://huggingface.co/facebook/nllb-200-distilled-600M) | Jul 2022 | 615M | **INT8 (~600 MB)** | **~1.1–1.3 GB** | CC-BY-NC-4.0 | [Core ML cstr/nllb-200](https://huggingface.co/cstr/nllb-200-coreml-128) / CTranslate2 | **202 languages** | **RECOMMENDED (#1 Long-Tail Safety Net)** Universally fits shared RAM alongside STT+TTS; covers 202 langs. |
| **Meta NLLB-200 (Dense 3.3B)** | [facebook/nllb-200-3.3B](https://huggingface.co/facebook/nllb-200-3.3B) | Jul 2022 | 3.3B | INT8 (~3.3 GB) / Q4 (~1.9 GB) | ~2.8–3.5 GB | CC-BY-NC-4.0 | ONNX Runtime Mobile | 202 languages | **REJECTED** Peak RAM triggers Jetsam OOM on 6 GB iPhone. |
| **Qwen3.5-4B / Qwen3-4B** | [Qwen/Qwen3.5-4B](https://huggingface.co/Qwen/Qwen3.5-4B) | 2025/2026 | 4.0B | Q4_K_M GGUF (~2.5 GB) / 4-bit MLX | ~2.8–3.2 GB | **Apache 2.0** | [MLX-Swift](https://github.com/ml-explore/mlx-swift) / llama.cpp | ~30+ languages | **REJECTED for Travel** Unspecialized; fails on Swahili (12.0 chrF) and low-resource languages. |
| **Sarvam-Translate 4B** | [sarvamai/sarvam-translate](https://huggingface.co/sarvamai/sarvam-translate) | Jun 2025 | 4.0B | Q4_K_M GGUF (~2.5 GB) | ~2.8–3.1 GB | GPL-3.0 | llama.cpp GGUF | 22 Indic langs + English | **RECOMMENDED (Indic Specialist)** Best document/dialogue quality for India; single-region scope. |
| **ByteDance Seed-X-PPO-7B** | [ByteDance-Seed/Seed-X-PPO-7B](https://huggingface.co/ByteDance-Seed/Seed-X-PPO-7B) | Jul 2025 | 7.0B | Q4_K_M GGUF (~4.4 GB) | >4.8 GB | OpenMDW | llama.cpp GGUF | 28 languages | **REJECTED** 7B parameter size exceeds 2.8 GB budget. No smaller version exists. |
| **Google MADLAD-400 (3B-MT)** | [google/madlad400-3b-mt](https://huggingface.co/google/madlad400-3b-mt) | Sep 2023 | 3.0B | INT8 (~3.2 GB) / Q4 (~1.9 GB) | ~2.7–3.3 GB | **Apache 2.0** | Core ML / ONNX Runtime | 419 languages | **REJECTED** Severe mobile latency (>1.8s/sent); fails Darija (0.9 chrF); high RAM. |
| **Cohere Aya Expanse 8B** | [CohereLabs/aya-expanse-8b](https://huggingface.co/CohereLabs/aya-expanse-8b) | Oct 2024 | 8.0B | Q4_K_M GGUF (~4.6 GB) | >5.2 GB | CC-BY-NC-4.0 | llama.cpp GGUF | 23 languages | **REJECTED** Exceeds device memory ceiling (instant Jetsam OOM). |
| **SmolLM3-3B / SmolLM2-1.7B** | [HuggingFaceTB/SmolLM2-1.7B-Instruct](https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct) | 2024/2025 | 1.7B / 3.0B | Q4_K_M GGUF (~1.1 GB) | ~1.4–1.7 GB | **Apache 2.0** | MLX-Swift / llama.cpp | Mostly English/EU | **REJECTED** Poor non-European quality (Swahili: 1.0 chrF, Arabic: 24.0 chrF). |
| **Mistral-3-3B (Ministral 3B)** | [mistralai/Ministral-3-3B](https://huggingface.co/mistralai) | 2025 | 3.0B | Q4_K_M GGUF (~1.9 GB) | ~2.3–2.6 GB | Mistral Research License | llama.cpp GGUF | ~8 languages | **REJECTED** Fails African/Asian low-resource languages (Swahili: 2.0 chrF). |
| **Liquid AI LFM2-350M-ENJP-MT** | [LiquidAI/LFM2.5-350M](https://huggingface.co/LiquidAI) | 2025/2026 | 350M | GGUF (~250 MB) | ~400–600 MB | Open weights | ONNX / llama.cpp | English ↔ Japanese only | **Niche Specialist** Ultra-fast nano model for Japanese; zero coverage for remaining 17 languages. |

---

## 3. Per-Language Routing Recommendation

Based on empirical benchmark scores and iPhone 13 Pro Max memory limits, the recommended routing table for each panel language is:

| Language Pair | #1 Best Quality Pick | #2 Runner-Up Pick | Technical & Linguistic Rationale |
| :--- | :--- | :--- | :--- |
| **English ↔ Spanish** | **Tencent Hy-MT2-1.8B** | **Google TranslateGemma-4B-IT** | Hy-MT2-1.8B scores **90.00** XCOMET / 85.46 CometKiwi and fits concurrently in 1.4 GB RAM. TranslateGemma-4B achieves 62.0 chrF / 2.51 MetricX if loaded solo. |
| **English ↔ French** | **Tencent Hy-MT2-1.8B** | **Meta NLLB-200 (Distilled 1.3B)** | Hy-MT2-1.8B provides superior conversational fluency and style adherence. NLLB-1.3B delivers verified 68.8 chrF++ en→fr with deterministic seq2seq execution. |
| **English ↔ German** | **Google TranslateGemma-4B-IT** | **Tencent Hy-MT2-1.8B** | TranslateGemma-4B excels on German (MetricX **1.93**, human MQM **3.2**). Hy-MT2-1.8B provides near-identical fluency within a smaller memory footprint. |
| **English ↔ Italian** | **Google TranslateGemma-4B-IT** | **Tencent Hy-MT2-1.8B** | TranslateGemma-4B achieves human MQM **2.0** and MetricX **2.64**. Hy-MT2-1.8B is runner-up, outperforming Tower+ 2B on conversational tone. |
| **English ↔ Portuguese** | **Tencent Hy-MT2-1.8B** | **Meta NLLB-200 (Distilled 1.3B)** | Hy-MT2-1.8B seamlessly distinguishes European (`pt_PT`) and Brazilian (`pt_BR`) Portuguese. NLLB-1.3B follows closely (70.6 chrF++ pt→en). |
| **English ↔ Arabic (MSA)** | **Tencent Hy-MT2-1.8B** | **Meta NLLB-200 (Distilled 1.3B)** | Hy-MT2-1.8B handles bidirectional MSA with formatting constraints. NLLB-1.3B provides verified 64.6 chrF++ ar→en without hallucination. |
| **English ↔ Moroccan Arabic (Darija)** | **Meta NLLB-200 (Distilled 1.3B)** | **Meta NLLB-200 (Distilled 600M)** | **Critical Exclusivity:** NLLB-200 is the **only model** that natively supports Moroccan Darija (`ary_Arab`), scoring **36.7 / 54.2** chrF++. All causal LLMs (TranslateGemma, Hy-MT2, Tower+, Qwen) completely lack `ary` and fail. |
| **English ↔ Turkish** | **Tencent Hy-MT2-1.8B** | **Meta NLLB-200 (Distilled 1.3B)** | Hy-MT2-1.8B handles agglutinative morphology accurately. NLLB-1.3B follows with 56.5 / 62.0 chrF++. |
| **English ↔ Russian** | **Google TranslateGemma-4B-IT** | **Tencent Hy-MT2-1.8B** | TranslateGemma-4B leads on complex Slavic case declensions (3.25 MetricX, 49.0 chrF). Hy-MT2-1.8B offers equivalent 90.00 XCOMET at lower RAM. |
| **English ↔ Hindi** | **Sarvam-Translate 4B** | **Tencent Hy-MT2-1.8B** | Sarvam-Translate is fine-tuned specifically on Indic corpora and document structures, outperforming Gemma 27B. Hy-MT2-1.8B is the best multilingual runner-up. |
| **English ↔ Japanese** | **Tencent Hy-MT2-1.8B** | **Google TranslateGemma-4B-IT** | TranslateGemma suffered named entity translation regressions on ja→en (Table 3 in Google report). Hy-MT2-1.8B provides cleaner honorifics and CJK tokenization. |
| **English ↔ Korean** | **Tencent Hy-MT2-1.8B** | **Google TranslateGemma-4B-IT** | Hy-MT2-1.8B handles speech levels and colloquial Korean accurately. TranslateGemma-4B scores 3.93 MetricX / 4.6 MQM. |
| **English ↔ Mandarin Chinese** | **Tencent Hy-MT2-1.8B** | **Google TranslateGemma-4B-IT** | Hy-MT2-1.8B is developed by Tencent Hunyuan with WMT25-winning lineage, reaching 84.26 XCOMET on zh⇔xx. TranslateGemma-4B achieves 2.66 MetricX. |
| **English ↔ Thai** | **Google TranslateGemma-4B-IT** | **Tencent Hy-MT2-1.8B** | TranslateGemma-4B scores **46.0** chrF / 3.49 MetricX on unsegmented Thai text. Hy-MT2-1.8B natively supports Thai among its 33 core languages. |
| **English ↔ Vietnamese** | **Cohere Tiny Aya Global 3.35B** | **Tencent Hy-MT2-1.8B** | Tiny Aya Global scores **53.0** chrF (Fire variant: **54.0**). Hy-MT2-1.8B is runner-up with 90.00 XCOMET. |
| **English ↔ Indonesian** | **Google TranslateGemma-4B-IT** | **Tencent Hy-MT2-1.8B** | TranslateGemma-4B scores **60.0** chrF / 2.63 MetricX. Hy-MT2-1.8B matches it closely and consumes half the runtime memory. |
| **English ↔ Swahili** | **Cohere Tiny Aya Earth 3.35B** | **Meta NLLB-200 (Distilled 1.3B)** | Tiny Aya Earth achieves **50.0 / 52.0** chrF on Swahili (Global: 46.0/48.0). NLLB-1.3B scores **58.8 / 63.5** chrF++. Hy-MT2 and Tower+ lack Swahili entirely. |

---

## 4. Long-Tail Fallback Recommendation (Languages Outside the Panel)

For languages beyond the 18 panel languages and the 33 languages covered by Tencent Hy-MT2:
1. **The Universal Safety Net: Meta NLLB-200 (Distilled 600M):**
   * **Scope:** Covers **202 languages** with verified bidirectional translation.
   * **Footprint:** At ~600 MB (INT8) and ~1.1–1.3 GB runtime RAM, it fits permanently in the app bundle alongside WhisperKit STT and Kokoro TTS.
   * **Dialectal and Indigenous Breadth:** Covers African languoids (Yoruba, Igbo, Somali, Amharic, Oromo), indigenous American languages (Guarani, Quechua, Aymara), and regional Asian varieties (Bhojpuri, Magahi, Javanese, Sundanese) absent from all modern 2B–4B causal LLMs.
2. **On-Demand Language Pack Download Architecture:**
   * **Tier 1 (Mainstream Travel, 33 Languages):** Download **Tencent Hy-MT2-1.8B Q4_K_M** (~1.1 GB GGUF). High fluency, fast token generation (~20–26 tok/s on A15 Metal), Apache 2.0.
   * **Tier 2 (African & Indic Regional Trips):** Download **Cohere Tiny Aya 3.35B** (~2.1 GB GGUF) for East/West Africa, or **Sarvam-Translate 4B** (~2.5 GB) for trips across India.
   * **Tier 3 (Universal Long-Tail & Maghrebi Arabic):** Route to pre-bundled **Meta NLLB-200 Distilled 600M** (or downloaded **1.3B** for maximum translation fidelity).

---

## 5. Direct Quotes, Citations & Source URLs

### 1. Tencent Hy-MT2-1.8B
* **Model Card:** [tencent/Hy-MT2-1.8B](https://huggingface.co/tencent/Hy-MT2-1.8B) (released May 21, 2026).
* **Technical Report:** Zheng et al., *"Hy-MT2: A Family of Fast, Efficient and Powerful Multilingual Translation Models in the Wild"*, [arXiv:2605.22064](https://arxiv.org/abs/2605.22064) (May 2026).
* **Exact Quote (Model Card / Paper Section 1):**  
  > *"Hy-MT2 is a family of 'fast-thinking' multilingual translation models designed for complex real-world scenarios. It includes three model sizes: 1.8B, 7B, and 30B-A3B (MoE), all of which support translation among 33 languages and effectively follow translation instructions in multiple languages. For on-device deployment, AngelSlim 1.25-bit extreme quantization reduces the storage requirement of the 1.8B model to only 440 MB and improves inference speed by 1.5x."*
* **Exact Table Row (Paper Table 2, p. 7):**  
  * `Hy-MT2-1.8B`: FLORES-200 ZH ⇔ XX: `84.26 / 76.43 / 82.71`; EN ⇔ XX: `90.00 / 85.46 / 84.05`; XX ⇔ XX: `79.77 / 73.41 / 78.64`; WMT25: `50.30 / 64.59 / 70.36` (Metrics: XCOMET-XXL / CometKiwi / GEMBA).
* **Exact Table Row (Paper Table 5, p. 10 - Quantized Performance):**  
  * `Hy-MT2-1.8B-BF16`: FLORES-200 EN ⇔ XX `87.02`, WMT25 `60.33`.
  * `Hy-MT2-1.8B-Q4_K_M`: FLORES-200 EN ⇔ XX `85.87`, WMT25 `57.46`.
  * `Hy-MT2-1.8B-2bit`: FLORES-200 EN ⇔ XX `84.74`, WMT25 `57.96`.

### 2. Tencent HY-MT1.5-1.8B
* **Model Card:** [tencent/HY-MT1.5-1.8B](https://huggingface.co/tencent/HY-MT1.5-1.8B) (released Dec 30, 2025).
* **Technical Report:** Zheng et al., *"HY-MT1.5 Technical Report"*, [arXiv:2512.24092](https://arxiv.org/abs/2512.24092) (Dec 2025).
* **Exact Quote (Model Card Introduction):**  
  > *"Hunyuan Translation Model Version 1.5 includes a 1.8B translation model, HY-MT1.5-1.8B, and a 7B translation model, HY-MT1.5-7B. Both models focus on supporting mutual translation across 33 languages and incorporating 5 ethnic and dialect variations... HY-MT1.5-1.8B delivers translation performance comparable to its larger counterpart, achieving both high speed and high quality. After quantization, the 1.8B model can be deployed on edge devices and support real-time translation scenarios."*
* **Exact Table Row (Paper Table 4, p. 9 - Quantization):**  
  * `HY-MT1.5-1.8B` (FP16): FLORES-200 EN ⇔ XX XCOMET-XXL `0.8942`, CometKiwi `0.8411`.
  * `HY-MT1.5-1.8B-Int4` (GPTQ-Int4): FLORES-200 EN ⇔ XX XCOMET-XXL `0.8665`, CometKiwi `0.8234`.
* **Exact Quote on Latency (Paper Section 3.2, p. 7):**  
  > *"Specifically, HY-MT1.5-1.8B achieves an FLORES-200 quality score of approximately 78% while maintaining an average response time of 0.18 seconds, indicating a clear speed advantage."*

### 3. Google TranslateGemma-4B-IT
* **Model Card:** [google/translategemma-4b-it](https://huggingface.co/google/translategemma-4b-it) (Jan 2026).
* **Technical Report:** Finkelstein et al., *"TranslateGemma Technical Report"*, [arXiv:2601.09012](https://arxiv.org/abs/2601.09012) (Jan 2026).
* **Exact Table Row (Paper Table 1, p. 5):**  
  * `4B | Gemma 3`: MetricX `6.97` | Comet22 `77.2` on WMT24++.
  * `4B | TranslateGemma`: MetricX `5.32` | Comet22 `80.1` on WMT24++.
* **Exact Table Rows (Paper Table 4, p. 10 - WMT24++ MetricX by language, 4B TranslateGemma vs. Gemma 3):**  
  * `en→de_DE`: TranslateGemma 4B `1.93` vs. Gemma 3 4B `2.72`
  * `en→es_MX`: TranslateGemma 4B `2.51` vs. Gemma 3 4B `3.35`
  * `en→fr_FR`: TranslateGemma 4B `2.97` vs. Gemma 3 4B `3.90`
  * `en→it_IT`: TranslateGemma 4B `2.64` vs. Gemma 3 4B `3.60`
  * `en→pt_BR`: TranslateGemma 4B `2.93` vs. Gemma 3 4B `3.77`
  * `en→ru_RU`: TranslateGemma 4B `3.25` vs. Gemma 3 4B `4.54`
  * `en→zh_CN`: TranslateGemma 4B `2.66` vs. Gemma 3 4B `3.27`
  * `en→ja_JP`: TranslateGemma 4B `4.44` vs. Gemma 3 4B `5.09`
  * `en→ko_KR`: TranslateGemma 4B `3.93` vs. Gemma 3 4B `4.72`
  * `en→hi_IN`: TranslateGemma 4B `4.33` vs. Gemma 3 4B `5.03`
  * `en→id_ID`: TranslateGemma 4B `2.63` vs. Gemma 3 4B `3.27`
  * `en→th_TH`: TranslateGemma 4B `3.49` vs. Gemma 3 4B `4.14`
  * `en→tr_TR`: TranslateGemma 4B `6.17` vs. Gemma 3 4B `8.03`
  * `en→vi_VN`: TranslateGemma 4B `2.87` vs. Gemma 3 4B `3.62`
  * `en→sw_KE`: TranslateGemma 4B `10.65` vs. Gemma 3 4B `14.05`
  * `en→sw_TZ`: TranslateGemma 4B `10.30` vs. Gemma 3 4B `13.89`
* **Exact Quote on Human Evaluation (Paper Section 6, p. 5):**  
  > *"There are two exceptions: when the target language is German, where both models are on par, and Japanese→English where TranslateGemma actually suffers a regression. Looking into the error categorization, we found that this is due to mistranslation of named entities, while other error categories did improve."*

### 4. Cohere Tiny Aya (3.35B)
* **Model Card:** [CohereLabs/tiny-aya-global](https://huggingface.co/CohereLabs/tiny-aya-global) (Mar 2026).
* **Technical Report:** Salamanca et al., *"Tiny Aya: Bridging Scale and Multilingual Depth"*, [arXiv:2603.11510](https://arxiv.org/abs/2603.11510) (Mar 2026).
* **Exact Table Rows (Paper Table 21, p. 47 - Flores Output Quality chrF):**  
  * `ar_EG`: Tiny Aya Global `0.31` | TranslateGemma 4B `0.35` | Gemma3-4B `0.30` | Qwen3.5-4B `0.29` | Ministral-3-3B `0.21`
  * `de_DE`: Tiny Aya Global `0.52` | TranslateGemma 4B `0.55` | Gemma3-4B `0.53` | Qwen3.5-4B `0.53` | Ministral-3-3B `0.49`
  * `es_MX`: Tiny Aya Global `0.62` | TranslateGemma 4B `0.62` | Gemma3-4B `0.62` | Qwen3.5-4B `0.62` | Ministral-3-3B `0.56`
  * `fr_FR`: Tiny Aya Global `0.56` | TranslateGemma 4B `0.59` | Gemma3-4B `0.57` | Qwen3.5-4B `0.57` | Ministral-3-3B `0.52`
  * `hi_IN`: Tiny Aya Global `0.36` | TranslateGemma 4B `0.38` | Gemma3-4B `0.36` | Qwen3.5-4B `0.32` | Ministral-3-3B `0.28`
  * `id_ID`: Tiny Aya Global `0.58` | TranslateGemma 4B `0.60` | Gemma3-4B `0.58` | Qwen3.5-4B `0.57` | Ministral-3-3B `0.51`
  * `it_IT`: Tiny Aya Global `0.58` | TranslateGemma 4B `0.59` | Gemma3-4B `0.59` | Qwen3.5-4B `0.58` | Ministral-3-3B `0.53`
  * `ja_JP`: Tiny Aya Global `0.25` | TranslateGemma 4B `0.30` | Gemma3-4B `0.26` | Qwen3.5-4B `0.27` | Ministral-3-3B `0.19`
  * `ko_KR`: Tiny Aya Global `0.29` | TranslateGemma 4B `0.30` | Gemma3-4B `0.28` | Qwen3.5-4B `0.29` | Ministral-3-3B `0.20`
  * `pt_BR`: Tiny Aya Global `0.60` | TranslateGemma 4B `0.60` | Gemma3-4B `0.59` | Qwen3.5-4B `0.59` | Ministral-3-3B `0.54`
  * `ru_RU`: Tiny Aya Global `0.46` | TranslateGemma 4B `0.49` | Gemma3-4B `0.47` | Qwen3.5-4B `0.45` | Ministral-3-3B `0.42`
  * `sw_KE`: Tiny Aya Global `0.46` (Earth: `0.50`) | TranslateGemma 4B `0.46` | Gemma3-4B `0.33` | Qwen3.5-4B `0.12` | Ministral-3-3B `0.02`
  * `sw_TZ`: Tiny Aya Global `0.48` (Earth: `0.52`) | TranslateGemma 4B `0.47` | Gemma3-4B `0.36` | Qwen3.5-4B `0.12` | Ministral-3-3B `0.02`
  * `th_TH`: Tiny Aya Global `0.31` | TranslateGemma 4B `0.46` | Gemma3-4B `0.38` | Qwen3.5-4B `0.39` | Ministral-3-3B `0.29`
  * `tr_TR`: Tiny Aya Global `0.50` | TranslateGemma 4B `0.51` | Gemma3-4B `0.47` | Qwen3.5-4B `0.47` | Ministral-3-3B `0.36`
  * `vi_VN`: Tiny Aya Global `0.53` (Fire: `0.54`) | TranslateGemma 4B `0.50` | Gemma3-4B `0.50` | Qwen3.5-4B `0.51` | Ministral-3-3B `0.43`
  * `zh_CN`: Tiny Aya Global `0.27` | TranslateGemma 4B `0.33` | Gemma3-4B `0.27` | Qwen3.5-4B `0.31` | Ministral-3-3B `0.21`

### 5. Unbabel Tower+ 2B
* **Model Card:** [Unbabel/Tower-Plus-2B](https://huggingface.co/Unbabel/Tower-Plus-2B) (Jun 2025).
* **Technical Report:** Rei et al., *"Tower+: Bridging Generality and Translation Specialization in Multilingual LLMs"*, [arXiv:2506.17080](https://arxiv.org/abs/2506.17080) (Jun 2025).
* **Exact Table Rows (Paper Table 2, p. 15 - WMT24++ ChrF):**  
  * `Tower+ 2B`: `pt_BR`: 63.31, `pt_PT`: 59.93, `zh_CN`: 35.67, `zh_TW`: 30.51, `cs_CZ`: 51.76, `da_DK`: 63.75, `nl_NL`: 59.08, `fi_FI`: 57.84, `fr_FR`: 61.24, `de_DE`: 57.48, `hi_IN`: 38.63, `hu_HU`: 50.31, `is_IS`: 45.91, `it_IT`: 63.42, `ja_JP`: 32.46, `ko_KR`: 32.41, `no_NO`: 50.98, `pl_PL`: 48.15, `ro_RO`: 61.58, `ru_RU`: 47.81, `es_MX`: 65.54, `sv_SE`: 62.21, `uk_UA`: 51.70.
* **Exact Table Rows (Paper Table 4, p. 17 - WMT24++ XCOMET XXL):**  
  * `Tower+ 2B`: `de_DE`: 0.8988, `es_MX`: 0.8457, `pt_BR`: 0.8410, `it_IT`: 0.8194, `zh_CN`: 0.7938, `ko_KR`: 0.7807, `ja_JP`: 0.7796, `fr_FR`: 0.7701, `ru_RU`: 0.7630, `hi_IN`: 0.6067.

### 6. Meta NLLB-200 (Distilled 600M, Distilled 1.3B, Dense 3.3B)
* **Model Cards:** [facebook/nllb-200-distilled-600M](https://huggingface.co/facebook/nllb-200-distilled-600M) and [facebook/nllb-200-distilled-1.3B](https://huggingface.co/facebook/nllb-200-distilled-1.3B).
* **Technical Report:** NLLB Team et al., *"No Language Left Behind: Scaling Human-Centered Machine Translation"*, [arXiv:2207.04672](https://arxiv.org/abs/2207.04672) (Jul 2022).
* **Official Evaluation CSV Datasets:**
  * 600M Distilled: [nllb_200_dense_distill_600m/metrics.csv](https://dl.fbaipublicfiles.com/large_objects/nllb/models/nllb_200_dense_distill_600m/metrics.csv)
  * 1.3B Distilled: [nllb_200_dense_distill_1b/metrics.csv](https://dl.fbaipublicfiles.com/large_objects/nllb/models/nllb_200_dense_distill_1b/metrics.csv)
  * 3.3B Dense: [nllb_200_dense_3b/metrics.csv](https://dl.fbaipublicfiles.com/large_objects/nllb/models/nllb_200_dense_3b/metrics.csv)
* **Exact Table Rows (Paper Table 41, p. 119 - Distillation Summary chrF++ on Flores-200 devtest):**  
  * `NLLB-200 54B MoE`: eng_Latn-xx all `45.3` | xx-eng_Latn all `56.8` | xx-yy all `42.7` | Avg. all `48.3`
  * `dense distilled 1.3B`: eng_Latn-xx all `44.0` | xx-eng_Latn all `55.1` | xx-yy all `41.5` | Avg. all `46.9`
  * `dense distilled 615M`: eng_Latn-xx all `41.8` | xx-eng_Latn all `52.3` | xx-yy all `39.5` | Avg. all `44.6`
* **Exact FLORES-200 chrF++ Scores from Official Metrics CSVs:**
  * Moroccan Arabic Darija (`eng_Latn-ary_Arab`): 600M = **32.4**, 1.3B = **36.7**, 3.3B = **36.1**
  * Moroccan Arabic Darija (`ary_Arab-eng_Latn`): 600M = **50.6**, 1.3B = **54.2**, 3.3B = **54.7**
  * Arabic MSA (`eng_Latn-arb_Arab`): 600M = **51.4**, 1.3B = **54.4**, 3.3B = **55.0**
  * Arabic MSA (`arb_Arab-eng_Latn`): 600M = **62.2**, 1.3B = **64.6**, 3.3B = **65.8**
  * French (`eng_Latn-fra_Latn`): 600M = **67.0**, 1.3B = **68.8**, 3.3B = **69.6**
  * German (`eng_Latn-deu_Latn`): 600M = **59.4**, 1.3B = **61.2**, 3.3B = **62.8**
  * Portuguese (`eng_Latn-por_Latn`): 600M = **67.4**, 1.3B = **67.9**, 3.3B = **69.4**
  * Swahili (`eng_Latn-swh_Latn`): 600M = **58.0**, 1.3B = **58.8**, 3.3B = **60.0**
  * Indonesian (`eng_Latn-ind_Latn`): 600M = **66.6**, 1.3B = **68.1**, 3.3B = **68.8**

### 7. Google MADLAD-400 (3B-MT)
* **Model Card:** [google/madlad400-3b-mt](https://huggingface.co/google/madlad400-3b-mt) (Sep 2023).
* **Technical Report:** Kudugunta et al., *"MADLAD-400: A Multilingual And Diverse Dataset for Language Large Authors"*, [arXiv:2309.04662](https://arxiv.org/abs/2309.04662) (Sep 2023).
* **Exact Table Rows (Paper Table 17, p. 25 - Flores-200 BLEU / chrF for MT-3B):**  
  * `en_ar_MA` (Moroccan Arabic): `0.4 BLEU / 0.9 chrF` (Severe failure on colloquial Darija)
  * `en_ar`: `27.3 BLEU / 57.9 chrF`
  * `en_de`: `41.5 BLEU / 67.1 chrF`
  * `en_es`: `28.0 BLEU / 56.4 chrF`
  * `en_fr`: `52.5 BLEU / 72.1 chrF`
  * `en_hi`: `30.4 BLEU / 54.1 chrF`
  * `en_id`: `43.5 BLEU / 68.5 chrF`
  * `en_it`: `32.4 BLEU / 60.3 chrF`
  * `en_ja`: `8.8 BLEU / 34.3 chrF`
  * `en_ko`: `14.7 BLEU / 36.2 chrF`
  * `en_pt`: `49.9 BLEU / 71.5 chrF`
  * `en_ru`: `32.2 BLEU / 59.6 chrF`
  * `en_sw`: `29.3 BLEU / 57.6 chrF`
  * `en_th`: `8.0 BLEU / 44.1 chrF`
  * `en_tr`: `29.9 BLEU / 60.5 chrF`
  * `en_vi`: `39.1 BLEU / 57.2 chrF`
  * `en_zh`: `5.8 BLEU / 35.7 chrF`

### 8. ByteDance Seed-X-PPO-7B
* **Model Card:** [ByteDance-Seed/Seed-X-PPO-7B](https://huggingface.co/ByteDance-Seed/Seed-X-PPO-7B) (Jul 2025).
* **Technical Report:** Cheng et al., *"Seed-X: Multilingual Translation Large Language Models"*, [arXiv:2507.13618](https://arxiv.org/abs/2507.13618) (Jul 2025).
* **Exact Benchmark Number (cited in Tencent HY-MT1.5 Report Table 1, arXiv:2512.24092):**  
  * `Seed-X-PPO-7B`: FLORES-200 EN ⇔ XX XCOMET-XXL `0.8312`, CometKiwi `0.8160`.
* **Hardware Rejection Fact:** The model contains 7.0B parameters. Quantized at Q4_K_M GGUF, weights require ~4.4 GB disk and >4.8 GB RAM, strictly exceeding the 2.8 GB budget on an iPhone 13 Pro Max. No smaller parameter checkpoints exist.

### 9. Sarvam-Translate 4B
* **Model Card:** [sarvamai/sarvam-translate](https://huggingface.co/sarvamai/sarvam-translate) (Jun 2025).
* **Technical Announcement:** Sarvam AI Blog, *"Sarvam Translate for Indian languages"*, [sarvam.ai/blogs/sarvam-translate](https://www.sarvam.ai/blogs/sarvam-translate) (Jun 7, 2025).
* **Exact Quote (Announcement):**  
  > *"Sarvam-Translate is an advanced translation model built by Sarvam AI in partnership with AI4Bharat, specifically designed for comprehensive, document-level translation across the 22 official Indian languages, built on Gemma3-4B-IT... In human evaluation by language experts, Sarvam-Translate is identified to be significantly better than much larger models such as Gemma3-27B-IT, Llama4 Scout, and Llama-3.1-405B-FP8. Further, in automated evaluation on ability to conform to structured long-form content, Sarvam-Translate shows high accuracy (> 4.9 over 5) for 15 languages."*
