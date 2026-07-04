import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @FocusState private var searchFocused: Bool
    @State private var showingIndexSettings = false

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            Divider()
            resultsList
            Divider()
            statusBar
        }
        .frame(minWidth: 760, idealWidth: 920, minHeight: 480, idealHeight: 620)
        .background(.regularMaterial)
        .onAppear {
            model.start()
            searchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusMacEverythingSearch)) { _ in
            searchFocused = true
        }
        .sheet(isPresented: $showingIndexSettings) {
            IndexSettingsView(model: model)
        }
    }

    private var searchHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("搜索：*.pdf !temp name:report path:Desktop size:>10mb date:today", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .medium))
                .focused($searchFocused)
                .onSubmit { model.submitSearch() }

            if !model.query.isEmpty {
                Button {
                    model.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("清空")
            }

            if model.isIndexing {
                ProgressView()
                    .controlSize(.small)
            }

            Menu {
                Button("索引目录设置…") { showingIndexSettings = true }
                Button("重建索引") { model.rebuildIndex() }
                Button("打开完全磁盘访问设置") { model.openFullDiskAccessSettings() }
                Divider()
                Menu("过滤器") {
                    Button("保存当前搜索为过滤器…") { model.saveCurrentQueryAsFilter() }
                        .disabled(model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("恢复默认过滤器") { model.resetDefaultFilters() }
                    Divider()
                    if model.savedFilters.isEmpty {
                        Text("暂无过滤器")
                    } else {
                        ForEach(model.savedFilters) { filter in
                            Button("\(filter.name)  —  \(filter.query)") {
                                model.applySavedFilter(filter)
                            }
                        }
                        Divider()
                        Menu("删除过滤器") {
                            ForEach(model.savedFilters) { filter in
                                Button(role: .destructive) {
                                    model.removeSavedFilter(filter)
                                } label: {
                                    Text(filter.name)
                                }
                            }
                        }
                    }
                }
                Menu("历史") {
                    if model.searchHistory.isEmpty {
                        Text("暂无搜索历史")
                    } else {
                        ForEach(model.searchHistory, id: \.self) { historyQuery in
                            Button(historyQuery) { model.applyHistoryQuery(historyQuery) }
                        }
                        Divider()
                        Button("清空历史") { model.clearSearchHistory() }
                    }
                }
                Menu("排序：\(model.sortOption.label)") {
                    ForEach(SearchSort.allCases) { option in
                        Button(option.label) { model.sortOption = option }
                    }
                }
                Divider()
                Text("快捷键：\(model.hotKeyDisplay)")
                Text("索引目录：\(model.rootPaths.count)  排除：\(model.excludedPaths.count)")
                Text("语法：*.pdf  !temp  name:  path:  size:>10mb  date:today")
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 17))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
    }

    @ViewBuilder
    private var resultsList: some View {
        if model.results.isEmpty {
            ContentUnavailableView {
                Label(model.isIndexing ? "正在建立索引" : "没有找到结果", systemImage: model.isIndexing ? "externaldrive.badge.timemachine" : "doc.text.magnifyingglass")
            } description: {
                Text(model.isIndexing ? "首次启动需要扫描一次文件目录。" : "试试更短的关键词，或使用 ext:pdf 等筛选条件。")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(model.results, selection: $model.selection) { entry in
                ResultRow(entry: entry)
                    .tag(entry.id)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        model.selection = entry.id
                        model.openSelected()
                    }
                    .contextMenu {
                        Button("打开") {
                            model.selection = entry.id
                            model.openSelected()
                        }
                        Button("在 Finder 中显示") {
                            model.selection = entry.id
                            model.revealSelected()
                        }
                        Button("打开所在文件夹") {
                            model.selection = entry.id
                            model.openSelectedParent()
                        }
                        Divider()
                        Button("复制路径") {
                            model.selection = entry.id
                            model.copySelectedPath()
                        }
                    }
            }
            .listStyle(.inset)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            Text(model.statusText)
            Text("索引 \(model.rootPaths.count) 个目录")
            if !model.excludedPaths.isEmpty {
                Text("排除 \(model.excludedPaths.count) 个")
            }
            if !model.query.isEmpty {
                Text("找到 \(model.results.count) 条")
                Text("排序：\(model.sortOption.label)")
            }
            if !model.savedFilters.isEmpty {
                Text("过滤器 \(model.savedFilters.count) 个")
            }
            if !model.searchHistory.isEmpty {
                Text("历史 \(model.searchHistory.count) 条")
            }
            Spacer()
            Text("Enter 打开  ⌘↩ Finder  \(model.hotKeyDisplay) 呼出")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .frame(height: 30)
    }
}

private struct ResultRow: View {
    let entry: FileEntry

    var body: some View {
        HStack(spacing: 11) {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.system(size: 13.5, weight: .medium))
                    .lineLimit(1)
                Text(displayPath)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                if let modifiedAt = entry.modifiedAt {
                    Text(modifiedAt, format: .dateTime.year().month().day())
                }
                if let size = entry.size, !entry.isDirectory {
                    Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                } else if entry.isDirectory {
                    Text("文件夹")
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(minWidth: 84, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private var icon: NSImage {
        let image = NSWorkspace.shared.icon(forFile: entry.path)
        image.size = NSSize(width: 32, height: 32)
        return image
    }

    private var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if entry.path.hasPrefix(home) {
            return "~" + entry.path.dropFirst(home.count)
        }
        return entry.path
    }
}
