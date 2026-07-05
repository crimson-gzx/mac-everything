# MacEverything

<p align="center">
  <strong>macOS 上的 Everything 风格极速文件搜索工具。</strong>
</p>

<p align="center">
  <a href="https://github.com/crimson-gzx/mac-everything/releases"><img alt="最新版" src="https://img.shields.io/github/v/release/crimson-gzx/mac-everything?style=flat-square"></a>
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-blue?style=flat-square"></a>
  <img alt="macOS" src="https://img.shields.io/badge/macOS-14%2B-black?style=flat-square&logo=apple">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-SwiftUI-orange?style=flat-square&logo=swift">
</p>

<p align="center">
  <img src="assets/preview.svg" alt="MacEverything 预览" width="900">
</p>

MacEverything 是一个原生 macOS 文件搜索工具，灵感来自 Windows 上的 Everything。它使用本地 SQLite/FTS 索引、FSEvents 实时监听、全局快捷键和 Quick Look 预览，让你更快找到文件。

如果这个项目对你有用，欢迎点个 Star。Star 越多，越容易让更多 Mac 用户找到这个开源替代方案。

## 下载安装

推荐下载 DMG 版：

```text
https://github.com/crimson-gzx/mac-everything/releases
```

最简单安装方式：

1. 下载 `MacEverything-v0.10.0.dmg`。
2. 打开 DMG。
3. 把 `MacEverything.app` 拖到 `Applications`。
4. 到“应用程序”里打开 MacEverything。
5. 如果 macOS 拦截：右键 App → 打开。

第一次打开可能会有点卡：macOS 会做安全校验，App 也会初始化 SQLite/FTS 索引；如果你重建索引，还会扫描所选目录。索引完成后，日常搜索会快很多。

当前版本还没有 Apple Developer ID 签名和 Apple 公证，所以可能出现“无法验证开发者 / 不安全”的提示。临时解决方式是右键 App → 打开；正式解决方式是后续发布 Developer ID 签名并公证过的 DMG。

隐私说明：MacEverything 完全开源，当前核心功能是本地文件名索引和搜索，不需要登录，不需要联网，也不会上传你的文件列表、文件内容或搜索记录。索引和设置默认保存在你自己的 Mac 上。

更详细的安装说明见：[INSTALL.zh-CN.md](INSTALL.zh-CN.md)。英文安装说明见：[INSTALL.md](INSTALL.md)。

## 适合谁

- 从 Windows 切到 Mac，想找一个类似 Everything 的工具
- 经常忘记文件放在哪，只记得文件名片段
- 不想每次都等 Spotlight 慢慢转
- 想要一个简单、原生、能自己改的开源版本

## 功能

- 文件和文件夹极速搜索
- 可视化管理索引目录：添加、移除、恢复默认 Home
- 可视化管理排除目录：添加、移除、清空排除
- 设置会保存到 `~/Library/Application Support/MacEverything/settings.plist`
- 搜索历史：自动记录已执行的搜索，可一键套用或清空
- 常用过滤器/书签：内置 PDF、图片、视频、今天修改、大文件，也可保存当前搜索为自定义过滤器
- Quick Look 预览：菜单、右键菜单、`⌘Y`，列表聚焦时也可按空格预览
- 结果显示配置：可隐藏/显示路径、修改日期、大小、类型
- 性能优化：搜索预计算缓存，避免每次输入都重复处理所有路径/文件名
- 性能优化：文件图标缓存，减少滚动列表时反复调用系统图标服务
- SQLite 索引后端：优先使用 `file-index.sqlite`，旧版 `file-index.plist` 会自动迁移
- SQLite FTS5 候选搜索：普通关键词先由数据库筛候选路径，再由内存搜索精排
- SwiftUI 原生 macOS 界面
- 菜单栏常驻
- 全局快捷键呼出，默认优先尝试 `⌘⇧F`
- 双击或 Enter 打开文件
- `⌘ Enter` 在 Finder 中显示
- 右键菜单：打开、Finder 显示、打开所在文件夹、复制路径
- FSEvents 增量监听文件变化
- 更接近 Everything 的搜索语法：
  - `report final`：多个关键词同时匹配
  - `"final report"`：短语匹配
  - `*.pdf`、`report*`：通配符
  - `!temp` 或 `-temp`：排除关键词
  - `report|invoice`：OR 匹配
  - `name:photo`：只匹配文件名
  - `path:Desktop`：只匹配路径
  - `ext:pdf`、`ext:jpg,png`：扩展名筛选
  - `!ext:tmp`：排除扩展名
  - `type:file`、`type:folder`：文件/文件夹筛选
  - `size:>10mb`、`size:<1gb`：大小筛选
  - `date:today`、`date:last7d`、`date:2026-07-04`：修改日期筛选
  - `sort:name`、`sort:size`、`sort:date`：搜索框内指定排序
- 右上角菜单支持排序：相关度、名称、路径、最近修改、大小

## 权限设置

为了搜索桌面、文稿、下载等受保护目录，建议添加完全磁盘访问权限：

```text
系统设置 → 隐私与安全性 → 完全磁盘访问权限 → 添加 MacEverything
```

授权后，回到 MacEverything 右上角菜单，点击“重建索引”。

如果不开权限，macOS 可能会限制它读取部分目录，搜索结果会不完整。

## 从源码运行

要求：

- macOS 14 或更新版本
- Xcode Command Line Tools / Swift 工具链

运行：

```bash
swift run
```

构建 Release：

```bash
swift build -c release
```

构建本地 `.app`：

```bash
zsh build-app.sh
```

生成 ZIP 和 DMG：

```bash
zsh scripts/package-release.sh 0.10.0
```

## Apple 公证

见 [NOTARIZATION.md](NOTARIZATION.md)。

## 索引文件位置

```text
~/Library/Application Support/MacEverything/file-index.sqlite
```

## 和 Windows Everything 的区别

Windows Everything 可以直接利用 NTFS 的 MFT/USN Journal，所以全盘索引非常快。

macOS/APFS 没有完全等价、公开给第三方应用的接口，所以 MacEverything 采用更现实的方案：

1. 首次扫描目录
2. 保存本地二进制索引
3. 内存中即时搜索
4. FSEvents 监听变化并增量更新

首次索引需要一点时间；索引完成后，日常搜索基本是即时的。

## 后续计划

- 文件夹选择界面
- 快捷键偏好设置
- 结果预览
- DMG 公证
- 真正的 `.icns` 应用图标
- 更适合 Mac App Store 的沙盒版本
- 更好的模糊搜索和排序

## 免责声明

当前版本是早期原型。首次运行会扫描用户主目录，并建议开启完全磁盘访问。如果你对隐私或权限敏感，请先阅读源码，或只在测试机上使用。

## 协议

MIT
