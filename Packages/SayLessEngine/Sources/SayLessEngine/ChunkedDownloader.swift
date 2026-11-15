import Foundation

/// Fast download of one big file: several HTTP Range requests at once, each on its own URLSession
/// (so its own TCP connection; one HTTP/2 connection would share a single congestion window).
/// Bytes stream straight into a preallocated `.part` file and a small map records finished chunks,
/// so a killed app resumes where it stopped. Falls back to one stream when the server ignores Range.
public final class ChunkedDownloader: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    public static let chunkBytes: Int64 = 8 << 20

    private struct Active { var worker: Int; var chunk: Int; var offset: Int64; var length: Int64; var written: Int64 = 0 }
    private enum Failure: Error { case noRange }

    // All state below is touched only on `queue` (serial).
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        q.name = "ChunkedDownloader"
        return q
    }()
    private var sessions: [URLSession] = []
    private var url: URL!
    private var handle: FileHandle!
    private var mapURL: URL!
    private var total: Int64 = 0
    private var done: [Bool] = []
    private var pending: [Int] = []
    private var active: [Int: Active] = [:]
    private var retries: [Int: Int] = [:]
    private var bytesDone: Int64 = 0
    private var lastReported = -1.0
    private var progress: (@Sendable (Double) -> Void)?
    private var continuation: CheckedContinuation<Void, Error>?
    private var finished = false

    public override init() {}

    /// - Parameters:
    ///   - part: where the unfinished bytes live (default `<dest>.part`).
    public func download(_ url: URL, to dest: URL, expectedBytes: Int64, connections: Int = 6, part: URL? = nil,
                         progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let fm = FileManager.default
        if let size = try? dest.resourceValues(forKeys: [.fileSizeKey]).fileSize, Int64(size) == expectedBytes {
            return dest
        }
        guard expectedBytes > Self.chunkBytes else {
            return try await FileDownloader().download(url, to: dest, expectedBytes: expectedBytes, progress: progress)
        }
        let part = part ?? dest.appendingPathExtension("part")
        let map = part.appendingPathExtension("map")
        let count = Int((expectedBytes + Self.chunkBytes - 1) / Self.chunkBytes)

        var doneChunks = [Bool](repeating: false, count: count)
        let partSize = (try? part.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? -1
        if partSize == expectedBytes, let s = try? String(contentsOf: map, encoding: .utf8), s.count == count {
            doneChunks = s.map { $0 == "1" }
        } else {
            let free = EnginePaths.freeBytes()
            if free > 0 && free < expectedBytes + 300_000_000 {
                throw EngineError.failed("Not enough free space: need \(expectedBytes / 1_000_000 + 300) MB")
            }
            try? fm.removeItem(at: part)
            try fm.createDirectory(at: part.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard fm.createFile(atPath: part.path, contents: nil) else { throw EngineError.failed("cannot create \(part.lastPathComponent)") }
            let h = try FileHandle(forWritingTo: part)
            try h.truncate(atOffset: UInt64(expectedBytes))
            try h.close()
            try String(repeating: "0", count: count).write(to: map, atomically: true, encoding: .utf8)
        }

        self.url = url
        self.handle = try FileHandle(forWritingTo: part)
        self.mapURL = map
        self.total = expectedBytes
        self.done = doneChunks
        self.pending = doneChunks.indices.filter { !doneChunks[$0] }
        self.bytesDone = doneChunks.indices.reduce(0) { $0 + ($1 < count && doneChunks[$1] ? chunkLength($1) : 0) }
        self.progress = progress
        progress(Double(bytesDone) / Double(total))

        let n = max(1, min(connections, pending.count))
        sessions = (0..<n).map { _ in
            let c = URLSessionConfiguration.default
            c.timeoutIntervalForRequest = 60
            c.timeoutIntervalForResource = 60 * 60 * 6
            c.waitsForConnectivity = true
            c.httpMaximumConnectionsPerHost = 2
            c.requestCachePolicy = .reloadIgnoringLocalCacheData
            c.urlCache = nil
            return URLSession(configuration: c, delegate: self, delegateQueue: queue)
        }
        defer { sessions.forEach { $0.invalidateAndCancel() }; sessions = [] }

        do {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
                    queue.addOperation {
                        // Cancelled before we started: finish() already ran with no continuation to resume.
                        if self.finished { c.resume(throwing: CancellationError()); return }
                        self.continuation = c
                        if self.pending.isEmpty { self.finish(nil); return }
                        for w in 0..<n { self.startNext(worker: w) }
                    }
                }
            } onCancel: {
                queue.addOperation { self.finish(CancellationError()) }
            }
        } catch Failure.noRange {
            try? handle.close()
            try? fm.removeItem(at: part)
            try? fm.removeItem(at: map)
            Breadcrumbs.note("range not supported, single stream: \(url.lastPathComponent)")
            return try await FileDownloader().download(url, to: dest, expectedBytes: expectedBytes, progress: progress)
        } catch {
            try? handle.close()
            throw error
        }
        try handle.synchronize()
        try handle.close()
        try? fm.removeItem(at: dest)
        try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.moveItem(at: part, to: dest)
        try? fm.removeItem(at: map)
        EnginePaths.excludeFromBackup(dest)
        return dest
    }

    private func chunkLength(_ chunk: Int) -> Int64 {
        min(Self.chunkBytes, total - Int64(chunk) * Self.chunkBytes)
    }

    private func startNext(worker: Int) {
        guard !finished, !pending.isEmpty, worker < sessions.count else { return }
        let chunk = pending.removeFirst()
        let offset = Int64(chunk) * Self.chunkBytes
        let length = chunkLength(chunk)
        var req = URLRequest(url: url)
        req.setValue("bytes=\(offset)-\(offset + length - 1)", forHTTPHeaderField: "Range")
        req.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        let task = sessions[worker].dataTask(with: req)
        active[task.taskIdentifier] = Active(worker: worker, chunk: chunk, offset: offset, length: length)
        task.resume()
    }

    private func finish(_ error: Error?) {
        guard !finished else { return }
        finished = true
        if error != nil { sessions.forEach { $0.invalidateAndCancel() } }
        let c = continuation
        continuation = nil
        if let error { c?.resume(throwing: error) } else { c?.resume() }
    }

    private func saveMap() {
        try? String(done.map { $0 ? "1" : "0" }).write(to: mapURL, atomically: true, encoding: .utf8)
    }

    // MARK: URLSessionDataDelegate (on `queue`)

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                           completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 206 { completionHandler(.allow); return }
        completionHandler(.cancel)
        if status == 200 { finish(Failure.noRange) }
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !finished, var a = active[dataTask.taskIdentifier] else { return }
        let room = a.length - a.written
        let slice = Int64(data.count) > room ? data.prefix(Int(room)) : data
        do {
            try handle.seek(toOffset: UInt64(a.offset + a.written))
            try handle.write(contentsOf: slice)
        } catch {
            finish(error)
            return
        }
        a.written += Int64(slice.count)
        active[dataTask.taskIdentifier] = a
        bytesDone += Int64(slice.count)
        let p = Double(bytesDone) / Double(total)
        if p - lastReported >= 0.002 { lastReported = p; progress?(min(1, p)) }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let a = active.removeValue(forKey: task.taskIdentifier), !finished else { return }
        if error == nil && a.written == a.length {
            done[a.chunk] = true
            saveMap()
            if done.allSatisfy({ $0 }) { finish(nil); return }
            startNext(worker: a.worker)
            return
        }
        // Retry this chunk from its start.
        bytesDone -= a.written
        let tries = (retries[a.chunk] ?? 0) + 1
        retries[a.chunk] = tries
        if tries > 6 {
            finish(error ?? EngineError.failed("download kept failing at \(a.offset / 1_000_000) MB"))
            return
        }
        pending.insert(a.chunk, at: 0)
        let worker = a.worker
        DispatchQueue.global().asyncAfter(deadline: .now() + Double(min(tries * 2, 10))) { [weak self] in
            self?.queue.addOperation { self?.startNext(worker: worker) }
        }
    }
}
