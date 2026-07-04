import SwiftUI

struct IndexSettingsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("索引目录设置")
                        .font(.title2.bold())
                    Text("选择 MacEverything 要搜索哪些目录，并排除不想扫的目录。修改后会自动重建索引。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

            GroupBox("要索引的目录") {
                VStack(alignment: .leading, spacing: 10) {
                    if model.rootPaths.isEmpty {
                        Text("暂无目录，默认会使用用户主目录。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.rootPaths, id: \.self) { path in
                            pathRow(path: path) {
                                model.removeIndexRoot(path)
                            }
                        }
                    }

                    HStack {
                        Button {
                            model.addIndexFolder()
                        } label: {
                            Label("添加索引目录", systemImage: "plus")
                        }
                        Button("恢复默认 Home") { model.resetIndexRoots() }
                        Spacer()
                    }
                }
                .padding(.vertical, 6)
            }

            GroupBox("排除目录") {
                VStack(alignment: .leading, spacing: 10) {
                    if model.excludedPaths.isEmpty {
                        Text("暂无自定义排除目录。系统会自动跳过缓存、废纸篓、App 自身索引目录和包文件。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.excludedPaths, id: \.self) { path in
                            pathRow(path: path) {
                                model.removeExcludedPath(path)
                            }
                        }
                    }

                    HStack {
                        Button {
                            model.addExcludedFolder()
                        } label: {
                            Label("添加排除目录", systemImage: "plus")
                        }
                        Button("清空排除") { model.clearExcludedFolders() }
                            .disabled(model.excludedPaths.isEmpty)
                        Spacer()
                    }
                }
                .padding(.vertical, 6)
            }

            Text("提示：如果添加桌面、文稿、下载或外置盘后结果不完整，请在系统设置里给 MacEverything 开启完全磁盘访问权限，然后重建索引。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(width: 680)
        .frame(minHeight: 520)
    }

    private func pathRow(path: String, remove: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
            Text(displayPath(path))
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button(role: .destructive) {
                remove()
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
            .help("移除")
        }
        .padding(.vertical, 3)
    }

    private func displayPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
