#ifndef DYNAMICSPLITRESOLVER_H
#define DYNAMICSPLITRESOLVER_H

#include <QObject>
#include <QProcess>
#include <QHostAddress>
#include <QString>
#include <QStringList>

/**
 * @brief The DynamicSplitResolver class - owns a single isolated dnsmasq
 * child process plus the ipset(s) it feeds, for the "dynamic" (ipset+dnsmasq)
 * split-tunneling mode. This process is deliberately NOT the system's DNS
 * resolver: it only ever receives queries that systemd-resolved has been
 * told (via DnsUtilsLinux::updateSplitResolvers, see the .rep/IPC side of
 * this feature) to route here for the specific split-tunneling domains.
 * Everything else keeps resolving wherever it already did.
 *
 * This class owns exactly one dnsmasq instance and one v4/one v6 ipset pair
 * at a time — starting a new one while already running stops the old one
 * first, it does not stack multiple resolvers.
 *
 * See amnezia-fork-session-report_v11 for the manual iptables/ip6tables/
 * ipset/dnsmasq verification this design is based on: dnsmasq's --ipset
 * directive was confirmed to populate hash:ip inet and inet6 ipsets
 * correctly from live A/AAAA answers (both single- and multi-address
 * responses), and ip6tables --match-set + fwmark + policy routing was
 * confirmed to actually steer real traffic based on those sets.
 */
class DynamicSplitResolver : public QObject
{
    Q_OBJECT
public:
    static DynamicSplitResolver& Instance();

    /**
     * @brief start - creates (or recreates, if already present from a
     * previous unclean shutdown) the v4/v6 ipsets, writes a dnsmasq config
     * covering splitDomains, and launches dnsmasq bound to
     * listenAddress:listenPort.
     *
     * @param listenAddress Loopback address for dnsmasq to bind. Caller is
     *        responsible for picking one that doesn't collide with an
     *        existing resolver — DynamicSplitResolver does not itself probe
     *        for what's already listening.
     * @param listenPort Port for dnsmasq to bind. If this is 53, the caller
     *        must have already ensured listenAddress is a dedicated
     *        loopback alias and not the system's primary loopback address
     *        (relevant for the SystemdResolvedLegacyPort53 strategy from
     *        DnsSplitStrategyDetector, where systemd-resolved has no way to
     *        ask for anything other than :53).
     * @param splitDomains Domains to feed into a single combined dnsmasq
     *        --ipset directive. Every A/AAAA answer dnsmasq gives out for
     *        any of these domains (or their subdomains) gets added to the
     *        v4/v6 ipsets, whichever matches the answer's family.
     * @param upstreamServers DNS servers dnsmasq forwards to for actually
     *        resolving these domains. Should be the same servers the VPN
     *        connection is already using (AmneziaDNS / the primary+secondary
     *        DNS pushed in the WireGuard config), not a hardcoded public
     *        resolver — these domain names shouldn't leak to a third party
     *        outside the tunnel just because of a hardcoded choice here.
     * @param ipsetV4Name / ipsetV6Name Names for the two ipsets. Caller
     *        picks these (expected convention: something namespaced like
     *        "amn-split4"/"amn-split6" to make them recognizable in `ipset
     *        list` output, distinct from anything the user might already
     *        have — see the detection work in the session report before
     *        assuming no collision).
     */
    bool start(const QHostAddress &listenAddress, quint16 listenPort,
               const QStringList &splitDomains, const QStringList &upstreamServers,
               const QString &ipsetV4Name, const QString &ipsetV6Name);

    /**
     * @brief stop - kills the dnsmasq child (if running) and destroys both
     * ipsets. Safe to call even if start() was never called or already
     * failed partway (e.g. ipsets created but dnsmasq failed to launch) —
     * cleans up whatever partial state exists.
     */
    bool stop();

    bool isRunning() const;

    /**
     * @brief dedicatedLoopbackAddress - the loopback alias this class
     * always binds its dnsmasq instance to, on port 53. Fixed rather than
     * caller-supplied: this is what lets callers use plain SetLinkDNS
     * (DnsUtilsLinux::updateSplitResolvers with useExplicitPort=false)
     * unconditionally, without needing SetLinkDNSEx (systemd >= 249) or any
     * free-port probing — SetLinkDNS always dials :53 on the address it's
     * given, so that address just needs to be ours alone. 127.0.0.0/8 is
     * entirely loopback per RFC 3330, so any address in it beyond
     * 127.0.0.1 is fair game and won't collide with whatever the user
     * already has bound to 127.0.0.1:53 (their own dnsmasq, systemd-
     * resolved's stub listener, Pi-hole, etc — see the fork session
     * report's DNS-environment survey).
     */
    static QHostAddress dedicatedLoopbackAddress();

private:
    DynamicSplitResolver() = default;
    ~DynamicSplitResolver();
    Q_DISABLE_COPY(DynamicSplitResolver)

    bool ensureLoopbackAlias();
    bool releaseLoopbackAlias();

    bool createIpset(const QString &name, bool isIpv6);
    bool destroyIpset(const QString &name);
    bool writeDnsmasqConfig(const QString &path, const QHostAddress &listenAddress,
                            quint16 listenPort, const QStringList &splitDomains,
                            const QStringList &upstreamServers,
                            const QString &ipsetV4Name, const QString &ipsetV6Name);

    QProcess *m_dnsmasqProcess = nullptr;
    QString m_configPath;
    QString m_ipsetV4Name;
    QString m_ipsetV6Name;
    bool m_loopbackAliasUp = false;
};

#endif // DYNAMICSPLITRESOLVER_H
