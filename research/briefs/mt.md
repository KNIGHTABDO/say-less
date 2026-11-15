# Task: on-device multilingual TEXT TRANSLATION for iPhone
Notes file: research/notes/mt.md

Find the best on-device machine translation for a travel translator: maximum language pairs, high quality, fast (short conversational sentences, target < 500 ms per sentence on A15), fits memory.
Must include and compare at least: Meta NLLB-200 (distilled 600M / 1.3B, CTranslate2/Core ML ports), MADLAD-400, Google TranslateGemma (2026) and Gemma 3/3n/4 small models, Opus-MT / Bergamot / Firefox Translations (tiny per-pair models!), Seamless M4T text path, Tower / Tower+ (Unbabel), Aya Expanse / Aya small (Cohere), Qwen3 small (0.6B–4B) used as translator, Hunyuan-MT, Sarvam, any 2026 releases.
Separate the two families clearly: (a) dedicated MT models (one multilingual model or many tiny per-pair models) vs (b) small general LLMs prompted to translate. Note quality metrics (chrF/COMET on FLORES-200 or WMT) where published.
