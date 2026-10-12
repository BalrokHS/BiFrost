# Changelog

Notable changes to Bifrost, newest first. Releases are identified by their version (`v<major>.<minor>.<patch>` tags on [GitHub Releases](https://github.com/BalrokHS/BiFrost/releases)). The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Add entries under **Unreleased** as you work. `script/publish_release.sh` uses that section as the release notes and moves it under the new version.

## [Unreleased]

## 0.2.2 - 2026-10-12

### Changed
- Installing an update while VPN connections are active now asks to disconnect them first. While an update waits for connections to end, the card offers "Disconnect all and continue" instead of a greyed-out download button.

## 0.2.1 - 2026-10-12

### Added
- OpenFortiVPN profiles with Password + OTP now connect first and ask for the code only when the server asks for it, so a code emailed after the first attempt can be entered. A small sheet with a countdown takes the code; a notification tells you when Bifrost is in the background.
- Profile icons: choose an avatar of initials (the default), a symbol, or import your own picture in the profile editor.
- A grid view for profiles, next to the list, with contact-card style cards. The choice is remembered.
- Soft colour waves along the bottom of the dashboard while profiles are connected, one layer per connection in its accent colour.

### Changed
- Profile icons are larger and round, tinted with the profile's accent colour, with a dot on connected profiles.
- OpenConnect profiles with Password + OTP still ask for the code up front.

## 0.2.0 - 2026-10-12

### Added
- A guided "Get started" checklist on the empty dashboard: enable VPN connections, approve a VPN client, add your first profile. Steps tick off as they are done.
- Adding a profile or connecting now asks you to enable VPN connections first when the connection service is off.

### Changed
- Releases use the app version as the single source of truth. Tags (`v0.2.0`), release titles, the changelog and the in-app update text show the version instead of a timestamp build number; the disk image is now `Bifrost.dmg`.

### Removed
- "Choose downloaded app…" in Bifrost updates. Updates are downloaded and verified in the app.

### Upgrading from an earlier build
- The release tag and disk image names changed, so earlier builds cannot find this update from inside the app. Download `Bifrost.dmg` from the release once and replace Bifrost in Applications; later updates install in the app.

## Build 1791803312 - 2026-10-12

### Changed
- Flat, denser interface: one near-black canvas, hairline dividers and small radii replace the glass cards, ambient gradient backdrop, glowing buttons and pulsing status dots.
- The dashboard lists profiles as rows in a single bordered list, with server, status, uptime and actions on each row.
- Status shows as a small dot with a grey label. The profile accent colour tints a profile's icon only while it is connected.
- The full-colour Bifrost logo leads the dashboard header and signs the settings header.
- Settings, the profile editor, the menu bar popover and the credential prompt follow the same flat styling.

## Build 1790770852 - 2026-09-30

### Added
- GitHub Actions release workflow (`.github/workflows/release.yml`): tests, builds, signs and publishes a release from the Actions tab.

## Build 1790766101 - 2026-09-30

First published release.

### Added
- In-app updates from GitHub Releases: a daily or on-demand check, a signed download, and installation through the existing staged replace-and-rollback flow. Every image is verified against a pinned Ed25519 key before it is mounted.
- `script/release_signing.swift` (update signing key in the login Keychain) and `script/publish_release.sh`.
- Coordinated app updates: the helper leases an idle window so replacement waits for running VPN sessions.
- Split DNS through the SystemConfiguration dynamic store, applied only after a tunnel reports it is connected.
- Unsigned, ad-hoc-signed DMG packaging with the hardened runtime and no debugger entitlement.

### Changed
- Renamed the project from VPNConfigurator to Bifrost.
- Identifiers moved to `gr.klianos.bifrost.*` (bundle, helper, XPC service, Keychain service, log subsystems).
- Application Support data moved from `VPN Configurator` to `Bifrost`; existing profiles and managed OpenVPN files migrate on first launch.
- README rewritten; the security model moved to `docs/security.md`.

### Migration
- Installs from before the rename cannot update in place. Disconnect and unregister the service with the old app, then install this release. Saved Keychain passwords and engine approvals are not carried over. Details in `docs/unsigned-updates.md`.

## Before the first release

Development history, condensed.

- Native SwiftUI app with Liquid Glass styling: dashboard, menu bar controls, profile editor and settings.
- Multiple concurrent VPN session state machines with live connection states and interface discovery.
- OpenFortiVPN (including SAML), OpenVPN and OpenConnect support through a privileged helper reached over XPC.
- Engine discovery and approval by SHA-256 of the executable and its non-system libraries.
- Saved credentials are preserved across reconnects; one-time passwords are never persisted.
- Regression test suite and local build scripts.
