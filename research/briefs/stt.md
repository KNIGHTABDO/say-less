# Task: on-device multilingual SPEECH-TO-TEXT (streaming) for iPhone
Notes file: research/notes/stt.md

Find the best on-device speech recognition models for a travel translator: maximum language coverage, streaming/low latency, fits iPhone 13 Pro Max.
Must include and compare at least: Whisper family (large-v3-turbo, distilled/quantized variants via WhisperKit / whisper.cpp), NVIDIA Canary / Parakeet multilingual variants, Meta MMS / Omnilingual ASR (2025+), Moonshine (multilingual?), SenseVoice, Kyutai STT, Mistral Voxtral (mini), Qwen ASR/Qwen-Omni, Google Gemma audio (Gemma 3n / newer), FunASR, any 2026 releases you find.
Also: automatic language identification (LID) — which model does spoken-language ID well on device, since travellers won't always know the other person's language.
Report Word Error Rate on a multilingual benchmark (FLEURS, Common Voice) where published.
