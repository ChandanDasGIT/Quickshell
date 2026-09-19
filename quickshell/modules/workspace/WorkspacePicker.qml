pragma Singleton
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool pickerVisible: false

    function toggle() {
        pickerVisible = !pickerVisible
    }

    IpcHandler {
        target: "workspaces"
        function toggle(): void {
            root.toggle()
        }
    }

    Process {
        id: runProc
        command: []
    }

    function pick(n) {
        runProc.command = ["bash", "-c", Quickshell.env("HOME") + "/.config/scripts/workspace_swap.sh " + n]
        runProc.running = true
        root.pickerVisible = false
    }

    PanelWindow {
        id: popup
        visible: root.pickerVisible
        color: "transparent"
        focusable: true

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusiveZone: 0

        // click outside to dismiss
        MouseArea {
            anchors.fill: parent
            onClicked: root.pickerVisible = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: grid.implicitWidth + 32
            height: grid.implicitHeight + 40
            color: "#0d0d0d"
            radius: 12
            border.color: "#2a2a2a"
            border.width: 1

            MouseArea {
                anchors.fill: parent
                onClicked: {} // swallow clicks so they don't hit the outer dismiss area
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12

                Text {
                    text: "SWAP OR MOVE TO WORKSPACE"
                    color: "#888"
                    font.family: "monospace"
                    font.letterSpacing: 1
                    Layout.alignment: Qt.AlignHCenter
                }

                GridLayout {
                    id: grid
                    columns: 5
                    rowSpacing: 10
                    columnSpacing: 10
                    Layout.alignment: Qt.AlignHCenter

                    Repeater {
                        model: 10
                        Rectangle {
                            width: 48
                            height: 48
                            radius: 8
                            color: wsMouse.containsMouse ? "#33ffffff" : "#1a1a1a"
                            border.color: "#2a2a2a"

                            Text {
                                anchors.centerIn: parent
                                text: (index + 1)
                                color: "white"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 16
                            }

                            MouseArea {
                                id: wsMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.pick(index + 1)
                            }
                        }
                    }
                }
            }
        }
    }
}
