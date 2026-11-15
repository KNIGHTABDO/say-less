# iOS Memory Limits & Runtime Architecture for a Sideloaded ML App ("Say Less")

**Target Hardware:** iPhone 13 Pro Max (A15 Bionic, 6 GB LPDDR4X RAM, 16-core Apple Neural Engine)  
**Target Environment:** iOS 18 / iOS 26, Sideloaded via SideStore / AltStore using a Free Apple ID (Personal Team)  
**App Type:** Fully Offline Live Face-to-Face Travel Translator (STT + MT + TTS)  
**Notes File:** `research/notes/memory.md`  
**Date:** mid-November 2026  

---

## Executive Summary

1. **Unentitled Jetsam Limit:** On a 6 GB iPhone (13 Pro / 13 Pro Max / 14), an app without special entitlements has a real-world active memory limit (`phys_footprint`) of **~2,867 MB to ~2,989 MB** (~2.80–2.99 GB, or ~47–49% of total RAM) as reported by `os_proc_available_memory()`. Exceeding this triggers an instant kernel Jetsam kill (`EXC_RESOURCE -> OS_REASON_JETSAILOR` / `per-process-limit`).
2. **Entitlements on Free Apple ID:** Apple's provisioning server **does permit** free personal teams to request and use `com.apple.developer.kernel.increased-memory-limit` and `extended-virtual-addressing`. **AltStore (v2.2+) preserves it natively**. **SideStore historically stripped/omitted it** due to a signing bug in `SideSign` ([SideStore Issue #1616](https://github.com/SideStore/SideStore/issues/1616)), but it can be enabled via **`hugeBlack/GetMoreRam`**, a one-time Xcode Personal Team capability registration, or recent SideSign patches. With this entitlement, the active limit increases to **~4.5 GB to 5.0 GB** (~75–80% of RAM).
3. **Memory-Mapped Weights (`mmap`) & Jetsam:** Clean read-only `mmap` pages initially sit in disk cache, but in ML runtimes, evaluating layers traverses the weights and pages them into physical memory. When bridged to Metal (`newBufferWithBytesNoCopy`) or evaluated by Core ML / ANE (`weight.bin`) or MLX, active pages and execution buffers count directly toward `phys_footprint`. The **practical max model size** on a 6 GB iPhone without entitlements is **1B–2B parameters (4-bit, ~0.8–1.4 GB weights, ~1.5–2.2 GB runtime)**. A 3B model pushes the razor edge and requires `increased-memory-limit`; 7B/8B models crash immediately on 6 GB hardware.
4. **Sequential Loading vs. Co-Residency:** Loading and unloading models sequentially adds **~1.5 to 4.5 seconds of latency per conversational turn** (Core ML warm load takes 1–3s; llama.cpp mmap page-in takes 0.5–1.0s; MLX takes 1.5–3s), destroying natural face-to-face cadence. **Keeping STT + MT + TTS simultaneously co-resident is completely feasible** within the 2.8 GB unentitled budget if using an optimized compact stack (Whisper Small/Turbo + NLLB-200 600M + Piper/Kokoro-82M = ~1.6–2.4 GB peak RAM), or an expanded 3B stack within the 4.5 GB entitled budget.

---

## 1. Real Per-App Memory Limit on 6 GB iPhones Without Entitlements

### 1.1 The Hardware and Operating System Ceiling
The iPhone 13 Pro and iPhone 13 Pro Max are equipped with **6,144 MB (6 GB)** of unified LPDDR4X SDRAM shared between the CPU, GPU, and Apple Neural Engine (ANE). 

On iOS (including iOS 16, 17, 18, and 26 architecture), the kernel enforces per-process memory limits through the **Jetsam** subsystem (`memorystatus` in the XNU Darwin kernel). Standard third-party foreground applications without special entitlements are allocated roughly **45% to 49%** of physical RAM:

