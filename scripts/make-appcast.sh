#!/usr/bin/env bash
#
# Generate an EdDSA-signed Sparkle appcast for the DMG(s) in dist/.
#
# Inputs (env):
#   SPARKLE_ED_PRIVATE_KEY   Raw EdDSA private key (base64 single line)
#                            generated once via Sparkle's `generate_keys`.
#                            Public counterpart goes in project.yml SUPublicEDKey.
#
# Produces:
#   dist/appcast/appcast.xml
#   dist/appcast/Mural-<version>.dmg  (copy of each DMG)
#
# The generate_appcast binary lives inside Sparkle's SPM checkout. After at
# least one xcodebuild against the Mural scheme, SPM caches Sparkle under
# DerivedData and we can find the binary by `find`.

set -euo pipefail

SRC_DIR="${1:-dist}"
OUT_DIR="dist/appcast"

if [ -z "${SPARKLE_ED_PRIVATE_KEY:-}" ]; then
  echo "fatal: \$SPARKLE_ED_PRIVATE_KEY is required (EdDSA private key, base64)" >&2
  echo "       generate once via Sparkle's \`generate_keys\` and keep secret." >&2
  exit 64
fi

GEN_APPCAST="$(find "$HOME/Library/Developer/Xcode/DerivedData" \
  -type f -name generate_appcast \
  2>/dev/null | head -1 || true)"
if [ -z "$GEN_APPCAST" ]; then
  echo "fatal: generate_appcast not found in DerivedData." >&2
  echo "       Build the Mural scheme at least once so SPM materialises Sparkle." >&2
  exit 69
fi

mkdir -p "$OUT_DIR"

# Copy every DMG in the source dir into the staging dir; generate_appcast
# wants all release artefacts in one directory.
shopt -s nullglob
for dmg in "$SRC_DIR"/*.dmg; do
  cp "$dmg" "$OUT_DIR/$(basename "$dmg")"
done

# generate_appcast --ed-key-file expects a path to a file containing the
# base64 key on a single line. Materialise the env var into a tmp file we
# delete on exit.
KEY_FILE="$(mktemp)"
trap 'rm -f "$KEY_FILE"' EXIT
printf '%s' "$SPARKLE_ED_PRIVATE_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

echo "==> Generating appcast in $OUT_DIR"
"$GEN_APPCAST" --ed-key-file "$KEY_FILE" "$OUT_DIR"

echo "==> Validating XML"
xmllint --noout "$OUT_DIR/appcast.xml"

echo "==> Done. Publish $OUT_DIR/ to your GH Pages branch (or wherever SUFeedURL points)."
ls -la "$OUT_DIR"
