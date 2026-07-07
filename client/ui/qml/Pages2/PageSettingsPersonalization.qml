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

        AccentColorPresetsType {
            id: accentColorPresets

            Layout.fillWidth: true
            Layout.topMargin: 16
            Layout.leftMargin: 16
            Layout.rightMargin: 16

            text: qsTr("Accent color")
            descriptionText: qsTr("Pick a preset, or fine-tune with the slider below.")

            value: SettingsController.accentColorHue()

            onMoved: {
                SettingsController.setAccentColorHue(value)
                AmneziaStyle.accentColorHue = value
                // Keep the slider handle in sync so it reflects the preset
                // that was just tapped, instead of looking stale.
                accentHueSlider.value = value
            }
        }

        HueSliderType {
            id: accentHueSlider

            Layout.fillWidth: true
            Layout.topMargin: 16
            Layout.leftMargin: 16
            Layout.rightMargin: 16

            text: qsTr("Fine-tune")
            descriptionText: qsTr("Drag to pick any color the presets above don't cover.")

            value: SettingsController.accentColorHue()

            onMoved: {
                SettingsController.setAccentColorHue(value)
                // Same immediate, app-wide re-color pattern as the OLED switcher above.
                AmneziaStyle.accentColorHue = value
                // Keep the preset row's selection ring in sync — if the slider
                // lands exactly on a preset hue, that swatch highlights;
                // otherwise none of them do, which is correct too.
                accentColorPresets.value = value
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
