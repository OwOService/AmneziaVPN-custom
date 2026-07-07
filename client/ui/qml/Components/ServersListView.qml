import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import SortFilterProxyModel 0.2

import PageEnum 1.0
import ContainerProps 1.0
import ContainersModelFilters 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"

ListViewType {
    id: root

    property int selectedIndex: ServersUiController.getServerIndexById(ServersUiController.defaultServerId)

    anchors.top: serversMenuHeader.bottom
    anchors.right: parent.right
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    anchors.topMargin: 16

    model: ServersModel

    Connections {
        target: ServersUiController
        function onDefaultServerIdChanged() {
            root.selectedIndex = ServersUiController.getServerIndexById(ServersUiController.defaultServerId)
        }
    }

    delegate: Item {
        id: menuContentDelegate
        objectName: "menuContentDelegate"

        property variant delegateData: model
        property VerticalRadioButton serverRadioButtonProperty: serverRadioButton

        implicitWidth: root.width
        implicitHeight: serverRadioButtonContent.implicitHeight

        // Elevate the row while it's being dragged so it reads as "picked up"
        // above its neighbors, and give it an opaque background so its text
        // doesn't show through-overlap with whatever row it's currently
        // hovering over (there's no live neighbor-shifting animation in this
        // first version, so the dragged row and the row underneath it can
        // occupy the same visual space for a moment).
        z: dragHandleArea.drag.active ? 2 : 0

        Rectangle {
            anchors.fill: parent
            visible: dragHandleArea.drag.active
            color: AmneziaStyle.color.midnightBlack
            opacity: 0.95
        }

        // Snap back to the ListView's own layout position once a drag ends
        // (either because it was dropped without reordering, or because
        // moveServerAtIndex triggered a model reset that will re-place this
        // delegate at its new index anyway).
        Behavior on y {
            enabled: !dragHandleArea.drag.active
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }

        ColumnLayout {
            id: serverRadioButtonContent
            objectName: "serverRadioButtonContent"

            anchors.fill: parent
            anchors.rightMargin: 16
            anchors.leftMargin: 16

            spacing: 0

            RowLayout {
                objectName: "serverRadioButtonRowLayout"

                Layout.fillWidth: true

                Item {
                    id: dragHandle
                    objectName: "serverDragHandle"

                    // Reordering only makes sense with more than one server.
                    // Unlike changing the *active* server (still guarded by
                    // ConnectionController.isConnected below), reordering the
                    // list doesn't touch the live connection, so it's allowed
                    // even while connected.
                    visible: root.count > 1

                    Layout.preferredWidth: visible ? 24 : 0
                    Layout.preferredHeight: 56
                    Layout.alignment: Qt.AlignVCenter

                    Grid {
                        anchors.centerIn: parent
                        columns: 2
                        rows: 3
                        spacing: 3

                        Repeater {
                            model: 6
                            Rectangle {
                                width: 3
                                height: 3
                                radius: 1.5
                                color: dragHandleArea.pressed ? AmneziaStyle.color.paleGray : AmneziaStyle.color.mutedGray
                            }
                        }
                    }

                    MouseArea {
                        id: dragHandleArea
                        objectName: "serverDragHandleArea"

                        anchors.fill: parent
                        cursorShape: Qt.SizeVerCursor
                        hoverEnabled: true

                        drag.target: menuContentDelegate
                        drag.axis: Drag.YAxis
                        // These are ABSOLUTE bounds on menuContentDelegate.y (the
                        // ListView positions delegates at y = rowIndex * height),
                        // not an offset from the current row's position — the row
                        // can be dragged anywhere from the very top of the list
                        // (y = 0) to the very bottom (y = (count - 1) * height).
                        drag.minimumY: 0
                        drag.maximumY: (root.count - 1) * menuContentDelegate.height

                        onReleased: {
                            const targetIndex = Math.max(0, Math.min(root.count - 1,
                                Math.round(menuContentDelegate.y / menuContentDelegate.height)))

                            // Always restore this delegate to its (pre-move) index's
                            // resting position. If the row actually moved,
                            // moveServerAtIndex triggers a full model reset right
                            // below, which re-lays-out every delegate (including
                            // this one, now at targetIndex) anyway — so this is
                            // just the correct fallback for the "dropped back in
                            // place" case, where no reset happens and the row
                            // must not stay stuck at the drop position.
                            menuContentDelegate.y = index * menuContentDelegate.height

                            if (targetIndex !== index) {
                                ServersUiController.moveServerAtIndex(index, targetIndex)
                            }
                        }
                    }
                }

                VerticalRadioButton {
                    id: serverRadioButton
                    objectName: "serverRadioButton"

                    Layout.fillWidth: true

                    text: name
                    descriptionText: isServerFromGatewayApi && (isSubscriptionExpired || isSubscriptionExpiringSoon)
                        ? (isSubscriptionExpired ? qsTr("Subscription expired. Please renew") : qsTr("Subscription expiring soon"))
                        : serverDescription
                    descriptionColor: isServerFromGatewayApi && (isSubscriptionExpired || isSubscriptionExpiringSoon)
                        ? (isSubscriptionExpired ? AmneziaStyle.color.vibrantRed : AmneziaStyle.color.goldenApricot)
                        : AmneziaStyle.color.mutedGray

                    checked: index === root.selectedIndex
                    checkable: !ConnectionController.isConnected

                    ButtonGroup.group: serversRadioButtonGroup

                    onClicked: {
                        if (ConnectionController.isConnected) {
                            PageController.showNotificationMessage(qsTr("Unable change server while there is an active connection"))
                            return
                        }

                        root.selectedIndex = index

                        ServersUiController.setDefaultServerAtIndex(index)
                    }

                    Keys.onEnterPressed: serverRadioButton.clicked()
                    Keys.onReturnPressed: serverRadioButton.clicked()
                }

                ImageButtonType {
                    id: serverInfoButton
                    objectName: "serverInfoButton"

                    image: "qrc:/images/controls/settings.svg"
                    imageColor: AmneziaStyle.color.paleGray

                    implicitWidth: 56
                    implicitHeight: 56

                    z: 1

                    onClicked: function() {
                        ServersUiController.setProcessedServerId(serverId)

                        if (ServersUiController.isServerFromApi(ServersUiController.processedServerId)) {
                            if (ServersUiController.isServerCountrySelectionAvailable(ServersUiController.processedServerId)) {
                                PageController.goToPage(PageEnum.PageSettingsApiAvailableCountries)
                            } else {
                                PageController.showBusyIndicator(true)
                                let result = SubscriptionUiController.getAccountInfo(ServersUiController.processedServerId, false)
                                PageController.showBusyIndicator(false)
                                if (!result) {
                                    return
                                }

                                PageController.goToPage(PageEnum.PageSettingsApiServerInfo)
                            }
                        } else {
                            PageController.goToPage(PageEnum.PageSettingsServerInfo)
                        }

                        drawer.closeTriggered()
                    }
                }
            }

            DividerType {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
            }
        }
    }
}
