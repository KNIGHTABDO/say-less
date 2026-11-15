import Foundation

/// Downloads one large file with progress, resume-after-failure and a size check.
/// Writes to `<dest>.part` first and moves into place only when complete.
public final class FileDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private var continuation: CheckedContinuation<URL, Error>?
    private var progress: (@Sendable (Double) -> Void)?
    private var expected: Int64 = 0
    private var dest: URL!
    private var resumeData: Data?
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 60 * 60 * 6
        config.waitsForConnectivity = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    public override init() {}

    public func download(_ url: URL, to dest: URL, expectedBytes: Int64, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        if let size = try? dest.resourceValues(forKeys: [.fileSizeKey]).fileSize, Int64(size) == expectedBytes {
            return dest
        }
        if EnginePaths.freeBytes() > 0 && EnginePaths.freeBytes() < expectedBytes + 300_000_000 {
            throw EngineError.failed("Not enough free space: need \(expectedBytes / 1_000_000 + 300) MB")
        }
        self.dest = dest
        self.expected = expectedBytes
        self.progress = progress
        var lastError: Error?
        for attempt in 0..<4 {
            do {
                return try await withCheckedThrowingContinuation { (c: CheckedContinuation<URL, Error>) in
                    self.continuation = c
                    let task = resumeData.map { session.downloadTask(withResumeData: $0) } ?? session.downloadTask(with: url)
                    task.resume()
                }
            } catch {
                lastError = error
                resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data
                try? await Task.sleep(for: .seconds(Double(attempt + 1) * 2))
            }
        }
        throw lastError ?? EngineError.failed("download failed")
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                           totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : expected
        if total > 0 { progress?(min(1, Double(totalBytesWritten) / Double(total))) }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let fm = FileManager.default
        do {
            let size = Int64((try location.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            if expected > 0 && size != expected {
                throw EngineError.failed("Size mismatch: got \(size) bytes, expected \(expected)")
            }
            try? fm.removeItem(at: dest)
            try fm.moveItem(at: location, to: dest)
            EnginePaths.excludeFromBackup(dest)
            resumeData = nil
            continuation?.resume(returning: dest)
        } catch {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, let c = continuation else { return }
        continuation = nil
        c.resume(throwing: error)
    }
}
