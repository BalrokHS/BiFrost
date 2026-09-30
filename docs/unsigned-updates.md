# Unsigned Bifrost updates

Bifrost ships ad-hoc-signed apps, without Developer ID or notarization. This is the supported release model, not a development fallback. Ad-hoc code identities change with the code; a shared bundle identifier does not establish publisher trust.

## User flow

1. Download and mount a Bifrost DMG from a source you trust.
2. In the **installed** Bifrost app, open Settings → General → Bifrost updates and choose the app inside the mounted image.
3. Bifrost stages a complete copy on the installation volume and validates its signatures, hardened runtime, identifiers, service definition and increasing build number. It rejects development entitlements. These checks establish integrity and packaging consistency, not publisher authenticity.
4. Choose **Install and reopen**. Existing VPN sessions continue. New starts are temporarily refused while the update waits for all sessions and pending launches to finish. Cancel releases that restriction.
5. The helper confirms it is idle, the app unregisters the old service, and the app replaces whole bundles without overwriting running signed binaries. The previous app remains in a hidden `.Bifrost-update-…/Previous.app` directory next to the installation for recovery.
6. The new app opens and registers its own helper if the service was previously enabled. macOS may require renewed background-item approval. Health is checked after registration and on return from System Settings. A failed replacement or failed app launch attempts rollback; a helper approval failure leaves the new app open for guided setup.

The installation folder must be writable. This flow does not acquire administrator rights to install the app. It never disconnects sessions automatically and never interprets an unresponsive helper as idle. Do not drag a replacement over a running app when using this flow.

## Lifecycle boundaries

- `HelperHandshake` reports protocol version and capabilities. Unsupported protocols fail closed; missing realm support blocks realm use, not every VPN connection. Product-version equality is not required.
- `prepareForUpdate` is a renewable 15-second lease, handled on the session queue. Pending launches and unfinished sessions both prevent replacement. It blocks new launches but leaves stop/status available. If the app disappears, the lease expires and new connections become possible again.
- Packaged releases use `gr.klianos.bifrost.helper.unsigned.<build>` as the launch daemon label. The XPC endpoint remains stable. The prior registration must be removed before the next release registers, preventing two daemons from competing for that endpoint and avoiding reuse of a prior ad-hoc build's registration identity.
- Unsigned helpers authorize only the exact code identity of their installed host app. A development-signed client has no special access to an unsigned helper.
- App replacement, relaunch and rollback run without a root updater. The helper never accepts arbitrary filesystem destinations or downloaded code.
- Updates are local and explicitly selected. There is no automatic download feed. A future downloader must verify release signatures from a pinned update key before installation; an app identifier, HTTPS, or an ad-hoc code signature alone is insufficient.

## Migration from the VPNConfigurator identifiers

Bifrost now uses `gr.klianos.bifrost` (helper `gr.klianos.bifrost.helper`). Builds with the old `com.klianos.VPNConfigurator` identifiers cannot update in place, because the updater requires the same bundle identifier. Before installing, use the **old** app to disconnect and unregister its service, then remove it. On first launch, profiles and managed OpenVPN files move automatically from `~/Library/Application Support/VPN Configurator` to `Bifrost`. Saved Keychain passwords and engine approvals (`/Library/Application Support`) are not carried over; re-enter passwords and re-approve engines.

## First migration from 0.6.x

Those apps have no coordinated app-update flow. Disconnect all VPNs and unregister the service **using that old app before replacing it**, then install the new unsigned release and enable VPN connections. The new client recognizes the shipped 0.6.2/0.6.3 handshake for limited compatibility, but never sends those helpers the new preparation method. That small migration adapter is intentionally retained.

If an old app has already been overwritten and its service cannot be reached, restore the old app from backup to complete this one-time migration. Do not reset all macOS background items or weaken code-signing checks to repair Bifrost.

## Release and verification

`BIFROST_BUILD_NUMBER=123 ./script/package_unsigned_dmg.sh` produces `dist/Bifrost-unsigned.dmg`. Choose a build number higher than every previously published build; do not reuse a published build number for different bytes. Without an override, the Unix timestamp is used. The app's release metadata and service label are set before the app is sealed. App and helper have ad-hoc signatures with hardened runtime and no debugger entitlement. Xcode builds also use ad-hoc signing by default, but distributable updates must go through packaging.

Run `./script/test.sh` for protocol, preparation, pending-launch, cancellation/lease-expiry, bundle replacement and rollback regressions. Set `BIFROST_TEST_RELEASE=/path/to/Bifrost.app` to additionally validate an actual packaged release and reject a tampered copy. Live upgrade QA must install one packaged unsigned build, enable and health-check its service, then use its update UI to install a second higher-numbered packaged build. Verify the old daemon label is absent and the new helper responds. Test active-session waiting with a disposable VPN separately; the automated helper tests use harmless processes and simulated sessions, not real gateways.
