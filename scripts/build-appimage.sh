#!/usr/bin/env bash
# Pack a built Flutter Linux bundle as an AppImage.
# Usage: scripts/build-appimage.sh <bundle-dir> <arch> <output-file>
set -euo pipefail

BUNDLE_DIR="${1:?usage: build-appimage.sh <bundle-dir> <arch> <output-file>}"
ARCH="${2:?usage: build-appimage.sh <bundle-dir> <arch> <output-file>}"  # x86_64 or aarch64
OUT="${3:?usage: build-appimage.sh <bundle-dir> <arch> <output-file>}"

case "$ARCH" in
  x86_64)  TOOL_ARCH="x86_64" ;;
  aarch64) TOOL_ARCH="aarch64" ;;
  *) echo "build-appimage: unsupported arch: $ARCH" >&2; exit 1 ;;
esac

APPDIR="$(mktemp -d)/er.AppDir"
mkdir -p "$APPDIR"
cp -a "$BUNDLE_DIR/." "$APPDIR/"
# appimagetool wants a desktop file named after the binary
cp "$APPDIR/com.httpanimations.er.desktop" "$APPDIR/er.desktop"

cat > "$APPDIR/AppRun" <<'RUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/er" "$@"
RUN
chmod +x "$APPDIR/AppRun"

curl -fsSL --retry 3 -o /tmp/appimagetool \
  "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${TOOL_ARCH}.AppImage"
chmod +x /tmp/appimagetool
ARCH="$ARCH" /tmp/appimagetool --appimage-extract-and-run "$APPDIR" "$OUT"
echo "build-appimage: $OUT"
