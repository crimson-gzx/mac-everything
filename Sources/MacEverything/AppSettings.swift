import Foundation

struct AppSettings: Codable, Equatable, Sendable {
    var rootPaths: [String]
    var excludedPaths: [String]

    static var defaultValue: AppSettings {
        AppSettings(
            rootPaths: [FileManager.default.homeDirectoryForCurrentUser.path],
            excludedPaths: []
        )
    }

    var rootURLs: [URL] {
        normalized(paths: rootPaths).map { URL(fileURLWithPath: $0) }
    }

    var excludedURLs: [URL] {
        normalized(paths: excludedPaths).map { URL(fileURLWithPath: $0) }
    }

    mutating func normalize() {
        rootPaths = Self.normalized(paths: rootPaths)
        excludedPaths = Self.normalized(paths: excludedPaths)
    }

    static func normalized(paths: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for path in paths {
            let normalized = (path as NSString).standardizingPath
            guard !normalized.isEmpty, !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            result.append(normalized)
        }
        return result
    }

    private func normalized(paths: [String]) -> [String] {
        Self.normalized(paths: paths)
    }
}

enum SettingsStore {
    static var fileURL: URL {
        IndexStore.directoryURL.appendingPathComponent("settings.plist")
    }

    static func load() -> AppSettings {
        do {
            let data = try Data(contentsOf: fileURL)
            var settings = try PropertyListDecoder().decode(AppSettings.self, from: data)
            settings.normalize()
            if settings.rootPaths.isEmpty {
                settings.rootPaths = AppSettings.defaultValue.rootPaths
            }
            return settings
        } catch {
            return .defaultValue
        }
    }

    static func save(_ settings: AppSettings) throws {
        var normalized = settings
        normalized.normalize()
        try FileManager.default.createDirectory(at: IndexStore.directoryURL, withIntermediateDirectories: true)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let data = try encoder.encode(normalized)
        try data.write(to: fileURL, options: .atomic)
    }
}
