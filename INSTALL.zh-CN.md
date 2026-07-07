# MacEverything 安装说明

推荐下载 DMG 版：`MacEverything-v0.10.1.dmg`。

## 最简单安装方式

1. 打开 DMG。
2. 把 `MacEverything.app` 拖到 `Applications`。
3. 到“应用程序”里打开 MacEverything。
4. 如果 macOS 拦截：右键 `MacEverything.app` → 打开。

## 第一次打开有点卡，正常吗？

正常。第一次打开可能会比后面慢，主要有三个原因：

1. macOS 会对从网上下载的 App 做安全校验。
2. MacEverything 第一次启动会初始化本地 SQLite / FTS 索引文件。
3. 如果你点击“重建索引”，它需要扫描你设置的索引目录；文件越多，首次索引越久。

索引完成后，后续启动会优先读取本地 SQLite 缓存，不会每次打开都全盘扫描。只有缓存不存在、索引目录/排除目录变化，或你手动点“重建索引”时，才会重新全量扫描。窗口底部会显示搜索耗时、FTS/内存模式、候选数量和索引耗时。

## macOS 提示“不安全”怎么办？

当前 GitHub Release 版本还没有 Apple Developer ID 签名和 Apple 公证，所以 Gatekeeper 会提示无法验证开发者或提示不安全。这不代表它一定有病毒，而是因为系统还不能验证这个 App 是否由受信任开发者签发。

补充说明：MacEverything 是完全开源项目，代码可以在 GitHub 上直接查看。当前版本的核心功能是本地文件名索引和搜索，不需要登录，不需要联网，也不会上传你的文件列表、文件内容或搜索记录。索引和设置默认保存在你自己的 Mac 上。

临时打开方式：

1. 打开 `Applications`。
2. 找到 `MacEverything.app`。
3. 右键点击 App。
4. 选择“打开”。
5. 在弹窗里再次选择“打开”。

正式解决方式：

- 注册 Apple Developer Program。
- 使用 Developer ID Application 证书签名 App。
- 把 DMG 提交给 Apple notarization 公证。
- 公证成功后再发布 DMG。

项目里已经预留了公证说明和脚本，见：[NOTARIZATION.md](NOTARIZATION.md)。

## 建议权限

为了搜索桌面、文稿、下载等目录，建议开启：

```text
系统设置 → 隐私与安全性 → 完全磁盘访问权限 → 添加 MacEverything
```

授权后，打开 MacEverything，右上角菜单点击“重建索引”。

## 快捷键

默认优先尝试：`⌘⇧F`。

如果冲突，程序会自动尝试备用快捷键，窗口底部会显示实际使用的组合。
