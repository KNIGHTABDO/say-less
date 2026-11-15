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

    // Paths are stored relative to `EnginePaths.root`. iOS moves the app's data container on every
    // update/reinstall, so an absolute path from an older build points at a folder that no longer exists.
    public var whisperPath: String? { Self.resolve(whisperFolder) ?? Self.scan(EnginePaths.whisperBase, dirNamed: ModelRegistry.bundled.speech.variant) }
    public var translationPath: String? {
        Self.resolve(translationFile) ?? ModelRegistry.bundled.translation.lazy
            .map { EnginePaths.gguf.appending(path: $0.url.lastPathComponent).path }
            .first { FileManager.default.fileExists(atPath: $0) }
    }
    public var voicePath: String? { Self.resolve(voiceFolder) }

    public var hasSpeech: Bool { whisperPath != nil }
    public var hasTranslation: Bool { translationPath != nil }
    public var hasVoice: Bool { voicePath != nil }

    /// Path to store for a file or folder under the root (relative when possible).
    public static func store(_ url: URL) -> String { relative(url.path, root: EnginePaths.root.path) }

    static func relative(_ path: String, root: String) -> String {
        let r = root.hasSuffix("/") ? root : root + "/"
        return path.hasPrefix(r) ? String(path.dropFirst(r.count)) : reroot(path, root: root)
    }

    /// Maps a stored path (relative, or absolute from any older container) onto the current root.
    public static func reroot(_ stored: String, root: String) -> String {
        let r = root.hasSuffix("/") ? String(root.dropLast()) : root
        guard stored.hasPrefix("/") else { return r + "/" + stored }
        let marker = "/Application Support/SayLess/"
        guard let range = stored.range(of: marker, options: .backwards) else { return stored }
        return r + "/" + stored[range.upperBound...]
    }

    private static func resolve(_ stored: String?) -> String? {
        guard let stored, !stored.isEmpty else { return nil }
        let path = reroot(stored, root: EnginePaths.root.path)
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    /// Finds a model folder by name when the manifest lost track of it.
    private static func scan(_ base: URL, dirNamed name: String) -> String? {
        guard let en = FileManager.default.enumerator(at: base, includingPropertiesForKeys: [.isDirectoryKey],
                                                      options: [.skipsHiddenFiles]) else { return nil }
        for case let url as URL in en where url.lastPathComponent == name {
            if (try? FileManager.default.contentsOfDirectory(atPath: url.path))?.isEmpty == false { return url.path }
        }
        return nil
    }
}
