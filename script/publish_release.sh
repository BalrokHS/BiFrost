#!/usr/bin/env bash
# Builds, signs and publishes a Bifrost release to GitHub Releases.
# The release is named after MARKETING_VERSION in the Xcode project (tag v0.2.0).
# Usage: ./script/publish_release.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="BalrokHS/BiFrost"
read -r VERSION BUILD < <("$ROOT_DIR/script/release_version.sh")
TAG="v$VERSION"
DMG="$ROOT_DIR/dist/Bifrost.dmg"

if [[ "$(git -C "$ROOT_DIR" status --porcelain)" != "" ]]; then
  echo "error: commit or stash your changes so the release matches a commit" >&2
  exit 1
fi
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo "error: release $TAG already exists. Raise MARKETING_VERSION; never reuse a version for different bytes." >&2
  exit 1
fi

CHANGELOG="$ROOT_DIR/CHANGELOG.md"
NOTES="$(awk '/^## \[Unreleased\]/{found=1; next} /^## /{if(found) exit} found' "$CHANGELOG")"
if [[ -z "${NOTES//[[:space:]]/}" ]]; then
  echo "error: CHANGELOG.md has nothing under [Unreleased]. Describe this release first." >&2
  exit 1
fi

"$ROOT_DIR/script/package_unsigned_dmg.sh"
swift "$ROOT_DIR/script/release_signing.swift" sign "$DMG"

gh release create "$TAG" "$DMG" "$DMG.sig" \
  --repo "$REPO" \
  --target "$(git -C "$ROOT_DIR" rev-parse HEAD)" \
  --title "Bifrost $VERSION" \
  --notes "$NOTES"

# Move the released notes under the new version and commit the changelog.
python3 - "$CHANGELOG" "$VERSION" "$(date +%F)" <<'PY'
import sys
path, version, day = sys.argv[1:]
text = open(path).read()
text = text.replace("## [Unreleased]\n", f"## [Unreleased]\n\n## {version} - {day}\n", 1)
open(path, "w").write(text)
PY
git -C "$ROOT_DIR" add CHANGELOG.md
git -C "$ROOT_DIR" commit -q -m "Release $VERSION"
git -C "$ROOT_DIR" pull -q --rebase
git -C "$ROOT_DIR" push -q origin HEAD
echo "Published $TAG"
