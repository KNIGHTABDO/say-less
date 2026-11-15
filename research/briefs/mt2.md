# Task: best-QUALITY on-device translation per language pair (round 2)
Notes file: research/notes/mt2.md
Metric: COMET (preferred, e.g. wmt22-comet-da / xCOMET / MetricX) or chrF++ on FLORES-200 / WMT24++ / WMT25, for English<->X for each panel language (and note X<->Y if available).
Candidates to evaluate at minimum: Google TranslateGemma (4B, and any smaller), Gemma 3 / 3n / Gemma 4 small models, Tencent Hy-MT1.5-1.8B and Hy-MT2-1.8B (open the actual Hugging Face card tencent/... and quote it), Unbabel Tower+ / Tower small, Cohere Aya Expanse 8B / Aya Vision / any small Aya, Qwen3 / Qwen3.5 small (0.6B–4B), Seed-X (ByteDance) 7B and any small version, Sarvam-Translate, Meta NLLB-200 (600M/1.3B/3.3B distilled), MADLAD-400 3B, SmolLM / LFM2 translation fine-tunes, Mistral small, any 2026 translation-specialist small models.
Report the quantized footprint at which each fits on a 6 GB iPhone (Q4_K_M GGUF / 4-bit MLX), and decode speed if published for A15/A16/A17/M-series.
