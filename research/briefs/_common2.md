## Context (round 2: QUALITY first)

App "Say Less": native SwiftUI iPhone app, fully OFFLINE live translator for world travel, two people face to face. Device: iPhone 13 Pro Max (A15, 6 GB RAM), iOS 26, sideloaded with SideStore on a free Apple ID. Models download inside the app per language pack.
**Apple's built-in Speech / Translation / AVSpeech voices are OUT of scope: do not recommend them.** We want the best-quality open models that exist in **November 2026**.

Round 1 ranked by coverage and found old defaults (Whisper large-v3-turbo, NLLB-200 600M, Piper). This round ranks by **measured quality per language**; size is only a cut-off (quantized weights must fit a ~2.8 GB app memory budget shared by STT + MT + TTS, or ~2 GB if loaded one at a time).

### Fixed language panel (score every candidate on these)
English, Spanish, French, German, Italian, Portuguese, Arabic (MSA), Moroccan Arabic (Darija, `ary`), Turkish, Russian, Hindi, Japanese, Korean, Mandarin Chinese, Thai, Vietnamese, Indonesian, Swahili.

### Rules
- Only numbers from **independent benchmarks or the official paper/model card** count. Quote the **exact sentence or table row** behind each number together with its URL. Vendor marketing claims or numbers from third-party write-ups = mark UNVERIFIED.
- Numbers must be for the **quantization that would actually ship** (int8 / 4-bit) when available; say when only full-precision numbers exist.
- iOS runtime must exist today (Core ML, MLX-Swift, llama.cpp GGUF, ONNX Runtime/sherpa-onnx, WhisperKit, ExecuTorch, LiteRT). If none, list as "no iOS path".
- Include releases from 2025 and 2026 (look at Hugging Face trending, papers with code, leaderboards, official blogs). X/Reddit = leads only, UNVERIFIED.
- Never invent numbers: write "unknown".

### Deliverable
Write results to the notes file named in your task:
1. A per-language matrix: rows = panel languages, columns = candidates, cells = score (metric named in the header) or "—" if unsupported.
2. A candidate table: model | HF card URL | release date | params | shipped-quant size | RAM | license | iOS runtime link | languages count.
3. **Per-language routing recommendation**: for each panel language, the best model and runner-up.
4. Long-tail fallback recommendation (for languages outside the panel).
5. Quotes + URLs section.
**Final response (stdout) ≤ 15 lines**: routing summary + notes file path.
