#!/usr/bin/env bash
# Build the HerdrNotify.app helper from source with Tuist and copy it into
# assets/ so plugin installs can run without downloading a binary artifact.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/.build/herdr-notify"
APP_SRC="$BUILD_DIR/Build/Products/Release/HerdrNotify.app"
APP_DST="$ROOT/assets/HerdrNotify.app"
APP_TMP="$ROOT/assets/.HerdrNotify.app.tmp.$$"

cleanup() {
  rm -rf "$APP_TMP"
}
trap cleanup EXIT

if ! command -v tuist >/dev/null 2>&1; then
  echo "tuist not found on PATH; install Tuist to rebuild HerdrNotify.app" >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found on PATH; install Xcode and select its Developer directory" >&2
  echo "example: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  echo "if you use Xcode beta: sudo xcode-select -s /Applications/Xcode-beta.app/Contents/Developer" >&2
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

if [ ! -d "$APP_SRC" ]; then
  echo "build product missing: $APP_SRC" >&2
  exit 1
fi

rm -rf "$APP_TMP"
cp -R "$APP_SRC" "$APP_TMP"
codesign --force --deep -s - "$APP_TMP" >/dev/null

rm -rf "$APP_DST"
mv "$APP_TMP" "$APP_DST"
echo "built notifier: $APP_DST"

staged_app="$(bash "$ROOT/scripts/setup-notifier.sh" --quiet --print-path)"
echo "staged notifier: $staged_app"
