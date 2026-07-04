# MacEverything v0.1.0

首个公开预览版。

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

## 下载和安装

下载附件：`MacEverything-v0.1.0.zip`

1. 解压 ZIP。
2. 把 `MacEverything.app` 拖到“应用程序”。
3. 第一次打开如被 macOS 拦截，请右键 App → 打开。
4. 建议到系统设置里给它开启完全磁盘访问权限。
5. 授权后在 App 右上角菜单中点击“重建索引”。

## 注意

这是早期原型版本，暂未 notarize 公证，也还不是 Mac App Store 沙盒版。更适合尝鲜、自用和反馈。
