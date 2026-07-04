import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var query: String = "" {
        didSet { scheduleSearch() }
    }
    @Published private(set) var results: [FileEntry] = []
    @Published var selection: String?
    @Published private(set) var isIndexing = false
    @Published private(set) var statusText = "准备中…"
    @Published private(set) var lastIndexedAt: Date?
    @Published var hotKeyDisplay = "⌘⇧F"

    let roots: [URL] = [FileManager.default.homeDirectoryForCurrentUser]

    private var entryMap: [String: FileEntry] = [:]
    private var watcher: FileSystemWatcher?
    private var searchTask: Task<Void, Never>?
    private var reindexTask: Task<Void, Never>?
    private var changeTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var pendingPaths = Set<String>()
    private var pendingFullRescan = false
    private var hasStarted = false

    var selectedEntry: FileEntry? {
        guard let selection else { return results.first }
        return results.first(where: { $0.id == selection })
    }

    private init() {}

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        Task {
            await loadExistingIndexOrBuild()
            startWatcher()
        }
    }

    func rebuildIndex() {
        guard reindexTask == nil else { return }

        reindexTask = Task { [weak self] in
            guard let self else { return }
            isIndexing = true
            statusText = "正在建立索引…"
            let scanRoots = roots

            let entries = await Task.detached(priority: .userInitiated) {
                FileIndexer.scan(roots: scanRoots)
            }.value

            guard !Task.isCancelled else {
                isIndexing = false
                reindexTask = nil
                return
            }

            entryMap = Dictionary(uniqueKeysWithValues: entries.map { ($0.path, $0) })
            lastIndexedAt = Date()
            isIndexing = false
            updateStatus()
            scheduleSearch(immediate: true)
            scheduleSave(immediate: true)
            reindexTask = nil
        }
    }

    func openSelected() {
        guard let entry = selectedEntry else { return }
        NSWorkspace.shared.open(entry.url)
    }

    func revealSelected() {
        guard let entry = selectedEntry else { return }
        NSWorkspace.shared.activateFileViewerSelecting([entry.url])
    }

    func openSelectedParent() {
        guard let entry = selectedEntry else { return }
        NSWorkspace.shared.open(entry.url.deletingLastPathComponent())
    }

    func copySelectedPath() {
        guard let entry = selectedEntry else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.path, forType: .string)
        statusText = "已复制路径"
    }

    func openFullDiskAccessSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else { return }
        NSWorkspace.shared.open(url)
    }

    func refreshIfNeeded() {
        if entryMap.isEmpty, !isIndexing {
            rebuildIndex()
        }
    }

    private func loadExistingIndexOrBuild() async {
        statusText = "正在读取索引…"
        do {
            let stored = try await Task.detached(priority: .userInitiated) {
                try IndexStore.load()
            }.value

            entryMap = Dictionary(uniqueKeysWithValues: stored.entries.map { ($0.path, $0) })
            lastIndexedAt = stored.createdAt
            updateStatus()
            scheduleSearch(immediate: true)

            if Date().timeIntervalSince(stored.createdAt) > 86_400 {
                rebuildIndex()
            }
        } catch {
            rebuildIndex()
        }
    }

    private func startWatcher() {
        guard watcher == nil else { return }
        watcher = FileSystemWatcher(paths: roots) { change in
            Task { @MainActor in
                AppModel.shared.receive(change)
            }
        }
        watcher?.start()
    }

    private func receive(_ change: FileSystemChange) {
        let filtered = change.paths.filter { !FileIndexer.isIgnored(path: $0) }
        guard !filtered.isEmpty || change.requiresFullRescan else { return }

        pendingPaths.formUnion(filtered)
        pendingFullRescan = pendingFullRescan || change.requiresFullRescan
        changeTask?.cancel()
        changeTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled, let self else { return }
            await applyPendingChanges()
        }
    }

    private func applyPendingChanges() async {
        let needsFullRescan = pendingFullRescan
        let paths = Array(pendingPaths)
        pendingFullRescan = false
        pendingPaths.removeAll(keepingCapacity: true)

        if needsFullRescan || paths.count > 2_000 {
            rebuildIndex()
            return
        }

        let updates = await Task.detached(priority: .utility) {
            paths.map { path in
                (path, FileIndexer.entry(at: URL(fileURLWithPath: path)))
            }
        }.value

        var changed = false
        for (path, entry) in updates {
            if let entry {
                if entryMap[path] != entry {
                    entryMap[path] = entry
                    changed = true
                }
            } else if entryMap[path] != nil || entryMap.keys.contains(where: { $0.hasPrefix(path + "/") }) {
                entryMap = entryMap.filter { key, _ in
                    key != path && !key.hasPrefix(path + "/")
                }
                changed = true
            }
        }

        guard changed else { return }
        updateStatus()
        scheduleSearch(immediate: true)
        scheduleSave()
    }

    private func scheduleSearch(immediate: Bool = false) {
        searchTask?.cancel()
        let currentQuery = query
        let entries = Array(entryMap.values)

        searchTask = Task { [weak self] in
            if !immediate {
                try? await Task.sleep(for: .milliseconds(70))
            }
            guard !Task.isCancelled, let self else { return }

            let found = await Task.detached(priority: .userInitiated) {
                SearchEngine.search(currentQuery, in: entries)
            }.value

            guard !Task.isCancelled else { return }
            results = found
            if let selection, found.contains(where: { $0.id == selection }) {
                return
            }
            selection = found.first?.id
        }
    }

    private func scheduleSave(immediate: Bool = false) {
        saveTask?.cancel()
        let entries = Array(entryMap.values)
        let saveRoots = roots

        saveTask = Task {
            if !immediate {
                try? await Task.sleep(for: .seconds(3))
            }
            guard !Task.isCancelled else { return }
            await Task.detached(priority: .utility) {
                try? IndexStore.save(entries: entries, roots: saveRoots)
            }.value
        }
    }

    private func updateStatus() {
        statusText = "已索引 \(entryMap.count.formatted()) 个项目"
    }
}
