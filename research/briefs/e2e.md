# Task: END-TO-END speech-to-speech / speech-to-text translation models runnable on iPhone
Notes file: research/notes/e2e.md

Find single models that take speech in one language and output translated text and/or speech directly (no separate STT/MT/TTS), that could run on iPhone 13 Pro Max offline.
Must include and compare at least: Meta SeamlessM4T v2 / SeamlessStreaming / Seamless Expressive, Kyutai Hibiki (and Hibiki-Zero / newer), Google's on-device speech translation models if any are open, Whisper "translate" task (only to English!), Qwen2.5-Omni / Qwen3-Omni small, Gemma 3n audio / newer Gemma, Voxtral, any 2025-2026 simultaneous speech translation releases (StreamSpeech, etc.).
Crucial: for each, state the language DIRECTIONS supported (many only translate INTO English), the size, and whether anyone has actually run it on an iPhone (link). The bar to beat: a cascade (Whisper-class STT + NLLB-class MT + TTS) covering ~50-100 languages in both directions.
