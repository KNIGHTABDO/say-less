# Task: iOS memory limits for a sideloaded ML app (round 2)
Notes file: research/notes/memory.md
Answer with sources (Apple docs, developer forums, SideStore/AltStore docs and GitHub issues, llama.cpp / MLX / WhisperKit issues):
1. The real per-app memory limit (jetsam / os_proc_available_memory) on a 6 GB iPhone (13 Pro / 13 Pro Max) on iOS 18/26, without entitlements.
2. Can `com.apple.developer.kernel.increased-memory-limit` (and `extended-virtual-addressing`) be used by an app signed with a FREE Apple ID via SideStore/AltStore? Does SideStore strip or keep entitlements? Any reports of it working.
3. Do memory-mapped model weights (llama.cpp mmap, Core ML compiled models on ANE, MLX) count against the jetsam footprint? Practical max model size people run on 6 GB iPhones (with links).
4. Cost of loading models in turn (load STT, unload, load MT...): measured load times for ~0.5–2 GB models on A15/A16 for Core ML / llama.cpp / MLX, and whether keeping two models resident is feasible.
**Final response ≤ 15 lines** + notes file path.
