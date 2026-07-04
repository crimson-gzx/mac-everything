#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_APP="$ROOT_DIR/dist/MacEverything.app"
INSTALL_APP="/Applications/MacEverything.app"
DESKTOP_LINK="$HOME/Desktop/MacEverything.app"

if [[ ! -d "$SOURCE_APP" ]]; then
  echo "找不到已构建的 MacEverything.app，请先运行 build-app.sh"
  exit 1
fi

rm -rf "$INSTALL_APP"
ditto "$SOURCE_APP" "$INSTALL_APP"
rm -rf "$DESKTOP_LINK"
ln -s "$INSTALL_APP" "$DESKTOP_LINK"

open -R "$DESKTOP_LINK"
echo "已安装到：$INSTALL_APP"
echo "桌面快捷方式：$DESKTOP_LINK"
