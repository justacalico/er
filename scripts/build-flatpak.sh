#!/usr/bin/env bash
# Package a built Flutter Linux bundle as a flatpak and export it into an
# ostree repo that can be served over plain HTTP.
#
# Usage: scripts/build-flatpak.sh <bundle-dir> <repo-dir> [branch]
set -euo pipefail

BUNDLE_DIR="${1:?usage: build-flatpak.sh <bundle-dir> <repo-dir> [branch]}"
REPO_DIR="${2:?usage: build-flatpak.sh <bundle-dir> <repo-dir> [branch]}"
BRANCH="${3:-stable}"

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v flatpak-builder >/dev/null 2>&1; then
  echo "build-flatpak: flatpak-builder not found" >&2
  exit 1
fi
if [ ! -f "$BUNDLE_DIR/er" ]; then
  echo "build-flatpak: no er binary in $BUNDLE_DIR" >&2
  exit 1
fi

flatpak remote-add --user --if-not-exists flathub \
  https://flathub.org/repo/flathub.flatpakrepo

# flatpak-builder hardlinks between the state dir and the build dir, so both
# must live on the repo checkout's filesystem.
STAGING="$(mktemp -d "$BASE_DIR/.flatpak-staging.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
mkdir -p "$STAGING/bundle"
cp -a "$BUNDLE_DIR/." "$STAGING/bundle/"
cp "$BASE_DIR/linux/er.png" "$STAGING/bundle/er.png"
cp "$BASE_DIR/packaging/flatpak/com.httpanimations.er.yaml" "$STAGING/"
cp "$BASE_DIR/packaging/flatpak/com.httpanimations.er.metainfo.xml" "$STAGING/"
sed 's/^Icon=.*/Icon=com.httpanimations.er/' \
  "$BASE_DIR/packaging/com.httpanimations.er.desktop" \
  > "$STAGING/com.httpanimations.er.desktop"
cp "$BASE_DIR/packaging/flatpak/icon-512.png" "$STAGING/"
cp "$BASE_DIR/packaging/flatpak/icon-128.png" "$STAGING/"

flatpak-builder --user --install-deps-from=flathub \
  --default-branch="$BRANCH" --repo="$REPO_DIR" --force-clean \
  "$STAGING/build" "$STAGING/com.httpanimations.er.yaml"

flatpak build-update-repo --generate-static-deltas "$REPO_DIR"

echo "build-flatpak: repo at $REPO_DIR (branch $BRANCH)"
