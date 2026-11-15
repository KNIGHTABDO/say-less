# Say Less

Face-to-face live translation for travel. Everything runs on the iPhone, offline:

- **Speech → text:** Whisper large-v3 (WhisperKit, Core ML / Neural Engine)
- **Translation:** Tencent Hy-MT2 1.8B, Q4_K_M (llama.cpp, Metal); HY-MT1.5 1.8B as fallback
- **Voice:** Qwen3-TTS 0.6B (TTSKit) for 10 languages; the rest are read-only cards

Models download inside the app on first run (Wi-Fi recommended, ~2.8 GB total) and never leave the phone.

## Build

There is no Mac in the loop: GitHub Actions is the compiler.

- Every push compiles the app for the simulator (`.github/workflows/ios.yml`).
- Changes under `Packages/` also run the real-model smoke test on the runner (`smoke.yml`).
- A `v*` tag builds an unsigned `SayLess.ipa` and attaches it, with a SideStore source (`apps.json`), to a GitHub Release.

## Install

1. Open the latest release on GitHub on the iPhone and download `SayLess.ipa`.
2. In SideStore: **My Apps → +** and pick the file.

Requires iOS 26. Built for iPhone 13 Pro Max (A15, 6 GB) and newer.
