import QtQuick
import QtQuick.Effects

Item {
    id: root

    property real maxWidth: 0
    property real fadeSize: 22
    property color indicatorColor: "#b3647d7d"
    default property alias content: flick.flickableData

        width: Math.min(flick.contentWidth, maxWidth)

        readonly property bool overflowing: flick.contentWidth > width + 0.5
        readonly property real maxX: Math.max(0, flick.contentWidth - flick.width)
        readonly property real leftTarget: (overflowing && flick.contentX > 1) ? 1 : 0
        readonly property real rightTarget: (overflowing && flick.contentX < maxX - 1) ? 1 : 0

        // Not readonly, so Behavior can animate them
        property real leftAmt: leftTarget
        property real rightAmt: rightTarget

        Behavior on leftAmt { NumberAnimation { duration: 150 } }
        Behavior on rightAmt { NumberAnimation { duration: 150 } }

        Flickable {
            id: flick
            anchors.fill: parent
            clip: true
            contentWidth: contentItem.childrenRect.width
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            // Fade the edges using a mask (only while overflowing)
            layer.enabled: root.overflowing
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: fadeMask
            }
        }

        // Mask: opaque in the middle, transparent at edges that can still scroll
        Item {
            id: fadeMask
            anchors.fill: parent
            visible: false
            layer.enabled: true

            readonly property real f: Math.min(0.45, root.fadeSize / Math.max(1, root.width))

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0;                color: Qt.rgba(1, 1, 1, 1 - root.leftAmt) }
                    GradientStop { position: fadeMask.f;         color: "white" }
                    GradientStop { position: 1 - fadeMask.f;     color: "white" }
                    GradientStop { position: 1.0;                color: Qt.rgba(1, 1, 1, 1 - root.rightAmt) }
                }
            }
        }

        // Scroll indicator
        Rectangle {
            id: indicator
            height: 2
            radius: 1
            anchors.bottom: parent.bottom
            color: root.indicatorColor
            width: Math.max(16, root.width * (flick.width / Math.max(1, flick.contentWidth)))
            x: root.maxX > 0 ? (flick.contentX / root.maxX) * (root.width - width) : 0
            opacity: root.overflowing && (flick.moving || hover.hovered || hideTimer.running) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        HoverHandler { id: hover }

        Timer { id: hideTimer; interval: 900 }

        WheelHandler {
            onWheel: (e) => {
                flick.contentX = Math.max(0, Math.min(root.maxX,
                                                      flick.contentX - (e.angleDelta.y || e.angleDelta.x)))
                hideTimer.restart()
            }
        }
}
