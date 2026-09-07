#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d /tmp/vpnconfigurator-tests.XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT
# Give the helper regression executable its required main.swift filename without
# rewriting production source or compiling the daemon entry point.
python3 - "$ROOT_DIR" "$TEST_DIR" <<'PY'
import pathlib, sys
root, out = map(pathlib.Path, sys.argv[1:])
(out / 'main.swift').write_text((root / 'Tests/HelperRegressionTests.swift').read_text())
PY
swiftc -swift-version 6 \
  "$ROOT_DIR/VPNConfigurator/Shared/HelperXPCProtocol.swift" \
  "$ROOT_DIR/VPNConfigurator/Shared/OpenVPNConfiguration.swift" \
  "$ROOT_DIR/VPNConfigurator/Shared/EngineDiscovery.swift" \
  "$ROOT_DIR/VPNConfiguratorHelper/ExecutableTrust.swift" \
  "$ROOT_DIR/VPNConfiguratorHelper/ApprovedEngineStore.swift" \
  "$ROOT_DIR/VPNConfiguratorHelper/HelperInputValidator.swift" \
  "$ROOT_DIR/VPNConfiguratorHelper/SecureRuntimeFiles.swift" \
  "$ROOT_DIR/VPNConfiguratorHelper/ResolverManager.swift" \
  "$ROOT_DIR/VPNConfiguratorHelper/VPNSession.swift" \
  "$ROOT_DIR/VPNConfiguratorHelper/HelperListener.swift" \
  "$ROOT_DIR/VPNConfiguratorHelper/OrphanedArtifactCleanup.swift" \
  "$ROOT_DIR/VPNConfiguratorHelper/HelperService.swift" \
  "$TEST_DIR/main.swift" -o "$TEST_DIR/helper-tests"
"$TEST_DIR/helper-tests"
swiftc -swift-version 6 -parse-as-library \
  "$ROOT_DIR/VPNConfigurator/Models/VPNProfile.swift" \
  "$ROOT_DIR/VPNConfigurator/Models/VPNCredentials.swift" \
  "$ROOT_DIR/VPNConfigurator/Shared/HelperXPCProtocol.swift" \
  "$ROOT_DIR/VPNConfigurator/Shared/OpenVPNConfiguration.swift" \
  "$ROOT_DIR/VPNConfigurator/Shared/EngineDiscovery.swift" \
  "$ROOT_DIR/VPNConfigurator/Services/PrivilegedHelperManager.swift" \
  "$ROOT_DIR/VPNConfigurator/Services/VPNController.swift" \
  "$ROOT_DIR/VPNConfigurator/Services/ProfileStore.swift" \
  "$ROOT_DIR/VPNConfigurator/Services/ConfigurationImporter.swift" \
  "$ROOT_DIR/VPNConfigurator/Services/KeychainStore.swift" \
  "$ROOT_DIR/Tests/ControllerRegressionTests.swift" -o "$TEST_DIR/controller-tests"
"$TEST_DIR/controller-tests"
