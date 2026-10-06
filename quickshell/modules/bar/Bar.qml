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
        id: content
        anchors.fill: parent
        anchors.margins: 4

        readonly property int gap: 8
        readonly property real sideWidth: Math.max(0, (width - centerSec.width) / 2 - gap)

        SideScroller {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            maxWidth: content.sideWidth

            LeftSection {
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        CenterSection {
            id: centerSec
            anchors.centerIn: parent
        }

        SideScroller {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            maxWidth: content.sideWidth

            RightSection {
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
