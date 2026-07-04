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
    @Published var sortOption: SearchSort = .relevance {
        didSet { scheduleSearch(immediate: true) }
    }
    @Published private(set) var settings = AppSettings.defaultValue

    var roots: [URL] { settings.rootURLs }
    var rootPaths: [String] { settings.rootPaths }
    var excludedPaths: [String] { settings.excludedPaths }

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

    private init() {
        settings = SettingsStore.load()
    }

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
            let scanExcludedPaths = excludedPaths

            let entries = await Task.detached(priority: .userInitiated) {
                FileIndexer.scan(roots: scanRoots, excludedPaths: scanExcludedPaths)
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

    func addIndexFolder() {
        guard let url = chooseFolder(title: "选择要索引的文件夹") else { return }
        var next = settings
        next.rootPaths.append(url.path)
        applySettings(next, shouldRebuild: true)
    }

    func removeIndexRoot(_ path: String) {
        var next = settings
        next.rootPaths.removeAll { $0 == path }
        if next.rootPaths.isEmpty {
            next.rootPaths = AppSettings.defaultValue.rootPaths
        }
        applySettings(next, shouldRebuild: true)
    }

    func resetIndexRoots() {
        var next = settings
        next.rootPaths = AppSettings.defaultValue.rootPaths
        applySettings(next, shouldRebuild: true)
    }

    func addExcludedFolder() {
        guard let url = chooseFolder(title: "选择要排除的文件夹") else { return }
        var next = settings
        next.excludedPaths.append(url.path)
        applySettings(next, shouldRebuild: true)
    }

    func removeExcludedPath(_ path: String) {
        var next = settings
        next.excludedPaths.removeAll { $0 == path }
        applySettings(next, shouldRebuild: true)
    }

    func clearExcludedFolders() {
        var next = settings
        next.excludedPaths.removeAll()
        applySettings(next, shouldRebuild: true)
    }

    private func loadExistingIndexOrBuild() async {
        statusText = "正在读取索引…"
        do {
            let stored = try await Task.detached(priority: .userInitiated) {
                try IndexStore.load()
            }.value

            if stored.roots != roots.map(\.path) || stored.excludedPaths != excludedPaths {
                rebuildIndex()
                return
            }

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

    private func restartWatcher() {
        watcher?.stop()
        watcher = nil
        startWatcher()
    }

    private func receive(_ change: FileSystemChange) {
        let currentExcludedPaths = excludedPaths
        let filtered = change.paths.filter { !FileIndexer.isIgnored(path: $0, excludedPaths: currentExcludedPaths) }
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

        let currentExcludedPaths = excludedPaths
        let updates = await Task.detached(priority: .utility) {
            paths.map { path in
                (path, FileIndexer.entry(at: URL(fileURLWithPath: path), excludedPaths: currentExcludedPaths))
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

    private func chooseFolder(title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func applySettings(_ nextSettings: AppSettings, shouldRebuild: Bool) {
        var normalized = nextSettings
        normalized.normalize()
        if normalized.rootPaths.isEmpty {
            normalized.rootPaths = AppSettings.defaultValue.rootPaths
        }
        guard normalized != settings else { return }

        settings = normalized
        try? SettingsStore.save(normalized)
        pendingPaths.removeAll(keepingCapacity: true)
        pendingFullRescan = false
        restartWatcher()
        statusText = "索引设置已更新"

        if shouldRebuild {
            entryMap.removeAll(keepingCapacity: true)
            results.removeAll()
            selection = nil
            rebuildIndex()
        } else {
            scheduleSearch(immediate: true)
        }
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

            let currentSort = sortOption
            let found = await Task.detached(priority: .userInitiated) {
                SearchEngine.search(currentQuery, in: entries, sort: currentSort)
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
        let saveExcludedPaths = excludedPaths

        saveTask = Task {
            if !immediate {
                try? await Task.sleep(for: .seconds(3))
            }
            guard !Task.isCancelled else { return }
            await Task.detached(priority: .utility) {
                try? IndexStore.save(entries: entries, roots: saveRoots, excludedPaths: saveExcludedPaths)
            }.value
        }
    }

    private func updateStatus() {
        statusText = "已索引 \(entryMap.count.formatted()) 个项目"
    }
}
