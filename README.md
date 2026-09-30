<p align="center"><img src="assets/logo.png" alt="Bifrost" width="480"></p>

<p align="center">
  A native macOS VPN manager for OpenFortiVPN, OpenVPN and OpenConnect.<br>
  Multiple concurrent connections, per-profile split DNS, and a narrowly scoped privileged helper.
</p>

<p align="center">
  <a href="https://github.com/BalrokHS/BiFrost/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/BalrokHS/BiFrost?display_name=tag&style=flat-square"></a>
  <img alt="macOS 26+" src="https://img.shields.io/badge/macOS-26%2B-blue?style=flat-square">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-orange?style=flat-square">
</p>

## Features

- **Three engines, one app.** Manage OpenFortiVPN (including SAML browser sign-in), OpenVPN and OpenConnect profiles from a single dashboard.
- **Concurrent sessions.** Run several VPNs at once, each with its own live state, tunnel interface and log.
- **Native interface.** SwiftUI with Liquid Glass, plus a menu bar extra for quick connect and disconnect.
- **Split DNS.** Profile-scoped resolver rules through the SystemConfiguration dynamic store. VPN-advertised DNS is ignored, and the rules are removed if the helper dies.
- **Careful with secrets.** Passwords live in the Keychain, one-time codes are never stored, and nothing sensitive appears in process arguments.
- **Pinned engines.** The helper only runs VPN clients whose exact bytes you approved. See [Security](docs/security.md).
- **Importing.** Bring in OpenVPN and OpenFortiVPN configurations. TLS material is stored in a protected app-managed profile with credentials stripped.
- **Self-updating.** Checks GitHub Releases and verifies each download against a pinned signature before installing. See [Updates](docs/unsigned-updates.md).

## Install

Requires macOS 26 or later. Download `Bifrost-unsigned.dmg` from the [latest release](https://github.com/BalrokHS/BiFrost/releases/latest), then drag **Bifrost** into **Applications**.

Bifrost is ad-hoc signed and not notarized, so macOS blocks the first launch:

1. Open Bifrost. macOS warns that it cannot verify the app; dismiss the warning.
2. Open **System Settings → Privacy & Security**, scroll down and click **Open Anyway**, then confirm with your password.

Or, from Terminal: `xattr -dr com.apple.quarantine /Applications/Bifrost.app`.

Then enable the connection service in Bifrost's settings and approve it under **System Settings → General → Login Items & Extensions**. Later updates are installed from inside the app and do not repeat the Gatekeeper step.

### VPN engines

Bifrost manages the VPN clients; it does not bundle them. Install the ones you need:

```sh
brew install openfortivpn openvpn openconnect vpnc-script
```

**Settings → VPN engines** lists what was found and each engine's version. An engine must be approved once (administrator prompt) before the helper will run it. After a Homebrew upgrade it asks for approval again, by design. See [engine approval](docs/security.md#engine-approval).

## Build from source

1. Open `Bifrost.xcodeproj` in Xcode 26.2 or newer.
2. Select the `Bifrost` scheme and **My Mac**, then run (`⌘R`).

From the command line:

```sh
./script/build_and_run.sh            # build and launch
./script/build_and_run.sh --build    # build only
./script/test.sh                     # regression tests
```

The tests use a harmless child process and a mock helper. They do not register a daemon, connect to gateways, or change routes and DNS.

## Releasing

```sh
./script/publish_release.sh
```

Builds the universal ad-hoc-signed DMG, signs it with the update key in your Keychain, creates the GitHub release with notes from [CHANGELOG.md](CHANGELOG.md), and stamps the changelog. The same script runs in CI: **Actions → Release → Run workflow**. Key setup and the release checklist are in [Updates](docs/unsigned-updates.md#publishing-a-release).

## Project layout

| Path | Contents |
| --- | --- |
| `Bifrost/` | The app: views, models, services and the design system |
| `BifrostHelper/` | The privileged helper daemon |
| `Bifrost/Shared/` | Code compiled into both targets (XPC protocol, OpenVPN parsing, engine discovery) |
| `Tests/` | Regression tests, run by `script/test.sh` |
| `script/` | Build, packaging, signing and release scripts |
| `docs/` | [Security model](docs/security.md), [updates](docs/unsigned-updates.md), [review fixes](docs/review-fixes.md) |

## Roadmap

The native split-DNS layer is the foundation for a later embedded DNS proxy. The immediate focus is exercising all three providers against real gateways and refining provider-specific authentication and recovery.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
