import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Style 1.0

import "TextTypes"

Item {
    id: root

    property alias text: title.text
    property alias descriptionText: description.text

    // Hue in degrees, 0-360. Saturation/Value are fixed to match the app's
    // original accent swatch (#FBB26A at hue 30), so only the hue channel
    // is user-adjustable, keeping brightness/contrast consistent app-wide.
    property int value: 30
    readonly property real accentSaturation: 0.5777
    readonly property real accentValue: 0.9843

    property bool isFocusable: true

    signal moved()

    implicitWidth: parent ? parent.width : 300
    implicitHeight: content.implicitHeight + track.height + track.anchors.topMargin

    function colorForHue(hueDegrees) {
        return Qt.hsva(((hueDegrees % 360) + 360) % 360 / 360, accentSaturation, accentValue, 1.0)
    }

    function setValueFromX(mouseX) {
        var usableWidth = track.width - handle.width
        var clampedX = Math.max(0, Math.min(usableWidth, mouseX - handle.width / 2))
        var newValue = Math.round((clampedX / usableWidth) * 360)
        if (newValue !== root.value) {
            root.value = newValue
            root.moved()
        }
    }

    ColumnLayout {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        ListItemTitleType {
            id: title
            Layout.fillWidth: true
            text: root.text
            color: AmneziaStyle.color.paleGray
        }

        CaptionTextType {
            id: description
            Layout.fillWidth: true
            color: AmneziaStyle.color.mutedGray
            visible: text !== ""
        }
    }

    Rectangle {
        id: track

        anchors.top: content.bottom
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.right: parent.right

        height: 12
        radius: height / 2

        border.color: root.activeFocus ? AmneziaStyle.color.paleGray : AmneziaStyle.color.transparent
        border.width: root.activeFocus ? 1 : 0

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0;  color: Qt.hsva(0/360,   1.0, 1.0, 1.0) }
            GradientStop { position: 1/6;  color: Qt.hsva(60/360,  1.0, 1.0, 1.0) }
            GradientStop { position: 2/6;  color: Qt.hsva(120/360, 1.0, 1.0, 1.0) }
            GradientStop { position: 3/6;  color: Qt.hsva(180/360, 1.0, 1.0, 1.0) }
            GradientStop { position: 4/6;  color: Qt.hsva(240/360, 1.0, 1.0, 1.0) }
            GradientStop { position: 5/6;  color: Qt.hsva(300/360, 1.0, 1.0, 1.0) }
            GradientStop { position: 1.0;  color: Qt.hsva(360/360, 1.0, 1.0, 1.0) }
        }

        Rectangle {
            id: handle

            width: 24
            height: 24
            radius: 12

            y: (track.height - height) / 2
            x: Math.max(0, Math.min(track.width - width, (root.value / 360) * (track.width - width)))

            color: root.colorForHue(root.value)
            border.color: AmneziaStyle.color.paleGray
            border.width: 2

            Behavior on x {
                enabled: !dragArea.drag.active
                PropertyAnimation { duration: 100 }
            }
        }

        MouseArea {
            id: dragArea

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            onPressed: mouse => root.setValueFromX(mouse.x)
            onPositionChanged: mouse => {
                if (pressed) {
                    root.setValueFromX(mouse.x)
                }
            }
        }
    }

    focus: isFocusable
    activeFocusOnTab: isFocusable

    Keys.onLeftPressed: {
        root.value = Math.max(0, root.value - 5)
        root.moved()
    }
    Keys.onRightPressed: {
        root.value = Math.min(360, root.value + 5)
        root.moved()
    }
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
}
