/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include "dnsutilslinux.h"

#include <net/if.h>

#include <QDBusVariant>
#include <QtDBus/QtDBus>

#include "leakdetector.h"
#include "logger.h"

constexpr const char* DBUS_RESOLVE_SERVICE = "org.freedesktop.resolve1";
constexpr const char* DBUS_RESOLVE_PATH = "/org/freedesktop/resolve1";
constexpr const char* DBUS_RESOLVE_MANAGER = "org.freedesktop.resolve1.Manager";
constexpr const char* DBUS_PROPERTY_INTERFACE =
    "org.freedesktop.DBus.Properties";

namespace {
Logger logger("DnsUtilsLinux");
}

DnsUtilsLinux::DnsUtilsLinux(QObject* parent) : DnsUtils(parent) {
  MZ_COUNT_CTOR(DnsUtilsLinux);
  logger.debug() << "DnsUtilsLinux created.";

  QDBusConnection conn = QDBusConnection::systemBus();
  m_resolver = new QDBusInterface(DBUS_RESOLVE_SERVICE, DBUS_RESOLVE_PATH,
                                  DBUS_RESOLVE_MANAGER, conn, this);
}

DnsUtilsLinux::~DnsUtilsLinux() {
  MZ_COUNT_DTOR(DnsUtilsLinux);

  for (auto iterator = m_linkDomains.constBegin();
       iterator != m_linkDomains.constEnd(); ++iterator) {
    QList<QVariant> argumentList;
    argumentList << QVariant::fromValue(iterator.key());
    argumentList << QVariant::fromValue(iterator.value());
    m_resolver->asyncCallWithArgumentList(QStringLiteral("SetLinkDomains"),
                                          argumentList);
  }

  if (m_ifindex > 0) {
    m_resolver->asyncCall(QStringLiteral("RevertLink"), m_ifindex);
  }

  logger.debug() << "DnsUtilsLinux destroyed.";
}

bool DnsUtilsLinux::updateResolvers(const QString& ifname,
                                    const QList<QHostAddress>& resolvers) {
  m_ifindex = if_nametoindex(qPrintable(ifname));
  if (m_ifindex <= 0) {
    logger.error() << "Unable to resolve ifindex for" << ifname;
    return false;
  }

  setLinkDNS(m_ifindex, resolvers);
  setLinkDefaultRoute(m_ifindex, true);
  updateLinkDomains();
  return true;
}

bool DnsUtilsLinux::restoreResolvers() {
  for (auto iterator = m_linkDomains.constBegin();
       iterator != m_linkDomains.constEnd(); ++iterator) {
    setLinkDomains(iterator.key(), iterator.value());
  }
  m_linkDomains.clear();

  /* Revert the VPN interface's DNS configuration */
  if (m_ifindex > 0) {
    QList<QVariant> argumentList = {QVariant::fromValue(m_ifindex)};
    QDBusPendingReply<> reply = m_resolver->asyncCallWithArgumentList(
        QStringLiteral("RevertLink"), argumentList);

    QDBusPendingCallWatcher* watcher = new QDBusPendingCallWatcher(reply, this);
    QObject::connect(watcher, SIGNAL(finished(QDBusPendingCallWatcher*)), this,
                     SLOT(dnsCallCompleted(QDBusPendingCallWatcher*)));

    m_ifindex = 0;
  }

  return true;
}

void DnsUtilsLinux::dnsCallCompleted(QDBusPendingCallWatcher* call) {
  QDBusPendingReply<> reply = *call;
  if (reply.isError()) {
    logger.error() << "Error received from the DBus service";
  }
  delete call;
}

void DnsUtilsLinux::setLinkDNS(int ifindex,
                               const QList<QHostAddress>& resolvers) {
  QList<DnsResolver> resolverList;
  char ifnamebuf[IF_NAMESIZE];
  const char* ifname = if_indextoname(ifindex, ifnamebuf);
  for (const auto& ip : resolvers) {
    resolverList.append(ip);
    if (ifname) {
      logger.debug() << "Adding DNS resolver" << ip.toString() << "via"
                     << ifname;
    }
  }

  QList<QVariant> argumentList;
  argumentList << QVariant::fromValue(ifindex);
  argumentList << QVariant::fromValue(resolverList);
  QDBusPendingReply<> reply = m_resolver->asyncCallWithArgumentList(
      QStringLiteral("SetLinkDNS"), argumentList);

  QDBusPendingCallWatcher* watcher = new QDBusPendingCallWatcher(reply, this);
  QObject::connect(watcher, SIGNAL(finished(QDBusPendingCallWatcher*)), this,
                   SLOT(dnsCallCompleted(QDBusPendingCallWatcher*)));
}

