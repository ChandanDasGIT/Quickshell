//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Qt5Compat.GraphicalEffects

Rectangle {
    id: trayContainer

    property bool wasOpen: false

    implicitWidth: 24
    implicitHeight: 24
    radius: 8
    color: toggleArea.containsMouse || trayPopup.visible
    ? "#33ffffff"
    : "#0f000000"

    Grid {
        anchors.centerIn: parent
        rows: 2
        columns: 2
        spacing: 2

        Repeater {
            model: 4

            Rectangle {
                width: 5
                height: 5
                radius: 1.5
                color: trayPopup.visible ? "#ffffff" : "#cfcfcf"

                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }
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

    PopupWindow {
        id: trayPopup

        width: 220
        height: listColumn.implicitHeight + 16

        color: "transparent"
        visible: false
        grabFocus: true

        anchor.window: Quickshell.windowFor(trayContainer)
        anchor.item: trayContainer
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        onVisibleChanged: if (!visible) menuPopup.visible = false

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
                    visible: SystemTray.items.values.length === 0
                    text: "No tray items"
                    color: "#777777"
                    font.pixelSize: 13
                    height: 32
                    verticalAlignment: Text.AlignVCenter
                }

                Repeater {
                    model: SystemTray.items

                    delegate: Rectangle {
                        id: row

                        required property var modelData

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
                                    row.modelData.activate()
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
