//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "."

PanelWindow {
    id: bar

    //exclusionMode: ExclusionMode.Normal
    anchors { top: true; left: true; right: true }
    implicitHeight: 34
    color: "#0f000000" // approximates rgba(0,0,0,0.65)

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        border.color: "#80647d7d"
        border.width: 0
        Rectangle {
            width: parent.width
            height: 3
            anchors.bottom: parent.bottom
            color: "#80647d7d"
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: 4

        LeftSection {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }

        CenterSection {
            anchors.centerIn: parent
        }

        RightSection {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
