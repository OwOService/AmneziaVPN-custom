import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import Style 1.0

import "TextTypes"

Button {
    id: root

    property string image
    property bool isSelected: false

    property string selectedBackgroundColor: AmneziaStyle.color.accentColor
    property string hoveredColor: AmneziaStyle.color.translucentWhite
    property string defaultBackgroundColor: AmneziaStyle.color.transparent

    property string selectedIconColor: AmneziaStyle.color.midnightBlack
    property string defaultIconColor: AmneziaStyle.color.mutedGray

    property string selectedTextColor: AmneziaStyle.color.midnightBlack
    property string defaultTextColor: AmneziaStyle.color.mutedGray

    property bool isFocusable: true
    property var clickedFunc

    hoverEnabled: true
    focusPolicy: Qt.StrongFocus

    implicitHeight: 44
    Layout.fillWidth: true

    Keys.onTabPressed: {
        FocusController.nextKeyTabItem()
    }

    Keys.onBacktabPressed: {
        FocusController.previousKeyTabItem()
    }

    Keys.onUpPressed: {
        FocusController.nextKeyUpItem()
    }

    Keys.onDownPressed: {
        FocusController.nextKeyDownItem()
    }

    Keys.onEnterPressed: {
        if (root.clickedFunc && typeof root.clickedFunc === "function") {
            root.clickedFunc()
        }
    }

    Keys.onReturnPressed: {
        if (root.clickedFunc && typeof root.clickedFunc === "function") {
            root.clickedFunc()
        }
    }

    onClicked: {
        if (root.clickedFunc && typeof root.clickedFunc === "function") {
            root.clickedFunc()
        }
    }

    background: Rectangle {
        id: background
        anchors.fill: parent
        radius: 10

        color: root.isSelected ? root.selectedBackgroundColor
             : (root.hovered ? root.hoveredColor : root.defaultBackgroundColor)

        border.color: root.activeFocus ? AmneziaStyle.color.paleGray : AmneziaStyle.color.transparent
        border.width: root.activeFocus ? 1 : 0

        Behavior on color {
            PropertyAnimation { duration: 150 }
        }
    }

    contentItem: RowLayout {
        spacing: 12

        Image {
            id: navIcon
            source: root.image
            sourceSize.width: 20
            sourceSize.height: 20
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.leftMargin: 14

            layer.enabled: true
            layer.effect: ColorOverlay {
                color: root.isSelected ? root.selectedIconColor : root.defaultIconColor
            }
        }

        ButtonTextType {
            text: root.text
            color: root.isSelected ? root.selectedTextColor : root.defaultTextColor
            font.pixelSize: 15
            font.weight: root.isSelected ? 600 : 500
            Layout.fillWidth: true
            Layout.rightMargin: 14
            elide: Text.ElideRight
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: false
    }
}
