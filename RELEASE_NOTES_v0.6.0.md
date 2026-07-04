# MacEverything v0.6.0

这版是性能优化版，主要解决“搜索和滚动感觉不够快”的问题。

## 推荐下载

推荐下载：`MacEverything-v0.6.0.dmg`

安装方式：打开 DMG，把 `MacEverything.app` 拖到 `Applications`。

## 为什么它还不能像 Windows Everything 一样快

Windows Everything 的核心优势是能利用 NTFS 的 MFT/USN Journal。macOS/APFS 没有给第三方 App 暴露完全等价的公开接口，所以 MacEverything 当前仍然需要通过目录扫描建立索引。

结论：

- 首次索引很难做到 Everything 那种速度。
- 索引完成后的日常搜索可以继续优化。
- 下一阶段要上 SQLite/FTS 或 mmap 索引后端，进一步减少 plist 和内存重建成本。

## 本版优化

- 新增 `SearchRecord` 预计算缓存。
  - 索引加载或更新后预先生成小写文件名、小写路径、扩展名。
  - 搜索时不再每次输入都对所有文件名和路径重复 lowercase。
- 新增 `FileIconCache`。
  - 按文件夹/扩展名缓存图标。
  - 减少结果列表滚动时反复调用系统图标服务。
- 使用 `UniformTypeIdentifiers` 获取扩展名图标，避免旧 API 警告。

## 适合升级的人

如果你已经用 v0.5.0，建议升级。这版不改索引格式，也不会丢索引目录、排除目录、历史和过滤器。

## 注意

当前 DMG 仍未 Apple 公证，首次打开可能需要右键打开。
