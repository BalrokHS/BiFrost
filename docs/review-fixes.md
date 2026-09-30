# Code-review fixes

This pass addresses the seven review findings.

The executable-trust finding was first fixed by requiring root-owned engine paths, which blocked every normal Homebrew installation, and then by copying engines into administrator-approved snapshots. Both are gone. Engines now stay where their package manager installed them and are pinned by the SHA-256 of the executable and its full library graph, re-measured before every launch. See the VPN engines section of the [README](../README.md) for the trust model and its limits.

## Configuration boundary

`Bifrost/Shared/OpenVPNConfiguration.swift` is compiled into both targets. It tokenizes the supported quoting/escaping syntax, normalizes the optional `--` prefix, checks an allowlist and argument counts, and renders canonical directives. Unknown options, unsupported inline blocks, device paths, malformed blocks and external TLS file references fail closed. Imported inline and file-referenced authentication directives are removed; credentials continue to come from the app.

The importer validates before creating a managed file, so unsupported external certificate/key references now fail during import. It does not automatically read or embed external TLS files. Existing managed files are revalidated by the helper at connection time. Expanding the supported OpenVPN subset requires an explicit review of each option's file, process, and credential effects.

OpenVPN accepts the `--` prefix in configuration files and supports quoted arguments; this is why filtering raw first tokens was insufficient. See the [OpenVPN 2.6 manual](https://openvpn.net/community-docs/community-articles/openvpn-2-6-manual.html).

## Executable trust

`BifrostHelper/ExecutableTrust.swift` checks every path component and symlink target for root ownership and non-root write access. Extended ACLs are conservatively rejected. It reads the Mach-O load commands to walk linked libraries recursively without executing a candidate or requiring Xcode on the recipient's Mac. System library references are accepted from Apple's system locations; non-system libraries must pass the same ownership checks. Every artifact in the installed snapshot is checked against the administrator-approved manifest, including scripts, sandbox policy and the CA bundle. Snapshot libraries refer only to that installation or system libraries. The old developer-machine-specific hardcoded hashes have been replaced by the explicit installation boundary.

Only thin, little-endian 64-bit Mach-O images with absolute library references are currently supported. The clean child environment uses a system-only PATH, a copied CA bundle, and disabled external OpenSSL configuration/module discovery. A macOS sandbox policy blocks runtime reads and execution from Homebrew and user-writable locations; this also isolates p11-kit configuration paths compiled into the external libraries. See the linked installation design for limitations.

The ACL inspection distinguishes a missing ACL property from failure to inspect the file, using macOS `lstatx_np` and `filesec_get_property`. Normal Homebrew paths still fail the root-execution policy, intentionally. The installer leaves Homebrew untouched and activates a separate protected copy.

## Session ownership and recovery

- A rejected OpenVPN/OpenConnect start no longer erases an existing session. Launch failure removes only the session created by that launch. A replacement cannot start until the old session has finished cleanup.
- `didFinish` and `stopRequested` guard log-driven transitions. Historical SAML messages cannot override connected, disconnecting, or finished states; a known authentication failure prevents a success marker from restoring connected state.
- `VPNController` reconciles saved profiles with helper status on startup and when the helper becomes enabled. It resumes polling surviving processes. Status failures produce a degraded/unknown state, not proof of disconnection, and cannot enable deletion of a potentially running tunnel.
- Each status request has an identity. Responses superseded by a newer request or a connect/disconnect operation are ignored. Disconnect during an in-flight launch is delivered after the start succeeds.
- XPC operations time out after 20 seconds and discard late/duplicate completions. A timeout does not prove the underlying operation was canceled; the controller queries status after a failed start/stop reply.
- Launchd owns the helper's process group, so an interrupted helper cannot intentionally abandon its VPN children. On startup, the helper removes only root runtime files with its two-UUID naming format and resolver files carrying a valid Bifrost profile marker.
- Engine measurement and approval-record work run on a dedicated serial trust queue. The session queue remains available for stop and status requests while files are being hashed.

`VPNHelperClient` is a main-actor protocol implemented by the real XPC manager and by a test double. `VPNController` accepts in-memory initial profiles for tests. Production still loads the existing profile store.

`VPNProfile` contains persisted configuration only. Live connection state and interface names are owned by `VPNController` in a separate runtime map, so transient helper state cannot leak into `profiles.json`. In the helper, provider handlers produce a `ProcessSpecification`; one launch path owns `Process` setup, pipes, input delivery, session registration and lifecycle logging.

The privileged helper is also split by responsibility. `main.swift` is only the daemon bootstrap; XPC client admission, session state, input validation, secure runtime files, resolver ownership, and orphan cleanup live in focused source files. `HelperService` remains the orchestration boundary and no longer mixes those security-sensitive primitives into its provider and lifecycle methods. Regression tests compile these production sources directly rather than extracting declarations from the daemon entry point.

## Verification and rollout

Run `./script/test.sh` for regression checks of option spellings, credentials, TLS references, canonicalization, duplicate starts, SAML transitions, ownership checks, Mach-O parsing, startup recovery, stale status replies, and disconnect/start races. Tests do not require VPN engines or administrator privileges. Import tests remove their own managed files.

Run `./script/build_and_run.sh --build` to build both targets without stopping or launching the GUI. The old version-mismatch restart flow has been replaced by the [unsigned app update lifecycle](unsigned-updates.md).

These checks do not establish real-gateway interoperability, distribution readiness, or an end-to-end protected provider installation. No helper registration, system permissions, routes, or DNS settings are changed by this verification pass.
