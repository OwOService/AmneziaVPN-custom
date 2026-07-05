pragma Singleton
import QtQuick

Item {
    readonly property string screenHome: "qrc:/ScreenHome.qml"
    readonly property string screenHomeIntroGifEx1: "qrc:/ScreenHomeIntroGifEx1.qml"

    readonly property int screenWidth: 380
    readonly property int screenHeight: 680

    readonly property int defaultMargin: 20

    // Desktop window sizing — separate from the mobile-oriented screenWidth/Height above,
    // which stayed hardcoded at phone dimensions and forced desktop into a fixed 600x800 shell.
    readonly property int desktopDefaultWidth: 1080
    readonly property int desktopDefaultHeight: 720
    readonly property int desktopMinWidth: 760
    readonly property int desktopMinHeight: 560

    // Below this window width, desktop falls back to the mobile-style bottom tab bar layout
    // instead of the sidebar, since the sidebar + content wouldn't fit comfortably.
    readonly property int desktopSidebarBreakpoint: 860
    readonly property int desktopSidebarWidth: 260

    function isMobile() {
        if (Qt.platform.os === "android" ||
                Qt.platform.os === "ios") {
            return true
        }
        return false
    }

    function isDesktop() {
        if (Qt.platform.os === "windows" ||
                Qt.platform.os === "linux" ||
                Qt.platform.os === "osx") {
            return true
        }
        return false
    }

    TextEdit{
        id: clipboard
        visible: false
    }

    function copyToClipBoard(text) {
        clipboard.text = text
        clipboard.selectAll()
        clipboard.copy()
        clipboard.select(0, 0)
    }
}
