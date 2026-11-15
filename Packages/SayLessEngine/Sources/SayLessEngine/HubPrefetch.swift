import Foundation

/// Fetches a Hugging Face repo's files in parallel straight into the layout WhisperKit/TTSKit use
/// (`base/models/<repo>/<file>` plus `.cache/huggingface/download/<file>.metadata` holding
/// commit, etag and time). The kit's own download afterwards sees matching metadata and only
/// verifies. If anything here is off, the kit just downloads that file itself, so this can only help.
public enum HubPrefetch {
    struct Revision: Decodable {
        struct Sibling: Decodable {
            struct LFS: Decodable { let sha256: String }
            let rfilename: String
            let blobId: String?
            let size: Int64?
            let lfs: LFS?
        }
        let sha: String
        let siblings: [Sibling]
    }

    /// Big files get a multi-connection download each; small ones go several at a time.
    static let bigFile: Int64 = 24 << 20

    public static func fetch(repo: String, endpoint: String = "https://huggingface.co", base: URL,
                             include: @Sendable (String) -> Bool,
                             progress: @escaping @Sendable (Double) -> Void) async throws {
        let api = URL(string: "\(endpoint)/api/models/\(repo)/revision/main?blobs=true")!
        let (data, response) = try await URLSession.shared.data(from: api)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw EngineError.failed("model list unavailable") }
        let rev = try JSONDecoder().decode(Revision.self, from: data)

        let root = base.appending(path: "models").appending(path: repo)
        let metaRoot = root.appending(path: ".cache/huggingface/download")
        let files = rev.siblings.filter { include($0.rfilename) && ($0.size ?? 0) > 0 }
        guard !files.isEmpty else { throw EngineError.failed("no files matched in \(repo)") }

        let meter = Meter(total: files.reduce(0) { $0 + ($1.size ?? 0) }, report: progress)
        var big: [Revision.Sibling] = []
        var small: [Revision.Sibling] = []
        for f in files {
            let dest = root.appending(path: f.rfilename)
            let meta = metaRoot.appending(path: f.rfilename + ".metadata")
            if isCurrent(dest: dest, meta: meta, size: f.size ?? -1, commit: rev.sha) {
                meter.set(f.rfilename, f.size ?? 0)
                continue
            }
            if (f.size ?? 0) >= bigFile { big.append(f) } else { small.append(f) }
        }
        let resolve = URL(string: endpoint)!.appending(path: repo).appending(path: "resolve").appending(path: rev.sha)

        @Sendable func finished(_ f: Revision.Sibling) throws {
            let meta = metaRoot.appending(path: f.rfilename + ".metadata")
            try FileManager.default.createDirectory(at: meta.deletingLastPathComponent(), withIntermediateDirectories: true)
            let etag = f.lfs?.sha256 ?? f.blobId ?? ""
            try "\(rev.sha)\n\(etag)\n\(Date().timeIntervalSince1970)\n".write(to: meta, atomically: true, encoding: .utf8)
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            // Big files one after another, each on several connections.
            group.addTask {
                for f in big.sorted(by: { ($0.size ?? 0) > ($1.size ?? 0) }) {
                    let dest = root.appending(path: f.rfilename)
                    let part = metaRoot.appending(path: f.rfilename + ".part")
                    _ = try await ChunkedDownloader().download(resolve.appending(path: f.rfilename), to: dest,
                                                               expectedBytes: f.size ?? 0, connections: 6, part: part) { p in
                        meter.set(f.rfilename, Int64(p * Double(f.size ?? 0)))
                    }
                    try finished(f)
                }
            }
            // Small files, four at a time, alongside.
            group.addTask {
                try await withThrowingTaskGroup(of: Void.self) { inner in
                    var it = small.makeIterator()
                    func next() -> Revision.Sibling? { it.next() }
                    for _ in 0..<4 {
                        guard let f = next() else { break }
                        inner.addTask { try await fetchSmall(f, from: resolve, root: root, done: finished, meter: meter) }
                    }
                    while try await inner.next() != nil {
                        if let f = next() {
                            inner.addTask { try await fetchSmall(f, from: resolve, root: root, done: finished, meter: meter) }
                        }
                    }
                }
            }
            try await group.waitForAll()
        }
        EnginePaths.excludeFromBackup(base)
    }

    private static func fetchSmall(_ f: Revision.Sibling, from resolve: URL, root: URL,
                                   done: @Sendable (Revision.Sibling) throws -> Void, meter: Meter) async throws {
        let dest = root.appending(path: f.rfilename)
        var lastError: Error?
        for attempt in 0..<4 {
            do {
                let (tmp, response) = try await URLSession.shared.download(from: resolve.appending(path: f.rfilename))
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw EngineError.failed("HTTP error for \(f.rfilename)") }
                let fm = FileManager.default
                try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? fm.removeItem(at: dest)
                try fm.moveItem(at: tmp, to: dest)
                try done(f)
                meter.set(f.rfilename, f.size ?? 0)
                return
            } catch {
                lastError = error
                try await Task.sleep(for: .seconds(Double(attempt + 1)))
            }
        }
        throw lastError ?? EngineError.failed("download failed: \(f.rfilename)")
    }

    private static func isCurrent(dest: URL, meta: URL, size: Int64, commit: String) -> Bool {
        guard let s = try? dest.resourceValues(forKeys: [.fileSizeKey]).fileSize, Int64(s) == size,
              let m = try? String(contentsOf: meta, encoding: .utf8) else { return false }
        return m.split(separator: "\n").first.map(String.init) == commit
    }

    /// Sums bytes across files and reports overall progress.
    final class Meter: @unchecked Sendable {
        private let lock = NSLock()
        private var bytes: [String: Int64] = [:]
        private let total: Int64
        private let report: @Sendable (Double) -> Void
        private var last = -1.0
        init(total: Int64, report: @escaping @Sendable (Double) -> Void) { self.total = max(1, total); self.report = report }
        func set(_ file: String, _ n: Int64) {
            lock.lock()
            bytes[file] = n
            let p = Double(bytes.values.reduce(0, +)) / Double(total)
            let send = p - last >= 0.002 || p >= 1
            if send { last = p }
            lock.unlock()
            if send { report(min(1, p)) }
        }
    }
}

/// Shell-style glob match, the same rule the Hub client uses (`*` also crosses `/`).
public func globMatch(_ pattern: String, _ name: String) -> Bool {
    fnmatch(pattern, name, 0) == 0
}