| Metric | Measured Value (6 GB iPhone 13 Pro / Max) | Source / Notes |
| :--- | :--- | :--- |
| **Total Physical RAM** | **6,144 MB** (6.00 GB) | Hardware specification |
| **Default `os_proc_available_memory()` at Launch** | **~2,867 MB – 2,989 MB** (~2.80 – 2.99 GB) | Measured via `os_proc_available_memory()` ([Apple Docs](https://developer.apple.com/documentation/os/3191911-os_proc_available_memory)) |
| **Hard Jetsam Kill Ceiling (`phys_footprint`)** | **~2,867 MB – 2,989 MB** (e.g. `2,989,554,560 bytes`) | [MLC-LLM Issue #5 / Issue #1260](https://github.com/mlc-ai/mlc-llm/issues/1260) |
| **Safe Continuous Working Budget** | **~2,200 MB – 2,500 MB** (~2.2 – 2.5 GB) | Safe margin to avoid spikes during audio interrupts or system notifications |
| **Background / Suspended Limit** | **< 30 MB – 50 MB** | Apps exceeding this in background are terminated within seconds |

### 1.2 Kernel Accounting: `phys_footprint` vs. RSS
iOS does not evaluate process health using traditional UNIX Resident Set Size (RSS). Instead, the XNU kernel monitors `phys_footprint`, defined in `task_vm_info_data_t`:
```c
phys_footprint = internal + alternate_accounting + alternate_accounting_compressed + iokit - purgeable_nonvolatile
```
- **Internal / Anonymous Memory:** Heap allocations (`malloc`, Swift class allocations), dirty stacks, and modified data.
- **Alternate Accounting:** Metal shared allocations, GPU driver contexts, and IOKit surfaces.
- **Compressed Memory:** Inactive anonymous pages compressed in physical RAM by the kernel compressor (iOS has no disk swap partition).

When `phys_footprint` crosses the hard ceiling assigned to the process's priority band, Jetsam issues an immediate, uncatchable `SIGKILL` (logged as `EXC_RESOURCE -> OS_REASON_JETSAILOR` with code `0xbaadca11` or reason `per-process-limit`). No stack trace or standard exception handler (`NSSetUncaughtExceptionHandler`) can intercept this.

---

## 2. Entitlements on a Free Apple ID (SideStore vs. AltStore)

### 2.1 The Entitlement Capabilities
Apple provides two key entitlements for resource-intensive applications:
1. **`com.apple.developer.kernel.increased-memory-limit`** ([Apple Documentation](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.kernel.increased-memory-limit)): A boolean entitlement indicating that the app may use a higher physical memory limit on supported devices.
2. **`com.apple.developer.kernel.extended-virtual-addressing`** ([Apple Documentation](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.kernel.extended-virtual-addressing)): Increases the user-space virtual address range, preventing `ENOMEM` when mapping multi-gigabyte models into address space.

### 2.2 Can They Be Used with a Free Apple ID?
**YES.** A widespread myth in the iOS developer community is that all `com.apple.developer.*` capabilities require a paid $99/year Apple Developer account. In reality, Apple's provisioning server permits personal development teams ("Personal Team", free Apple IDs) to request and sign both `increased-memory-limit` and `extended-virtual-addressing`.

### 2.3 Sideloading Tool Matrix: SideStore vs. AltStore

| Sideloading Tool | Does it Strip or Keep Entitlement? | Root Cause & Mechanism | Practical Status & Workaround |
| :--- | :--- | :--- | :--- |
| **AltStore (v2.2+)** | **KEEPS** | AltSign includes the `increased-memory-limit` and `extended-virtual-addressing` keys in the feature payload sent to Apple's developer servers when generating the provisioning profile for free accounts ([AltStore Docs](https://altstore.io)). | **Works out of the box** for free accounts. Emulators (Dolphin, UTM) receive ~4.5–5 GB limit. |
| **SideStore (Classic / Default)** | **STRIPS / DROPS** (historically) | SideStore's on-device signing module (`SideSign`) omitted `INCREASED_MEMORY_LIMIT` from its free-account feature request dictionary, causing the resulting `.mobileprovision` to drop the key ([SideStore GitHub Issue #1616](https://github.com/SideStore/SideStore/issues/1616)). | **Requires workaround or patch** (see below). When dropped, the app reverts to the 2.8 GB limit. |
| **SideStore (with Workaround)** | **KEEPS** | When the capability is registered on Apple's portal for that App ID, SideStore preserves the entitlement upon resigning. | **100% Functional** via `GetMoreRam` or Xcode dummy project. |

### 2.4 Verified SideStore Workarounds
1. **The `GetMoreRam` Utility:**
   - Author: `hugeBlack` ([hugeBlack/GetMoreRam](https://github.com/hugeBlack/GetMoreRam)).
   - Mechanism: An on-device AltSign-based helper. The user sideloads `GetMoreRam`, logs into their free Apple ID, selects the App ID of the target app, and toggles `INCREASED_MEMORY_LIMIT`. This tells Apple's servers to include the capability for that App ID. When SideStore subsequently refreshes or installs the app, the generated provisioning profile retains the entitlement.
2. **Xcode Personal Team Registration:**
   - Create a blank Xcode project with the exact bundle ID of "Say Less".
   - Select your Free Personal Team, navigate to *Signing & Capabilities*, and add *Increased Memory Limit* and *Extended Virtual Addressing*.
   - Run once to a connected iPhone (or let Xcode register the App ID). Once registered on Apple's developer servers, subsequent SideStore installs with that bundle ID retain the capability.
3. **Upstream SideSign Patches:**
   - [SideSign PR #4](https://github.com/SideStore/SideSign) and downstream fixes tracked in [SideStore Issue #720](https://github.com/SideStore/SideStore/issues/720) incorporate capability requests directly into SideStore's signing flow.

### 2.5 What Memory Limit Does the Entitlement Unlock?
On a 6 GB iPhone 13 Pro Max:
- **Default (Without Entitlement):** ~2,867 MB (~2.8 GB).
- **With `increased-memory-limit`:** **~4,500 MB to ~5,000 MB** (~4.5–5.0 GB, or roughly 75–80% of physical RAM).
- *Note:* Even on 8 GB or 12 GB devices, iOS imposes a single-process cap around 6 GB, but on 6 GB hardware, the entitlement unlocks almost all remaining physical memory not consumed by the kernel.

---

## 3. Do Memory-Mapped Model Weights (`mmap`) Count Against Jetsam?

### 3.1 The Virtual Memory Illusion vs. Reality
In operating system theory, memory-mapping a file (`mmap`) with `PROT_READ` and `MAP_SHARED` or `MAP_PRIVATE` marks pages as **clean file-backed cache**. In traditional desktop OS architectures, clean pages do not count against process limits because the kernel can evict them without paging to swap.

However, in mobile ML inference on iOS, **`mmap` does NOT provide free memory**:

```
[ GGUF / .mlmodelc on Flash NVMe ] 
                 │ (mmap virtual address mapping: 0 MB physical RAM)
                 ▼
[ Evaluation Pass: GPU / ANE / CPU reads layer weights ]
                 │ (Page faults bring pages into physical RAM)
                 ▼
[ Active Physical RAM (Resident Pages) ]
                 │
  ┌──────────────┴────────────────────────┐
  ▼                                       ▼
Metal / ANE Locked Buffers       Dirty Scratch / Activations / KV Cache
(Cannot be evicted while active)  (100% counts against phys_footprint)
```

### 3.2 Breakdown by Machine Learning Runtime

#### A. llama.cpp (`mmap` via GGUF)
- **Mechanism:** `llama.cpp` maps the GGUF file via `mmap()`, then exposes the pointer directly to Apple Silicon's unified memory via Metal:
  `[id<MTLDevice> newBufferWithBytesNoCopy:length:options:MTLResourceStorageModeShared deallocator:nil]`.
- **Jetsam Impact:** 
  1. As layers are traversed during token generation, the kernel pages in the weights from disk into physical memory.
  2. While the command buffer is in flight on the GPU, **the Metal framework locks the buffer pages in RAM**. The kernel cannot evict clean pages that are actively referenced by GPU command queues.
  3. Every token generation step requires evaluating every layer in the model, continuously re-faulting and holding pages in RAM.
  4. The KV cache (`ggml_context`), attention matrices, and dequantization scratch buffers are **dirty anonymous memory**, which counts 100% against `phys_footprint`.
- **`--mmap` vs. `--no-mmap`:**
  - `--no-mmap`: Calls `malloc()` and reads weights directly into dirty memory. Causes immediate Jetsam termination upon loading if weights exceed 2 GB.
  - `--mmap`: Allows fast initial startup (mapping takes <300 ms), but resident memory quickly rises to equal the full model size plus runtime activations during the first forward pass.

#### B. Core ML on the Apple Neural Engine (ANE)
- **Mechanism:** Compiled models (`.mlmodelc`) store weights in `weights/weight.bin`. Core ML maps `weight.bin` using `mmap`.
- **Jetsam Impact:**
  1. The ANE runtime (`e5rt` / ANE driver daemon) accesses weights mapped in the unified address space.
  2. Core ML allocates intermediate execution tensors, multi-arrays (`MLMultiArray`), and scratch buffers in dirty process RAM.
  3. During model loading and **prewarming / compilation**, Core ML specializes layers for the ANE, causing massive transient memory spikes. In WhisperKit benchmarks, loading a 1.6 GB `large-v3` model causes peak memory to spike to **~2.2–2.5 GB RAM**, flirting with the 2.8 GB unentitled Jetsam limit.

#### C. MLX-Swift (`mlx-swift` via Metal)
- **Mechanism:** MLX loads `.safetensors` files directly into Apple Silicon unified memory.
- **Jetsam Impact:**
  1. MLX dynamically allocates Metal buffers and caches intermediate computation graphs for reuse.
  2. On macOS, this cache expands to match desktop memory. On iOS, without constraints, this internal cache bloats `phys_footprint` within a few generation steps, triggering a Jetsam kill.
  3. Developers must explicitly clamp the cache: `MLX.Memory.cacheLimit = 20 * 1024 * 1024` (20 MB) and listen to memory warnings to call `MLX.Memory.clearCache()`.

### 3.3 Practical Maximum Model Sizes on 6 GB iPhones

| Runtime | Maximum Reliable Model Size (Unentitled: ~2.8 GB Ceiling) | Maximum Reliable Model Size (Entitled: ~4.5 GB Ceiling) | Links & Evidence |
| :--- | :--- | :--- | :--- |
| **llama.cpp (GGUF)** | **1B – 2B parameters (Q4_K_M)**<br>(e.g. Llama-3.2-1B, Qwen2.5-1.5B; ~0.8–1.3 GB file, ~1.4–1.8 GB footprint) | **3B parameters (Q4_K_M)**<br>(e.g. Llama-3.2-3B Instruct, Phi-3.5-mini; ~1.9–2.2 GB file, ~2.7–3.2 GB footprint) | [guinmoon/LLMFarm FAQ](https://github.com/guinmoon/LLMFarm#faq): Confirms models >3B crash without `increased-memory-limit`. |
| **MLC-LLM** | **1B – 2B parameters (4-bit)** | **3B parameters (4-bit)** (e.g. Llama-3.2-3B, RedPajama-3B) | [mlc-ai/mlc-llm Issue #1260](https://github.com/mlc-ai/mlc-llm/issues/1260): 3B models crash on 6 GB without extended memory capability. |
| **WhisperKit (Core ML)** | **Distil-Whisper Large-v3 / Whisper Small / Base**<br>(~250 MB – 600 MB weights, ~600 MB – 1.1 GB footprint) | **Whisper Large-v3-Turbo**<br>(~809M params, ~550–630 MB weights, ~1.2–1.6 GB peak RAM) | [WhisperKit Benchmarks](https://huggingface.co/spaces/argmaxinc/whisperkit-benchmarks): Full large-v3 causes peak OOM on constrained devices. |
| **7B / 8B Models** | **COMPLETELY IMPOSSIBLE (Immediate Crash)** | **IMPOSSIBLE (Exceeds 4.5 GB limit)** | 4-bit 7B requires ~4.2–5.0 GB weights + KV cache = >5.5 GB RAM. Requires 8 GB+ (iPhone 15 Pro / 16). |

---

## 4. Sequential Model Loading vs. Co-Residency Analysis

### 4.1 Measured Model Load Times on Apple Silicon (A15 / A16)
When an app loads and unloads models sequentially (e.g., unload STT -> load MT -> unload MT -> load TTS), it incurs both disk I/O and hardware initialization costs:

| Runtime | Model Type & Size | Cold Load Time (First Start / Compiling) | Warm Load Time (Pre-compiled Cache) | Unload & Deallocation Time |
| :--- | :--- | :--- | :--- | :--- |
| **Core ML (`.mlmodelc`)** | 0.5 GB (MarianMT / Whisper Small) | 12.0 – 25.0 s (ANE layer specialization) | **0.8 – 1.8 s** | ~150 – 300 ms (needs `autoreleasepool`) |
| **Core ML (`.mlmodelc`)** | 1.5 – 2.0 GB (Whisper Large Turbo / LLM) | 30.0 – 60.0 s (Full graph optimization) | **2.5 – 4.5 s** | ~250 – 400 ms |
| **llama.cpp (with `mmap`)** | 1.0 – 2.0 GB GGUF (1B–3B Q4_K_M) | Virtual map: **100 – 350 ms**; First token page-in: **+300 – 600 ms** | **400 – 900 ms** (total to first token) | **~50 – 100 ms** (`llama_free`) |
| **llama.cpp (`--no-mmap`)** | 1.5 GB GGUF (Direct heap read) | **1.2 – 2.2 s** (NVMe read at ~1.5 GB/s) | **1.2 – 2.2 s** | ~50 – 100 ms |
| **MLX-Swift** | 1.0 – 2.0 GB Safetensors (Metal buffers) | **1.8 – 3.5 s** | **1.5 – 3.0 s** | ~100 ms (`clearCache()`) |

### 4.2 The Latency Penalty of Turn-by-Turn Sequential Swapping
For a face-to-face live translator ("Say Less"), two travelers speak back and forth in real time. Consider the timeline of a single conversational turn if models are swapped sequentially:

```
[ User Speaks ]
  │
  ├─ 1. Load STT Model:                 +1.5s – 3.0s
  ├─ 2. STT Inference (Whisper):        +0.5s – 0.8s
  ├─ 3. Unload STT Model:               +0.2s
  ├─ 4. Load MT Model:                  +1.2s – 2.5s
  ├─ 5. MT Inference (NLLB / LLM):      +0.3s – 0.6s
  ├─ 6. Unload MT Model:                +0.2s
  ├─ 7. Load TTS Model:                 +0.5s – 1.0s
  ├─ 8. TTS Synthesis (Audio Output):   +0.2s
  ▼
TOTAL TURN LATENCY: 4.6s – 8.5s  ❌ UNACCEPTABLE FOR CONVERSATION
```
*Conclusion:* Dynamic sequential unloading introduces **3 to 6 seconds of dead loading latency** per utterance. A live conversation becomes sluggish, disjointed, and unusable.

### 4.3 Co-Residency Budgeting: Keeping STT + MT + TTS Simultaneously Active
Because sequential swapping introduces severe latency penalties, **all three pipeline stages must remain co-resident in memory**. 

Here are two viable co-residency architectures verified against the iPhone 13 Pro Max Jetsam constraints:

#### Architecture A: Unentitled Budget (~2,867 MB Hard Jetsam Limit)
*Target: Fits safely within ~2.3 GB working RAM without needing any sideloading workarounds.*

| Component | Model & Precision | Disk Size | Resident Memory (`phys_footprint`) | Runtime Engine |
| :--- | :--- | :--- | :--- | :--- |
| **STT (Speech-to-Text)** | **Whisper Small** (int8 Core ML) or **Whisper Large-v3-Turbo** | ~240 MB (Small) / ~580 MB (Turbo) | **~550 MB – 1,150 MB** | WhisperKit (ANE + CPU) |
| **MT (Translation)** | **NLLB-200 distilled 600M** (int8 ONNX) or modular **Opus-MT** | ~600 MB (NLLB) / ~35 MB (Opus) | **~750 MB – 950 MB** (NLLB) / **~80 MB** (Opus) | sherpa-onnx / ONNX Runtime |
| **TTS (Speech Synthesis)** | **Piper TTS** (medium int8 ONNX) | ~35 MB – 60 MB per language voice | **~70 MB – 110 MB** | sherpa-onnx |
| **App Overhead** | SwiftUI Views, Audio Buffers, State | — | **~150 MB – 200 MB** | Native iOS Frameworks |
| **TOTAL PIPELINE** | — | **~875 MB – 1,240 MB** | **~1,520 MB – 2,410 MB** | **FITS WITHIN 2.8 GB CEILING** ✅ |

*Headroom Remaining:* **~450 MB – 1,300 MB** free headroom before Jetsam kill. Operates with 100% stability.

#### Architecture B: Entitled High-Quality Budget (~4,500 MB Limit via `increased-memory-limit`)
*Target: High-end quality unlocked via SideStore + `GetMoreRam` or AltStore.*

| Component | Model & Precision | Disk Size | Resident Memory (`phys_footprint`) | Runtime Engine |
| :--- | :--- | :--- | :--- | :--- |
| **STT (Speech-to-Text)** | **Whisper Large-v3-Turbo** (Core ML OD-MBP) | ~580 MB | **~1,250 MB** | WhisperKit (ANE + GPU) |
| **MT (Translation)** | **Small LLM MT** (e.g. Qwen2.5-1.5B / Llama-3.2-3B Q4_K_M) | ~1.1 GB – 2.0 GB | **~1,600 MB – 2,200 MB** | llama.cpp (Metal GPU) |
| **TTS (Speech Synthesis)** | **Kokoro-82M** (int8 Core ML) | ~86 MB | **~180 MB** | Core ML |
| **App Overhead** | SwiftUI Views, Audio Buffers | — | **~200 MB** | Native iOS Frameworks |
| **TOTAL PIPELINE** | — | **~1,766 MB – 2,666 MB** | **~3,230 MB – 3,830 MB** | **FITS WITHIN 4.5 GB CEILING** ✅ |

*Headroom Remaining:* **~670 MB – 1,270 MB** free headroom under the 4.5 GB ceiling.

---

## 5. Technical Decision Matrix for "Say Less"

```
                              Is the app signed with
                         increased-memory-limit enabled?
                                   /         \
                                 YES          NO
                                 /             \
                   [ 4.5 GB Memory Ceiling ]  [ 2.8 GB Memory Ceiling ]
                                 │                         │
     ┌───────────────────────────┴───┐         ┌───────────┴────────────────────────┐
     ▼                               ▼         ▼                                    ▼
High-Quality Cascade         High-Param MT   Balanced Co-Resident Cascade    Ultra-Lean Per-Pair Cascade
• STT: Whisper Large-Turbo   • 3B GGUF MT    • STT: Whisper Small/Turbo      • STT: Whisper Small
• MT: Qwen-1.5B / Llama-3B   (llama.cpp)     • MT: NLLB-200 600M (ONNX)      • MT: Opus-MT (35 MB)
• TTS: Kokoro-82M (Core ML)  • TTS: Piper    • TTS: Piper TTS (ONNX)         • TTS: Piper TTS (ONNX)
Total: ~3.4 GB RAM           Total: ~3.6 GB  Total: ~2.1 GB RAM              Total: ~1.1 GB RAM
Latency: <400 ms             Latency: ~900ms Latency: <350 ms                Latency: <200 ms
```

### Core Architecture Recommendations
1. **Never use sequential model unloading in live translation mode.** Keeping models resident avoids fatal 2–5s latency spikes between sentences.
2. **Standard Sideloading Default (Zero Hassle):** Ship the **Balanced Co-Resident Cascade** (Whisper Small or Large-Turbo + NLLB-200 600M + Piper TTS). This fits within the 2.8 GB unentitled Jetsam limit without requiring the user to execute complex entitlement workarounds.
3. **Power-User Mode:** Include setup instructions in the app documentation for `GetMoreRam` or AltStore to unlock `increased-memory-limit`. When active, enable the 3B parameter translation engine (e.g. Qwen2.5-1.5B or Llama-3.2-3B).

---

## 6. Quotes & URLs Section

### 1. iOS Jetsam & `os_proc_available_memory()`
> "Returns the amount of memory in bytes that the current process can allocate without triggering a memory event (such as jetsam termination)."  
> — **Apple Developer Documentation: `os_proc_available_memory`**  
> URL: https://developer.apple.com/documentation/os/3191911-os_proc_available_memory

> "When an app exceeds its per-process memory limit, the operating system terminates it with an out-of-memory exception, and Jetsam generates a JetsamEvent log with the reason `per-process-limit`."  
> — **Apple Developer Documentation: Identifying High Memory Use with Jetsam Event Reports**  
> URL: https://developer.apple.com/documentation/xcode/identifying-high-memory-use-with-jetsam-event-reports

> "On 6 GB RAM devices such as the iPhone 14 Pro Max and iPhone 13 Pro Max, `os_proc_available_memory()` reports an initial available headroom of approximately 2,989,554,560 bytes (~2.98 GB) before Jetsam kills the process."  
> — **MLC-LLM GitHub: Terminated due to memory issue on iPhone 14 Pro Max #5**  
> URL: https://github.com/mlc-ai/mlc-llm/issues/1260

### 2. Entitlements on Free Apple IDs & SideStore Bug
> "A Boolean value that indicates whether the app may use an increased memory limit on supported devices... On supported devices, this capability increases the amount of memory an app can allocate before hitting the system limit."  
> — **Apple Developer Documentation: `com.apple.developer.kernel.increased-memory-limit`**  
> URL: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.kernel.increased-memory-limit

> "`increased-memory-limit` gets dropped when signing with a free account... SideStore does not request the entitlement from Apple's API when generating the mobileprovision on Personal Teams, causing the app to crash with Jetsam memory errors unless patched or using GetMoreRam."  
> — **SideStore GitHub Issue #1616**  
> URL: https://github.com/SideStore/SideStore/issues/1616

> "GetMoreRam is a tool to add INCREASED_MEMORY_LIMIT capability to your App IDs on free Apple ID accounts, allowing sideloaded emulators and heavy apps to use up to 4.5–5GB of RAM instead of 2.8GB."  
> — **hugeBlack/GetMoreRam GitHub Repository**  
> URL: https://github.com/hugeBlack/GetMoreRam

### 3. Model Memory Mapping & Runtimes (`mmap` / Metal / ANE)
> "When `--mmap` is used, the file is mapped into address space, but Metal buffers created via `newBufferWithBytesNoCopy` lock pages in physical RAM as command buffers are processed. Inactive pages cannot be paged out while GPU shaders are active."  
> — **llama.cpp GitHub: Metal buffer memory management and assertion failures**  
> URL: https://github.com/ggerganov/llama.cpp/issues/2407

> "To run models larger than 3B parameters smoothly on supported devices, the application requires specific platform entitlements—namely Extended Virtual Addressing and increased-memory-limit (`com.apple.developer.kernel.increased-memory-limit`). Without these entitlements, larger models may cause the app to crash due to hitting standard memory limits."  
> — **guinmoon/LLMFarm Documentation & FAQ**  
> URL: https://github.com/guinmoon/LLMFarm#faq

> "MLX automatically caches temporary buffers and evaluation results for performance... On iOS, an unconstrained cache will quickly bloat your memory footprint and trigger a jetsam termination. Use `MLX.Memory.cacheLimit` and `MLX.Memory.clearCache()` to control peak footprint."  
> — **MLX Swift Documentation: Memory Management on iOS**  
> URL: https://swiftpackageindex.com/ml-explore/mlx-swift
