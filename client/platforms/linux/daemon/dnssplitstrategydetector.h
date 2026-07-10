/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef DNSSPLITSTRATEGYDETECTOR_H
#define DNSSPLITSTRATEGYDETECTOR_H

#include <QObject>
#include <QString>

// Determines how domain-specific DNS routing for dynamic (ipset+dnsmasq)
// split tunneling can be wired up on this particular Linux system, without
// assuming any single DNS stack. See amnezia-fork-session-report_v11 for the
// full investigation behind this — in short:
//
//   - Amnezia's existing DnsUtilsLinux already talks to systemd-resolved via
//     its org.freedesktop.resolve1 D-Bus API for the *whole-tunnel* DNS push
//     (root search domain "."). We reuse the same D-Bus service, but ask it
//     to route only the split-tunnel domains to our own local resolver
//     instead of everything.
//   - SetLinkDNS (the method DnsUtilsLinux already uses) takes only an
//     address, no port — systemd-resolved always dials port 53 on whatever
//     address we give it. SetLinkDNSEx (added in systemd 249) adds an
//     explicit port parameter, which is what lets our resolver bind to an
//     arbitrary free port instead of fighting over :53 with whatever the
//     user already has there (dnsmasq, Pi-hole, unbound, ...).
//   - RouterLinux::startDynamicSplitTunneling() deliberately does NOT use
//     SetLinkDNSEx even when it's available: it always binds via a
//     dedicated loopback alias on :53 (see DynamicSplitResolver::
//     dedicatedLoopbackAddress()) and plain SetLinkDNS instead. That one
//     code path works against every systemd-resolved version, not just
//     >= 249, so SystemdResolvedWithPort and SystemdResolvedLegacyPort53
//     are currently treated identically by that caller — only whether
//     resolved is active at all (i.e. not Unknown) actually matters. The
//     distinction below is kept purely for lastDetectionDetails()
//     diagnostics and as a hook for a possible future optimization that
//     skips the alias when SetLinkDNSEx is available.
//   - If systemd-resolved isn't running at all (masked/disabled — not a
//     hypothetical: this is the actual state on at least one fork
//     maintainer's daily-driver machine), there is currently NO fallback
//     anywhere in Amnezia's DNS push code. We do not attempt to silently
//     rewrite /etc/resolv.conf or otherwise fight the user's existing setup
//     here; Unknown must resolve to the static (non-dynamic) site-list
//     fallback in IpSplitTunnelingController, with the user told plainly
//     that dynamic mode isn't available on their system.
class DnsSplitStrategyDetector : public QObject {
  Q_OBJECT

 public:
  enum class Strategy {
    // systemd-resolved is active and its D-Bus interface exposes
    // SetLinkDNSEx (systemd >= 249): our resolver can bind to any free
    // loopback port; we tell resolved about it explicitly via SetLinkDNSEx.
    SystemdResolvedWithPort,

    // systemd-resolved is active but only exposes the legacy SetLinkDNS
    // (systemd < 249, no port parameter — resolved will always dial :53 on
    // whatever address we hand it). Our resolver must bind to :53 on a
    // dedicated loopback alias (e.g. 127.0.0.2:53) instead of the user's
    // primary loopback address, to avoid colliding with anything already
    // bound to 127.0.0.1:53.
    SystemdResolvedLegacyPort53,

    // Neither of the above: systemd-resolved isn't active (masked,
    // disabled, not installed, or the D-Bus call failed for any other
    // reason), or the D-Bus interface didn't answer as expected. No safe
    // generic way to intercept domain-specific DNS on this system without
    // risking a fight with whatever the user has configured (their own
    // dnsmasq, Pi-hole, NetworkManager's internal resolver, etc). Callers
    // must fall back to the existing static, resolve-once-at-connect
    // mechanism and surface that clearly in the UI.
    Unknown,
  };

  explicit DnsSplitStrategyDetector(QObject* parent = nullptr);

  // Synchronous by design: this runs once, early, during connection setup
  // (not on a hot path), and every check involved (D-Bus introspection,
  // `resolvectl --version`) is inherently a single quick round trip. Doing
  // this async would just push the same "wait for one reply" complexity
  // onto every caller for no real benefit here.
  Strategy detect();

  // Human-readable explanation of the last detect() result, meant to be
  // shown to the user (via a notification banner) when Strategy::Unknown is
  // returned, so "dynamic mode isn't available" doesn't feel like a silent
  // failure.
  QString lastDetectionDetails() const { return m_lastDetails; }

 private:
  bool isResolvedActive();
  bool resolvedSupportsSetLinkDNSEx();

  QString m_lastDetails;
};

#endif  // DNSSPLITSTRATEGYDETECTOR_H
