# MacEverything

一个原生 macOS 文件名极速搜索工具，灵感来自 Windows 上的 Everything。

<p align="center">
  <img src="assets/preview.svg" alt="MacEverything 预览" width="900">
</p>

MacEverything 的思路是：先建立一次本地索引，然后从内存里即时搜索；文件新增、删除、移动、重命名后，通过 macOS FSEvents 自动更新索引。

> 当前还是早期原型，更适合 GitHub Release / 自行分发使用。它还不是 Mac App Store 沙盒版。

## 适合谁

- 从 Windows 切到 Mac，想找一个类似 Everything 的工具
- 经常忘记文件放在哪，只记得文件名片段
- 不想每次都等 Spotlight 慢慢转
- 想要一个简单、原生、能自己改的开源版本

## 功能

- 文件和文件夹极速搜索
- SwiftUI 原生 macOS 界面
- 菜单栏常驻
- 全局快捷键呼出，默认优先尝试 `⌘⇧F`
- 双击或 Enter 打开文件
- `⌘ Enter` 在 Finder 中显示
- 右键菜单：打开、Finder 显示、打开所在文件夹、复制路径
- FSEvents 增量监听文件变化
- 搜索语法：
  - `report final`：多个关键词同时匹配
  - `ext:pdf`：只看 PDF
  - `ext:jpg,png`：多个扩展名
  - `type:file`：只看文件
  - `type:folder`：只看文件夹

## 下载安装

到 GitHub Releases 下载最新版：

```text
https://github.com/crimson-gzx/mac-everything/releases
```

下载 `MacEverything-v0.1.0.zip` 后：

1. 解压 ZIP。
2. 把 `MacEverything.app` 拖进“应用程序”。
3. 第一次打开如果提示来自互联网，右键 App → 打开。
4. 建议开启完全磁盘访问权限。

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

安装到应用程序并创建桌面快捷方式：

```bash
zsh install-shortcut.sh
```

## 索引文件位置

```text
~/Library/Application Support/MacEverything/file-index.plist
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
- DMG 打包和公证
- 真正的 `.icns` 应用图标
- 更适合 Mac App Store 的沙盒版本
- 更好的模糊搜索和排序

## 免责声明

当前版本是早期原型。首次运行会扫描用户主目录，并建议开启完全磁盘访问。如果你对隐私或权限敏感，请先阅读源码，或只在测试机上使用。

## 协议

MIT
