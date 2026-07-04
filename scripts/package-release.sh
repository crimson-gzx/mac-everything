#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-0.1.0}"
APP_NAME="MacEverything"
APP_PATH="$ROOT_DIR/dist/$APP_NAME.app"
RELEASE_DIR="$ROOT_DIR/dist/release/MacEverything-v$VERSION"
ZIP_PATH="$ROOT_DIR/dist/MacEverything-v$VERSION.zip"

cd "$ROOT_DIR"
zsh build-app.sh

rm -rf "$RELEASE_DIR" "$ZIP_PATH"
mkdir -p "$RELEASE_DIR"
ditto "$APP_PATH" "$RELEASE_DIR/$APP_NAME.app"
cat > "$RELEASE_DIR/INSTALL-zh-CN.txt" <<'TXT'
MacEverything 安装说明

1. 把 MacEverything.app 拖到“应用程序”。
2. 第一次打开如果被 macOS 拦截：右键 MacEverything.app → 打开。
3. 建议开启权限：系统设置 → 隐私与安全性 → 完全磁盘访问权限 → 添加 MacEverything。
4. 授权后打开 MacEverything，右上角菜单点击“重建索引”。

默认快捷键优先尝试：⌘⇧F
如果冲突，程序会自动尝试备用快捷键，并在窗口底部显示实际使用的组合。

项目地址：
https://github.com/crimson-gzx/mac-everything
TXT

cd "$ROOT_DIR/dist/release"
ditto -c -k --norsrc --noextattr --keepParent "MacEverything-v$VERSION" "$ZIP_PATH"

echo "Built release archive: $ZIP_PATH"
