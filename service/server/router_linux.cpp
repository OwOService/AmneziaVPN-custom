#include "router_linux.h"

#include <QProcess>
#include <QThread>
#include <core/utils/utilities.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <net/route.h>
#include <linux/if.h>
#include <linux/if_tun.h>
#include <linux/netlink.h>
#include <linux/rtnetlink.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <paths.h>
#include <fcntl.h>
#include <errno.h>
#include <stdio.h>
#include <unistd.h>
#include <QFileInfo>

#include <core/utils/networkUtilities.h>

RouterLinux &RouterLinux::Instance()
{
    static RouterLinux s;
    return s;
}

bool RouterLinux::routeAdd(const QString &ipWithSubnet, const QString &gw, const int &sock)
{
    QString ip = NetworkUtilities::ipAddressFromIpWithSubnet(ipWithSubnet);
    QString mask = NetworkUtilities::netMaskFromIpWithSubnet(ipWithSubnet);

    if (!NetworkUtilities::checkIPv4Format(ip) || !NetworkUtilities::checkIPv4Format(gw)) {
        qCritical().noquote() << "Critical, trying to add invalid route: " << ip << gw;
        return false;
    }

    struct rtentry route;
    memset(&route, 0, sizeof( route ));

    // set gateway
    ((struct sockaddr_in *)&route.rt_gateway)->sin_family = AF_INET;
    ((struct sockaddr_in *)&route.rt_gateway)->sin_addr.s_addr = inet_addr(gw.toStdString().c_str());
    ((struct sockaddr_in *)&route.rt_gateway)->sin_port = 0;
    // set host rejecting
    ((struct sockaddr_in *)&route.rt_dst)->sin_family = AF_INET;
    ((struct sockaddr_in *)&route.rt_dst)->sin_addr.s_addr = inet_addr(ip.toStdString().c_str());
    ((struct sockaddr_in *)&route.rt_dst)->sin_port = 0;
    // set mask
    ((struct sockaddr_in *)&route.rt_genmask)->sin_family = AF_INET;
    ((struct sockaddr_in *)&route.rt_genmask)->sin_addr.s_addr = inet_addr(mask.toStdString().c_str());
    ((struct sockaddr_in *)&route.rt_genmask)->sin_port = 0;

    route.rt_flags = RTF_UP | RTF_GATEWAY;
    route.rt_metric = 0;

    if (int err = ioctl(sock, SIOCADDRT, &route) < 0)
    {
        qDebug().noquote() << "route add error: gw "
                           << ((struct sockaddr_in *)&route.rt_gateway)->sin_addr.s_addr
                           << " ip " << ((struct sockaddr_in *)&route.rt_dst)->sin_addr.s_addr
                           << " mask " << ((struct sockaddr_in *)&route.rt_genmask)->sin_addr.s_addr << " " << err;
        return false;
    }

    m_addedRoutes.append({ipWithSubnet, gw});
    return true;
}

int RouterLinux::routeAddList(const QString &gw, const QStringList &ips)
{
    int temp_sock = socket(AF_INET, SOCK_DGRAM,  IPPROTO_IP);
    int cnt = 0;
    for (const QString &ip: ips) {
        if (routeAdd(ip, gw, temp_sock)) cnt++;
    }
    close(temp_sock);
    return cnt;
}

bool RouterLinux::clearSavedRoutes()
{
    int temp_sock = socket(AF_INET, SOCK_DGRAM,  IPPROTO_IP);
    int cnt = 0;
    for (const Route &r: m_addedRoutes) {
        if (routeDelete(r.dst, r.gw, temp_sock)) cnt++;
    }
    bool ret = (cnt == m_addedRoutes.count());
    m_addedRoutes.clear();
    close(temp_sock);
    return ret;
}

