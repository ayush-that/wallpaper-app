#!/usr/bin/env bash
#
# Sign + notarise + staple a Mural.app build.
#
# Inputs (env):
#   DEVELOPER_ID        Full Developer ID Application identity string,
#                       e.g. "Developer ID Application: Your Name (TEAMID)"
#   KEYCHAIN_PROFILE    notarytool stored-credentials profile name
#                       (created once via `xcrun notarytool store-credentials`)
#
# Optional positional arg:
#   $1  Path to the .app bundle (default: build/Build/Products/Release/Mural.app)
#
# Exits non-zero on any signing / notarisation failure.

set -euo pipefail

APP_PATH="${1:-build/Build/Products/Release/Mural.app}"
ENTITLEMENTS="App/Mural.entitlements"

if [ -z "${DEVELOPER_ID:-}" ]; then
  echo "fatal: \$DEVELOPER_ID is required (Developer ID Application identity)" >&2
  exit 64
fi
if [ -z "${KEYCHAIN_PROFILE:-}" ]; then
  echo "fatal: \$KEYCHAIN_PROFILE is required (notarytool stored profile name)" >&2
  exit 64
fi
if [ ! -d "$APP_PATH" ]; then
  echo "fatal: app bundle not found at $APP_PATH" >&2
  exit 66
fi

echo "==> Signing nested binaries in $APP_PATH"
# Sign every nested framework/bundle/binary first so the outer signature
# covers their already-signed copies. Order matters: deepest first.
find "$APP_PATH" \( \
    -name "*.xpc" -o \
    -name "*.dylib" -o \
    -name "*.framework" -o \
    -name "*.bundle" -o \
    -name "muralctl" \
  \) -print0 |
  while IFS= read -r -d '' nested; do
    if [ -d "$nested" ] || [ -f "$nested" ]; then
      codesign --force --options runtime --timestamp \
        --entitlements "$ENTITLEMENTS" \
        --sign "$DEVELOPER_ID" \
        "$nested"
    fi
  done

echo "==> Signing $APP_PATH"
codesign --force --deep --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$DEVELOPER_ID" \
  "$APP_PATH"

echo "==> Zipping for notarytool"
ZIP="$(mktemp -d)/Mural.zip"
ditto -c -k --keepParent "$APP_PATH" "$ZIP"

echo "==> Submitting to Apple Notary Service (this can take 1-15 minutes)"
xcrun notarytool submit "$ZIP" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait

echo "==> Stapling notarisation ticket to $APP_PATH"
xcrun stapler staple "$APP_PATH"

echo "==> Verifying"
spctl --assess --type execute --verbose=4 "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "==> Signed + notarised: $APP_PATH"
