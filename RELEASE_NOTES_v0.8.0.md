# MacEverything v0.8.0

这版继续速度路线：新增 SQLite FTS5 候选搜索。

## 推荐下载

推荐下载：`MacEverything-v0.8.0.dmg`

安装方式：打开 DMG，把 `MacEverything.app` 拖到 `Applications`。

## 新增

- 新增 SQLite FTS5 虚拟表：`entries_fts`。
- 保存索引时同步写入 FTS 数据。
- 普通关键词搜索会先通过 SQLite FTS5 获取候选路径。
- 候选集再交给原来的 SearchEngine 做最终过滤和相关度排序。
- 复杂语法或 FTS 不可用时，会自动回退到原来的全量内存搜索。

## 为什么这样做

直接把所有搜索都交给 FTS 会破坏现有语法，例如：

- `ext:pdf`
- `!temp`
- `size:>10mb`
- `date:today`
- `type:file`
- `report|invoice`

所以 v0.8.0 采用更稳的混合方案：

1. SQLite FTS5 先缩小候选范围。
2. 原来的搜索引擎继续负责完整语法、排除规则、大小/日期筛选和排序。

## 注意

已有 v0.7.0 SQLite 索引的用户，建议升级后点一次“重建索引”，这样会生成新的 FTS 表数据。

当前 DMG 仍未 Apple 公证，首次打开可能需要右键打开。
