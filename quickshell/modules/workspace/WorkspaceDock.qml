import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

Rectangle {
    id: root

    required property var activeWorkspaceList
    required property int activeWorkspace
    required property bool isDragging
    required property var parentWindow

    signal pick(int wsId)
    signal focusWindow(var window)
    signal killWindow(var window)
    signal getWindows(int wsId, var callback)

    function getWindowsForWorkspace(wsId) {
        if (wsId < 0) return []
        return Hyprland.toplevels.values.filter(function(t) {
            return t.wayland != null && t.workspace && t.workspace.id === wsId;
        });
    }

    visible: activeWorkspaceList.length > 0 && !isDragging
    height: 48
    radius: 16
    color: "#161622"
    border.color: "#2a2a3a"
    border.width: 1

    Flickable {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        contentWidth: Math.max(width - 24, dockRow.implicitWidth)
        contentHeight: height
        clip: true
        boundsBehavior: Flickable.DragOverBounds

        Row {
            id: dockRow
            anchors.centerIn: parent
            spacing: 8

            Repeater {
                model: root.activeWorkspaceList

                Rectangle {
                    id: wsGroupPill
                    required property int modelData
                    readonly property int wsId: modelData
                    readonly property var wsWindows: root.getWindowsForWorkspace(wsId)
                    readonly property bool isActiveWs: root.activeWorkspace === wsId

                    implicitWidth: groupRow.implicitWidth + 12
                    height: 32
                    radius: 8
                    color: isActiveWs ? "#2a2d42" : "#20202e"
                    border.color: isActiveWs ? "#89b4fa" : "#2a2a3a"
                    border.width: 1

                    Row {
                        id: groupRow
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 4
                            color: "#16161e"
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: wsGroupPill.wsId === 10 ? "0" : wsGroupPill.wsId.toString()
                                color: wsGroupPill.isActiveWs ? "#89b4fa" : "#888888"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.pick(wsGroupPill.wsId)
                            }
                        }

                        Rectangle {
                            width: 1
                            height: 14
                            color: "#2a2a3a"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Row {
                            spacing: 4
                            anchors.verticalCenter: parent.verticalCenter

                            Repeater {
                                model: wsGroupPill.wsWindows

                                Rectangle {
                                    id: dockIconBtn
                                    required property var modelData
                                    property bool hovered: false

                                    width: 24
                                    height: 24
                                    radius: 5
                                    color: (modelData.activated || hovered) ? "#313244" : "transparent"
                                    border.color: modelData.activated ? "#89b4fa" : (hovered ? "#2a2a3a" : "transparent")
                                    border.width: 1

                                    property string appId: modelData.wayland ? modelData.wayland.appId : ""
                                    property var entry: {
                                        if (appId) {
                                            var byId = DesktopEntries.byId(appId) || DesktopEntries.heuristicLookup(appId);
                                            if (byId) return byId;
                                        }
                                        return DesktopEntries.heuristicLookup(modelData.title) || null;
                                    }

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
                                        width: 16
                                        height: 16
                                        source: dockIconBtn.resolveIconPath()
                                        asynchronous: true
                                    }

                                    Rectangle {
                                        visible: modelData.activated
                                        width: 3
                                        height: 3
                                        radius: 1.5
                                        color: "#89b4fa"
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 1.5
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    MouseArea {
                                        id: iconMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                                        onEntered: dockIconBtn.hovered = true
                                        onExited: dockIconBtn.hovered = false

                                        onClicked: (mouse) => {
                                            if (mouse.button === Qt.RightButton) {
                                                root.killWindow(dockIconBtn.modelData)
                                            } else {
                                                root.focusWindow(dockIconBtn.modelData)
                                            }
                                        }
                                    }

                                    PopupWindow {
                                        visible: iconMouseArea.containsMouse && !root.isDragging
                                        color: "transparent"
                                        anchor {
                                            window: root.parentWindow
                                            item: dockIconBtn
                                            edges: Edges.Top
                                            gravity: Edges.Top
                                            margins.bottom: 6
                                        }
                                        implicitWidth: tooltipCol.implicitWidth + 14
                                        implicitHeight: tooltipCol.implicitHeight + 8

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 6
                                            color: "#181825"
                                            border.color: "#2a2a3a"
                                            border.width: 1

                                            Column {
                                                id: tooltipCol
                                                anchors.centerIn: parent
                                                spacing: 2

                                                Text {
                                                    text: dockIconBtn.entry && dockIconBtn.entry.name ? dockIconBtn.entry.name : dockIconBtn.appId
                                                    color: "#89b4fa"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }
                                                Text {
                                                    text: dockIconBtn.modelData.title || ""
                                                    color: "#cdd6f4"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 10
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 1
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
