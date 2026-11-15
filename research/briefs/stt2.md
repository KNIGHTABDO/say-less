# Task: best-QUALITY on-device speech recognition per language (round 2)
Notes file: research/notes/stt2.md
Metric: WER/CER on FLEURS (and Common Voice where available), per panel language.
Candidates to evaluate at minimum: Whisper large-v3 / large-v3-turbo (and any Whisper v4 / 2026 successor), Distil-Whisper multilingual, NVIDIA Canary-1B-v2 / Canary-Qwen / Parakeet-tdt-0.6b-v3 / newer Nemotron ASR small models, Meta Omnilingual ASR (300M, 1B, 3B, 7B CTC and LLM variants), Mistral Voxtral Mini / Voxtral Realtime, Qwen3-ASR / Qwen3-Omni small, Kyutai STT, SenseVoice, FunASR / Fun-ASR-Nano, Moonshine (multilingual), Gemma 3n / Gemma 4 audio, Microsoft Phi-4-multimodal audio, IBM Granite Speech, ElevenLabs/others open releases, any 2026 multilingual ASR on HF leaderboards (Open ASR Leaderboard multilingual track).
Also: best on-device spoken language identification (LID) model and its accuracy.
