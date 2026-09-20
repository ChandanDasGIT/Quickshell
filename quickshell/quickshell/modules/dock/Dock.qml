// ~/.config/quickshell/modules/dock/Dock.qml
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

PanelWindow {
    id: dockWindow

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    property bool dockVisible: false
    visible: dockVisible

    onDockVisibleChanged: {
        if (dockVisible) {
            visible = true;
        } else {
            hideTimer.start();
        }
    }

    Timer {
        id: hideTimer
        interval: 130
        onTriggered: dockWindow.visible = false
    }

    implicitWidth: dockBackground.implicitWidth
    implicitHeight: dockBackground.implicitHeight

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
        readonly property color background: "#1e1e2e"
        readonly property color groupBackground: "#252538"
        readonly property color popupBackground: "#181825"
        readonly property color accent: "#89b4fa"
        readonly property color iconIdle: "#313244"
        readonly property color iconActive: "#45475a"
        readonly property color text: "#cdd6f4"
        readonly property color wsBadgeBg: "#181825"
        readonly property color wsTagText: "#a6adc8"
    }

    Rectangle {
        id: dockBackground
        implicitWidth: dockRow.implicitWidth + 32
        implicitHeight: dockRow.implicitHeight + 20
        radius: 26
        color: theme.background
        anchors.centerIn: parent

        opacity: dockWindow.dockVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

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

                    implicitWidth: groupCol.implicitWidth + 14
                    implicitHeight: groupCol.implicitHeight + 12
                    radius: 18
                    color: theme.groupBackground

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
                                    radius: 14
                                    color: modelData.activated ? theme.iconActive : theme.iconIdle
                                    border.color: modelData.activated ? theme.accent : "transparent"
                                    border.width: 2

                                    Behavior on color { ColorAnimation { duration: 150 } }

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
                                        }
                                    }

                                    PopupWindow {
                                        id: previewPopup
                                        visible: delegateRoot.hovered && modelData.wayland != null

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
                            height: 26
                            radius: 8
                            color: theme.wsBadgeBg
                            border.color: "#313244"
                            border.width: 1
                            anchors.horizontalCenter: parent.horizontalCenter

                            Text {
                                anchors.centerIn: parent
                                text: wsGroup.wsId === 10 ? "0" : wsGroup.wsId.toString()
                                color: theme.wsTagText
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                font.bold: true
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
