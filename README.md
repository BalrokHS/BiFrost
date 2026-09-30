# Bifrost

A personal macOS VPN manager built with SwiftUI and the native Liquid Glass APIs in macOS 26.

## Milestone 0.6

The current app includes:

- A dashboard for imported and manually created VPN profiles.
- Native Liquid Glass connection cards and buttons.
- Multiple concurrent VPN session state machines.
- Menu bar controls.
- Live connection states and interface discovery.
- Profile and settings screens.
- Create, edit, and delete VPN profiles.
- Import OpenVPN and OpenFortiVPN configuration metadata.
- Store imported OpenVPN TLS material in a protected app-managed profile while removing inline or file-referenced username/password directives.
- Persist non-secret profile metadata in Application Support.
- Save reusable passwords in macOS Keychain.
- Prompt for one-time passwords without persisting them.
- Build provider-specific, secret-free launch plans for all three VPN clients.
- Bundle an ad-hoc-signed connection service with guided `SMAppService` setup and coordinated app updates.
- Verify helper availability over a privileged XPC Mach service.
- Start and stop profile-based OpenFortiVPN sessions, including SAML browser handoff, through the privileged helper without external FortiVPN configuration files.
- Start and stop imported OpenVPN profiles while supplying app-managed credentials through a root-only runtime file.
- Start and stop OpenConnect profiles while supplying credentials over protected standard input.
- Validate the calling app's signing requirement before accepting privileged XPC requests.
- Discover the VPN clients you installed yourself, report their versions, and run them in place once an administrator has approved their exact bytes.
- Stream bounded process output and detect PPP, utun, and tun interfaces and provider-specific tunnel-ready states.
- Put passwords and OTPs in a root-only temporary config instead of process arguments.
- Ignore VPN-advertised DNS and install profile-configured split-DNS rules through the macOS SystemConfiguration dynamic store (`SupplementalMatchDomains`, removed automatically if the helper dies) only after each tunnel reports that it is connected.

It does **not** persist OTP values. The embedded DNS proxy remains a future milestone; current DNS handling uses profile-scoped native macOS resolver rules.

The bundled privileged helper exposes a health check and deliberately narrow provider-specific APIs. It validates typed profile fields and imported OpenVPN directives, creates root-only ephemeral runtime files where required, and removes them when each process exits or when the helper next starts after an interrupted shutdown.

## VPN engines

The app does not implement any VPN protocol. It manages `openfortivpn`, `openvpn` and `openconnect`, which you install yourself:

```sh
brew install openfortivpn openvpn openconnect vpnc-script
```

Settings › **VPN engines** lists what it found, each engine's version, and whether the privileged helper is willing to run it. Discovery searches `/opt/homebrew/{sbin,bin}`, `/usr/local/{sbin,bin}`, `/opt/local/{sbin,bin}`, `/usr/sbin` and `/usr/bin`, in that order.

### Approval

Finding an engine is not the same as trusting it. Package managers install into a prefix your own user account can write to, so anything running as you could replace `openvpn` — and the helper would then execute the replacement as root.

Approving an engine records the SHA-256 of the executable and of every non-system library it loads (4–13 files per engine in a typical Homebrew install) into a root-owned file at the legacy-compatible path `/Library/Application Support/VPN Configurator/approved-engines.json`. The helper re-measures all of them before every connection and refuses to launch anything that no longer matches. Approval prompts for administrator credentials once per engine; connections afterwards are silent.

A Homebrew upgrade replaces those files, so the engine will report **Changed since approval** and ask you to approve it again. That is the intended cost of the design: an upgrade you performed looks exactly like a substitution you did not, and only you can tell them apart.

**What this does and does not protect against.** Pinning detects an engine or library that was replaced between connections — a backdoored build planted and waiting for you to connect. It does not stop an attacker who already runs code as your user and races the interval between measurement and `exec`; macOS offers no `fexecve`, so closing that window would require executing a copy you cannot write to. Engines are also launched with a fixed environment (no `DYLD_*`, `OPENSSL_CONF=/dev/null`, `SSL_CERT_FILE=/etc/ssl/cert.pem`) so their TLS libraries do not take configuration or trust roots from the package prefix — but a library such as p11-kit can still read module configuration from that prefix, which is inside the trust boundary you accept when you approve an engine from it.

Build and launch the app with `./script/build_and_run.sh`. The connection service reports **Helper 0.7.0**. Its protocol and capabilities determine compatibility independently of its display version. Health checks never restart a working service just because versions differ.

Unsigned distribution is the permanent release target. See [unsigned updates](docs/unsigned-updates.md) for the lifecycle, migration, and verification workflow.

OpenVPN import supports an explicit subset of directives and embedded TLS material. Profiles referencing external certificate/key files are rejected at import with instructions to export an embedded profile. Routes remain controlled by the provider and gateway.

See [the implementation notes](docs/review-fixes.md) for the code-review fixes this design followed.

## Run

1. Open `VPNConfigurator.xcodeproj` in Xcode 26.2 or newer.
2. Select the `VPNConfigurator` scheme and **My Mac**.
3. Press **Run** (`⌘R`).

Build without stopping or launching the GUI: `./script/build_and_run.sh --build`.

Create a universal, ad-hoc-signed Release DMG without an Apple Developer
membership: `./script/package_unsigned_dmg.sh`. Set `BIFROST_BUILD_NUMBER` in CI to an increasing positive integer; otherwise packaging uses the current Unix timestamp. The image is written to
`dist/Bifrost-unsigned.dmg`. Because it has no Developer ID signature or
notarization ticket, recipients must explicitly allow the app through macOS
Gatekeeper.

An ad-hoc build has no team identifier, so the helper cannot pin its client to
one. It pins clients to the
designated requirement of the app bundle it was launched from, which for ad-hoc
code is the code hash of every architecture slice. A tampered or unrelated copy
claiming the same bundle identifier is refused. launchd already resolves the
daemon's `BundleProgram` out of that same bundle, so pinning to it concedes no
privilege the install location did not already carry. The packaging script also
re-signs the app and helper without `com.apple.security.get-task-allow`, which
Xcode adds to local builds and which would otherwise let any process of the same
user attach to the app and drive its privileged connection.

Run regression tests: `./script/test.sh`. Tests use a harmless child process and a mock helper; they do not register a daemon, connect to gateways, or change routes/DNS. Import tests create and remove their own managed configuration file without changing saved profiles or Keychain entries.

## Current architecture direction

The native split-DNS layer remains the foundation for a later embedded DNS proxy. The immediate focus is exercising all three providers against real gateways and refining provider-specific authentication and recovery behavior.
