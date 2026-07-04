# MacEverything v0.7.0

这版开始把索引后端从原型阶段的 plist 转向 SQLite，为后续 FTS/mmap 和更细粒度增量写入打基础。

## 推荐下载

推荐下载：`MacEverything-v0.7.0.dmg`

安装方式：打开 DMG，把 `MacEverything.app` 拖到 `Applications`。

## 新增

- 新增 SQLite 索引后端：`file-index.sqlite`。
- App 启动时优先读取 SQLite 索引。
- 旧版用户如果只有 `file-index.plist`，会自动读取旧索引并迁移写入 SQLite。
- 保存索引时使用事务批量写入。
- 批量写入时先暂时移除索引，提交后再重建索引，减少大量文件写入时的维护开销。
- SQLite 表里预留 `lower_name`、`lower_path`、`extension` 字段，为后续数据库侧查询/FTS 做准备。
- Package 已链接系统 `sqlite3`。

## 为什么这是速度路线的关键一步

v0.6.0 优化的是内存搜索和列表滚动；v0.7.0 优化的是索引持久化结构。

这版还不是完整 FTS 搜索，但已经把后端从“整包二进制 plist”换成“可索引、可扩展、可增量化”的数据库结构。后面继续做 FTS 后，搜索可以逐步从全量内存扫描转向数据库查询。

## 注意

当前 DMG 仍未 Apple 公证，首次打开可能需要右键打开。
