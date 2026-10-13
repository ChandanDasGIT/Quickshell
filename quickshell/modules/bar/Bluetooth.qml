import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland

Item {
    id: btRoot
    implicitWidth: btSeg.implicitWidth
    implicitHeight: btSeg.implicitHeight

    // ---- Bluetooth state (native, live-updating) ----
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btPowered: adapter ? adapter.enabled : false
    readonly property bool btBusy: adapter
    ? (adapter.state === BluetoothAdapterState.Enabling
    || adapter.state === BluetoothAdapterState.Disabling)
    : false
    readonly property bool isScanning: adapter ? adapter.discovering : false

    readonly property var connectedDevice: {
        const devs = Bluetooth.devices.values;
        for (let i = 0; i < devs.length; i++) {
            if (devs[i].connected) return devs[i];
        }
        return null;
    }
    readonly property bool btConnected: connectedDevice !== null
    readonly property string btDeviceName: connectedDevice ? connectedDevice.name : "None"

    // Stop scanning automatically so discovery doesn't run forever
    Timer {
        id: scanStopTimer
        interval: 8000
        onTriggered: { if (btRoot.adapter) btRoot.adapter.discovering = false }
    }

    function toggleScan() {
        if (!adapter) return;
        if (adapter.discovering) {
            adapter.discovering = false;
            scanStopTimer.stop();
        } else {
            adapter.discovering = true;
            scanStopTimer.restart();
        }
    }

    // Unnamed devices show up with their MAC (dashed) as the name; hide those
    function isNamed(dev) {
        if (!dev || !dev.name || dev.name === "") return false;
        return dev.name.replace(/-/g, ":").toUpperCase() !== dev.address.toUpperCase();
    }
    // Only named devices; rebuilds when devices or their names change
    ScriptModel {
        id: btModel
        values: Bluetooth.devices.values.filter(function(d) { return btRoot.isNamed(d) })
    }

    // ================= REUSABLE STYLED COMPONENTS =================
    component ActionButton: Rectangle {
        id: btnRoot
        property string icon: ""
        property string text: ""
        property bool active: false
        property bool busy: false
        signal clicked()

        Layout.fillWidth: true
        implicitHeight: 32
        radius: 6
        color: btnMouse.containsMouse && !busy
        ? (active ? "#b4befe" : "#313244")
        : (active ? "#89b4fa" : "#1e1e2e")

        RowLayout {
            anchors.centerIn: parent
            spacing: 8
            Text {
                visible: !btnRoot.busy
                text: btnRoot.icon
                color: btnRoot.active ? "#11111b" : "#cdd6f4"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
            }
            Text {
                id: spinner
                visible: btnRoot.busy
                text: "\uf110"
                color: btnRoot.active ? "#11111b" : "#cdd6f4"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                RotationAnimator on rotation {
                    from: 0; to: 360; duration: 1000
                    loops: Animation.Infinite; running: spinner.visible
                }
            }
            Text {
                text: btnRoot.text
                color: btnRoot.active ? "#11111b" : "#cdd6f4"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true
            }
        }
        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: btnRoot.busy ? Qt.WaitCursor : Qt.PointingHandCursor
            onClicked: { if (!btnRoot.busy) btnRoot.clicked() }
        }
    }

    component InfoRow: RowLayout {
        property string icon: ""
        property string name: ""
        property string value: "--"

        Layout.fillWidth: true
        spacing: 8
        Text {
            text: icon; color: "#89b4fa"
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
            Layout.preferredWidth: 18; horizontalAlignment: Text.AlignHCenter
        }
        Text {
            text: name; color: "#a6adc8"
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
            Layout.fillWidth: true
        }
        Text {
            text: value; color: "#cdd6f4"
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true
            horizontalAlignment: Text.AlignRight
        }
    }

    // ================= DEVICE DELEGATE =================
    component BtDelegate: ColumnLayout {
        id: delRoot
        required property var modelData
        required property int index

        readonly property bool isSelected: ListView.view.currentIndex === index
        readonly property bool isConnecting:
        modelData.state === BluetoothDeviceState.Connecting
        || modelData.state === BluetoothDeviceState.Disconnecting

        width: ListView.view.width
        spacing: 4

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: 6
            color: rowMouse.containsMouse || delRoot.isSelected ? "#313244" : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Text {
                    text: delRoot.modelData.connected ? "\uf294" : "\uf293"
                    color: delRoot.modelData.connected ? "#a6e3a1" : "#cdd6f4"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                }
                Text {
                    text: delRoot.modelData.name
                    color: delRoot.modelData.connected ? "#a6e3a1" : "#cdd6f4"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                    font.bold: delRoot.modelData.connected
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Text {
                    id: rowSpinner
                    visible: delRoot.isConnecting
                    text: "\uf110"; color: "#89b4fa"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                    RotationAnimator on rotation {
                        from: 0; to: 360; duration: 1000
                        loops: Animation.Infinite; running: rowSpinner.visible
                    }
                }
            }
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const view = delRoot.ListView.view;
                    view.currentIndex = (view.currentIndex === delRoot.index) ? -1 : delRoot.index;
                    Qt.callLater(function() { view.positionViewAtIndex(delRoot.index, ListView.Contain) });
                }
            }
        }

        // Expandable action area
        Rectangle {
            visible: delRoot.isSelected && !delRoot.isConnecting
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: 4
            color: actionMouse.containsMouse
            ? (delRoot.modelData.connected ? "#f38ba8" : "#b4befe")
            : (delRoot.modelData.connected ? "#eba0ac" : "#89b4fa")

            Text {
                anchors.centerIn: parent
                text: delRoot.modelData.connected ? "Disconnect" : "Connect"
                color: "#11111b"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true
            }
            MouseArea {
                id: actionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (delRoot.modelData.connected) delRoot.modelData.disconnect();
                    else delRoot.modelData.connect();
                    delRoot.ListView.view.currentIndex = -1;
                }
            }
        }
    }

    // ================= MAIN BAR WIDGET =================
    Rectangle {
        id: btSeg
        color: btMouseArea.containsMouse ? "#33ffffff" : "transparent"
        radius: 4
        implicitHeight: 24
        implicitWidth: btIcon.implicitWidth + 12

        Text {
            id: btIcon
            anchors.centerIn: parent
            text: {
                if (!btRoot.btPowered) return "\uDB80\uDCB2";    // bluetooth off (crossed out)
                if (btRoot.btConnected) return "\uDB80\uDCB1";   // bluetooth connected
                return "\uDB80\uDCAF";                           // bluetooth on
            }
            color: {
                if (!btRoot.btPowered) return "#ffffff";         // soft red when off
                if (btRoot.btConnected) return "#89b4fa";        // blue when connected
                return Theme.iconColor;                          // normal when on, not connected
            }
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
        }
        MouseArea {
            id: btMouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: btPopup.visible = !btPopup.visible
        }
    }

    PopupWindow {
        id: btPopup
        visible: false
        color: "transparent"

        anchor {
            item: btSeg
            edges: Edges.Bottom
            gravity: Edges.Bottom
        }
        implicitWidth: 280
        implicitHeight: 420
        mask: Region { item: btCard }

        HyprlandFocusGrab {
            id: btGrab
            windows: [btPopup]
            onActiveChanged: { if (!active) btPopup.visible = false }
        }

        onVisibleChanged: {
            if (visible) {
                Qt.callLater(function() { btGrab.active = true });
            } else {
                btGrab.active = false;
                btList.currentIndex = -1;
                scanStopTimer.stop();
                if (btRoot.adapter) btRoot.adapter.discovering = false;
            }
        }

        Rectangle {
            id: btCard
            anchors.top: parent.top
            anchors.topMargin: 6
            width: parent.width
            height: btCol.implicitHeight + 20
            clip: true
            radius: 12
            color: "#161622"
            border.color: "#2a2a3a"
            border.width: 1

            Behavior on height {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                id: btCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 10
                spacing: 8

                ActionButton {
                    icon: btRoot.btPowered ? "\uf205" : "\uf204"
                    text: !btRoot.adapter ? "No Adapter"
                    : (btRoot.btPowered ? "Bluetooth On" : "Bluetooth Off")
                    active: btRoot.btPowered
                    busy: btRoot.btBusy
                    onClicked: { if (btRoot.adapter) btRoot.adapter.enabled = !btRoot.adapter.enabled }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#313244" }

                InfoRow {
                    icon: "\uf294"; name: "Status"
                    value: btRoot.btConnected ? "Connected" : "Disconnected"
                }
                InfoRow {
                    icon: "\uf10b"; name: "Device"
                    value: btRoot.btDeviceName
                    visible: btRoot.btConnected
                }

                Rectangle {
                    Layout.fillWidth: true; height: 1; color: "#313244"
                    visible: btRoot.btPowered
                }

                RowLayout {
                    visible: btRoot.btPowered
                    Layout.fillWidth: true

                    Text {
                        text: "Available Devices"
                        color: "#cdd6f4"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        radius: 4
                        color: scanMouse.containsMouse ? "#313244" : "transparent"

                        Text {
                            id: scanIcon
                            anchors.centerIn: parent
                            text: "\uf021"
                            color: btRoot.isScanning ? "#89b4fa" : "#a6adc8"
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12

                            RotationAnimator on rotation {
                                from: 0; to: 360; duration: 1000
                                loops: Animation.Infinite; running: btRoot.isScanning
                            }
                        }
                        MouseArea {
                            id: scanMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: btRoot.toggleScan()
                        }
                    }
                }

                ListView {
                    id: btList
                    readonly property int maxRows: 5
                    readonly property real maxListHeight: maxRows * 32 + (maxRows - 1) * spacing

                    visible: btRoot.btPowered && count > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, maxListHeight)
                    clip: true
                    spacing: 2
                    currentIndex: -1
                    boundsBehavior: Flickable.StopAtBounds
                    model: btModel
                    delegate: BtDelegate {}

                    add: Transition {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 }
                    }
                    remove: Transition {
                        NumberAnimation { property: "opacity"; to: 0; duration: 120 }
                    }
                    displaced: Transition {
                        NumberAnimation { property: "y"; duration: 180; easing.type: Easing.OutCubic }
                    }

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                }
            }
        }
    }
}