bool RouterLinux::routeDelete(const QString &ipWithSubnet, const QString &gw, const int &sock)
{
#ifdef MZ_DEBUG
    qDebug().noquote() << "RouterLinux::routeDelete: " << ipWithSubnet << gw;
#endif

    QString ip = NetworkUtilities::ipAddressFromIpWithSubnet(ipWithSubnet);
    QString mask = NetworkUtilities::netMaskFromIpWithSubnet(ipWithSubnet);

    if (!NetworkUtilities::checkIPv4Format(ip) || !NetworkUtilities::checkIPv4Format(gw)) {
        qCritical().noquote() << "Critical, trying to remove invalid route: " << ip << gw;
        return false;
    }

    if (ipWithSubnet == "0.0.0.0/0") {
        qDebug().noquote() << "Warning, trying to remove default route, skipping: " << ip << gw;
        return true;
    }

    struct rtentry route;
    memset(&route, 0, sizeof( route ));

    // set gateway
    ((struct sockaddr_in *)&route.rt_gateway)->sin_family = AF_INET;
    ((struct sockaddr_in *)&route.rt_gateway)->sin_addr.s_addr = inet_addr(gw.toStdString().c_str());
    ((struct sockaddr_in *)&route.rt_gateway)->sin_port = 0;
    // set host rejecting
    ((struct sockaddr_in *)&route.rt_dst)->sin_family = AF_INET;
    ((struct sockaddr_in *)&route.rt_dst)->sin_addr.s_addr = inet_addr(ip.toStdString().c_str());
    ((struct sockaddr_in *)&route.rt_dst)->sin_port = 0;
    // set mask
    ((struct sockaddr_in *)&route.rt_genmask)->sin_family = AF_INET;
    ((struct sockaddr_in *)&route.rt_genmask)->sin_addr.s_addr = inet_addr(mask.toStdString().c_str());
    ((struct sockaddr_in *)&route.rt_genmask)->sin_port = 0;

    route.rt_flags = RTF_UP | RTF_GATEWAY;
    route.rt_metric = 0;
    //route.rt_dev = "ens33";

    if (ioctl(sock, SIOCDELRT, &route) < 0)
    {
        qDebug().noquote() << "route delete error: gw " << gw << " ip " << ip << " mask " << mask;
        return false;
    }
    return true;
}

bool RouterLinux::routeDeleteList(const QString &gw, const QStringList &ips)
{
    int temp_sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_IP);
    int cnt = 0;
    for (const QString &ip: ips) {
        if (routeDelete(ip, gw, temp_sock)) cnt++;
    }
    close(temp_sock);
    return cnt;
}

bool RouterLinux::isServiceActive(const QString &serviceName) {
    QProcess process;
    process.start("systemctl", { "is-active", "--quiet", serviceName });
    process.waitForFinished();

    return process.exitCode() == 0;
}

bool RouterLinux::flushDns()
{
    QProcess p;
    p.setProcessChannelMode(QProcess::MergedChannels);

    //check what the dns manager use
    if (isServiceActive("nscd.service")) {
        qDebug() << "Restarting nscd.service";
        p.start("systemctl", { "restart", "nscd" });
    } else if (isServiceActive("systemd-resolved.service")) {
        qDebug() << "Restarting systemd-resolved.service";
        p.start("systemctl", { "restart", "systemd-resolved" });
    } else {
        qDebug() << "No suitable DNS manager found.";
        return false;
    }

    p.waitForFinished();
    QByteArray output(p.readAll());
    if (output.isEmpty())
        qDebug().noquote() << "Flush dns completed";
    else
        qDebug().noquote() << "OUTPUT systemctl restart nscd/systemd-resolved: " + output;

    return true;
}

bool RouterLinux::createTun(const QString &dev, const QString &subnet) {
    qDebug().noquote() << "createTun start";

    QProcess process;
    QStringList commands;

    commands << "ip" << "tuntap" << "add" << "mode" << "tun" << "dev" << dev;
    process.start("sudo", commands);
    if (!process.waitForStarted(1000))
    {
        qDebug().noquote() << "Could not start adding tun device!\n";
        return false;
    }
    else if (!process.waitForFinished(2000))
    {
        qDebug().noquote() << "Could not add tun device!\n";
        return false;
    }
    commands.clear();

    commands << "ip" << "addr" << "add" << QString("%1/24").arg(subnet) << "dev" << dev;
    process.start("sudo", commands);
    if (!process.waitForStarted(1000))
    {
        qDebug().noquote() << "Could not start adding a subnet for tun device!\n";
        return false;
    }
    else if (!process.waitForFinished(2000))
    {
        qDebug().noquote() << "Could not add a subnet for tun device!\n";
        return false;
    }
    commands.clear();

    commands << "ip" << "link" << "set" << "dev" << dev << "up";
    process.start("sudo", commands);
    if (!process.waitForStarted(1000))
    {
        qDebug().noquote() << "Could not start link set for tun device!\n";
        return false;
    }
    else if (!process.waitForFinished(2000))
    {
        qDebug().noquote() << "Could not link set for tun device!\n";
        return false;
    }

    return true;
}

