import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Style 1.0

import "TextTypes"

Item {
    id: root

    property alias text: title.text
    property alias descriptionText: description.text

    // Same fixed saturation/value as HueSliderType, so every swatch previews
    // exactly the color that tapping it will actually apply — no separate
    // "preset palette" to keep in sync with the slider's own math.
    property int value: 30
    readonly property real accentSaturation: 0.5777
    readonly property real accentValue: 0.9843

    // 30 (the app's original golden apricot) first, then a spread of hues
    // around the wheel so there's a reasonable pick for most tastes.
    readonly property var presetHues: [30, 0, 50, 140, 190, 220, 260, 320]

    property bool isFocusable: true

    signal moved()

    implicitWidth: parent ? parent.width : 300
    implicitHeight: content.implicitHeight + swatchRow.implicitHeight + swatchRow.anchors.topMargin

    function colorForHue(hueDegrees) {
        return Qt.hsva(((hueDegrees % 360) + 360) % 360 / 360, accentSaturation, accentValue, 1.0)
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

    RowLayout {
        id: swatchRow

        anchors.top: content.bottom
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.right: parent.right

        spacing: 12

        Repeater {
            model: root.presetHues

            Rectangle {
                id: swatch
                objectName: "accentPresetSwatch"

                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: width / 2

                color: root.colorForHue(modelData)

                border.width: root.value === modelData ? 3 : (swatchArea.containsMouse ? 1 : 0)
                border.color: AmneziaStyle.color.paleGray

                Behavior on border.width {
                    NumberAnimation { duration: 100 }
                }

                MouseArea {
                    id: swatchArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        if (root.value !== modelData) {
                            root.value = modelData
                            root.moved()
                        }
                    }
                }

                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Accent color preset")
            }
        }
    }

    focus: isFocusable
    activeFocusOnTab: isFocusable

    Keys.onLeftPressed: {
        var currentIndex = root.presetHues.indexOf(root.value)
        var nextIndex = currentIndex <= 0 ? root.presetHues.length - 1 : currentIndex - 1
        root.value = root.presetHues[nextIndex]
        root.moved()
    }
    Keys.onRightPressed: {
        var currentIndex = root.presetHues.indexOf(root.value)
        var nextIndex = currentIndex < 0 || currentIndex === root.presetHues.length - 1 ? 0 : currentIndex + 1
        root.value = root.presetHues[nextIndex]
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
