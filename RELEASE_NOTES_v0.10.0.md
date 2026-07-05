# MacEverything v0.10.0

这版新增扫描进度和性能指标，让搜索速度和索引状态更可见。

## 推荐下载

推荐下载：`MacEverything-v0.10.0.dmg`

安装方式：打开 DMG，把 `MacEverything.app` 拖到 `Applications`。

## 新增

- 底部状态栏显示当前索引项目数量。
- 搜索后显示搜索耗时。
- 搜索后显示本次是否使用 SQLite FTS5 候选搜索。
- 搜索后显示 FTS 候选数量。
- 重建索引后显示索引耗时。
- 右上角菜单里也会显示性能摘要。

## 为什么这一步重要

前几版主要在做性能结构：

- v0.6.0：搜索预计算缓存和图标缓存。
- v0.7.0：SQLite 索引后端。
- v0.8.0：SQLite FTS5 候选搜索。
- v0.9.0：增量 SQLite 写入。

v0.10.0 让这些优化变得可观察：你可以看到一次搜索到底是走 FTS 还是内存搜索、耗时多少、候选集有多大。

## 首次打开和安全提示

第一次打开可能会有点卡，这是正常的：macOS 会校验从网上下载的 App，MacEverything 也会初始化本地 SQLite / FTS 索引。如果你点击“重建索引”，还需要扫描所选目录；文件越多，首次索引越久。

当前 DMG 还没有 Apple Developer ID 签名和 Apple 公证，所以 macOS 可能提示“无法验证开发者”或“不安全”。这不代表它一定有病毒，而是系统无法验证它是受信任开发者签发并公证过的 App。

临时打开方式：把 App 拖到 Applications 后，右键 `MacEverything.app` → 打开 → 再次确认打开。

正式解决方式：后续需要使用 Developer ID Application 证书签名，并提交 Apple notarization 公证，之后再发布公证过的 DMG。

## 注意

如果你从旧版本升级，建议点一次“重建索引”，保证 SQLite 和 FTS 表完整。