bool RouterLinux::deleteTun(const QString &dev)
{
    struct {
        struct nlmsghdr  nh;
        struct ifinfomsg ifm;
        unsigned char    data[64];
    } req;
    struct rtattr *rta;
    int ret, rtnl;

    rtnl = socket(AF_NETLINK, SOCK_DGRAM, NETLINK_ROUTE);
    if (rtnl < 0) {
        qDebug().noquote() << "can't open rtnl: " << errno;
        return 1;
    }

    memset(&req, 0, sizeof(req));
    req.nh.nlmsg_len = NLMSG_ALIGN(NLMSG_LENGTH(sizeof(req.ifm)));
    req.nh.nlmsg_flags = NLM_F_REQUEST;
    req.nh.nlmsg_type = RTM_DELLINK;

    req.ifm.ifi_family = AF_UNSPEC;

    rta = (struct rtattr *)(((char *)&req) + NLMSG_ALIGN(req.nh.nlmsg_len));
    rta->rta_type = IFLA_IFNAME;
    rta->rta_len = RTA_LENGTH(IFNAMSIZ);
    req.nh.nlmsg_len += rta->rta_len;
    memcpy(RTA_DATA(rta), dev.toStdString().c_str(), IFNAMSIZ);

    ret = send(rtnl, &req, req.nh.nlmsg_len, 0);
    if (ret < 0)
        qDebug().noquote() << "can't send: errno";
    ret = (unsigned int)ret != req.nh.nlmsg_len;

    close(rtnl);
    qDebug().noquote() << "deleteTun ret" << ret;
    return ret;
}

bool RouterLinux::updateResolvers(const QString& ifname, const QList<QHostAddress>& resolvers)
{
    return m_dnsUtil->updateResolvers(ifname, resolvers);
}

bool RouterLinux::restoreResolvers() {
    return m_dnsUtil->restoreResolvers();
}

namespace {
// Small helper mirroring the fire-and-check-exit-code pattern used
// throughout this file (createTun, StartRoutingIpv6, ...), but returning
// success/failure instead of early-returning, since setup/teardown here
// need to keep going and report the aggregate result even if one step in
// the middle fails (e.g. a rule that's already absent on teardown).
bool runCommand(const QString &program, const QStringList &args, bool ignoreFailure = false)
{
    QProcess process;
    process.start(program, args);
    if (!process.waitForStarted(1000) || !process.waitForFinished(2000)) {
        qDebug().noquote() << "RouterLinux: command failed to run:" << program << args;
        return ignoreFailure;
    }
    if (process.exitCode() != 0 && !ignoreFailure) {
        qDebug().noquote() << "RouterLinux: command exited" << process.exitCode() << ":"
                          << program << args << "-" << process.readAllStandardError();
        return false;
    }
    return true;
}
}  // namespace

