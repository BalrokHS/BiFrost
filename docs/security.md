# Security model

Bifrost does not implement any VPN protocol. It drives `openfortivpn`, `openvpn` and `openconnect` through a small privileged helper. This page explains what the helper trusts and why.

## Privileged helper

The bundled helper is registered with `SMAppService` and reached over an XPC Mach service. It exposes a health check and deliberately narrow, provider-specific APIs. It validates typed profile fields and imported OpenVPN directives, creates root-only ephemeral runtime files where required, and removes them when each process exits or when the helper next starts after an interrupted shutdown.

- Passwords and one-time codes never appear in process arguments. They go through a root-only temporary config, a root-only runtime file, or protected standard input, depending on the engine.
- OTP values are never persisted. Reusable passwords live in the macOS Keychain.
- The helper validates the calling app's signing requirement before accepting XPC requests.
- The helper never accepts arbitrary filesystem destinations or downloaded code.

## Engine approval

Finding an engine is not the same as trusting it. Package managers install into a prefix your own user account can write to, so anything running as you could replace `openvpn`, and the helper would then execute the replacement as root.

Approving an engine records the SHA-256 of the executable and of every non-system library it loads (4–13 files per engine in a typical Homebrew install) into a root-owned file, `/Library/Application Support/Bifrost/approved-engines.json`. The helper re-measures all of them before every connection and refuses to launch anything that no longer matches. Approval prompts for administrator credentials once per engine; connections afterwards are silent.

A Homebrew upgrade replaces those files, so the engine reports **Changed since approval** and asks you to approve it again. That is the intended cost of the design: an upgrade you performed looks exactly like a substitution you did not, and only you can tell them apart.

**What this does and does not protect against.** Pinning detects an engine or library that was replaced between connections, such as a backdoored build planted and waiting for you to connect. It does not stop an attacker who already runs code as your user and races the interval between measurement and `exec`; macOS offers no `fexecve`, so closing that window would require executing a copy you cannot write to. Engines are launched with a fixed environment (no `DYLD_*`, `OPENSSL_CONF=/dev/null`, `SSL_CERT_FILE=/etc/ssl/cert.pem`) so their TLS libraries do not take configuration or trust roots from the package prefix. A library such as p11-kit can still read module configuration from that prefix, which is inside the trust boundary you accept when you approve an engine from it.

## Ad-hoc signing

Bifrost ships ad-hoc-signed, without a Developer ID or notarization. An ad-hoc build has no team identifier, so the helper cannot pin its client to one. It pins clients to the designated requirement of the app bundle it was launched from, which for ad-hoc code is the code hash of every architecture slice. A tampered or unrelated copy claiming the same bundle identifier is refused. launchd already resolves the daemon's `BundleProgram` out of that same bundle, so pinning to it concedes no privilege the install location did not already carry.

The packaging script re-signs the app and helper with the hardened runtime and without `com.apple.security.get-task-allow`, which Xcode adds to local builds and which would otherwise let any process of the same user attach to the app and drive its privileged connection.

## Updates

Downloaded updates are authenticated with a detached Ed25519 signature against a key pinned in the app, before the disk image is even mounted. See [unsigned updates](unsigned-updates.md) for the full lifecycle.

## DNS and routes

Bifrost ignores VPN-advertised DNS and installs profile-configured split-DNS rules through the macOS SystemConfiguration dynamic store (`SupplementalMatchDomains`, removed automatically if the helper dies), only after a tunnel reports that it is connected. Routes remain controlled by the provider and gateway.

## OpenVPN import

Import supports an explicit subset of directives and embedded TLS material. Profiles that reference external certificate or key files are rejected with instructions to export an embedded profile. Inline or file-referenced username and password directives are removed on import. See [review fixes](review-fixes.md) for the code-review changes this design followed.
