import Foundation

struct StoredIndex: Codable, Sendable {
    static let currentVersion = 2

    let version: Int
    let createdAt: Date
    let roots: [String]
    let excludedPaths: [String]
    let entries: [FileEntry]
}

enum IndexStore {
    static var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("MacEverything", isDirectory: true)
    }

    static var fileURL: URL {
        directoryURL.appendingPathComponent("file-index.plist")
    }

    static var databaseURL: URL {
        IndexDatabase.fileURL
    }

    static func load() throws -> StoredIndex {
        do {
            return try IndexDatabase.load()
        } catch {
            let legacy = try loadLegacyPlist()
            try? IndexDatabase.save(entries: legacy.entries, roots: legacy.roots.map { URL(fileURLWithPath: $0) }, excludedPaths: legacy.excludedPaths)
            return legacy
        }
    }

    static func save(entries: [FileEntry], roots: [URL], excludedPaths: [String]) throws {
        try IndexDatabase.save(entries: entries, roots: roots, excludedPaths: excludedPaths)
    }

    private static func loadLegacyPlist() throws -> StoredIndex {
        let data = try Data(contentsOf: fileURL)
        let index = try PropertyListDecoder().decode(StoredIndex.self, from: data)
        guard index.version == StoredIndex.currentVersion else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return index
    }
}

enum FileIndexer {
    private static let resourceKeys: [URLResourceKey] = [
        .isDirectoryKey,
        .isRegularFileKey,
        .isSymbolicLinkKey,
        .isPackageKey,
        .contentModificationDateKey,
        .fileSizeKey
    ]

    static func scan(
        roots: [URL],
        excludedPaths: [String] = [],
        progress: @escaping @Sendable (Int) -> Void = { _ in }
    ) -> [FileEntry] {
        let fileManager = FileManager.default
        let normalizedExcludedPaths = AppSettings.normalized(paths: excludedPaths)
        var entries: [FileEntry] = []
        entries.reserveCapacity(100_000)

        for root in roots {
            guard fileManager.fileExists(atPath: root.path) else { continue }
            guard !isIgnored(path: root.path, excludedPaths: normalizedExcludedPaths) else { continue }

            let rootValues = try? root.resourceValues(forKeys: Set(resourceKeys))
            entries.append(makeEntry(url: root, values: rootValues))

            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: resourceKeys,
                options: [],
                errorHandler: { _, _ in true }
            ) else { continue }

            for case let url as URL in enumerator {
                autoreleasepool {
                    let values = try? url.resourceValues(forKeys: Set(resourceKeys))
                    if shouldSkip(url: url, values: values, excludedPaths: normalizedExcludedPaths) {
                        if values?.isDirectory == true {
                            enumerator.skipDescendants()
                        }
                        return
                    }

                    entries.append(makeEntry(url: url, values: values))
                    if entries.count.isMultiple(of: 2_000) {
                        progress(entries.count)
                    }
                }
            }
        }

        entries.sort {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        progress(entries.count)
        return entries
    }

    static func isIgnored(path: String, excludedPaths: [String] = []) -> Bool {
        let normalizedPath = (path as NSString).standardizingPath
        if normalizedPath.contains("/Library/Caches/") || normalizedPath.hasSuffix("/Library/Caches") { return true }
        if normalizedPath.contains("/.Trash/") || normalizedPath.hasSuffix("/.Trash") { return true }
        if normalizedPath.hasPrefix(IndexStore.directoryURL.path) { return true }
        for excludedPath in AppSettings.normalized(paths: excludedPaths) {
            if normalizedPath == excludedPath || normalizedPath.hasPrefix(excludedPath + "/") {
                return true
            }
        }
        return false
    }

    static func entry(at url: URL, excludedPaths: [String] = []) -> FileEntry? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let values = try? url.resourceValues(forKeys: Set(resourceKeys))
        guard !shouldSkip(url: url, values: values, excludedPaths: excludedPaths) else { return nil }
        return makeEntry(url: url, values: values)
    }

    private static func shouldSkip(url: URL, values: URLResourceValues?, excludedPaths: [String]) -> Bool {
        if values?.isSymbolicLink == true { return true }
        if values?.isPackage == true { return true }
        return isIgnored(path: url.path, excludedPaths: excludedPaths)
    }

    private static func makeEntry(url: URL, values: URLResourceValues?) -> FileEntry {
        FileEntry(
            path: url.path,
            name: url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent,
            isDirectory: values?.isDirectory ?? false,
            modifiedAt: values?.contentModificationDate,
            size: values?.isRegularFile == true ? Int64(values?.fileSize ?? 0) : nil
        )
    }
}
