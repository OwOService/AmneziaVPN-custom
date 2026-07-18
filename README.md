# AmneziaVPN — Custom Fork (Unofficial)

> **This is an unofficial, community fork of [AmneziaVPN](https://github.com/amnezia-vpn/amnezia-client).
> It is not affiliated with, endorsed by, or maintained by the Amnezia team.**
> "Amnezia" and "AmneziaVPN" are names/trademarks of the original project; this fork does not
> claim to be an official Amnezia product or release.

## What this is

This fork patches the **desktop client only** (server-side infrastructure is untouched and
uses upstream AmneziaWG/Xray as-is). It exists to fix bugs and add improvements that hadn't
yet been picked up upstream at the time of forking. Some or all of these fixes may eventually
be merged back into the upstream project.

Current focus: Linux and Windows. Android support is not a priority for this fork yet.

### Notable changes vs. upstream

- Fixed an indefinite "Connecting…"/"Reconnecting…" hang: protocols (WireGuard/AmneziaWG, Xray)
  could report `NoError` from `start()` without ever confirming a real handshake/tunnel, leaving
  the UI stuck if the connection never actually completed. Added a watchdog timeout that
  correctly transitions the connection state to `Error`.
- Added more detailed error reporting surfaced to the UI (e.g. distinguishing timeout, broken
  pipe, TLS handshake failure) instead of only a generic error code.
- Distinguished expected disconnects (user clicked "Disconnect") from unexpected ones, so real
  connection failures are no longer silently treated as a normal disconnect.
- (In progress) Investigating and fixing split tunneling behavior on desktop platforms.

See commit history and session notes in this repository for full technical detail on each fix.

## Building

This fork tracks upstream build instructions. See the
[original project's build documentation](https://github.com/amnezia-vpn/amnezia-client) for
platform requirements (Qt, CMake, Conan, etc.). No build process changes have been introduced
by this fork beyond the source changes themselves.

## Updates

The built-in auto-updater (which points to official Amnezia release servers) is disabled in
this fork to avoid silently overwriting custom changes with an official release. Updates to
this fork are distributed manually via this repository's
[Releases](../../releases) page.

## License

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)**, the same
license as the upstream project. See [`LICENSE`](./LICENSE) for the full license text.

In accordance with GPL-3.0, the complete corresponding source code for this fork — including
all modifications — is published in this repository alongside any binaries we distribute. If
you received a binary build of this fork without a copy of or link to this source, you are
entitled to request one.

### Attribution

This fork is based on [amnezia-vpn/amnezia-client](https://github.com/amnezia-vpn/amnezia-client),
© the Amnezia project contributors, licensed under GPL-3.0. All upstream copyright notices are
preserved in the source files. This is an independent, non-commercial, community modification
and is not produced, reviewed, or supported by the original authors unless explicitly stated
in a given release.
# Naiveproxy-master-test-
