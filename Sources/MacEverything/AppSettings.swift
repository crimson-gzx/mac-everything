import Foundation

struct SavedFilter: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var query: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, query: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.query = query
        self.createdAt = createdAt
    }
}

struct ResultDisplayOptions: Codable, Equatable, Sendable {
    var showPath: Bool
    var showModifiedDate: Bool
    var showSize: Bool
    var showKind: Bool

    static let defaultValue = ResultDisplayOptions(
        showPath: true,
        showModifiedDate: true,
        showSize: true,
        showKind: true
    )
}

struct AppSettings: Codable, Equatable, Sendable {
    var rootPaths: [String]
    var excludedPaths: [String]
    var searchHistory: [String]
    var savedFilters: [SavedFilter]
    var displayOptions: ResultDisplayOptions

    static var defaultValue: AppSettings {
        AppSettings(
            rootPaths: [FileManager.default.homeDirectoryForCurrentUser.path],
            excludedPaths: [],
            searchHistory: [],
            savedFilters: Self.defaultFilters,
            displayOptions: .defaultValue
        )
    }

    static var defaultFilters: [SavedFilter] {
        [
            SavedFilter(name: "PDF", query: "*.pdf"),
            SavedFilter(name: "图片", query: "ext:jpg,jpeg,png,gif,webp,heic"),
            SavedFilter(name: "视频", query: "ext:mp4,mov,mkv,avi"),
            SavedFilter(name: "今天修改", query: "date:today"),
            SavedFilter(name: "大文件", query: "type:file size:>100mb sort:size")
        ]
    }

    var rootURLs: [URL] {
        Self.normalized(paths: rootPaths).map { URL(fileURLWithPath: $0) }
    }

    var excludedURLs: [URL] {
        Self.normalized(paths: excludedPaths).map { URL(fileURLWithPath: $0) }
    }

    mutating func normalize() {
        rootPaths = Self.normalized(paths: rootPaths)
        excludedPaths = Self.normalized(paths: excludedPaths)
        searchHistory = Self.normalizedQueries(searchHistory, limit: 30)
        savedFilters = Self.normalizedFilters(savedFilters)
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

    static func normalizedQueries(_ queries: [String], limit: Int) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for query in queries {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(trimmed)
            if result.count >= limit { break }
        }
        return result
    }

    static func normalizedFilters(_ filters: [SavedFilter]) -> [SavedFilter] {
        var seenNames = Set<String>()
        var result: [SavedFilter] = []
        for filter in filters {
            let name = filter.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let query = filter.query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !query.isEmpty else { continue }
            let key = name.lowercased()
            guard !seenNames.contains(key) else { continue }
            seenNames.insert(key)
            result.append(SavedFilter(id: filter.id, name: name, query: query, createdAt: filter.createdAt))
        }
        return result
    }

    enum CodingKeys: String, CodingKey {
        case rootPaths
        case excludedPaths
        case searchHistory
        case savedFilters
        case displayOptions
    }

    init(
        rootPaths: [String],
        excludedPaths: [String],
        searchHistory: [String],
        savedFilters: [SavedFilter],
        displayOptions: ResultDisplayOptions
    ) {
        self.rootPaths = rootPaths
        self.excludedPaths = excludedPaths
        self.searchHistory = searchHistory
        self.savedFilters = savedFilters
        self.displayOptions = displayOptions
        normalize()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rootPaths = try container.decodeIfPresent([String].self, forKey: .rootPaths) ?? Self.defaultValue.rootPaths
        excludedPaths = try container.decodeIfPresent([String].self, forKey: .excludedPaths) ?? []
        searchHistory = try container.decodeIfPresent([String].self, forKey: .searchHistory) ?? []
        savedFilters = try container.decodeIfPresent([SavedFilter].self, forKey: .savedFilters) ?? Self.defaultFilters
        displayOptions = try container.decodeIfPresent(ResultDisplayOptions.self, forKey: .displayOptions) ?? .defaultValue
        normalize()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rootPaths, forKey: .rootPaths)
        try container.encode(excludedPaths, forKey: .excludedPaths)
        try container.encode(searchHistory, forKey: .searchHistory)
        try container.encode(savedFilters, forKey: .savedFilters)
        try container.encode(displayOptions, forKey: .displayOptions)
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
            if settings.savedFilters.isEmpty {
                settings.savedFilters = AppSettings.defaultFilters
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
