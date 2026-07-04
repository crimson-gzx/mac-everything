#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-0.1.0}"
APP_NAME="MacEverything"
APP_PATH="$ROOT_DIR/dist/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/dist"
RELEASE_ROOT="$DIST_DIR/release"
RELEASE_DIR="$RELEASE_ROOT/MacEverything-v$VERSION"
DMG_DIR="$RELEASE_ROOT/dmg-root"
ZIP_PATH="$DIST_DIR/MacEverything-v$VERSION.zip"
DMG_PATH="$DIST_DIR/MacEverything-v$VERSION.dmg"

cd "$ROOT_DIR"
zsh build-app.sh

rm -rf "$RELEASE_DIR" "$DMG_DIR" "$ZIP_PATH" "$DMG_PATH"
mkdir -p "$RELEASE_DIR" "$DMG_DIR"

cat > "$RELEASE_DIR/INSTALL-zh-CN.txt" <<'TXT'
MacEverything 安装说明

1. 把 MacEverything.app 拖到“应用程序”。
2. 第一次打开如果被 macOS 拦截：右键 MacEverything.app → 打开。
3. 建议开启权限：系统设置 → 隐私与安全性 → 完全磁盘访问权限 → 添加 MacEverything。
4. 授权后打开 App，右上角菜单点击“重建索引”。

快捷键：默认优先尝试 ⌘⇧F。
项目地址：https://github.com/crimson-gzx/mac-everything
TXT

cat > "$DMG_DIR/README-先看我.txt" <<'TXT'
安装方法：

1. 把 MacEverything.app 拖到右边的 Applications。
2. 到“应用程序”里打开 MacEverything。
3. 如果 macOS 提示无法打开：右键 MacEverything.app → 打开。
4. 建议开启：系统设置 → 隐私与安全性 → 完全磁盘访问权限。

快捷键：默认优先尝试 ⌘⇧F。
TXT

ditto "$APP_PATH" "$RELEASE_DIR/$APP_NAME.app"
ditto "$APP_PATH" "$DMG_DIR/$APP_NAME.app"
ln -s /Applications "$DMG_DIR/Applications"

cd "$RELEASE_ROOT"
ditto -c -k --norsrc --noextattr --keepParent "MacEverything-v$VERSION" "$ZIP_PATH"

hdiutil create \
  -volname "MacEverything v$VERSION" \
  -srcfolder "$DMG_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Built ZIP: $ZIP_PATH"
echo "Built DMG: $DMG_PATH"
