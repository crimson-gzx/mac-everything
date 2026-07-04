# MacEverything v0.1.0

首个公开预览版。

## 推荐下载

推荐下载：`MacEverything-v0.1.0.dmg`

安装方式最简单：打开 DMG，把 `MacEverything.app` 拖到 `Applications`。

也保留 ZIP 版：`MacEverything-v0.1.0.zip`

## 这是什么

MacEverything 是一个原生 macOS 文件名极速搜索工具，目标是提供接近 Windows Everything 的体验。

## 主要功能

- 首次扫描用户主目录并建立本地索引
- 后续从内存索引即时搜索
- 使用 FSEvents 增量监听文件变化
- 菜单栏常驻
- 全局快捷键呼出，优先尝试 `⌘⇧F`
- 双击或 Enter 打开文件
- `⌘ Enter` 在 Finder 中显示
- 右键复制路径、打开所在文件夹
- 支持 `ext:pdf`、`ext:jpg,png`、`type:file`、`type:folder`

## 简单安装说明

1. 下载 `MacEverything-v0.1.0.dmg`。
2. 打开 DMG。
3. 把 `MacEverything.app` 拖到 `Applications`。
4. 到“应用程序”里打开 MacEverything。
5. 如果 macOS 拦截：右键 App → 打开。
6. 建议开启完全磁盘访问权限，再点击“重建索引”。

English installation instructions are included in the DMG and ZIP as `README.txt` / `INSTALL.txt`.

## 注意

这是早期原型版本，暂未 notarize 公证，也还不是 Mac App Store 沙盒版。更适合尝鲜、自用和反馈。
