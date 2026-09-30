#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Bifrost"
SCHEME="VPNConfigurator"
# Every published build needs a new increasing number. CI can supply its own.
RELEASE_BUILD="${BIFROST_BUILD_NUMBER:-$(date +%s)}"
if [[ ! "$RELEASE_BUILD" =~ ^[1-9][0-9]{0,17}$ ]]; then
  echo "error: BIFROST_BUILD_NUMBER must be a positive integer (at most 18 digits)" >&2
  exit 1
fi
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/DerivedData/UnsignedRelease"
PRODUCTS_DIR="$DERIVED_DATA/Build/Products/Release"
APP_BUNDLE="$PRODUCTS_DIR/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/dist"
STAGING_DIR="$DIST_DIR/dmg-root"
DMG_PATH="$DIST_DIR/$APP_NAME-unsigned.dmg"

rm -rf "$DERIVED_DATA" "$STAGING_DIR"
mkdir -p "$DIST_DIR" "$STAGING_DIR"

xcodebuild \
  -project "$ROOT_DIR/VPNConfigurator.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  CURRENT_PROJECT_VERSION="$RELEASE_BUILD" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  clean build

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "error: expected app bundle was not produced at $APP_BUNDLE" >&2
  exit 1
fi

HELPER_BINARY="$APP_BUNDLE/Contents/Resources/VPNConfiguratorHelper"

# Ad-hoc requirements change with each release. Give Service Management a
# distinct registration identity while retaining the stable XPC endpoint. The
# app's updater unregisters the previous service BEFORE swapping bundles.
python3 - "$APP_BUNDLE" "$RELEASE_BUILD" <<'PYPLIST'
import pathlib, plistlib, sys
app, build = pathlib.Path(sys.argv[1]), sys.argv[2]
info_path = app / 'Contents/Info.plist'
info = plistlib.loads(info_path.read_bytes())
label = 'com.klianos.VPNConfigurator.helper.unsigned.' + build
old = app / 'Contents/Library/LaunchDaemons/com.klianos.VPNConfigurator.helper.plist'
daemon = plistlib.loads(old.read_bytes())
daemon['Label'] = label
new = old.with_name(label + '.plist')
new.write_bytes(plistlib.dumps(daemon))
old.unlink()
info['BifrostDistribution'] = 'adhoc-v1'
info['BifrostHelperDaemonPlist'] = new.name
info['CFBundleVersion'] = build
info_path.write_bytes(plistlib.dumps(info))
PYPLIST

# Xcode signs a local build with com.apple.security.get-task-allow, which lets
# any process running as the same user attach to the app and drive its
# privileged XPC connection. Re-sign both binaries ad hoc, without entitlements,
# so the distributed image keeps the Hardened Runtime protections it advertises.
# The nested helper is signed first because signing the app re-seals it.
codesign --force --options runtime --sign - "$HELPER_BINARY"
codesign --force --options runtime --sign - "$APP_BUNDLE"

for BINARY in "$HELPER_BINARY" "$APP_BUNDLE"; do
  if codesign --display --entitlements - --xml "$BINARY" 2>/dev/null | grep -q "get-task-allow"; then
    echo "error: get-task-allow survived re-signing of $BINARY" >&2
    exit 1
  fi
done

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

ditto "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -ov \
  "$DMG_PATH"

codesign --force --sign - "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"
hdiutil verify "$DMG_PATH"

rm -rf "$STAGING_DIR"

echo "$DMG_PATH"
