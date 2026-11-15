# Task: existing open-source or shipped OFFLINE translator / transcription apps on iOS (feasibility proof)
Notes file: research/notes/oss-apps.md

Find iOS apps (open-source preferred, but also notable closed apps with published tech details) that already run speech recognition and/or translation fully on-device on iPhone. For each: repo/App Store link, which models + runtime they use, which iPhones they support, measured latency/memory if published, languages, license, last update.
Examples to check: WhisperKit sample apps (Argmax), whisper.cpp iOS examples, sherpa-onnx iOS demos, Mozilla/Bergamot translation on iOS, "Offline Translator" style apps using NLLB/Opus-MT, MLX-Swift examples, llama.cpp iOS apps (LLMFarm, PocketPal, etc.) used for translation, any 2025-2026 "on-device live translator" GitHub repos.
Goal: tell us which stack combinations are already PROVEN to run on an iPhone with 6 GB RAM, and which code we can learn from or reuse (with license).
