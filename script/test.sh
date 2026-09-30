#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d /tmp/bifrost-tests.XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT
# Give the helper regression executable its required main.swift filename without
# rewriting production source or compiling the daemon entry point.
python3 - "$ROOT_DIR" "$TEST_DIR" <<'PY'
import pathlib, sys
root, out = map(pathlib.Path, sys.argv[1:])
(out / 'main.swift').write_text((root / 'Tests/HelperRegressionTests.swift').read_text())
PY
swiftc -swift-version 6 \
  "$ROOT_DIR/Bifrost/Shared/HelperXPCProtocol.swift" \
  "$ROOT_DIR/Bifrost/Shared/OpenVPNConfiguration.swift" \
  "$ROOT_DIR/Bifrost/Shared/EngineDiscovery.swift" \
  "$ROOT_DIR/BifrostHelper/ExecutableTrust.swift" \
  "$ROOT_DIR/BifrostHelper/ApprovedEngineStore.swift" \
  "$ROOT_DIR/BifrostHelper/HelperInputValidator.swift" \
  "$ROOT_DIR/BifrostHelper/SecureRuntimeFiles.swift" \
  "$ROOT_DIR/BifrostHelper/ResolverManager.swift" \
  "$ROOT_DIR/BifrostHelper/VPNSession.swift" \
  "$ROOT_DIR/BifrostHelper/HelperListener.swift" \
  "$ROOT_DIR/BifrostHelper/OrphanedArtifactCleanup.swift" \
  "$ROOT_DIR/BifrostHelper/HelperService.swift" \
  "$TEST_DIR/main.swift" -o "$TEST_DIR/helper-tests"
"$TEST_DIR/helper-tests"
swiftc -swift-version 6 -parse-as-library \
  "$ROOT_DIR/Bifrost/Models/VPNProfile.swift" \
  "$ROOT_DIR/Bifrost/Models/VPNCredentials.swift" \
  "$ROOT_DIR/Bifrost/Shared/HelperXPCProtocol.swift" \
  "$ROOT_DIR/Bifrost/Shared/OpenVPNConfiguration.swift" \
  "$ROOT_DIR/Bifrost/Shared/EngineDiscovery.swift" \
  "$ROOT_DIR/Bifrost/Services/PrivilegedHelperManager.swift" \
  "$ROOT_DIR/Bifrost/Services/AppUpdateInstaller.swift" \
  "$ROOT_DIR/Bifrost/Services/UpdateFeed.swift" \
  "$ROOT_DIR/Bifrost/Services/VPNController.swift" \
  "$ROOT_DIR/Bifrost/Services/ProfileStore.swift" \
  "$ROOT_DIR/Bifrost/Services/ConfigurationImporter.swift" \
  "$ROOT_DIR/Bifrost/Services/KeychainStore.swift" \
  "$ROOT_DIR/Tests/ControllerRegressionTests.swift" -o "$TEST_DIR/controller-tests"
"$TEST_DIR/controller-tests"
