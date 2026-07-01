#!/usr/bin/env bash
# Build the HerdrNotify.app helper from source with Tuist and copy it into
# assets/ so plugin installs can run without downloading a binary artifact.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/.build/herdr-notify"
APP_SRC="$BUILD_DIR/Build/Products/Release/HerdrNotify.app"
APP_DST="$ROOT/assets/HerdrNotify.app"

if ! command -v tuist >/dev/null 2>&1; then
  echo "tuist not found on PATH; install Tuist to rebuild HerdrNotify.app" >&2
  exit 1
fi

cd "$ROOT"
tuist generate --no-open
xcodebuild \
  -workspace HerdrTerminalNotifier.xcworkspace \
  -scheme HerdrNotify \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=NO \
  build

rm -rf "$APP_DST"
mkdir -p "$(dirname "$APP_DST")"
cp -R "$APP_SRC" "$APP_DST"
codesign --force --deep -s - "$APP_DST" >/dev/null 2>&1 || true
echo "built notifier: $APP_DST"
