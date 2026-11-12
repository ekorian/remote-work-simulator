#!/usr/bin/env bash
# Download the pinned Godot build into .tools/ (git-ignored) and verify it.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="4.7.2"
ZIP="Godot_v${VERSION}-stable_linux.x86_64.zip"
SHA512="9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65"
DEST=".tools/godot-${VERSION}"
mkdir -p "$DEST"
if [ ! -x "$DEST/Godot_v${VERSION}-stable_linux.x86_64" ]; then
  curl -fsSL -o "$DEST/$ZIP" "https://github.com/godotengine/godot/releases/download/${VERSION}-stable/$ZIP"
  echo "${SHA512}  $DEST/$ZIP" | sha512sum -c -
  unzip -o -q "$DEST/$ZIP" -d "$DEST"
  rm -f "$DEST/$ZIP"
  chmod +x "$DEST/Godot_v${VERSION}-stable_linux.x86_64"
fi
ln -sf "godot-${VERSION}/Godot_v${VERSION}-stable_linux.x86_64" .tools/godot
.tools/godot --version
