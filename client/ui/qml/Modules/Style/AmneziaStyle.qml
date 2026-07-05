pragma Singleton

import QtQuick

QtObject {
    id: root

    // Loaded once at singleton startup from the persisted setting. The Personalization page
    // updates this property directly (for immediate, app-wide reactivity) in addition to
    // persisting the new value via SettingsController, since plain method calls like
    // SettingsController.isOledThemeEnabled() don't establish a live QML binding dependency.
    property bool oledThemeEnabled: SettingsController.isOledThemeEnabled()

    // Same loading/live-update pattern as oledThemeEnabled above: read once at
    // startup, then the Personalization page's hue slider updates this property
    // directly so every control re-colors immediately as the user drags it.
    property int accentColorHue: SettingsController.accentColorHue()

    // Saturation/Value are fixed to match the app's original accent swatch
    // (#FBB26A, which sits at hue 30 with these exact S/V values) so only the
    // hue channel changes and the default look is pixel-identical to before
    // this setting existed.
    readonly property real accentSaturation: 0.5777
    readonly property real accentValue: 0.9843

    // Returns an actual (optionally translucent) color object — use this for
    // anything assigned to a QML "color" property, so alpha is preserved.
    function hueToColor(hueDegrees, saturation, value, alpha) {
        return Qt.hsva(((hueDegrees % 360) + 360) % 360 / 360, saturation, value, alpha === undefined ? 1.0 : alpha)
    }

    // Returns an opaque "#RRGGBB" string — use this only where a literal hex
    // string is required (e.g. colors embedded into HTML-formatted text),
    // since string values assigned to "color" properties always come out fully
    // opaque regardless of alpha.
    function hueToHex(hueDegrees, saturation, value) {
        var c = hueToColor(hueDegrees, saturation, value, 1.0)
        function toHex(n) {
            var s = Math.max(0, Math.min(255, Math.round(n * 255))).toString(16)
            return s.length === 1 ? '0' + s : s
        }
        return '#' + toHex(c.r) + toHex(c.g) + toHex(c.b)
    }

    property QtObject color: QtObject {
        readonly property color transparent: 'transparent'
        readonly property color paleGray: '#D7D8DB'
        readonly property color lightGray: '#C1C2C5'
        readonly property color mutedGray: '#878B91'
        readonly property color charcoalGray: '#494B50'
        readonly property color slateGray: '#2C2D30'
        // In OLED mode these collapse toward pure black to avoid visible grey backlight
        // bleed on OLED panels; everywhere in the app that reads these two colors picks
        // up the change automatically, no per-file edits needed.
        readonly property color onyxBlack: root.oledThemeEnabled ? '#000000' : '#1C1D21'
        readonly property color midnightBlack: root.oledThemeEnabled ? '#000000' : '#0E0E11'
        readonly property color goldenApricot: goldenApricotString
        // Semantic alias for the app's single accent color (== goldenApricot).
        // New code should reference this name, not goldenApricot directly.
        readonly property color accentColor: goldenApricotString
        readonly property color benefitsPanelBackground: '#1C1C1E'
        readonly property color softViolet: '#A87BE2'
        // These four are darker/deeper shades of the same accent hue (same hue as
        // goldenApricot, ~30°, just different saturation/value) — used for checked
        // track backgrounds, focus rings, disabled states, etc. Kept in sync with
        // the hue slider so those elements re-color along with everything else.
        readonly property color burntOrange: root.hueToHex(root.accentColorHue, 0.9464, 0.6588)
        readonly property color mutedBrown: root.hueToHex(root.accentColorHue, 0.5379, 0.5176)
        readonly property color richBrown: root.hueToHex(root.accentColorHue, 0.9697, 0.3882)
        readonly property color deepBrown: root.hueToHex(root.accentColorHue, 0.9688, 0.2510)
        readonly property color vibrantRed: '#EB5757'
        readonly property color darkCharcoal: '#261E1A'
        readonly property color pearlGray: '#EAEAEC'

        readonly property color sheerWhite: Qt.rgba(1, 1, 1, 0.12)
        readonly property color translucentWhite: Qt.rgba(1, 1, 1, 0.08)
        readonly property color barelyTranslucentWhite: Qt.rgba(1, 1, 1, 0.05)
        readonly property color translucentMidnightBlack: Qt.rgba(14/255, 14/255, 17/255, 0.8)
        readonly property color softGoldenApricot: root.hueToColor(root.accentColorHue, root.accentSaturation, root.accentValue, 0.3)
        readonly property color mistyGray: Qt.rgba(215/255, 216/255, 219/255, 0.8)
        readonly property color cloudyGray: Qt.rgba(215/255, 216/255, 219/255, 0.65)
        readonly property color translucentRichBrown: root.hueToColor(root.accentColorHue, 0.9697, 0.3882, 0.26)
        readonly property color translucentSlateGray: Qt.rgba(85/255, 86/255, 92/255, 0.13)
        readonly property color translucentOnyxBlack: Qt.rgba(28/255, 29/255, 33/255, 0.13)

        // Dynamic: recomputed from the user's chosen hue (Personalization page).
        // At the default hue (30) this reproduces the original literal '#FBB26A'
        // exactly, so existing visuals are unaffected until the user moves the slider.
        readonly property string goldenApricotString: root.hueToHex(root.accentColorHue, root.accentSaturation, root.accentValue)
    }
}
