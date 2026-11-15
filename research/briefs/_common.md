## Context (shared by every research job)

We are building "Say Less", a native SwiftUI iPhone app: a **fully offline, on-device live translator for world travel**.
The core moment: two people face to face, phone between them, each speaks their own language, the other sees text and hears speech in theirs, with as little delay as possible. Must work with no internet (airplane mode, abroad without data). Must cover **as many of the world's languages as possible** (travel everywhere: Europe, Asia, Middle East, Africa, Latin America). Moroccan Arabic (Darija) support is a bonus worth noting.

Target device: **iPhone 13 Pro Max** (A15 Bionic, 16-core Neural Engine, **6 GB RAM**, iOS 26). The app is sideloaded with **SideStore on a free Apple ID**, so assume the "increased memory limit" entitlement is NOT available: plan for roughly **2.5–3 GB max app memory** (verify the real jetsam limit for 6 GB iPhones if you can find it). Models are downloaded inside the app per language/trip (not bundled), so disk size matters but is not fatal.

Date: **mid-November 2026**. Look for the newest releases (2025 and 2026), not only famous older models. Search Hugging Face, GitHub, model cards, official blogs, arXiv, Apple developer docs. Posts on X/Twitter/Reddit are allowed as leads only: any claim whose only source is a social post must be marked **UNVERIFIED**.

### Hard filters for every candidate
1. Languages supported (give the count AND the list or a link to the list).
2. A **working iOS runtime exists today**: Core ML, MLX-Swift, llama.cpp/GGUF, ONNX Runtime / sherpa-onnx, WhisperKit, ExecuTorch, or a shipped iOS app/SDK using it. A bare PyTorch checkpoint with no iOS path = reject (list it separately as "promising, no iOS path").
3. Fits the memory budget above (quantized size + runtime RAM).
4. Streaming / low-latency capable (say how: chunked, streaming encoder, etc.).
5. License allows use in a personal (and ideally commercial) app.

### Deliverable
Write the full result to the notes file named in your task. It must contain:
- A markdown table, one row per candidate: name | model-card URL | release date | params | quantized disk size | runtime RAM | languages (count) | license | iOS runtime + link | published iPhone/Apple-silicon speed numbers (with source URL) | streaming? | notes.
- A ranked top 3 with one paragraph each on why.
- A "rejected and why" list.
- Every factual claim needs a source URL next to it. Never invent numbers; write "unknown" instead.

**Your final response (stdout) must be at most 15 lines**: the top 3 in one line each + the notes file path. Do not paste the table in the response.
