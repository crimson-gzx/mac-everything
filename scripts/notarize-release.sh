#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-0.1.0}"
APP_PATH="$ROOT_DIR/dist/MacEverything.app"
DMG_PATH="$ROOT_DIR/dist/MacEverything-v$VERSION.dmg"
KEYCHAIN_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-MacEverythingNotary}"

if [[ -z "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  echo "Missing DEVELOPER_ID_APPLICATION. Example:"
  echo "export DEVELOPER_ID_APPLICATION='Developer ID Application: Your Name (TEAMID)'"
  exit 1
fi

cd "$ROOT_DIR"
zsh build-app.sh

codesign --force --deep --timestamp --options runtime \
  --sign "$DEVELOPER_ID_APPLICATION" \
  "$APP_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl -a -vvv -t execute "$APP_PATH" || true

SKIP_BUILD=1 zsh scripts/package-release.sh "$VERSION"

xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl -a -vvv -t open "$DMG_PATH"

echo "Notarized DMG: $DMG_PATH"
echo "Upload this DMG to GitHub Releases after verification."
