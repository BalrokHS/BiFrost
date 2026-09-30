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

CHANGELOG="$ROOT_DIR/CHANGELOG.md"
NOTES="$(awk '/^## \[Unreleased\]/{found=1; next} /^## /{if(found) exit} found' "$CHANGELOG")"
if [[ -z "${NOTES//[[:space:]]/}" ]]; then
  echo "error: CHANGELOG.md has nothing under [Unreleased]. Describe this release first." >&2
  exit 1
fi

BIFROST_BUILD_NUMBER="$BUILD" "$ROOT_DIR/script/package_unsigned_dmg.sh"
swift "$ROOT_DIR/script/release_signing.swift" sign "$DMG"

gh release create "$TAG" "$DMG" "$DMG.sig" \
  --repo "$REPO" \
  --target "$(git -C "$ROOT_DIR" rev-parse HEAD)" \
  --title "Bifrost build $BUILD" \
  --notes "$NOTES"

# Move the released notes under the new build and commit the changelog.
python3 - "$CHANGELOG" "$BUILD" "$(date +%F)" <<'PY'
import sys
path, build, day = sys.argv[1:]
text = open(path).read()
text = text.replace("## [Unreleased]\n", f"## [Unreleased]\n\n## Build {build} - {day}\n", 1)
open(path, "w").write(text)
PY
git -C "$ROOT_DIR" add CHANGELOG.md
git -C "$ROOT_DIR" commit -q -m "Release build $BUILD"
git -C "$ROOT_DIR" push -q origin HEAD
echo "Published $TAG"
