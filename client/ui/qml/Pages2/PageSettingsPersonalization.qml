import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import PageEnum 1.0
import Style 1.0

import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"

PageType {
    id: root

    ColumnLayout {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        anchors.topMargin: 20 + PageController.safeAreaTopMargin

        BackButtonType {
            id: backButton
        }

        BaseHeaderType {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16

            headerText: qsTr("Personalization")
            descriptionText: qsTr("Customize the look of the app.")
        }

        SwitcherType {
            id: oledThemeSwitcher

            Layout.fillWidth: true
            Layout.topMargin: 16
            Layout.leftMargin: 16
            Layout.rightMargin: 16

            text: qsTr("OLED dark theme")
            descriptionText: qsTr("Use pure black backgrounds to save battery and avoid glow on OLED screens.")

            checked: SettingsController.isOledThemeEnabled()

            onToggled: function() {
                if (checked !== SettingsController.isOledThemeEnabled()) {
                    SettingsController.toggleOledThemeEnabled(checked)
                    // Also flip the live style property directly so the whole app re-colors
                    // immediately, instead of only taking effect after the next launch.
                    AmneziaStyle.oledThemeEnabled = checked
                }
            }
        }

        DividerType {
            Layout.fillWidth: true
            Layout.topMargin: 16
            Layout.leftMargin: 16
            Layout.rightMargin: 16
        }

        HueSliderType {
            id: accentHueSlider

            Layout.fillWidth: true
            Layout.topMargin: 16
            Layout.leftMargin: 16
            Layout.rightMargin: 16

            text: qsTr("Accent color")
            descriptionText: qsTr("Drag to change the app's accent color.")

            value: SettingsController.accentColorHue()

            onMoved: {
                SettingsController.setAccentColorHue(value)
                // Same immediate, app-wide re-color pattern as the OLED switcher above.
                AmneziaStyle.accentColorHue = value
            }
        }

        DividerType {
            Layout.fillWidth: true
            Layout.topMargin: 16
            Layout.leftMargin: 16
            Layout.rightMargin: 16
        }
    }
}
