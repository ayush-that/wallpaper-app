#!/usr/bin/env bash
#
# Build a notarised DMG installer from a signed Mural.app.
#
# Inputs (env):
#   DEVELOPER_ID        Same identity used to sign the .app
#   KEYCHAIN_PROFILE    notarytool stored profile name
#
# Optional positional arg:
#   $1  Path to the signed .app bundle
#       (default: build/Build/Products/Release/Mural.app)
#
# Produces:
#   dist/Mural-<version>.dmg  (signed + notarised + stapled)

set -euo pipefail

APP_PATH="${1:-build/Build/Products/Release/Mural.app}"

if [ -z "${DEVELOPER_ID:-}" ]; then
  echo "fatal: \$DEVELOPER_ID is required" >&2
  exit 64
fi
if [ -z "${KEYCHAIN_PROFILE:-}" ]; then
  echo "fatal: \$KEYCHAIN_PROFILE is required" >&2
  exit 64
fi
if [ ! -d "$APP_PATH" ]; then
  echo "fatal: app bundle not found at $APP_PATH" >&2
  exit 66
fi

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "create-dmg not installed. Install via: brew install create-dmg" >&2
  exit 69
fi

VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP_PATH/Contents/Info.plist")"
OUT_DIR="dist"
OUT_FILE="$OUT_DIR/Mural-${VERSION}.dmg"
BACKGROUND="scripts/dmg/background.png"

mkdir -p "$OUT_DIR"
rm -f "$OUT_FILE"

EXTRA_OPTS=()
if [ -f "$BACKGROUND" ]; then
  EXTRA_OPTS+=(--background "$BACKGROUND")
fi

echo "==> Building $OUT_FILE"
create-dmg \
  --volname "Mural" \
  --window-size 600 400 \
  --icon-size 96 \
  --icon "Mural.app" 150 180 \
  --app-drop-link 450 180 \
  --no-internet-enable \
  "${EXTRA_OPTS[@]}" \
  "$OUT_FILE" \
  "$APP_PATH"

echo "==> Signing $OUT_FILE"
codesign --force --sign "$DEVELOPER_ID" --timestamp "$OUT_FILE"

echo "==> Submitting DMG to Apple Notary Service"
xcrun notarytool submit "$OUT_FILE" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait

echo "==> Stapling notarisation ticket to DMG"
xcrun stapler staple "$OUT_FILE"

echo "==> Verifying"
spctl --assess --type install --verbose=4 "$OUT_FILE"

echo "==> Done: $OUT_FILE"
