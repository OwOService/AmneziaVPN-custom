/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef DNSUTILSLINUX_H
#define DNSUTILSLINUX_H

#include <QDBusInterface>
#include <QDBusPendingCallWatcher>

#include "daemon/dnsutils.h"
#include "dbustypeslinux.h"

class DnsUtilsLinux final : public DnsUtils {
  Q_OBJECT
  Q_DISABLE_COPY_MOVE(DnsUtilsLinux)

 public:
  DnsUtilsLinux(QObject* parent);
  ~DnsUtilsLinux();
  bool updateResolvers(const QString& ifname,
                       const QList<QHostAddress>& resolvers) override;
  bool restoreResolvers() override;

  // Domain-specific counterpart to updateResolvers(): routes only
  // splitDomains to our resolver instead of taking over all DNS on the
  // link. Deliberately does NOT call setLinkDefaultRoute(true) — that flag
  // is what makes updateResolvers()'s "." domain capture all DNS traffic,
  // and split mode must never do that. Caller picks
  // useExplicitPort based on DnsSplitStrategyDetector's result:
  //   true  -> SetLinkDNSEx (systemd >= 249), resolverPort honored as-is.
  //   false -> SetLinkDNS (legacy), resolverPort MUST be 53 and resolver
  //            MUST be a dedicated loopback alias the caller has already
  //            arranged not to collide with anything else on :53.
  bool updateSplitResolvers(const QString& ifname, const QHostAddress& resolver,
                            quint16 resolverPort, const QStringList& splitDomains,
                            bool useExplicitPort);

  // Reverts exactly the domains previously installed by
  // updateSplitResolvers() for ifname, without touching whole-tunnel DNS
  // state if that's also active on a different interface. Safe to call even
  // if updateSplitResolvers() was never called (no-op).
  bool restoreSplitResolvers(const QString& ifname);

 private:
  void setLinkDNSEx(int ifindex, const QHostAddress& resolver, quint16 port);
  void setLinkDNS(int ifindex, const QList<QHostAddress>& resolvers);
  void setLinkDomains(int ifindex, const QList<DnsLinkDomain>& domains);
  void setLinkDefaultRoute(int ifindex, bool enable);
  void updateLinkDomains();

 private slots:
  void dnsCallCompleted(QDBusPendingCallWatcher*);
  void dnsDomainsReceived(QDBusPendingCallWatcher*);

 private:
  int m_ifindex = 0;
  QMap<int, DnsLinkDomainList> m_linkDomains;
  QDBusInterface* m_resolver = nullptr;

  // Split-mode state, deliberately separate from m_ifindex/m_linkDomains
  // above: those are wired to the "." root-domain bookkeeping that
  // updateLinkDomains()/dnsDomainsReceived() do for the whole-tunnel case
  // (stripping other interfaces' conflicting root domains etc), which
  // doesn't apply here — we only ever need to remember exactly the
  // specific domains we ourselves installed, so we can clear precisely
  // those without re-querying or disturbing anything else.
  int m_splitIfindex = 0;
  QStringList m_splitDomains;
};

#endif  // DNSUTILSLINUX_H
