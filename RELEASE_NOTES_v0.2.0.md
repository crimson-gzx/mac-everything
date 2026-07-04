# MacEverything v0.2.0

这版主要补齐第一批 Everything 风格能力，并加入真正的 App 图标。

## 推荐下载

推荐下载：`MacEverything-v0.2.0.dmg`

安装方式：打开 DMG，把 `MacEverything.app` 拖到 `Applications`。

## 新增

- 新增线框风格 `.icns` App 图标，Dock 和 Finder 会显示真实图标。
- 搜索框支持更多 Everything 风格语法：
  - `*.pdf`、`report*`：通配符
  - `!temp` 或 `-temp`：排除关键词
  - `report|invoice`：OR 匹配
  - `"final report"`：短语匹配
  - `name:photo`：只匹配文件名
  - `path:Desktop`：只匹配路径
  - `!ext:tmp`：排除扩展名
  - `size:>10mb`、`size:<1gb`：大小筛选
  - `date:today`、`date:last7d`、`date:2026-07-04`：修改日期筛选
  - `sort:name`、`sort:size`、`sort:date`：搜索框内排序
- 右上角菜单新增排序：相关度、名称、路径、最近修改、大小。
- 搜索核心新增自检覆盖通配符、排除、路径/名称、大小/日期和排序。

## 安装说明

1. 下载 `MacEverything-v0.2.0.dmg`。
2. 打开 DMG。
3. 把 `MacEverything.app` 拖到 `Applications`。
4. 到“应用程序”里打开 MacEverything。
5. 如果 macOS 拦截：右键 App → 打开。
6. 建议开启完全磁盘访问权限，然后点击“重建索引”。

## 还没完全复刻 Everything 的部分

这版补的是搜索语法和排序。后面还要继续做：索引目录管理、排除目录管理、正则搜索、书签/过滤器、历史搜索、表格列配置、批量操作、Quick Look 预览、真正的多盘索引。

## 注意

当前 DMG 仍未 Apple 公证，首次打开可能需要右键打开。
