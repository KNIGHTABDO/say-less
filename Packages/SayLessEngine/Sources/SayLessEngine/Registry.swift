import Foundation

/// The models the app uses. Bundled in code so the app works without any network lookup;
/// a later build can override it from a remote `models.json`.
public struct ModelRegistry: Codable, Sendable {
    public struct Speech: Codable, Sendable {
        public var variant: String      // WhisperKit variant folder name
        public var repo: String
        public var downloadMB: Int
        public var residentMB: Int
    }
    public struct Translation: Codable, Sendable {
        public var id: String
        public var displayName: String
        public var url: URL
        public var bytes: Int64
        public var residentMB: Int
    }
    public struct Voice: Codable, Sendable {
        public var displayName: String
        public var downloadMB: Int
        public var residentMB: Int
    }

    public var speech: Speech
    /// Tried in order; the first one that loads and passes the self-test wins.
    public var translation: [Translation]
    public var voice: Voice

    public static let bundled = ModelRegistry(
        speech: .init(variant: "openai_whisper-large-v3-v20240930_626MB",
                      repo: "argmaxinc/whisperkit-coreml", downloadMB: 626, residentMB: 700),
        translation: [
            .init(id: "hy-mt2-1.8b-q4km", displayName: "Hy-MT2 1.8B",
                  url: URL(string: "https://huggingface.co/tencent/Hy-MT2-1.8B-GGUF/resolve/main/Hy-MT2-1.8B-Q4_K_M.gguf")!,
                  bytes: 1_133_080_448, residentMB: 1250),
            .init(id: "hy-mt1.5-1.8b-q4km", displayName: "HY-MT1.5 1.8B",
                  url: URL(string: "https://huggingface.co/tencent/HY-MT1.5-1.8B-GGUF/resolve/main/HY-MT1.5-1.8B-Q4_K_M.gguf")!,
                  bytes: 1_133_080_512, residentMB: 1250),
        ],
        voice: .init(displayName: "Qwen3-TTS 0.6B", downloadMB: 1000, residentMB: 1000)
    )
}

/// Where everything lives on disk.
public enum EnginePaths {
    public static var root: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appending(path: "SayLess", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    public static var models: URL { sub("Models") }
    public static var whisperBase: URL { sub("Models/whisper") }
    public static var ttsBase: URL { sub("Models/tts") }
    public static var gguf: URL { sub("Models/gguf") }
    public static var breadcrumbs: URL { root.appending(path: "breadcrumbs.log") }
    public static var manifest: URL { root.appending(path: "installed.json") }

    private static func sub(_ path: String) -> URL {
        let url = root.appending(path: path, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Model files are re-downloadable: keep them out of iCloud/iTunes backups.
    public static func excludeFromBackup(_ url: URL) {
        var u = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? u.setResourceValues(values)
    }

    public static func freeBytes() -> Int64 {
        let values = try? root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage ?? 0
    }

    public static func size(of url: URL) -> Int64 {
        guard let en = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        var total: Int64 = 0
        for case let f as URL in en {
            total += Int64((try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }
}

/// What is installed (persisted as JSON).
public struct InstalledManifest: Codable, Sendable {
    public var whisperFolder: String?
    public var translationID: String?
    public var translationFile: String?
    public var voiceFolder: String?

    public init() {}

    public static func load() -> InstalledManifest {
        guard let data = try? Data(contentsOf: EnginePaths.manifest),
              let m = try? JSONDecoder().decode(InstalledManifest.self, from: data) else { return InstalledManifest() }
        return m
    }

    public func save() {
        if let data = try? JSONEncoder().encode(self) { try? data.write(to: EnginePaths.manifest, options: .atomic) }
    }

    public var hasSpeech: Bool { whisperFolder.map { FileManager.default.fileExists(atPath: $0) } ?? false }
    public var hasTranslation: Bool { translationFile.map { FileManager.default.fileExists(atPath: $0) } ?? false }
    public var hasVoice: Bool { voiceFolder.map { FileManager.default.fileExists(atPath: $0) } ?? false }
}
