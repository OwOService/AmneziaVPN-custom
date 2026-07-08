/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include "dnssplitstrategydetector.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QProcess>
#include <QRegularExpression>

#include "logger.h"

namespace {
Logger logger("DnsSplitStrategyDetector");

constexpr const char* DBUS_RESOLVE_SERVICE = "org.freedesktop.resolve1";
constexpr const char* DBUS_RESOLVE_PATH = "/org/freedesktop/resolve1";
constexpr const char* DBUS_INTROSPECTABLE_INTERFACE =
    "org.freedesktop.DBus.Introspectable";

// SetLinkDNSEx landed in systemd 249. We don't strictly need the version
// number if the D-Bus introspection check below succeeds, but we keep it
// around for lastDetectionDetails() so a user filing a bug report can just
// paste the message instead of us going back and forth over "what systemd
// version do you have".
constexpr int MIN_SYSTEMD_VERSION_FOR_SETLINKDNSEX = 249;
}  // namespace

DnsSplitStrategyDetector::DnsSplitStrategyDetector(QObject* parent)
    : QObject(parent) {}

bool DnsSplitStrategyDetector::isResolvedActive() {
  QDBusConnection bus = QDBusConnection::systemBus();
  if (!bus.isConnected()) {
    m_lastDetails = QStringLiteral(
        "Could not connect to the D-Bus system bus at all.");
    return false;
  }

  // Checking "is org.freedesktop.resolve1 active" this way (rather than
  // systemctl is-active) avoids depending on systemd's CLI being on PATH
  // for the daemon process, and matches exactly what DnsUtilsLinux itself
  // relies on already: if this name isn't registered, its existing
  // updateResolvers() D-Bus calls are already silently failing today.
  QDBusReply<bool> reply =
      bus.interface()->isServiceRegistered(DBUS_RESOLVE_SERVICE);
  if (!reply.isValid() || !reply.value()) {
    m_lastDetails = QStringLiteral(
        "systemd-resolved (org.freedesktop.resolve1) is not registered on "
        "the D-Bus system bus — it is likely masked, disabled, or not "
        "installed.");
    return false;
  }

  return true;
}

bool DnsSplitStrategyDetector::resolvedSupportsSetLinkDNSEx() {
  QDBusConnection bus = QDBusConnection::systemBus();

  QDBusMessage introspectCall = QDBusMessage::createMethodCall(
      DBUS_RESOLVE_SERVICE, DBUS_RESOLVE_PATH, DBUS_INTROSPECTABLE_INTERFACE,
      QStringLiteral("Introspect"));
  QDBusMessage reply = bus.call(introspectCall);

  if (reply.type() != QDBusMessage::ReplyMessage ||
      reply.arguments().isEmpty()) {
    m_lastDetails = QStringLiteral(
        "systemd-resolved is active, but D-Bus introspection of its "
        "Manager interface failed — treating as legacy (no SetLinkDNSEx) "
        "to be safe.");
    return false;
  }

  const QString xml = reply.arguments().first().toString();
  const bool hasSetLinkDNSEx = xml.contains(QStringLiteral("SetLinkDNSEx"));

  // Best-effort version string, purely for lastDetectionDetails() — parsing
  // failure here must never flip the actual strategy decision, since the
  // introspection check above is the authoritative source of truth.
  QProcess resolvectl;
  resolvectl.start(QStringLiteral("resolvectl"), {QStringLiteral("--version")});
  QString versionLine;
  if (resolvectl.waitForFinished(2000)) {
    const QString output = QString::fromUtf8(resolvectl.readAllStandardOutput());
    QRegularExpression versionRegex(QStringLiteral("systemd (\\d+)"));
    QRegularExpressionMatch match = versionRegex.match(output);
    if (match.hasMatch()) {
      versionLine = match.captured(1);
    }
  }

  if (hasSetLinkDNSEx) {
    m_lastDetails =
        QStringLiteral("systemd-resolved exposes SetLinkDNSEx (systemd %1, "
                        ">= %2 required) — our resolver can use any free "
                        "loopback port.")
            .arg(versionLine.isEmpty() ? QStringLiteral("?") : versionLine)
            .arg(MIN_SYSTEMD_VERSION_FOR_SETLINKDNSEX);
  } else {
    m_lastDetails =
        QStringLiteral("systemd-resolved is active but only exposes the "
                        "legacy SetLinkDNS (systemd %1, older than %2) — no "
                        "port parameter, our resolver must bind to a "
                        "dedicated loopback alias on :53.")
            .arg(versionLine.isEmpty() ? QStringLiteral("?") : versionLine)
            .arg(MIN_SYSTEMD_VERSION_FOR_SETLINKDNSEX);
  }

  return hasSetLinkDNSEx;
}

DnsSplitStrategyDetector::Strategy DnsSplitStrategyDetector::detect() {
  if (!isResolvedActive()) {
    logger.info() << "DNS split strategy: Unknown —" << m_lastDetails;
    return Strategy::Unknown;
  }

  const bool hasPortSupport = resolvedSupportsSetLinkDNSEx();
  logger.info() << "DNS split strategy:"
               << (hasPortSupport ? "SystemdResolvedWithPort"
                                   : "SystemdResolvedLegacyPort53")
               << "—" << m_lastDetails;

  return hasPortSupport ? Strategy::SystemdResolvedWithPort
                         : Strategy::SystemdResolvedLegacyPort53;
}
