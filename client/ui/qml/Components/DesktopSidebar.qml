import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import PageEnum 1.0
import Style 1.0

import "../Config"
import "../Controls2"
import "../Controls2/TextTypes"

// Desktop-only left navigation sidebar, shown instead of the mobile bottom tab bar
// once the window is wide enough (see GC.desktopSidebarBreakpoint). Drives the same
// tabBarStackView as the mobile TabBar in PageStart.qml — this is a second set of
// entry points into the existing navigation, not a parallel navigation stack.

Rectangle {
    id: root

    property int currentIndex: 0
    property var goToTabBarPageFunc

    signal navigateRequested(int index)

    width: GC.desktopSidebarWidth
    color: AmneziaStyle.color.midnightBlack

    border.width: 0

    Rectangle {
        // right-edge separator against the content area
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: AmneziaStyle.color.slateGray
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 0

        Header1TextType {
            text: "AmneziaVPN"
            color: AmneziaStyle.color.paleGray
        }

        CaptionTextType {
            text: qsTr("Current server: %1").arg(ServersUiController.defaultServerName)
            color: AmneziaStyle.color.mutedGray
            Layout.topMargin: 4
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 16
            Layout.bottomMargin: 16
            height: 1
            color: AmneziaStyle.color.slateGray
        }

        SidebarNavButtonType {
            Layout.fillWidth: true
            text: qsTr("Home")
            image: "qrc:/images/controls/home.svg"
            isSelected: root.currentIndex === 0
            clickedFunc: function() { root.navigateRequested(0) }
        }

        SidebarNavButtonType {
            Layout.fillWidth: true
            Layout.topMargin: 6
            visible: !SettingsController.isOnTv() && ServersUiController.hasServerWithWriteAccess()
            text: qsTr("Share")
            image: "qrc:/images/controls/share-2.svg"
            isSelected: root.currentIndex === 1
            clickedFunc: function() { root.navigateRequested(1) }
        }

        SidebarNavButtonType {
            Layout.fillWidth: true
            Layout.topMargin: 6
            text: qsTr("Settings")
            image: (ServersUiController.hasServersFromGatewayApi && NewsModel.hasUnread && SettingsController.isNewsNotificationsEnabled())
                   ? "qrc:/images/controls/settings-news.svg" : "qrc:/images/controls/settings.svg"
            isSelected: root.currentIndex === 2
            clickedFunc: function() { root.navigateRequested(2) }
        }

        SidebarNavButtonType {
            Layout.fillWidth: true
            Layout.topMargin: 6
            text: qsTr("Add server")
            image: "qrc:/images/controls/plus.svg"
            isSelected: root.currentIndex === 3
            clickedFunc: function() { root.navigateRequested(3) }
        }

        Item {
            // spacer pushing the close action to the bottom
            Layout.fillHeight: true
        }

        SidebarNavButtonType {
            Layout.fillWidth: true
            text: qsTr("Close application")
            image: "qrc:/images/controls/close.svg"
            isSelected: false
            clickedFunc: function() { PageController.closeWindow() }
        }
    }
}
