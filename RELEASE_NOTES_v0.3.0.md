# MacEverything v0.3.0

这版继续补 Everything 体验里最关键的索引管理能力。

## 推荐下载

推荐下载：`MacEverything-v0.3.0.dmg`

安装方式：打开 DMG，把 `MacEverything.app` 拖到 `Applications`。

## 新增

- 新增“索引目录设置”窗口。
- 可以添加多个要索引的目录。
- 可以移除索引目录。
- 可以一键恢复默认 Home 目录。
- 可以添加排除目录，例如 `node_modules`、`.git`、大型缓存目录。
- 可以移除或清空排除目录。
- 修改索引目录或排除目录后，会自动重启 FSEvents 监听并重建索引。
- 设置保存到：`~/Library/Application Support/MacEverything/settings.plist`
- 索引缓存升级到 v2，会记录索引目录和排除目录；配置变化时会自动重建索引。
- 状态栏会显示当前索引目录数量和排除目录数量。

## 使用方法

1. 打开 MacEverything。
2. 点击右上角 `...` 菜单。
3. 点击“索引目录设置…”。
4. 添加要搜索的文件夹，或添加要排除的文件夹。
5. 设置变化后等待索引重建完成。

## 建议

如果你要索引桌面、文稿、下载或外置盘，建议开启完全磁盘访问权限：

```text
系统设置 → 隐私与安全性 → 完全磁盘访问权限 → 添加 MacEverything
```

## 还没完全复刻 Everything 的部分

后面还要继续做：正则搜索、过滤器/书签、搜索历史、表格列配置、批量操作、Quick Look 预览、真正的多盘索引、SQLite/FTS 或 mmap 索引后端。

## 注意

当前 DMG 仍未 Apple 公证，首次打开可能需要右键打开。
