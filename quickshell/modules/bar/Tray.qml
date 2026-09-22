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

    implicitWidth: trayRow.implicitWidth + 16
    implicitHeight: 24

    color: "#0f000000"
    radius: 8

    RowLayout {
        id: trayRow
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: SystemTray.items

            delegate: Rectangle {
                id: trayItem

                required property var modelData

                implicitWidth: 24
                implicitHeight: 24
                radius: 4

                color: mouseArea.containsMouse
                ? "#33ffffff"
                : "transparent"

                IconImage {
                    id: trayIcon
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: modelData.icon
                    mipmap: true
                    visible: false
                }

                Desaturate {
                    anchors.fill: trayIcon
                    source: trayIcon
                    desaturation: 0.0 // 1.0 = fully grayscale, 0.0 = full color
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        if (modelData.hasMenu) {
                            menuPopup.trayMenu = modelData.menu
                            menuPopup.openFor(trayItem)
                        } else {
                            modelData.activate()
                        }
                    }
                }
            }
        }
    }

    PopupWindow {
        id: menuPopup

        property var trayMenu
        property var anchorItem

        width: 280
        height: menuColumn.implicitHeight + 16

        color: "#181818"
        visible: false
        grabFocus: true

        anchor.window: Quickshell.windowFor(trayContainer)

        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom

        function openFor(item) {
            anchorItem = item
            anchor.item = item
            visible = true
        }

        function closeMenu() {
            visible = false
            trayMenu = null
        }

        QsMenuOpener {
            id: menuOpener
            menu: menuPopup.trayMenu
        }

        onVisibleChanged: {
            if (!visible) {
                trayMenu = null
            }
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

                            color: menuMouse.containsMouse
                            ? "#25ffffff"
                            : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10

                                // Deliberately blank.
                                // We do NOT render modelData.icon.

                                Text {
                                    Layout.fillWidth: true

                                    text: menuItem.modelData.text
                                    color: menuItem.modelData.enabled
                                    ? "#ffffff"
                                    : "#777777"

                                    font.pixelSize: 13

                                    elide: Text.ElideRight
                                }

                                // Checkbox / radio indicator
                                Text {
                                    visible: menuItem.modelData.buttonType !== 0

                                    text: menuItem.modelData.checkState
                                    ? "✓"
                                    : ""

                                    color: "#ffffff"
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
                                    menuPopup.closeMenu()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    QsMenuAnchor {
        id: menuAnchor
        anchor.window: Quickshell.windowFor(trayContainer)
        anchor.edges: Edges.Bottom | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
    }
}
