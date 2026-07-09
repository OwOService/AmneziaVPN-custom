#ifndef ROUTERLINUX_H
#define ROUTERLINUX_H

#include <QTimer>
#include <QString>
#include <QSettings>
#include <QHash>
#include <QDebug>
#include <QObject>

#include "../client/platforms/linux/daemon/dnsutilslinux.h"

/**
 * @brief The Router class - General class for handling ip routing
 */
class RouterLinux : public QObject
{
    Q_OBJECT
public:
    struct Route {
        QString dst;
        QString gw;
    };

    static RouterLinux& Instance();

    bool routeAdd(const QString &ip, const QString &gw, const int &sock);
    int routeAddList(const QString &gw, const QStringList &ips);
    bool clearSavedRoutes();
    bool routeDelete(const QString &ip, const QString &gw, const int &sock);
    bool routeDeleteList(const QString &gw, const QStringList &ips);
    QString getgatewayandiface();
    bool flushDns();
    bool createTun(const QString &dev, const QString &subnet);
    bool deleteTun(const QString &dev);
    bool StartRoutingIpv6();
    bool StopRoutingIpv6();
    bool updateResolvers(const QString& ifname, const QList<QHostAddress>& resolvers);
    bool restoreResolvers();

    /**
     * @brief setupDynamicSplitRouting - wires up the mangle+ipset+policy-routing
     * chain for the ipset+dnsmasq dynamic split-tunneling mode: packets whose
     * destination is in ipsetV4Name/ipsetV6Name get fwmark-tagged, and a
     * dedicated routing table sends fwmark'd traffic through tunnelDevice.
     * This is entirely separate from the existing cgroup-based
     * setupTrafficSplitting() in linuxfirewall.cpp — different mechanism,
     * different fwmark, safe to run alongside it.
     * Verified manually against real traffic before writing this — see
     * amnezia-fork-session-report_v11 (the ip6tables --match-set + fwmark +
     * "ip -6 route get ... mark" comparison against an unreachable-route
     * test table).
     */
    bool setupDynamicSplitRouting(const QString &tunnelDevice, const QString &ipsetV4Name,
                                  const QString &ipsetV6Name, quint32 fwmark, int tableId);
    bool teardownDynamicSplitRouting(const QString &ipsetV4Name, const QString &ipsetV6Name,
                                     quint32 fwmark, int tableId);
public slots:

private:
    RouterLinux() {m_dnsUtil = new DnsUtilsLinux(this);}
    RouterLinux(RouterLinux const &) = delete;
    RouterLinux& operator= (RouterLinux const&) = delete;

    bool isServiceActive(const QString &serviceName);
    QList<Route> m_addedRoutes;
    DnsUtilsLinux *m_dnsUtil;
};

#endif // ROUTERLINUX_H

