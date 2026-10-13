//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Qt5Compat.GraphicalEffects
import Quickshell.Hyprland

Rectangle {
    id: trayContainer

    property bool wasOpen: false

    implicitWidth: 24
    implicitHeight: 24
    radius: 8
    color: toggleArea.containsMouse || trayPopup.visible
    ? "#33ffffff"
    : "#0f000000"

    Text {
        anchors.centerIn: parent
        text: "\u25BC"
        font.pixelSize: 16

        // Keeps the same color changing animation you originally had
        color: trayPopup.visible ? "#ffffff" : "#cfcfcf"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: toggleArea
        anchors.fill: parent
        hoverEnabled: true

        // With grabFocus, a click outside closes the popup first, so remember
        // the state at press time to avoid it instantly reopening.
        onPressed: trayContainer.wasOpen = trayPopup.visible
        onClicked: {
            if (!trayContainer.wasOpen)
                trayPopup.visible = true
        }
    }

    // Hide tray items whose id/title/tooltip contains any of these (lowercase)
    readonly property var hiddenPatterns: [
        "nm-applet",
        "blueman",
        "bluetooth",
        "xwaylandvideobridge",
        "wayland to x"
    ]

    ScriptModel {
        id: trayModel
        values: SystemTray.items.values.filter(function(item) {
            const hay = ((item.id || "") + " " + (item.title || "") + " "
            + (item.tooltipTitle || "")).toLowerCase();
            for (let i = 0; i < trayContainer.hiddenPatterns.length; i++) {
                if (hay.indexOf(trayContainer.hiddenPatterns[i]) >= 0) return false;
            }
            return true;
        })
    }

    PopupWindow {
        id: trayPopup

        implicitWidth: 220
        height: listColumn.implicitHeight + 16

        color: "transparent"
        visible: false
        grabFocus: true

        //anchor.window: Quickshell.windowFor(trayContainer)
        anchor.item: trayContainer
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        onVisibleChanged: {
            if (visible) Hyprland.refreshToplevels()
                else menuPopup.visible = false
        }

        Rectangle {
            anchors.fill: parent
            color: "#181818"
            radius: 10
            border.width: 1
            border.color: "#30ffffff"

            Column {
                id: listColumn

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 8
                }
                spacing: 2

                Text {
                    visible: trayModel.values.length === 0
                    text: "No tray items"
                    color: "#777777"
                    font.pixelSize: 13
                    height: 32
                    verticalAlignment: Text.AlignVCenter
                }

                Repeater {
                    model: trayModel

                    delegate: Rectangle {
                        id: row

                        required property var modelData

                        // Each row keeps its own handle on the app's menu
                        QsMenuOpener {
                            id: rowMenu
                            menu: row.modelData.hasMenu ? row.modelData.menu : null
                        }

                        // Trigger the menu's "Open/Show/Restore" entry; fall back to activate()
                        function norm(s) { return (s || "").toLowerCase().replace(/[^a-z0-9]/g, "") }

                        // Find an already-open window for this tray app
                        function findWindow() {
                            const keys = [row.modelData.id, row.modelData.title, row.modelData.tooltipTitle]
                            .map(norm).filter(function(k) { return k.length >= 3 });
                            const wins = Hyprland.toplevels.values;
                            for (let i = 0; i < wins.length; i++) {
                                const o = wins[i].lastIpcObject;
                                if (!o) continue;
                                const cls = norm(o.class);
                                const init = norm(o.initialClass);
                                for (let k = 0; k < keys.length; k++) {
                                    if (!keys[k]) continue;
                                    if ((cls && (cls.indexOf(keys[k]) >= 0 || keys[k].indexOf(cls) >= 0))
                                        || (init && (init.indexOf(keys[k]) >= 0 || keys[k].indexOf(init) >= 0)))
                                        return wins[i];
                                }
                            }
                            return null;
                        }

                        function openApp() {
                            const win = findWindow();
                            if (win) {
                                Hyprland.dispatch('hl.dsp.focus({ window = "address:0x' + win.address + '" })');
                                return;
                            }

                            // No open window: trigger the menu's Open/Show entry, else activate()
                            const entries = rowMenu.children ? rowMenu.children.values : [];
                            for (let i = 0; i < entries.length; i++) {
                                const e = entries[i];
                                if (e.isSeparator || !e.enabled) continue;
                                const t = (e.text || "").toLowerCase();
                                if (/hide|close|quit|exit/.test(t)) continue;
                                if (/open|show|restore/.test(t)) {
                                    e.triggered();
                                    return;
                                }
                            }
                            row.modelData.activate();
                        }

                        width: listColumn.width
                        height: 32
                        radius: 6
                        color: rowMouse.containsMouse ? "#25ffffff" : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            IconImage {
                                Layout.preferredWidth: 18
                                Layout.preferredHeight: 18
                                source: row.modelData.icon
                                mipmap: true
                            }

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.tooltipTitle
                                || row.modelData.title
                                || row.modelData.id
                                color: "#ffffff"
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton || row.modelData.onlyMenu) {
                                    if (row.modelData.hasMenu) {
                                        var p = row.mapToItem(null, 0, 0)
                                        menuPopup.openFor(row.modelData.menu, p.y, row.height)
                                    }
                                } else {
                                    row.openApp()
                                    trayPopup.visible = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    PopupWindow {
        id: menuPopup

        property var trayMenu

        width: 220
        height: menuColumn.implicitHeight + 16

        color: "transparent"
        visible: false
        grabFocus: true

        anchor.window: trayPopup
        anchor.edges: Edges.Top | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Right

        function openFor(menu, y, h) {
            visible = false
            trayMenu = menu
            anchor.rect.x = trayPopup.width
            anchor.rect.y = y
            anchor.rect.width = 1
            anchor.rect.height = h
            visible = true
        }

        onVisibleChanged: if (!visible) trayMenu = null

        QsMenuOpener {
            id: menuOpener
            menu: menuPopup.trayMenu
        }

        Rectangle {
            anchors.fill: parent
            color: "#181818"
            radius: 10
            border.width: 1
            border.color: "#30ffffff"

            Column {
                id: menuColumn

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 8
                }
                spacing: 2

                Repeater {
                    model: menuOpener.children

                    delegate: Item {
                        id: menuItem

                        required property var modelData

                        width: menuColumn.width
                        height: modelData.isSeparator ? 9 : 32

                        Rectangle {
                            visible: menuItem.modelData.isSeparator
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }
                            height: 1
                            color: "#30ffffff"
                        }

                        Rectangle {
                            visible: !menuItem.modelData.isSeparator
                            anchors.fill: parent
                            radius: 6
                            color: menuMouse.containsMouse ? "#25ffffff" : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10

                                Text {
                                    Layout.fillWidth: true
                                    text: menuItem.modelData.text
                                    color: menuItem.modelData.enabled ? "#ffffff" : "#777777"
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: menuItem.modelData.buttonType !== 0
                                    && menuItem.modelData.checkState
                                    text: "✓"
                                    color: "#ffffff"
                                    font.pixelSize: 13
                                }

                                Text {
                                    visible: menuItem.modelData.hasChildren
                                    text: "›"
                                    color: "#777777"
                                    font.pixelSize: 13
                                }
                            }

                            MouseArea {
                                id: menuMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: menuItem.modelData.enabled

                                onClicked: {
                                    menuItem.modelData.triggered()
                                    menuPopup.visible = false
                                    trayPopup.visible = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
