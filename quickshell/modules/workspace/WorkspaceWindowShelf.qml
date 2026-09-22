import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    required property var windowModel
    required property bool isDragging
    required property int targetWs

    signal focusWindow(var window)
    signal killWindow(var window)

    height: listContainer.implicitHeight
    opacity: (!isDragging && targetWs !== -1 && windowModel.length > 0) ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 140 } }

    Rectangle {
        id: listContainer
        width: parent.width
        implicitHeight: listColumn.implicitHeight + 16
        color: "#11111b"
        radius: 16
        border.color: "#2a2a2a"
        border.width: 1

        Column {
            id: listColumn
            anchors.centerIn: parent
            spacing: 6
            width: parent.width - 24

            Repeater {
                model: root.windowModel

                Rectangle {
                    id: listItem
                    required property var modelData

                    width: listColumn.width
                    height: 34
                    radius: 6
                    color: itemMouse.containsMouse
                        ? "#313244"
                        : (modelData.activated ? "#1e1e2e" : "transparent")
                    border.color: modelData.activated ? "#339af0" : (itemMouse.containsMouse ? "#45475a" : "transparent")
                    border.width: 1

                    property string appId: modelData.wayland ? modelData.wayland.appId : ""
                    property var entry: {
                        if (appId) {
                            var byAppId = DesktopEntries.byId(appId) || DesktopEntries.heuristicLookup(appId);
                            if (byAppId) return byAppId;
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

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            source: listItem.resolveIconPath()
                            asynchronous: true
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 28
                            text: {
                                var appName = listItem.entry && listItem.entry.name ? listItem.entry.name : listItem.appId;
                                if (appName && modelData.title) {
                                    return appName + " — " + modelData.title;
                                }
                                return modelData.title || appName || "Window";
                            }
                            color: modelData.activated ? "#ffffff" : "#cdd6f4"
                            font.pixelSize: 12
                            font.family: "JetBrainsMono Nerd Font"
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton) {
                                root.killWindow(listItem.modelData)
                            } else {
                                root.focusWindow(listItem.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