bool RouterLinux::setupDynamicSplitRouting(const QString &tunnelDevice,
                                           const QString &ipsetV4Name,
                                           const QString &ipsetV6Name, quint32 fwmark,
                                           int tableId)
{
    const QString markHex = QStringLiteral("0x%1").arg(fwmark, 0, 16);
    const QString chainV4 = QStringLiteral("AMN_SPLIT_DYN");
    const QString chainV6 = QStringLiteral("AMN_SPLIT_DYN6");

    bool ok = true;

    // mangle chains: create is allowed to fail (chain may already exist
    // from a previous unclean shutdown), flush must succeed so we never
    // start with stale rules from a previous site list.
    runCommand("sudo", {"iptables", "-t", "mangle", "-N", chainV4}, /*ignoreFailure=*/true);
    ok &= runCommand("sudo", {"iptables", "-t", "mangle", "-F", chainV4});
    ok &= runCommand("sudo", {"iptables", "-t", "mangle", "-A", chainV4, "-m", "set",
                              "--match-set", ipsetV4Name, "dst", "-j", "MARK",
                              "--set-xmark", markHex + "/0xffffffff"});
    runCommand("sudo", {"iptables", "-t", "mangle", "-D", "OUTPUT", "-j", chainV4},
              /*ignoreFailure=*/true);
    ok &= runCommand("sudo", {"iptables", "-t", "mangle", "-A", "OUTPUT", "-j", chainV4});

    runCommand("sudo", {"ip6tables", "-t", "mangle", "-N", chainV6}, /*ignoreFailure=*/true);
    ok &= runCommand("sudo", {"ip6tables", "-t", "mangle", "-F", chainV6});
    ok &= runCommand("sudo", {"ip6tables", "-t", "mangle", "-A", chainV6, "-m", "set",
                              "--match-set", ipsetV6Name, "dst", "-j", "MARK",
                              "--set-xmark", markHex + "/0xffffffff"});
    runCommand("sudo", {"ip6tables", "-t", "mangle", "-D", "OUTPUT", "-j", chainV6},
              /*ignoreFailure=*/true);
    ok &= runCommand("sudo", {"ip6tables", "-t", "mangle", "-A", "OUTPUT", "-j", chainV6});

    // Policy routing table, addressed purely by numeric id (see session
    // report — /etc/iproute2/rt_tables doesn't exist on every distro, no
    // reason to depend on it). WireGuard interfaces are point-to-point, so
    // a device-only default route (no explicit gateway) is correct here,
    // same convention the rest of this codebase already uses for the tun
    // device.
    const QString tableIdStr = QString::number(tableId);
    runCommand("sudo", {"ip", "route", "del", "default", "table", tableIdStr},
              /*ignoreFailure=*/true);
    ok &= runCommand("sudo",
                     {"ip", "route", "add", "default", "dev", tunnelDevice, "table", tableIdStr});
    runCommand("sudo", {"ip", "rule", "del", "fwmark", markHex, "lookup", tableIdStr},
              /*ignoreFailure=*/true);
    ok &= runCommand(
        "sudo", {"ip", "rule", "add", "fwmark", markHex, "lookup", tableIdStr, "priority", "100"});

    runCommand("sudo", {"ip", "-6", "route", "del", "default", "table", tableIdStr},
              /*ignoreFailure=*/true);
    ok &= runCommand(
        "sudo", {"ip", "-6", "route", "add", "default", "dev", tunnelDevice, "table", tableIdStr});
    runCommand("sudo", {"ip", "-6", "rule", "del", "fwmark", markHex, "lookup", tableIdStr},
              /*ignoreFailure=*/true);
    ok &= runCommand("sudo", {"ip", "-6", "rule", "add", "fwmark", markHex, "lookup", tableIdStr,
                             "priority", "100"});

    qDebug().noquote() << "RouterLinux::setupDynamicSplitRouting" << (ok ? "OK" : "FAILED")
                      << "mark" << markHex << "table" << tableIdStr << "dev" << tunnelDevice;
    return ok;
}