void DnsUtilsLinux::setLinkDomains(int ifindex,
                                   const QList<DnsLinkDomain>& domains) {
  char ifnamebuf[IF_NAMESIZE];
  const char* ifname = if_indextoname(ifindex, ifnamebuf);
  if (ifname) {
    for (const auto& d : domains) {
      // The DNS search domains often winds up revealing user's ISP which
      // can correlate back to their location.
      logger.debug() << "Setting DNS domain:" << logger.sensitive(d.domain)
                     << "via" << ifname << (d.search ? "search" : "");
    }
  }

  QList<QVariant> argumentList;
  argumentList << QVariant::fromValue(ifindex);
  argumentList << QVariant::fromValue(domains);
  QDBusPendingReply<> reply = m_resolver->asyncCallWithArgumentList(
      QStringLiteral("SetLinkDomains"), argumentList);

  QDBusPendingCallWatcher* watcher = new QDBusPendingCallWatcher(reply, this);
  QObject::connect(watcher, SIGNAL(finished(QDBusPendingCallWatcher*)), this,
                   SLOT(dnsCallCompleted(QDBusPendingCallWatcher*)));
}

void DnsUtilsLinux::setLinkDefaultRoute(int ifindex, bool enable) {
  QList<QVariant> argumentList;
  argumentList << QVariant::fromValue(ifindex);
  argumentList << QVariant::fromValue(enable);
  QDBusPendingReply<> reply = m_resolver->asyncCallWithArgumentList(
      QStringLiteral("SetLinkDefaultRoute"), argumentList);

  QDBusPendingCallWatcher* watcher = new QDBusPendingCallWatcher(reply, this);
  QObject::connect(watcher, SIGNAL(finished(QDBusPendingCallWatcher*)), this,
                   SLOT(dnsCallCompleted(QDBusPendingCallWatcher*)));
}

void DnsUtilsLinux::updateLinkDomains() {
  /* Get the list of search domains, and remove any others that might conspire
   * to satisfy DNS resolution. Unfortunately, this is a pain because Qt doesn't
   * seem to be able to demarshall complex property types.
   */
  QDBusMessage message = QDBusMessage::createMethodCall(
      DBUS_RESOLVE_SERVICE, DBUS_RESOLVE_PATH, DBUS_PROPERTY_INTERFACE, "Get");
  message << QString(DBUS_RESOLVE_MANAGER);
  message << QString("Domains");
  QDBusPendingReply<QVariant> reply =
      m_resolver->connection().asyncCall(message);

  QDBusPendingCallWatcher* watcher = new QDBusPendingCallWatcher(reply, this);
  QObject::connect(watcher, SIGNAL(finished(QDBusPendingCallWatcher*)), this,
                   SLOT(dnsDomainsReceived(QDBusPendingCallWatcher*)));
}

void DnsUtilsLinux::dnsDomainsReceived(QDBusPendingCallWatcher* call) {
  QDBusPendingReply<QVariant> reply = *call;
  if (reply.isError()) {
    logger.error() << "Error retrieving the DNS  domains from the DBus service";
    delete call;
    return;
  }

  /* Update the state of the DNS domains */
  m_linkDomains.clear();
  QDBusArgument args = qvariant_cast<QDBusArgument>(reply.value());
  QList<DnsDomain> list = qdbus_cast<QList<DnsDomain>>(args);
  for (const auto& d : list) {
    if (d.ifindex == 0) {
      continue;
    }
    m_linkDomains[d.ifindex].append(DnsLinkDomain(d.domain, d.search));
  }

  /* Drop any competing root search domains. */
  DnsLinkDomain root = DnsLinkDomain(".", true);
  for (auto iterator = m_linkDomains.constBegin();
       iterator != m_linkDomains.constEnd(); ++iterator) {
    if (!iterator.value().contains(root)) {
      continue;
    }
    QList<DnsLinkDomain> newlist = iterator.value();
    newlist.removeAll(root);
    setLinkDomains(iterator.key(), newlist);
  }

  /* Add a root search domain for the new interface. */
  QList<DnsLinkDomain> newlist = {root};
  setLinkDomains(m_ifindex, newlist);
  delete call;
}

