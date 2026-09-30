# Changelog

Notable changes to Bifrost, newest first. Releases are identified by their build number (`build-<N>` tags on [GitHub Releases](https://github.com/BalrokHS/BiFrost/releases)). The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Add entries under **Unreleased** as you work. `script/publish_release.sh` uses that section as the release notes and moves it under the new build.

## [Unreleased]

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
