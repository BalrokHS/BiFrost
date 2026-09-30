#!/usr/bin/env bash
# Builds, signs and publishes a Bifrost release to GitHub Releases.
# Usage: BIFROST_BUILD_NUMBER=123 ./script/publish_release.sh   (defaults to a Unix timestamp)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="BalrokHS/BiFrost"
BUILD="${BIFROST_BUILD_NUMBER:-$(date +%s)}"
TAG="build-$BUILD"
DMG="$ROOT_DIR/dist/Bifrost-unsigned.dmg"

if [[ "$(git -C "$ROOT_DIR" status --porcelain)" != "" ]]; then
  echo "error: commit or stash your changes so the release matches a commit" >&2
  exit 1
fi
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo "error: release $TAG already exists. Never reuse a build number for different bytes." >&2
  exit 1
fi

BIFROST_BUILD_NUMBER="$BUILD" "$ROOT_DIR/script/package_unsigned_dmg.sh"
swift "$ROOT_DIR/script/release_signing.swift" sign "$DMG"

gh release create "$TAG" "$DMG" "$DMG.sig" \
  --repo "$REPO" \
  --target "$(git -C "$ROOT_DIR" rev-parse HEAD)" \
  --title "Bifrost build $BUILD" \
  --notes "Bifrost build $BUILD. Installed copies verify the signature before installing."
echo "Published $TAG"
