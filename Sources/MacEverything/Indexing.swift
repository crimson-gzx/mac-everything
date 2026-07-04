import Foundation

struct StoredIndex: Codable, Sendable {
    static let currentVersion = 1

    let version: Int
    let createdAt: Date
    let roots: [String]
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

    static func load() throws -> StoredIndex {
        let data = try Data(contentsOf: fileURL)
        let index = try PropertyListDecoder().decode(StoredIndex.self, from: data)
        guard index.version == StoredIndex.currentVersion else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return index
    }

    static func save(entries: [FileEntry], roots: [URL]) throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let payload = StoredIndex(
            version: StoredIndex.currentVersion,
            createdAt: Date(),
            roots: roots.map(\.path),
            entries: entries
        )
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let data = try encoder.encode(payload)
        try data.write(to: fileURL, options: .atomic)
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
        progress: @escaping @Sendable (Int) -> Void = { _ in }
    ) -> [FileEntry] {
        let fileManager = FileManager.default
        var entries: [FileEntry] = []
        entries.reserveCapacity(100_000)

        for root in roots {
            guard fileManager.fileExists(atPath: root.path) else { continue }

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
                    if shouldSkip(url: url, values: values) {
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

    static func isIgnored(path: String) -> Bool {
        if path.contains("/Library/Caches/") || path.hasSuffix("/Library/Caches") { return true }
        if path.contains("/.Trash/") || path.hasSuffix("/.Trash") { return true }
        if path.hasPrefix(IndexStore.directoryURL.path) { return true }
        return false
    }

    static func entry(at url: URL) -> FileEntry? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let values = try? url.resourceValues(forKeys: Set(resourceKeys))
        guard !shouldSkip(url: url, values: values) else { return nil }
        return makeEntry(url: url, values: values)
    }

    private static func shouldSkip(url: URL, values: URLResourceValues?) -> Bool {
        if values?.isSymbolicLink == true { return true }
        if values?.isPackage == true { return true }
        return isIgnored(path: url.path)
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
