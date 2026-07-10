#ifndef CONNECTIONUICONTROLLER_H
#define CONNECTIONUICONTROLLER_H

#include <QObject>

#include "core/controllers/connectionController.h"
#include "core/utils/errorCodes.h"
#include "core/utils/routeModes.h"
#include "core/utils/commonStructs.h"
#include "core/protocols/vpnProtocol.h"
#include "core/controllers/serversController.h"

class ConnectionUiController : public QObject
{
    Q_OBJECT

public:
    Q_PROPERTY(bool isConnected READ isConnected NOTIFY connectionStateChanged)
    Q_PROPERTY(bool isConnectionInProgress READ isConnectionInProgress NOTIFY connectionStateChanged)
    Q_PROPERTY(QString connectionStateText READ connectionStateText NOTIFY connectionStateChanged)
    // See VpnConnection::DynamicSplitTunnelingStatus: 0=Off, 1=Active, 2=Error.
    Q_PROPERTY(int dynamicSplitTunnelingStatus READ dynamicSplitTunnelingStatus NOTIFY dynamicSplitTunnelingStatusChanged)
    Q_PROPERTY(QString dynamicSplitTunnelingErrorMessage READ dynamicSplitTunnelingErrorMessage NOTIFY dynamicSplitTunnelingStatusChanged)

    explicit ConnectionUiController(ConnectionController* connectionController,
                                    ServersController* serversController,
                                    QObject *parent = nullptr);

    ~ConnectionUiController() = default;

    bool isConnected() const;
    bool isConnectionInProgress() const;
    QString connectionStateText() const;
    int dynamicSplitTunnelingStatus() const;
    QString dynamicSplitTunnelingErrorMessage() const;

public slots:
    void toggleConnection();

    void openConnection();
    void closeConnection();

    bool isRevokeBlockedDuringActiveConnection(const QString &serverId, int containerIndex, const QString &clientId) const;

    ErrorCode getLastConnectionError();
    void onConnectionStateChanged(Vpn::ConnectionState state);

    void onTranslationsUpdated();

signals:
    void connectionStateChanged();
    void dynamicSplitTunnelingStatusChanged();

    void connectionErrorOccurred(ErrorCode errorCode);
    void connectionErrorOccurredWithDetail(ErrorCode errorCode, const QString &detail);

    void connectButtonClicked();
    void preparingConfig();
    void prepareConfig();
    void unsupportedConnectDrawerRequested();
    void noInstalledContainers();

private:
    Vpn::ConnectionState getCurrentConnectionState();
    void notifyConnectionBlocked(ErrorCode errorCode);

    ConnectionController* m_connectionController;
    ServersController* m_serversController;

    bool m_isConnected = false;
    bool m_isConnectionInProgress = false;
    QString m_connectionStateText = tr("Connect");

    Vpn::ConnectionState m_state;
};

#endif
