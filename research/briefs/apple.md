# Task: Apple's BUILT-IN on-device speech + translation stack on iOS 26 (zero-download baseline)
Notes file: research/notes/apple.md

Document exactly what Apple gives a third-party app for free, offline, on iOS 26 (and 26.x updates through Nov 2026):
- Translation framework (TranslationSession): which languages, offline after language download?, can a sideloaded app use it?, batch/streaming API, latency notes.
- SpeechAnalyzer / SpeechTranscriber (new in iOS 26) and SFSpeechRecognizer on-device: languages supported on-device, streaming, accuracy notes vs Whisper.
- AVSpeechSynthesizer: offline voices per language, personal/premium voices.
- Live Translation (in Messages/FaceTime/Phone/AirPods) — is any of it exposed to third-party apps via API in iOS 26.x?
- Foundation Models framework (on-device ~3B LLM): can it translate? languages?
- Any limitations for apps signed with a free Apple ID / sideloaded (entitlements, model downloads).
Give the INTERSECTION of languages where Apple supports on-device STT + translation + TTS together. Cite Apple developer docs / WWDC session URLs.
