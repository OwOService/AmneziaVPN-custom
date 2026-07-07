import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QtCore

import SortFilterProxyModel 0.2

import PageEnum 1.0
import ContainerProps 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"
import "../Components"

PageType {
    id: root

    property var isServerFromTelegramApi: ServersUiController.isServerFromApi(ServersUiController.defaultServerId)

    // pageEnabled now only reflects whether the current server/container supports
    // split tunneling at all — this is a hard block regardless of connection state.
    // Editing the site list itself (add/remove/import/presets/search) is allowed
    // even while connected; only the on/off toggle and the mode selector are
    // locked while connected, via the separate toggleAndModeEnabled binding below,
    // since those change routing behavior in a way that doesn't apply live.
    property bool pageEnabled
    readonly property bool toggleAndModeEnabled: root.pageEnabled && !ConnectionController.isConnected

    Component.onCompleted: {
        if (ServersUiController.isDefaultServerDefaultContainerHasSplitTunneling) {
            PageController.showNotificationMessage(qsTr("Default server does not support split tunneling function"))
            root.pageEnabled = false
        } else {
            root.pageEnabled = true
        }
    }

    Connections {
        target: IpSplitTunnelingController

        function onFinished(message) {
            PageController.showNotificationMessage(message)
        }

        function onErrorOccurred(errorMessage) {
            PageController.showErrorMessage(errorMessage)
        }
    }

    QtObject {
        id: routeMode
        property int allSites: 0
        property int onlyForwardSites: 1
        property int allExceptSites: 2
    }

    property list<QtObject> routeModesModel: [
        onlyForwardSites,
        allExceptSites
    ]

    QtObject {
        id: onlyForwardSites
        property string name: qsTr("Only the sites listed here will be accessed through the VPN")
        property int type: routeMode.onlyForwardSites
    }
    QtObject {
        id: allExceptSites
        property string name: qsTr("Addresses from the list should not be accessed via VPN")
        property int type: routeMode.allExceptSites
    }

    function getRouteModesModelIndex() {
        var currentRouteMode = IpSplitTunnelingController.routeMode
        if ((routeMode.onlyForwardSites === currentRouteMode) || (routeMode.allSites === currentRouteMode)) {
            return 0
        } else if (routeMode.allExceptSites === currentRouteMode) {
            return 1
        }
    }

    ColumnLayout {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        anchors.topMargin: 20 + PageController.safeAreaTopMargin

        BackButtonType {
            id: backButton
        }

        HeaderTypeWithSwitcher {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16

            headerText: qsTr("Split tunneling")

            enabled: root.toggleAndModeEnabled
            showSwitcher: true
            switcher {
                checked: IpSplitTunnelingController.isSplitTunnelingEnabled
                enabled: root.toggleAndModeEnabled
            }
            switcherFunction: function(checked) {
                IpSplitTunnelingController.toggleSplitTunneling(checked)
                selector.text = root.routeModesModel[getRouteModesModelIndex()].name
            }
        }

        DropDownType {
            id: selector

            Layout.fillWidth: true
            Layout.topMargin: 32
            Layout.leftMargin: 16
            Layout.rightMargin: 16

            drawerHeight: 0.4375
            drawerParent: root

            enabled: root.toggleAndModeEnabled

            headerText: qsTr("Mode")

            listView: ListViewWithRadioButtonType {
                rootWidth: root.width

                model: root.routeModesModel

                selectedIndex: getRouteModesModelIndex()

                clickedFunction: function() {
                    selector.text = selectedText
                    selector.closeTriggered()
                    if (IpSplitTunnelingController.routeMode !== root.routeModesModel[selectedIndex].type) {
                        IpSplitTunnelingController.routeMode = root.routeModesModel[selectedIndex].type
                    }
                }

                Component.onCompleted: {
                    if (root.routeModesModel[selectedIndex].type === IpSplitTunnelingController.routeMode) {
                        selector.text = selectedText
                    } else {
                        selector.text = root.routeModesModel[0].name
                    }
                }

                Connections {
                    target: IpSplitTunnelingController
                    function onRouteModeChanged() {
                        selectedIndex = getRouteModesModelIndex()
                    }
                }
            }
        }

        Rectangle {
            id: reconnectNoticeBanner
            objectName: "reconnectNoticeBanner"

            Layout.fillWidth: true
            Layout.topMargin: 16
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.preferredHeight: reconnectNoticeContent.implicitHeight + 24

            visible: root.pageEnabled && ConnectionController.isConnected
            radius: 8
            color: AmneziaStyle.color.softGoldenApricot

            RowLayout {
                id: reconnectNoticeContent

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 12
                anchors.rightMargin: 12

                spacing: 8

                Image {
                    source: "qrc:/images/controls/info.svg"
                    sourceSize: Qt.size(20, 20)
                    Layout.alignment: Qt.AlignTop
                }

                CaptionTextType {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: AmneziaStyle.color.paleGray
                    text: qsTr("You can edit the site list while connected, but changes to which sites use the VPN only take effect after you reconnect.")
                }
            }
        }

        DividerType {
            Layout.topMargin: 16
            Layout.leftMargin: 16
            Layout.rightMargin: 16
        }

        LabelWithButtonType {
            id: sitePresetsButton
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16

            enabled: root.pageEnabled

            text: qsTr("Add Russian services preset")
            descriptionText: qsTr("Bypass the VPN for Russian banks, marketplaces and government sites")
            rightImageSource: "qrc:/images/controls/chevron-right.svg"

            clickedFunction: function() {
                sitePresetsDrawer.openTriggered()
            }
        }
    }

    ListViewType {
        id: listView

        ScrollBar.vertical: ScrollBarType { policy: ScrollBar.AlwaysOn }

        anchors.top: header.bottom
        anchors.topMargin: 16
        anchors.bottom: parent.bottom
        anchors.bottomMargin: addSiteButton.implicitHeight + 48 + (searchField.textField.activeFocus ? 0 : PageController.imeHeight)

        width: parent.width

        enabled: root.pageEnabled
        clip: true

        model: SortFilterProxyModel {
            id: proxyIpSplitTunnelingModel
            sourceModel: IpSplitTunnelingModel
            filters: [
                AnyOf {
                    RegExpFilter {
                        roleName: "url"
                        pattern: ".*" + searchField.textField.text + ".*"
                        caseSensitivity: Qt.CaseInsensitive
                    }
                    RegExpFilter {
                        roleName: "ip"
                        pattern: ".*" + searchField.textField.text + ".*"
                        caseSensitivity: Qt.CaseInsensitive
                    }
                }
            ]
        }

        delegate: ColumnLayout {
            width: listView.width

            LabelWithButtonType {
                id: site
                Layout.fillWidth: true

                text: url
                descriptionText: ip
                rightImageSource: "qrc:/images/controls/trash.svg"
                rightImageColor: AmneziaStyle.color.paleGray

                clickedFunction: function() {
                    var headerText = qsTr("Remove ") + url + "?"
                    var yesButtonText = qsTr("Continue")
                    var noButtonText = qsTr("Cancel")

                    var yesButtonFunction = function() {
                        IpSplitTunnelingController.removeSite(proxyIpSplitTunnelingModel.mapToSource(index))
                        if (!GC.isMobile()) {
                            site.rightButton.forceActiveFocus()
                        }
                    }
                    var noButtonFunction = function() {
                        if (!GC.isMobile()) {
                            site.rightButton.forceActiveFocus()
                        }
                    }

                    showQuestionDrawer(headerText, "", yesButtonText, noButtonText, yesButtonFunction, noButtonFunction)
                }
            }

            DividerType {}
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        
        height: addSiteButton.implicitHeight + 48
        
        color: AmneziaStyle.color.midnightBlack
        
        RowLayout {
            id: addSiteButton

            enabled: root.pageEnabled

            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 24
            anchors.rightMargin: 16
            anchors.leftMargin: 16
            anchors.bottomMargin: 24

            TextFieldWithHeaderType {
                id: searchField

                Layout.fillWidth: true
                rightButtonClickedOnEnter: true

                textField.placeholderText: qsTr("website or IP")
                buttonImageSource: "qrc:/images/controls/plus.svg"

                clickedFunc: function() {
                    PageController.showBusyIndicator(true)
                    IpSplitTunnelingController.addSite(textField.text)
                    textField.text = ""
                    PageController.showBusyIndicator(false)
                }
            }

            ImageButtonType {
                id: addSiteButtonImage
                implicitWidth: 56
                implicitHeight: 56

                image: "qrc:/images/controls/more-vertical.svg"
                imageColor: AmneziaStyle.color.paleGray

                onClicked: function () {
                    moreActionsDrawer.openTriggered()
                }

                Keys.onReturnPressed: addSiteButtonImage.clicked()
                Keys.onEnterPressed: addSiteButtonImage.clicked()
            }
        }
    }

    DrawerType2 {
        id: moreActionsDrawer

        anchors.fill: parent
        expandedHeight: parent.height * 0.4375

        expandedStateContent: ColumnLayout {
            id: moreActionsDrawerContent

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right

            Header2Type {
                Layout.fillWidth: true
                Layout.margins: 16

                headerText: qsTr("Additional options")
            }

            LabelWithButtonType {
                id: importSitesButton
                Layout.fillWidth: true

                text: qsTr("Import")
                rightImageSource: "qrc:/images/controls/chevron-right.svg"

                clickedFunction: function() {
                    importSitesDrawer.openTriggered()
                }
            }

            DividerType {}

            LabelWithButtonType {
                id: exportSitesButton
                Layout.fillWidth: true
                text: qsTr("Save site list")

                clickedFunction: function() {
                    var fileName = ""
                    if (GC.isMobile()) {
                        fileName = "amnezia_sites.json"
                    } else {
                        fileName = SystemController.getFileName(qsTr("Save sites"),
                                                                qsTr("Sites files (*.json)"),
                                                                StandardPaths.standardLocations(StandardPaths.DocumentsLocation) + "/amnezia_sites",
                                                                true,
                                                                ".json")
                    }
                    if (fileName !== "") {
                        PageController.showBusyIndicator(true)
                        IpSplitTunnelingController.exportSites(fileName)
                        moreActionsDrawer.closeTriggered()
                        PageController.showBusyIndicator(false)
                    }
                }
            }

            DividerType {}
            
            LabelWithButtonType {
                id: clearSitesButton
                Layout.fillWidth: true

                text: qsTr("Clear site list")

                clickedFunction: function() {
                    var headerText = qsTr("Clear site list?")
                    var descriptionText = qsTr("All sites will be removed from list.")
                    var yesButtonText = qsTr("Continue")
                    var noButtonText = qsTr("Cancel")

                    var yesButtonFunction = function() {
                        PageController.showBusyIndicator(true)
                        IpSplitTunnelingController.removeSites()
                        PageController.showBusyIndicator(false)
                    }
                    var noButtonFunction = function() {
                        
                    }

                    showQuestionDrawer(headerText, descriptionText, yesButtonText, noButtonText, yesButtonFunction, noButtonFunction)
                }
            }

            DividerType {}
        }
    }

    DrawerType2 {
        id: importSitesDrawer

        anchors.fill: parent
        expandedHeight: parent.height * 0.4375

        expandedStateContent: Item {
            implicitHeight: importSitesDrawer.expandedHeight

            BackButtonType {
                id: importSitesDrawerBackButton

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 16

                backButtonFunction: function() {
                    importSitesDrawer.closeTriggered()
                }
                
                onFocusChanged: {
                    if (this.activeFocus) {
                        importSitesDrawerListView.positionViewAtBeginning()
                    }
                }
            }

            ListViewType {
                id: importSitesDrawerListView

                anchors.top: importSitesDrawerBackButton.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                header: ColumnLayout {
                    width: importSitesDrawerListView.width

                    Header2Type {
                        Layout.fillWidth: true
                        Layout.margins: 16

                        headerText: qsTr("Import a list of sites")
                    }
                }

                model: importOptions

                delegate: ColumnLayout {
                    width: importSitesDrawerListView.width

                    LabelWithButtonType {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16

                        text: title

                        clickedFunction: function() {
                            clickedHandler()
                        }
                    }

                    DividerType {}
                }
            }
        }
    }

    DrawerType2 {
        id: sitePresetsDrawer

        anchors.fill: parent
        expandedHeight: parent.height * 0.6

        expandedStateContent: Item {
            implicitHeight: sitePresetsDrawer.expandedHeight

            BackButtonType {
                id: sitePresetsDrawerBackButton

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 16

                backButtonFunction: function() {
                    sitePresetsDrawer.closeTriggered()
                }

                onFocusChanged: {
                    if (this.activeFocus) {
                        sitePresetsDrawerListView.positionViewAtBeginning()
                    }
                }
            }

            ListViewType {
                id: sitePresetsDrawerListView

                anchors.top: sitePresetsDrawerBackButton.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                header: ColumnLayout {
                    width: sitePresetsDrawerListView.width

                    Header2Type {
                        Layout.fillWidth: true
                        Layout.margins: 16

                        headerText: qsTr("Add Russian services preset")
                    }

                    CaptionTextType {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.bottomMargin: 8

                        color: AmneziaStyle.color.mutedGray
                        wrapMode: Text.WordWrap
                        text: qsTr("These Russian services and banks track the IP addresses of servers that connect to them, which puts VPN server IPs at risk of being blocked. Adding a preset routes that service directly through your own connection instead of the VPN.")
                    }

                    DividerType {}
                }

                model: sitePresetOptions

                delegate: ColumnLayout {
                    width: sitePresetsDrawerListView.width

                    LabelWithButtonType {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16

                        text: title
                        descriptionText: description

                        clickedFunction: function() {
                            clickedHandler()
                        }
                    }

                    DividerType {}
                }
            }
        }
    }

    property list<QtObject> importOptions: [
        replaceOption,
        addOption,
    ]

    property list<QtObject> sitePresetOptions: [
        presetAll,
        presetSberBank,
        presetTBank,
        presetVtb,
        presetAlfaBank,
        presetOzonBank,
        presetGosuslugi,
        presetGovernmentOther,
        presetYandex,
        presetVk,
        presetVkVideo,
        presetOk,
        presetMax,
        presetWildberries,
        presetOzon,
        presetMagnit,
        presetPerekrestok,
        presetDetskiyMir,
        presetGoldApple,
        presetSamokat,
        preset2gis,
    ]

    QtObject {
        id: replaceOption

        readonly property string title: qsTr("Replace site list")
        readonly property var clickedHandler: function() {
            var fileName = SystemController.getFileName(qsTr("Open sites file"),
                                                        qsTr("Sites files (*.json)"))
            if (fileName !== "") {
                root.importSites(fileName, true)
            }
        }
    }

    QtObject {
        id: addOption

        readonly property string title: qsTr("Add imported sites to existing ones")
        readonly property var clickedHandler: function() {
            var fileName = SystemController.getFileName(qsTr("Open sites file"),
                                                        qsTr("Sites files (*.json)"))
            if (fileName !== "") {
                root.importSites(fileName, false)
            }
        }
    }

    QtObject {
        id: presetAll
        readonly property string title: qsTr("All of the above")
        readonly property string description: qsTr("Adds every preset below in one go")
        readonly property var clickedHandler: function() { root.addAllPresets() }
    }

    QtObject {
        id: presetSberBank
        readonly property string title: qsTr("SberBank")
        readonly property string description: "6 " + qsTr("domains")
        readonly property var clickedHandler: function() { root.addPreset(":/splitTunnelingPresets/SberBank.json") }
    }

    QtObject {
        id: presetTBank
        readonly property string title: qsTr("T-Bank")
        readonly property string description: "10 " + qsTr("domains")
        readonly property var clickedHandler: function() { root.addPreset(":/splitTunnelingPresets/T-BANK.json") }
    }

    QtObject {
        id: presetVtb
        readonly property string title: qsTr("VTB")
        readonly property string description: "11 " + qsTr("domains")
        readonly property var clickedHandler: function() { root.addPreset(":/splitTunnelingPresets/VTB.json") }
    }

    QtObject {
        id: presetAlfaBank
        readonly property string title: qsTr("Alfa-Bank")
        readonly property string description: "577 " + qsTr("domains")
        readonly property var clickedHandler: function() { root.addPreset(":/splitTunnelingPresets/AlfaBank.json") }
    }

    QtObject {
        id: presetOzonBank
        readonly property string title: qsTr("Ozon Bank")
        readonly property string description: "8 " + qsTr("domains")
        readonly property var clickedHandler: function() { root.addPreset(":/splitTunnelingPresets/OZON_BANK.json") }
    }

    QtObject {
        id: presetGosuslugi
        readonly property string title: qsTr("Gosuslugi")
        readonly property string description: "30 " + qsTr("domains")
        readonly property var clickedHandler: function() { root.addPreset(":/splitTunnelingPresets/Gosuslugi.json") }
    }

    QtObject {
        id: presetGovernmentOther
        readonly property string title: qsTr("Other government sites")
        readonly property string description: "8 " + qsTr("domains")
        readonly property var clickedHandler: function() { root.addPreset(":/splitTunnelingPresets/Goverment_OTHER.json") }
    }

    QtObject {
        id: presetYandex
        readonly property string title: qsTr("Yandex ecosystem")
        readonly property string description: "134 " + qsTr("domains")
        readonly property var clickedHandler: function() { root.addPreset(":/splitTunnelingPresets/Yandex-ALL.json") }
    }

    QtObject {
        id: presetVk
        readonly property string title: qsTr("VK")
        readonly property string description: "27 " + qsTr("domains")
        readonly property var clickedHandler: function() { root.addPreset(":/splitTunnelingPresets/VK.json") }
    }

    QtObject {
        id: presetVkVideo
        readonly property string title: qsTr("VK Video")
        readonly property string description: "81 " + qsTr("domains")
        readonly property var clickedHandler: function() { root.addPreset(":/splitTunnelingPresets/VK-VIDEO.json") }
    }

    QtObject {
        id: presetOk
        readonly property string title: qsTr("Odnoklassniki")
        readonly property string description: "15 " + qsTr("domains")
        readonly property var clickedHandler: function() { root.addPreset(":/splitTunnelingPresets/OK.json") }
    }

    QtObject {
        id: presetMax
        readonly property string title: qsTr("MAX messenger")
        readonly property string description: "20 " + qsTr("domains")
        readonly property var clickedHandler: function() { root.addPreset(":/splitTunnelingPresets/MAX.json") }
    }

    QtObject {
        id: presetWildberries
        readonly property string title: qsTr("Wildberries")
        readonly property string description: "64 " + qsTr("domains")
        readonly property var clickedHandler: function() { root.addPreset(":/splitTunnelingPresets/Wildberries.json") }
    }

    QtObject {
        id: presetOzon
        readonly property string title: qsTr("OZON")
        readonly property string description: "20 " + qsTr("domains")
        readonly property var clickedHandler: function() { root.addPreset(":/splitTunnelingPresets/OZON.json") }
    }

    QtObject {
        id: presetMagnit
        readonly property string title: qsTr("Magnit")
        readonly property string description: "359 " + qsTr("domains")
        readonly property var clickedHandler: function() { root.addPreset(":/splitTunnelingPresets/MAGNIT.json") }
    }

    QtObject {
        id: presetPerekrestok
        readonly property string title: qsTr("Perekrestok")
        readonly property string description: "99 " + qsTr("domains")
        readonly property var clickedHandler: function() { root.addPreset(":/splitTunnelingPresets/Perekrestok.json") }
    }

    QtObject {
        id: presetDetskiyMir
        readonly property string title: qsTr("Detsky Mir")
        readonly property string description: "279 " + qsTr("domains")
        readonly property var clickedHandler: function() { root.addPreset(":/splitTunnelingPresets/Detskiy-Mir.json") }
    }

    QtObject {
        id: presetGoldApple
        readonly property string title: qsTr("Gold Apple")
        readonly property string description: "150 " + qsTr("domains")
        readonly property var clickedHandler: function() { root.addPreset(":/splitTunnelingPresets/GOLD-APPLE.json") }
    }

    QtObject {
        id: presetSamokat
        readonly property string title: qsTr("Samokat")
        readonly property string description: "15 " + qsTr("domains")
        readonly property var clickedHandler: function() { root.addPreset(":/splitTunnelingPresets/SAMOKAT.json") }
    }

    QtObject {
        id: preset2gis
        readonly property string title: qsTr("2GIS")
        readonly property string description: "41 " + qsTr("domains")
        readonly property var clickedHandler: function() { root.addPreset(":/splitTunnelingPresets/2GIS.json") }
    }

    readonly property var allPresetFiles: [
        ":/splitTunnelingPresets/SberBank.json",
        ":/splitTunnelingPresets/T-BANK.json",
        ":/splitTunnelingPresets/VTB.json",
        ":/splitTunnelingPresets/AlfaBank.json",
        ":/splitTunnelingPresets/OZON_BANK.json",
        ":/splitTunnelingPresets/Gosuslugi.json",
        ":/splitTunnelingPresets/Goverment_OTHER.json",
        ":/splitTunnelingPresets/Yandex-ALL.json",
        ":/splitTunnelingPresets/VK.json",
        ":/splitTunnelingPresets/VK-VIDEO.json",
        ":/splitTunnelingPresets/OK.json",
        ":/splitTunnelingPresets/MAX.json",
        ":/splitTunnelingPresets/Wildberries.json",
        ":/splitTunnelingPresets/OZON.json",
        ":/splitTunnelingPresets/MAGNIT.json",
        ":/splitTunnelingPresets/Perekrestok.json",
        ":/splitTunnelingPresets/Detskiy-Mir.json",
        ":/splitTunnelingPresets/GOLD-APPLE.json",
        ":/splitTunnelingPresets/SAMOKAT.json",
        ":/splitTunnelingPresets/2GIS.json",
    ]

    function addPreset(fileName) {
        PageController.showBusyIndicator(true)
        IpSplitTunnelingController.importSites(fileName, false)
        PageController.showBusyIndicator(false)
        sitePresetsDrawer.closeTriggered()
        moreActionsDrawer.closeTriggered()
    }

    function addAllPresets() {
        PageController.showBusyIndicator(true)
        for (var i = 0; i < root.allPresetFiles.length; i++) {
            IpSplitTunnelingController.importSites(root.allPresetFiles[i], false)
        }
        PageController.showBusyIndicator(false)
        sitePresetsDrawer.closeTriggered()
        moreActionsDrawer.closeTriggered()
    }

    function importSites(fileName, replaceExistingSites) {
        PageController.showBusyIndicator(true)
        IpSplitTunnelingController.importSites(fileName, replaceExistingSites)
        PageController.showBusyIndicator(false)
        importSitesDrawer.closeTriggered()
        moreActionsDrawer.closeTriggered()
    }
}