void DnsUtilsLinux::setLinkDNSEx(int ifindex, const QHostAddress& resolver,
                                 quint16 port) {
  DnsResolverExList resolverList;
  resolverList.append(DnsResolverEx(resolver, port));

  QList<QVariant> argumentList;
  argumentList << QVariant::fromValue(ifindex);
  argumentList << QVariant::fromValue(resolverList);
  QDBusPendingReply<> reply = m_resolver->asyncCallWithArgumentList(
      QStringLiteral("SetLinkDNSEx"), argumentList);

  QDBusPendingCallWatcher* watcher = new QDBusPendingCallWatcher(reply, this);
  QObject::connect(watcher, SIGNAL(finished(QDBusPendingCallWatcher*)), this,
                   SLOT(dnsCallCompleted(QDBusPendingCallWatcher*)));
}

bool DnsUtilsLinux::updateSplitResolvers(const QString& ifname,
                                         const QHostAddress& resolver,
                                         quint16 resolverPort,
                                         const QStringList& splitDomains,
                                         bool useExplicitPort) {
  int ifindex = if_nametoindex(qPrintable(ifname));
  if (ifindex <= 0) {
    logger.error() << "Unable to resolve ifindex for" << ifname
                   << "(split resolvers)";
    return false;
  }

  if (!useExplicitPort && resolverPort != 53) {
    // Caller bug, not a runtime condition: SetLinkDNS has no port field,
    // so anything other than 53 here would silently be ignored by
    // resolved and queries would go to the wrong place. Refuse rather than
    // pretend this worked.
    logger.error() << "updateSplitResolvers: resolverPort" << resolverPort
                   << "requested without useExplicitPort — SetLinkDNS only "
                      "ever dials :53, this would silently misroute queries";
    return false;
  }

  logger.debug() << "Routing" << splitDomains.size()
                 << "split-tunneling domain(s) via" << resolver.toString()
                 << ":" << resolverPort << "on" << ifname
                 << (useExplicitPort ? "(SetLinkDNSEx)" : "(SetLinkDNS)");

  if (useExplicitPort) {
    setLinkDNSEx(ifindex, resolver, resolverPort);
  } else {
    setLinkDNS(ifindex, {resolver});
  }

  // route-only=true for every domain here (per org.freedesktop.resolve1:
  // false means "search domain", true means "routing domain only") — we
  // want these matched for routing purposes without ever being appended
  // as a suffix to unqualified single-label lookups the way a real search
  // domain would be.
  //
  // NOTE: SetLinkDomains *replaces* the full domain list for this link,
  // it is not additive. If updateResolvers() (whole-tunnel, "." domain)
  // is ever active on the same ifname as this, calling this method after
  // it will silently clobber the "." entry and vice-versa. The two modes
  // are mutually exclusive in the UI today (split vs. full routing), but
  // if that ever changes, this needs to merge domain lists instead of
  // overwriting — flagging here rather than solving it now since no
  // caller exercises both paths on one interface yet.
  QList<DnsLinkDomain> domains;
  for (const QString& domain : splitDomains) {
    domains.append(DnsLinkDomain(domain, /*routeOnly=*/true));
  }
  setLinkDomains(ifindex, domains);

  // Deliberately NOT calling setLinkDefaultRoute(true) here — that's what
  // makes updateResolvers()'s whole-tunnel push receive DNS traffic that
  // doesn't match any configured domain. Split mode must only ever receive
  // queries for splitDomains; everything else keeps going wherever it
  // already was.

  m_splitIfindex = ifindex;
  m_splitDomains = splitDomains;
  return true;
}

bool DnsUtilsLinux::restoreSplitResolvers(const QString& ifname) {
  Q_UNUSED(ifname);
  if (m_splitIfindex <= 0) {
    return true;  // nothing to do
  }

  setLinkDomains(m_splitIfindex, {});

  QList<QVariant> argumentList = {QVariant::fromValue(m_splitIfindex)};
  QDBusPendingReply<> reply =
      m_resolver->asyncCallWithArgumentList(QStringLiteral("RevertLink"),
                                            argumentList);
  QDBusPendingCallWatcher* watcher = new QDBusPendingCallWatcher(reply, this);
  QObject::connect(watcher, SIGNAL(finished(QDBusPendingCallWatcher*)), this,
                   SLOT(dnsCallCompleted(QDBusPendingCallWatcher*)));

  logger.debug() << "Reverted split-tunneling DNS routing for"
                 << m_splitDomains.size() << "domain(s) on ifindex"
                 << m_splitIfindex;

  m_splitIfindex = 0;
  m_splitDomains.clear();
  return true;
}

static DnsMetatypeRegistrationProxy s_dnsMetatypeProxy;