bool RouterLinux::teardownDynamicSplitRouting(const QString &ipsetV4Name,
                                              const QString &ipsetV6Name, quint32 fwmark,
                                              int tableId)
{
    const QString markHex = QStringLiteral("0x%1").arg(fwmark, 0, 16);
    const QString chainV4 = QStringLiteral("AMN_SPLIT_DYN");
    const QString chainV6 = QStringLiteral("AMN_SPLIT_DYN6");
    const QString tableIdStr = QString::number(tableId);

    // Best-effort in every step — teardown must not abort partway and
    // leave some rules dangling just because an earlier one was already
    // gone (e.g. called twice, or after a partial setup failure).
    runCommand("sudo", {"ip", "rule", "del", "fwmark", markHex, "lookup", tableIdStr},
              /*ignoreFailure=*/true);
    runCommand("sudo", {"ip", "-6", "rule", "del", "fwmark", markHex, "lookup", tableIdStr},
              /*ignoreFailure=*/true);
    runCommand("sudo", {"ip", "route", "del", "default", "table", tableIdStr},
              /*ignoreFailure=*/true);
    runCommand("sudo", {"ip", "-6", "route", "del", "default", "table", tableIdStr},
              /*ignoreFailure=*/true);

    runCommand("sudo", {"iptables", "-t", "mangle", "-D", "OUTPUT", "-j", chainV4},
              /*ignoreFailure=*/true);
    runCommand("sudo", {"iptables", "-t", "mangle", "-F", chainV4}, /*ignoreFailure=*/true);
    runCommand("sudo", {"iptables", "-t", "mangle", "-X", chainV4}, /*ignoreFailure=*/true);

    runCommand("sudo", {"ip6tables", "-t", "mangle", "-D", "OUTPUT", "-j", chainV6},
              /*ignoreFailure=*/true);
    runCommand("sudo", {"ip6tables", "-t", "mangle", "-F", chainV6}, /*ignoreFailure=*/true);
    runCommand("sudo", {"ip6tables", "-t", "mangle", "-X", chainV6}, /*ignoreFailure=*/true);

    // Note: ipsetV4Name/ipsetV6Name themselves are destroyed by
    // DynamicSplitResolver::stop(), not here — this method only owns the
    // netfilter/routing side, not the ipsets it references. They're taken
    // as parameters only for the log line below, for symmetry with setup.
    qDebug().noquote() << "RouterLinux::teardownDynamicSplitRouting done, mark" << markHex
                      << "table" << tableIdStr << "(ipsets" << ipsetV4Name << "/" << ipsetV6Name
                      << "left to DynamicSplitResolver::stop())";
    return true;
}

namespace {
// Verified live against real traffic in the fork session report (ip -6
// route get ... mark 0x4001 / table 200). Doesn't collide with the
// existing cgroup-based app split tunneling, which uses fwmark 0x3211
// (see kPacketTag in linuxfirewall.cpp) and an rt_tables-named table
// rather than a bare numeric id.
constexpr quint32 kDynSplitFwmark = 0x4001;
constexpr int kDynSplitTableId = 200;
const QString kDynSplitIpsetV4 = QStringLiteral("amn-split4");
const QString kDynSplitIpsetV6 = QStringLiteral("amn-split6");
}  // namespace

bool RouterLinux::startDynamicSplitTunneling(const QString &tunnelDevice,
                                             const QStringList &splitDomains,
                                             const QList<QHostAddress> &upstreamServers)
{
    // Never leave two dynamic sessions layered on top of each other — a
    // reconnect with a changed site list must tear down cleanly first, the
    // same "stop before start" discipline DynamicSplitResolver::start()
    // already applies to itself.
    if (m_dynamicSplitTunnelingActive) {
        stopDynamicSplitTunneling();
    }

    DnsSplitStrategyDetector detector;
    if (detector.detect() == DnsSplitStrategyDetector::Strategy::Unknown) {
        qDebug().noquote() << "RouterLinux::startDynamicSplitTunneling: no usable "
                              "systemd-resolved found, caller should fall back to static "
                              "split tunneling";
        return false;
    }

    QStringList upstreamStrings;
    for (const QHostAddress &addr : upstreamServers) {
        upstreamStrings << addr.toString();
    }

    const QHostAddress resolverAddress = DynamicSplitResolver::dedicatedLoopbackAddress();
    constexpr quint16 resolverPort = 53;

    if (!DynamicSplitResolver::Instance().start(resolverAddress, resolverPort, splitDomains,
                                                upstreamStrings, kDynSplitIpsetV4,
                                                kDynSplitIpsetV6)) {
        return false;
    }

    // Plain SetLinkDNS (useExplicitPort=false): works against any
    // systemd-resolved version, not just >= 249 — see
    // DynamicSplitResolver::dedicatedLoopbackAddress() for why that's the
    // whole point of always using this address. splitDomains are pushed as
    // route-only domains, which systemd-resolved matches against the
    // domain itself and all of its subdomains — no manual subdomain
    // enumeration required on the caller's side.
    if (!m_dnsUtil->updateSplitResolvers(tunnelDevice, resolverAddress, resolverPort,
                                         splitDomains, /*useExplicitPort=*/false)) {
        DynamicSplitResolver::Instance().stop();
        return false;
    }

    if (!setupDynamicSplitRouting(tunnelDevice, kDynSplitIpsetV4, kDynSplitIpsetV6,
                                  kDynSplitFwmark, kDynSplitTableId)) {
        m_dnsUtil->restoreSplitResolvers(tunnelDevice);
        DynamicSplitResolver::Instance().stop();
        return false;
    }

    m_dynamicSplitTunnelingActive = true;
    m_dynamicSplitTunnelDevice = tunnelDevice;
    qDebug().noquote() << "RouterLinux::startDynamicSplitTunneling: active for"
                      << splitDomains.size() << "domain(s) via" << tunnelDevice;
    return true;
}

