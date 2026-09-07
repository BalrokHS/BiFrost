#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Bifrost"
BUNDLE_ID="com.klianos.VPNConfigurator"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/DerivedData"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/Bifrost.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/Bifrost"

if [[ "$MODE" != "--build" && "$MODE" != "build" ]]; then
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
fi

xcodebuild \
  -project "$ROOT_DIR/VPNConfigurator.xcodeproj" \
  -scheme VPNConfigurator \
  -configuration Debug \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  build

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  --build|build)
    ;;
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--build|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
