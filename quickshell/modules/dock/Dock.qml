// ~/.config/quickshell/modules/dock/Dock.qml
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

PanelWindow {
    id: dockWindow

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Anchor full screen so clicks outside the dock pill hit the dismiss backdrop
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    property bool dockVisible: false
    visible: dockVisible

    onDockVisibleChanged: {
        if (dockVisible) {
            visible = true;
            backdropArea.forceActiveFocus();
        } else {
            hideTimer.start();
        }
    }

    Timer {
        id: hideTimer
        interval: 130
        onTriggered: dockWindow.visible = false
    }

    // Full-screen backdrop area: clicking outside the dock pill dismisses it
    MouseArea {
        id: backdropArea
        anchors.fill: parent
        focus: true
        onClicked: dockWindow.dockVisible = false

        Keys.onPressed: function(event) {
            if (event.key < Qt.Key_0 || event.key > Qt.Key_9) return;

            var digit = event.key - Qt.Key_0;
            var targetWs = (digit === 0) ? 10 : digit;

            if (wsHelper.workspaceList.indexOf(targetWs) === -1) return;

            if (Hyprland.usingLua) {
                Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + targetWs + "\" })");
            } else {
                Hyprland.dispatch("workspace " + targetWs);
            }
            dockWindow.dockVisible = false;
            event.accepted = true;
        }
    }

    QtObject {
        id: wsHelper

        readonly property var workspaceList: {
            var toplevels = Hyprland.toplevels.values;
            var map = {};
            for (var i = 0; i < toplevels.length; i++) {
                var t = toplevels[i];
                if (t.wayland != null && t.workspace && t.workspace.id >= 0) {
                    map[t.workspace.id] = true;
                }
            }
            var list = Object.keys(map).map(function(k) { return parseInt(k); });
            return list.sort(function(a, b) { return a - b; });
        }

        function getWindowsForWorkspace(wsId) {
            return Hyprland.toplevels.values.filter(function(t) {
                return t.wayland != null && t.workspace && t.workspace.id === wsId;
            });
        }
    }

    QtObject {
        id: theme
        readonly property color background: "#1a1a2e"
        readonly property color groupBackground: "#4d2f3f52"
        readonly property color popupBackground: "#f2181825"
        readonly property color accent: "#89b4fa"
        readonly property color iconIdle: "#40313244"
        readonly property color iconActive: "#5545475a"
        readonly property color text: "#cdd6f4"
        readonly property color wsBadgeBg: "#40181825"
        readonly property color wsTagText: "#a6adc8"
        readonly property color borderSubtle: "#26cdd6f4"
        readonly property color divider: "#40ffffff"
    }

    Rectangle {
        id: dockBackground
        implicitWidth: dockRow.implicitWidth + 32
        implicitHeight: dockRow.implicitHeight + 20
        radius: 26
        color: theme.background
        border.width: 1
        border.color: theme.borderSubtle
        anchors.centerIn: parent

        scale: dockWindow.dockVisible ? 1 : 0.92
        opacity: dockWindow.dockVisible ? 1 : 0
        anchors.verticalCenterOffset: dockWindow.dockVisible ? 0 : 12

        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#80000000"
            shadowBlur: 0.6
            shadowVerticalOffset: 6
            shadowOpacity: 0.5
        }

        Row {
            id: dockRow
            anchors.centerIn: parent
            spacing: 12

            // --- Outer Repeater: One section per Workspace ---
            Repeater {
                model: wsHelper.workspaceList

                Rectangle {
                    id: wsGroup
                    required property int modelData
                    readonly property int wsId: modelData
                    readonly property var wsWindows: wsHelper.getWindowsForWorkspace(wsId)

                    implicitWidth: groupCol.implicitWidth + 24
                    implicitHeight: groupCol.implicitHeight + 20
                    radius: 12
                    color: theme.groupBackground
                    border.width: 1
                    border.color: theme.borderSubtle

                    Column {
                        id: groupCol
                        anchors.centerIn: parent
                        spacing: 5 // Reduced spacing to offset the larger badge

                        // Top: The row of open apps in this workspace
                        Row {
                            id: iconsRow
                            spacing: 8
                            anchors.horizontalCenter: parent.horizontalCenter

                            Repeater {
                                model: wsGroup.wsWindows

                                Rectangle {
                                    id: delegateRoot
                                    required property var modelData
                                    property bool hovered: false

                                    width: 64
                                    height: 64
                                    radius: 16
                                    color: (modelData.activated || hovered) ? theme.iconActive : "transparent"
                                    border.color: modelData.activated ? theme.accent : (hovered ? theme.borderSubtle : "transparent")
                                    border.width: (modelData.activated || hovered) ? (modelData.activated ? 3 : 1) : 0

                                    scale: hovered ? 1.12 : 1.0
                                    transformOrigin: Item.Bottom

                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                    Behavior on scale {
                                        NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2 }
                                    }

                                    property string appId: modelData.wayland ? modelData.wayland.appId : ""

                                    property var entry: {
                                        if (appId) {
                                            var byAppId = DesktopEntries.byId(appId) || DesktopEntries.heuristicLookup(appId);
                                            if (byAppId) return byAppId;
                                        }
                                        return DesktopEntries.heuristicLookup(modelData.title) || null;
                                    }

                                    property string iconPath: resolveIconPath()

                                    function resolveIconPath() {
                                        var candidates = [];
                                        if (entry && entry.icon) candidates.push(entry.icon);
                                        if (appId) {
                                            candidates.push(appId, appId.toLowerCase());
                                            if (appId.indexOf(".") !== -1) {
                                                var tail = appId.split(".").pop();
                                                candidates.push(tail, tail.toLowerCase());
                                            }
                                        }
                                        for (var i = 0; i < candidates.length; i++) {
                                            var path = Quickshell.iconPath(candidates[i], true);
                                            if (path.length > 0) return path;
                                        }
                                        return Quickshell.iconPath("image-missing");
                                    }

                                    IconImage {
                                        anchors.centerIn: parent
                                        width: 38
                                        height: 38
                                        source: delegateRoot.iconPath
                                        asynchronous: true
                                    }

                                    Rectangle {
                                        visible: modelData.wayland != null
                                        width: 5; height: 5; radius: 2.5
                                        color: theme.accent
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 4
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onEntered: delegateRoot.hovered = true
                                        onExited: delegateRoot.hovered = false
                                        onClicked: function(mouse) {
                                            var addr = "0x" + modelData.address;
                                            if (mouse.button === Qt.RightButton) {
                                                Hyprland.dispatch("closewindow address:" + addr);
                                                return;
                                            }
                                            if (Hyprland.usingLua) {
                                                Hyprland.dispatch(
                                                    "hl.dsp.focus({ window = \"address:" + addr + "\" })"
                                                );
                                            } else {
                                                Hyprland.dispatch("focuswindow address:" + addr);
                                            }
                                            // Close dock immediately upon selecting an application
                                            dockWindow.dockVisible = false;
                                        }
                                    }

                                    PopupWindow {
                                        id: previewPopup
                                        visible: delegateRoot.hovered && modelData.wayland != null
                                        color: "transparent"

                                        anchor {
                                            window: dockWindow
                                            item: delegateRoot
                                            edges: Edges.Top
                                            gravity: Edges.Top
                                            margins.bottom: 12
                                        }

                                        implicitWidth: 220
                                        implicitHeight: 140

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 12
                                            color: theme.popupBackground
                                            border.color: theme.accent
                                            border.width: 1
                                            clip: true

                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                spacing: 4

                                                ScreencopyView {
                                                    id: preview
                                                    width: parent.width
                                                    height: parent.height - titleLabel.implicitHeight - 4
                                                    captureSource: delegateRoot.hovered ? modelData.wayland : null
                                                    live: delegateRoot.hovered
                                                    paintCursor: false
                                                }

                                                Text {
                                                    id: titleLabel
                                                    width: parent.width
                                                    text: modelData.title
                                                    color: theme.text
                                                    font.pixelSize: 11
                                                    elide: Text.ElideRight
                                                    horizontalAlignment: Text.AlignHCenter
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Bottom: Larger full-width workspace banner
                        Rectangle {
                            width: iconsRow.implicitWidth
                            height: 1
                            color: theme.divider
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Rectangle {
                            id: wsNumberHitbox
                            width: 32
                            height: 24
                            radius: 6
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: wsGroup.wsId === 10 ? "0" : wsGroup.wsId.toString()
                                color: wsNumberArea.containsMouse ? theme.accent : theme.wsTagText
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 16
                                font.letterSpacing: 0.5
                                font.bold: true

                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            MouseArea {
                                id: wsNumberArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (Hyprland.usingLua) {
                                        Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + wsGroup.wsId + "\" })");
                                    } else {
                                        Hyprland.dispatch("workspace " + wsGroup.wsId);
                                    }
                                    dockWindow.dockVisible = false;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "dock"

        function toggle(): void {
            dockWindow.dockVisible = !dockWindow.dockVisible;
        }

        function show(): void {
            dockWindow.dockVisible = true;
        }

        function hide(): void {
            dockWindow.dockVisible = false;
        }
    }
}
