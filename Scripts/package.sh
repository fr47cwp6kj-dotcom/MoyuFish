#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"
DIST_DIR="${OUTPUT_DIR:-$ROOT_DIR/build-artifacts}"
APP_DIR="$DIST_DIR/MoyuFish.app"
APP_CONTENTS="$APP_DIR/Contents"

swift build -c "$CONFIGURATION" --package-path "$ROOT_DIR" --scratch-path /tmp/MoyuFishBuild/.build --product MoyuFish

BIN_DIR="$(swift build -c "$CONFIGURATION" --package-path "$ROOT_DIR" --scratch-path /tmp/MoyuFishBuild/.build --show-bin-path)"
test ! -e "$APP_DIR" || { printf 'Refusing to overwrite %s\n' "$APP_DIR" >&2; exit 1; }

mkdir -p "$APP_CONTENTS/MacOS" "$APP_CONTENTS/Resources"

cp "$BIN_DIR/MoyuFish" "$APP_CONTENTS/MacOS/MoyuFish"
cp "$ROOT_DIR/Resources/AppInfo.plist" "$APP_CONTENTS/Info.plist"

/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_CONTENTS/Info.plist" >/dev/null
plutil -lint "$APP_CONTENTS/Info.plist" "$ROOT_DIR/Resources/AppInfo.plist"

codesign --force --sign - --timestamp=none "$APP_DIR"
codesign --verify --strict --verbose=2 "$APP_DIR"

printf 'App bundle: %s\n' "$APP_DIR"
