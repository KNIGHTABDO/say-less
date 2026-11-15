# Say Less: on-device model research summary (2026-11-15)

Six Gemini 3.8 Flash research jobs (briefs in `briefs/`, full tables in `notes/`), with key claims spot-checked by Claude.
Everything here is a **shortlist**. The real decision comes from a benchmark build running on the iPhone 13 Pro Max.

## Verdict: cascade, hybrid "Apple first, open models for everything else"

No single end-to-end speech-to-speech model is ready for two-way travel in Nov 2026. The open ones translate mostly *into English* (Whisper translate, Hibiki FR→EN), cover few languages (LFM3-Audio-2B: 18), or nearly exhaust the ~2.8 GB app memory (Gemma 3n E2B). So the plan is **STT → translation → TTS**, with each stage swappable.

Apple's on-device engines *probably* run in system daemons, so their RAM would not count against our app's memory limit. That would be a big win on a 6 GB phone, but it is unverified (see flags).

## How many languages actually work end to end (estimates, to verify on the phone)
| Tier | Text translation (STT ∩ MT) | With spoken voice output too |
|---|---|---|
| Apple only | ~20 (bounded by `TranslationSession`) | ~20 |
| + WhisperKit + NLLB | ~95–99 (Whisper's list) | ~50–60 (bounded by offline AVSpeech/Piper voices) |
| + Omnilingual ASR + NLLB | up to ~200 (NLLB's list), incl. Darija | voice only via MMS-TTS (non-commercial, rough quality) |
Voice output always covers fewer languages than text. For the rest the other person reads the screen.

| Stage | Tier 1: zero download (Apple) | Tier 2: universal | Tier 3: long tail / bonus |
|---|---|---|---|
| Speech → text | SpeechAnalyzer / SpeechTranscriber (iOS 26; A15 support unverified, DictationTranscriber is Apple's fallback) | **WhisperKit** (~99 langs, Core ML/ANE, also detects the spoken language). **Size is a benchmark variable**: base/small (~300 MB RAM) vs large-v3-turbo (~1.3 GB RAM) | Meta **Omnilingual ASR 300M** via sherpa-onnx (1,600+ langs incl. Darija `ary`, ~365 MB int8; one benchmark reports English broken in the int8 build) |
| Translation | Translation framework (`TranslationSession`) | **NLLB-200 distilled 600M** int8 (200 langs incl. Darija, CC-BY-NC = fine for a personal app) | **Hy-MT2 1.8B** (Tencent, May 2026, 33 langs, claims beat commercial MT, ~440 MB at 1.25-bit, but needs Tencent's custom llama.cpp kernel). Opus-MT/Bergamot tiny per-pair models for speed |
| Text → speech | AVSpeechSynthesizer (offline + premium voices, most languages) | Piper voices via sherpa-onnx (~35–40 langs) | **Phonon** (Gradium, Oct 2026, 31–40M params, 5 langs, Core ML backend), Kokoro-82M (8 langs), MMS-TTS (1,100 langs, non-commercial) |
| End-to-end (watch list) | n/a | n/a | LFM3-Audio-2B (18 langs, 2B), worth one benchmark only |

## Flagged / unverified
- Gemini claimed a "44-language intersection" for Apple's three engines. That is **not verified**. Apple's Translate has historically covered ~20 languages. The app's diagnostics screen will read `supportedLocales` / `LanguageAvailability` on the real phone.
- Gemini's iPhone speed numbers (RTF, ms) come from mixed sources. They need to be re-measured on the device.
- **Memory budget**: Whisper large-v3-turbo (~1.3 GB) + NLLB 600M (~1.2 GB) ≈ 2.5 GB, which is too close to the ceiling once a voice model is added. Default to a smaller Whisper unless the benchmark proves otherwise.
- "Apple engines run out of process, so they cost our app ~0 RAM" comes from Gemini only. To be measured.
- SpeechTranscriber has hardware requirements (Apple engineer on the dev forums; iPhone 11 reported unsupported). Whether the A15 qualifies is unknown, so check `SpeechTranscriber.isAvailable` on the phone. Fallback: `DictationTranscriber`.
- The phone's iOS version is assumed to be iOS 26.x. To confirm.
- NLLB int8 ONNX port (`boat1603`) was not opened by Claude.
- Memory ceiling for a free-Apple-ID sideloaded app on a 6 GB iPhone: ~2.8 GB assumed. To be measured.
- Hy-MT2's quality claims come from Tencent and secondary press only.

## Implications for the app
- **Language packs per trip**: offline everything-at-once doesn't fit. Packs are downloaded in-app; the app shows which tier each language runs on.
- **Model registry in-app**: models are swappable without a rebuild (download from Hugging Face URLs).
- **Diagnostics screen from build 1**: latency per stage, tokens/s, peak memory, thermal state, copyable log.
- **First spike** = an ugly benchmark build: Apple tier vs WhisperKit + NLLB on the phone, numbers out via the diagnostics screen.

## Sources checked by Claude
- Phonon TTS: https://huggingface.co/blog/phonon-tts
- Hy-MT2: https://dev.to/czmilo/tencent-open-sources-hy-mt2-series-three-models-redefine-translation-1kcl , https://github.com/Tencent-Hunyuan/HY-MT
- Omnilingual ASR in sherpa-onnx: https://csukuangfj.github.io/sherpa/onnx/omnilingual-asr/index.html
- LFM3-Audio-2B: https://huggingface.co/LiquidAI/LFM3-Audio-2B
- Proven iOS stack: https://github.com/voiceping-ai/ios-android-offline-speech-translation (Apache-2.0). Opened by Claude: it actually uses **SenseVoice (sherpa-onnx) or Apple SFSpeechRecognizer + Apple Translation + AVSpeechSynthesizer**, not WhisperKit as Gemini said. There are no iPhone numbers; the only benchmark is on an A12X iPad.
- SpeechTranscriber hardware gate: https://developer.apple.com/forums/thread/801197 , https://developer.apple.com/forums/thread/807739
