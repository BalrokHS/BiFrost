#!/usr/bin/env bash
# Prints "<version> <build>" for the current project, e.g. "0.2.0 2000".
# MARKETING_VERSION in the Xcode project is the single source of truth. The
# integer build orders releases and names the helper registration; it is
# major * 1000000 + minor * 1000 + patch, mirroring UpdateFeed.build(forVersion:).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(xcodebuild -project "$ROOT_DIR/Bifrost.xcodeproj" -scheme Bifrost \
  -configuration Release -showBuildSettings 2>/dev/null \
  | awk '$1 == "MARKETING_VERSION" { print $3; exit }')"

if [[ ! "$VERSION" =~ ^(0|[1-9][0-9]{0,2})\.(0|[1-9][0-9]{0,2})\.(0|[1-9][0-9]{0,2})$ ]]; then
  echo "error: MARKETING_VERSION '$VERSION' must be major.minor.patch with each part below 1000" >&2
  exit 1
fi

IFS=. read -r MAJOR MINOR PATCH <<<"$VERSION"
BUILD=$(( MAJOR * 1000000 + MINOR * 1000 + PATCH ))
if (( BUILD < 1 )); then
  echo "error: version $VERSION must be greater than 0.0.0" >&2
  exit 1
fi

echo "$VERSION $BUILD"
