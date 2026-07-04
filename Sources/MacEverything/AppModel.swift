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
    var searchHistory: [String] { settings.searchHistory }
    var savedFilters: [SavedFilter] { settings.savedFilters }
    var displayOptions: ResultDisplayOptions { settings.displayOptions }

    private var entryMap: [String: FileEntry] = [:]
    private var searchRecords: [SearchRecord] = []
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
            rebuildSearchRecords()
            lastIndexedAt = Date()
            isIndexing = false
            updateStatus()
            scheduleSearch(immediate: true)
            scheduleSave(immediate: true)
            reindexTask = nil
        }
    }

    func openSelected() {
        recordCurrentQuery()
        guard let entry = selectedEntry else { return }
        NSWorkspace.shared.open(entry.url)
    }

    func submitSearch() {
        recordCurrentQuery()
        openSelected()
    }

    func previewSelected() {
        QuickLookPreviewer.shared.preview(selected: selectedEntry, results: results)
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

    func applyHistoryQuery(_ historyQuery: String) {
        query = historyQuery
        recordQuery(historyQuery)
        scheduleSearch(immediate: true)
    }

    func applySavedFilter(_ filter: SavedFilter) {
        query = filter.query
        recordQuery(filter.query)
        scheduleSearch(immediate: true)
    }

    func saveCurrentQueryAsFilter() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusText = "当前搜索为空，无法保存过滤器"
            return
        }
        let defaultName = trimmed.count > 24 ? String(trimmed.prefix(24)) + "…" : trimmed
        guard let name = promptForText(title: "保存过滤器", message: "给这个搜索条件起个名字", defaultValue: defaultName) else { return }
        saveFilter(name: name, query: trimmed)
    }

    func saveFilter(name: String, query filterQuery: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedQuery = filterQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedQuery.isEmpty else { return }
        var next = settings
        next.savedFilters.removeAll { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }
        next.savedFilters.insert(SavedFilter(name: trimmedName, query: trimmedQuery), at: 0)
        applySettings(next, shouldRebuild: false)
        statusText = "已保存过滤器：\(trimmedName)"
    }

    func removeSavedFilter(_ filter: SavedFilter) {
        var next = settings
        next.savedFilters.removeAll { $0.id == filter.id }
        applySettings(next, shouldRebuild: false)
        statusText = "已删除过滤器"
    }

    func resetDefaultFilters() {
        var next = settings
        next.savedFilters = AppSettings.defaultFilters
        applySettings(next, shouldRebuild: false)
        statusText = "已恢复默认过滤器"
    }

    func clearSearchHistory() {
        var next = settings
        next.searchHistory.removeAll()
        applySettings(next, shouldRebuild: false)
        statusText = "已清空搜索历史"
    }

    func setDisplayOption(_ keyPath: WritableKeyPath<ResultDisplayOptions, Bool>, to value: Bool) {
        var next = settings
        next.displayOptions[keyPath: keyPath] = value
        applySettings(next, shouldRebuild: false)
    }

    func resetDisplayOptions() {
        var next = settings
        next.displayOptions = .defaultValue
        applySettings(next, shouldRebuild: false)
        statusText = "已恢复默认显示列"
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
            rebuildSearchRecords()
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
        var databaseUpserts: [FileEntry] = []
        var databaseRemovals: [String] = []

        for (path, entry) in updates {
            if let entry {
                if entryMap[path] != entry {
                    entryMap[path] = entry
                    databaseUpserts.append(entry)
                    changed = true
                }
            } else if entryMap[path] != nil || entryMap.keys.contains(where: { $0.hasPrefix(path + "/") }) {
                entryMap = entryMap.filter { key, _ in
                    key != path && !key.hasPrefix(path + "/")
                }
                databaseRemovals.append(path)
                changed = true
            }
        }

        guard changed else { return }
        rebuildSearchRecords()
        updateStatus()
        scheduleSearch(immediate: true)

        let wroteIncrementally = await Task.detached(priority: .utility) {
            do {
                try IndexDatabase.applyChanges(upserts: databaseUpserts, removals: databaseRemovals)
                return true
            } catch {
                return false
            }
        }.value

        if !wroteIncrementally {
            scheduleSave()
        }
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

    private func promptForText(title: String, message: String, defaultValue: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.stringValue = defaultValue
        alert.accessoryView = field

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        return field.stringValue
    }

    private func recordCurrentQuery() {
        recordQuery(query)
    }

    private func recordQuery(_ rawQuery: String) {
        let trimmed = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var next = settings
        next.searchHistory.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        next.searchHistory.insert(trimmed, at: 0)
        next.searchHistory = AppSettings.normalizedQueries(next.searchHistory, limit: 30)
        applySettings(next, shouldRebuild: false)
    }

    private func applySettings(_ nextSettings: AppSettings, shouldRebuild: Bool) {
        var normalized = nextSettings
        normalized.normalize()
        if normalized.rootPaths.isEmpty {
            normalized.rootPaths = AppSettings.defaultValue.rootPaths
        }
        guard normalized != settings else { return }

        let indexScopeChanged = normalized.rootPaths != settings.rootPaths || normalized.excludedPaths != settings.excludedPaths
        settings = normalized
        try? SettingsStore.save(normalized)

        if indexScopeChanged {
            pendingPaths.removeAll(keepingCapacity: true)
            pendingFullRescan = false
            restartWatcher()
            statusText = "索引设置已更新"
        }

        if shouldRebuild {
            entryMap.removeAll(keepingCapacity: true)
            searchRecords.removeAll(keepingCapacity: true)
            results.removeAll()
            selection = nil
            rebuildIndex()
        } else {
            scheduleSearch(immediate: true)
        }
    }

    private func rebuildSearchRecords() {
        searchRecords = SearchEngine.makeRecords(from: Array(entryMap.values))
    }

    private func scheduleSearch(immediate: Bool = false) {
        searchTask?.cancel()
        let currentQuery = query
        let records = searchRecords

        searchTask = Task { [weak self] in
            if !immediate {
                try? await Task.sleep(for: .milliseconds(70))
            }
            guard !Task.isCancelled, let self else { return }

            let currentSort = sortOption
            let found = await Task.detached(priority: .userInitiated) {
                let candidatePaths = IndexDatabase.candidatePaths(for: currentQuery)
                let candidateRecords: [SearchRecord]
                if let candidatePaths {
                    let candidateSet = Set(candidatePaths)
                    candidateRecords = records.filter { candidateSet.contains($0.entry.path) }
                } else {
                    candidateRecords = records
                }
                return SearchEngine.search(currentQuery, in: candidateRecords, sort: currentSort)
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
