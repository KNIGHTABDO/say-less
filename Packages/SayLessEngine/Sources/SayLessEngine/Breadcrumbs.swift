import Foundation
#if os(iOS)
import os
#endif

/// Memory headroom and crash breadcrumbs. Before every model load we write the stage and the
/// free memory to disk, and mark it done afterwards. If the app is killed (jetsam) mid-load,
/// the next launch reads "died loading X" and can adapt (for example start with voice off).
public enum MemoryProbe {
    /// MB the app can still allocate before iOS kills it. Int.max where unknown (macOS).
    public static func availableMB() -> Int {
        #if os(iOS)
        let bytes = os_proc_available_memory()
        return bytes > 0 ? Int(bytes / 1_048_576) : Int.max
        #else
        return Int.max
        #endif
    }

    /// Resident footprint of this process in MB.
    public static func footprintMB() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return kr == KERN_SUCCESS ? Int(info.phys_footprint / 1_048_576) : 0
    }
}

public enum Breadcrumbs {
    private static let lock = NSLock()

    public static func begin(_ stage: String) {
        write("BEGIN \(stage) avail=\(MemoryProbe.availableMB())MB footprint=\(MemoryProbe.footprintMB())MB")
    }

    public static func end(_ stage: String, ms: Int) {
        write("END \(stage) \(ms)ms footprint=\(MemoryProbe.footprintMB())MB")
    }

    public static func note(_ text: String) { write("NOTE \(text)") }

    /// The stage that began but never ended in the previous run, if any.
    public static func unfinishedStage() -> String? {
        guard let text = try? String(contentsOf: EnginePaths.breadcrumbs, encoding: .utf8) else { return nil }
        var open: [String: Bool] = [:]
        var last: String?
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 3).map(String.init)
            guard parts.count >= 3 else { continue }
            if parts[1] == "BEGIN" { open[parts[2]] = true; last = parts[2] }
            if parts[1] == "END" { open[parts[2]] = false }
        }
        if let last, open[last] == true { return last }
        return nil
    }

    public static func tail(_ lines: Int = 80) -> String {
        guard let text = try? String(contentsOf: EnginePaths.breadcrumbs, encoding: .utf8) else { return "" }
        return text.split(separator: "\n").suffix(lines).joined(separator: "\n")
    }

    /// Start a new session log, keeping the previous one's tail for diagnostics.
    public static func rotate() {
        lock.lock(); defer { lock.unlock() }
        let url = EnginePaths.breadcrumbs
        if let text = try? String(contentsOf: url, encoding: .utf8) {
            let kept = text.split(separator: "\n").suffix(200).joined(separator: "\n")
            try? (kept + "\n--- launch \(Date().formatted(.iso8601)) ---\n").write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private static func write(_ line: String) {
        lock.lock(); defer { lock.unlock() }
        let stamp = String(format: "%.3f", Date().timeIntervalSince1970)
        let data = Data("\(stamp) \(line)\n".utf8)
        let url = EnginePaths.breadcrumbs
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(data); try? h.synchronize(); try? h.close()
        } else {
            try? data.write(to: url)
        }
    }
}
