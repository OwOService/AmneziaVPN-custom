import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import PageEnum 1.0
import Style 1.0

import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"

DrawerType2 {
    id: root

    property bool isAppSplitTinnelingEnabled: Qt.platform.os === "windows" || Qt.platform.os === "android"

    anchors.fill: parent
    expandedHeight: parent.height * 0.9

    expandedStateContent: ColumnLayout {
        id: content

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        Header2Type {
            Layout.fillWidth: true
            Layout.topMargin: 24
            Layout.rightMargin: 16
            Layout.leftMargin: 16
            Layout.bottomMargin: 16

            headerText: qsTr("Split tunneling")
            descriptionText:  qsTr("Allows you to connect to some sites or applications through a VPN connection and bypass others")
        }

        LabelWithButtonType {
            id: splitTunnelingSwitch
            Layout.fillWidth: true
            Layout.topMargin: 16

            visible: ServersUiController.isDefaultServerDefaultContainerHasSplitTunneling

            text: qsTr("Split tunneling on the server")
            descriptionText: qsTr("Enabled \nCan't be disabled for current server")
            rightImageSource: "qrc:/images/controls/chevron-right.svg"

            clickedFunction: function() {
                PageController.goToPage(PageEnum.PageSettingsSplitTunneling)
                root.closeTriggered()
            }
        }

        DividerType {
            visible: ServersUiController.isDefaultServerDefaultContainerHasSplitTunneling
        }

        LabelWithButtonType {
            id: siteBasedSplitTunnelingSwitch
            Layout.fillWidth: true
            Layout.topMargin: 16

            text: qsTr("Site-based split tunneling")
            descriptionText: enabled && IpSplitTunnelingController.isSplitTunnelingEnabled ? qsTr("Enabled") : qsTr("Disabled")
            rightImageSource: "qrc:/images/controls/chevron-right.svg"

            clickedFunction: function() {
                PageController.goToPage(PageEnum.PageSettingsSplitTunneling)
                root.closeTriggered()
            }
        }

        DividerType {
            visible: dynamicSplitTunnelingRow.visible
        }

        ColumnLayout {
            id: dynamicSplitTunnelingRow

            Layout.fillWidth: true
            Layout.topMargin: 16
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: 4

            // Only meaningful on Linux — the dynamic (DNS-driven) mechanism has
            // no macOS/Windows implementation yet, see Router::startDynamicSplitTunneling
            // — and only when site-based split tunneling is actually routing
            // specific sites through the VPN. routeMode === 1 is
            // RouteMode::VpnOnlyForwardSites (see routeModes.h); the dynamic
            // mechanism doesn't apply to VpnAllExceptSites.
            visible: Qt.platform.os === "linux" &&
                     IpSplitTunnelingController.isSplitTunnelingEnabled &&
                     IpSplitTunnelingController.routeMode === 1

            SwitcherType {
                id: dynamicSplitTunnelingSwitch
                Layout.fillWidth: true

                text: qsTr("Dynamic split tunneling")
                descriptionText: qsTr("Automatically covers subdomains too — add \"bank.ru\" once instead of listing every subdomain by hand. Falls back to the static site list if unavailable.")

                checked: IpSplitTunnelingController.isDynamicSplitTunnelingEnabled

                onToggled: function() {
                    if (checked !== IpSplitTunnelingController.isDynamicSplitTunnelingEnabled) {
                        IpSplitTunnelingController.isDynamicSplitTunnelingEnabled = checked
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8

                Rectangle {
                    id: statusDot
                    width: 8
                    height: 8
                    radius: 4
                    Layout.alignment: Qt.AlignVCenter
                    color: {
                        if (ConnectionController.dynamicSplitTunnelingStatus === 1) return AmneziaStyle.color.accentColor
                        if (ConnectionController.dynamicSplitTunnelingStatus === 2) return AmneziaStyle.color.vibrantRed
                        return AmneziaStyle.color.mutedGray
                    }
                }

                CaptionTextType {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: statusDot.color
                    text: {
                        // VpnConnection::DynamicSplitTunnelingStatus: 0=Off, 1=Active, 2=Error
                        if (ConnectionController.dynamicSplitTunnelingStatus === 1) return qsTr("Active")
                        if (ConnectionController.dynamicSplitTunnelingStatus === 2) {
                            var details = ConnectionController.dynamicSplitTunnelingErrorMessage
                            return details.length > 0 ? details : qsTr("Error")
                        }
                        return qsTr("Disabled")
                    }
                }
            }
        }

        DividerType {
        }

        LabelWithButtonType {
            id: appSplitTunnelingSwitch
            visible: isAppSplitTinnelingEnabled

            Layout.fillWidth: true

            text: qsTr("App-based split tunneling")
            descriptionText: AppSplitTunnelingController.isSplitTunnelingEnabled ? qsTr("Enabled") : qsTr("Disabled")
            rightImageSource: "qrc:/images/controls/chevron-right.svg"

            clickedFunction: function() {
                PageController.goToPage(PageEnum.PageSettingsAppSplitTunneling)
                root.closeTriggered()
            }
        }

        DividerType {
            visible: isAppSplitTinnelingEnabled
        }
    }
}
