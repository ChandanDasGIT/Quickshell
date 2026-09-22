//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "."

PanelWindow {
    id: bar

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-bar"
    exclusionMode: ExclusionMode.Auto

    anchors {
        top: true
        left: true
        right: true
    }

    height: 34
    implicitHeight: 34
    color: "transparent"

    // Frosted Glass Base Layer
    Rectangle {
        anchors.fill: parent
        // Translucent background: Hex #AARRGGBB (~60% opacity black)
        color: "#99121212"

        // Bottom border only
        Rectangle {
            width: parent.width
            height: 2
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