bool RouterLinux::stopDynamicSplitTunneling()
{
    if (!m_dynamicSplitTunnelingActive) {
        return true;  // nothing to do
    }

    // Best-effort, same as teardownDynamicSplitRouting()'s own internals:
    // every step runs regardless of whether an earlier one reports failure,
    // so a partial prior failure never leaves the rest of the chain stuck.
    teardownDynamicSplitRouting(kDynSplitIpsetV4, kDynSplitIpsetV6, kDynSplitFwmark,
                               kDynSplitTableId);
    m_dnsUtil->restoreSplitResolvers(m_dynamicSplitTunnelDevice);
    DynamicSplitResolver::Instance().stop();

    m_dynamicSplitTunnelingActive = false;
    m_dynamicSplitTunnelDevice.clear();
    return true;
}

bool RouterLinux::StartRoutingIpv6()
{
    QProcess process;
    QStringList commands;

    commands << "sysctl" << "-w" << "net.ipv6.conf.all.disable_ipv6=0";
    process.start("sudo", commands);
    if (!process.waitForStarted(1000))
    {
        qDebug().noquote() << "Could not start activate ipv6\n";
        return false;
    }
    else if (!process.waitForFinished(2000))
    {
        qDebug().noquote() << "Could not activate ipv6\n";
        return false;
    }
    commands.clear();

    commands << "sysctl" << "-w" << "net.ipv6.conf.default.disable_ipv6=0";
    process.start("sudo", commands);
    if (!process.waitForStarted(1000))
    {
        qDebug().noquote() << "Could not start activate ipv6\n";
        return false;
    }
    else if (!process.waitForFinished(2000))
    {
        qDebug().noquote() << "Could not activate ipv6\n";
        return false;
    }
    commands.clear();

    qDebug().noquote() << "StartRoutingIpv6 OK";
    return true;
}

bool RouterLinux::StopRoutingIpv6()
{
    QProcess process;
    QStringList commands;

    commands << "sysctl" << "-w" << "net.ipv6.conf.all.disable_ipv6=1";
    process.start("sudo", commands);
    if (!process.waitForStarted(1000))
    {
        qDebug().noquote() << "Could not start disable ipv6\n";
        return false;
    }
    else if (!process.waitForFinished(2000))
    {
        qDebug().noquote() << "Could not disable ipv6\n";
        return false;
    }
    commands.clear();

    commands << "sysctl" << "-w" << "net.ipv6.conf.default.disable_ipv6=1";
    process.start("sudo", commands);
    if (!process.waitForStarted(1000))
    {
        qDebug().noquote() << "Could not start disable ipv6\n";
        return false;
    }
    else if (!process.waitForFinished(2000))
    {
        qDebug().noquote() << "Could not disable ipv6\n";
        return false;
    }
    commands.clear();

    qDebug().noquote() << "StopRoutingIpv6 OK";
    return true;
}
