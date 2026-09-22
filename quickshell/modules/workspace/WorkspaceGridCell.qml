import QtQuick

Item {
    id: root
    implicitWidth: 72
    implicitHeight: 72
    width: 72
    height: 72

    property int cellIndex: 0
    readonly property int wsNumber: cellIndex + 1

    property bool isSelected: false
    property bool isInspected: false
    property bool hasWindows: false
    property bool isCurrentActive: false
    property int incomingWs: -1
    property var activeSources: []
    property Item containerItem
    property Item dragProxyItem

    signal targetHovered(int wsNumber)
    signal targetUnhovered(int wsNumber)
    signal pick(int wsNumber)
    signal kill(int wsNumber)
    signal toggleSelection(int wsNumber)
    signal toggleInspect(int wsNumber)
    signal swapTriggered(var sources, int targetWs)
    signal dragEntered(int index)
    signal dragExited(int index)
    signal dragStarted(var sources, int anchorWs)
    signal dragEnded()

    function isShiftActive(mouse) {
        return (mouse.modifiers & Qt.ShiftModifier) !== 0
    }

    DropArea {
        anchors.fill: parent
        keys: ["workspace"]
        onEntered: root.dragEntered(root.cellIndex)
        onExited: root.dragExited(root.cellIndex)
        onDropped: (drop) => {
            if (root.activeSources && root.activeSources.length > 0) {
                root.swapTriggered(root.activeSources, root.wsNumber)
            }
        }
    }

    Rectangle {
        id: baseSlot
        anchors.fill: parent
        radius: 12
        clip: true
        color: root.isSelected
        ? "#163859"
        : (root.isInspected ? "#1e2836" : (wsMouse.containsMouse ? "#262626" : "#171717"))
        border.color: root.isSelected
        ? "#339af0"
        : (root.isInspected ? "#5c7cfa" : (root.incomingWs !== -1 ? "#4dabf7" : "#2a2a2a"))
        border.width: root.isSelected || root.incomingWs !== -1 || root.isInspected ? 2 : 1

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: "#228be6"
            opacity: root.incomingWs !== -1 ? 0.22 : 0.0
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 3
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 22
            radius: 1.5
            color: "#339af0"
            visible: root.isCurrentActive
        }

        Column {
            anchors.centerIn: parent
            spacing: 1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.wsNumber === 10 ? "0" : String(root.wsNumber)
                color: root.isSelected || root.isInspected
                ? "#ffffff"
                : (root.incomingWs !== -1 ? "#d0d0d0" : "#aaaaaa")
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 18
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.incomingWs !== -1
                text: "(" + (root.incomingWs === 10 ? "0" : root.incomingWs) + ")"
                color: "#74c0fc"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                font.bold: true
            }
        }

        Rectangle {
            anchors {
                right: parent.right
                bottom: parent.bottom
                margins: 7
            }
            width: 5
            height: 5
            radius: 2.5
            color: "#4dabf7"
            visible: root.hasWindows
        }
    }

    MouseArea {
        id: wsMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: 10

        property real startX: 0
        property real startY: 0
        property bool wasDragged: false
        property bool shiftHeldOnPress: false

        onEntered: root.targetHovered(root.wsNumber)
        onExited: root.targetUnhovered(root.wsNumber)

        onDoubleClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton && !root.isShiftActive(mouse)) {
                root.pick(root.wsNumber)
            }
        }

        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                root.kill(root.wsNumber)
                return
            }

            shiftHeldOnPress = root.isShiftActive(mouse)
            if (shiftHeldOnPress) {
                root.toggleSelection(root.wsNumber)
                return
            }

            startX = mouse.x
            startY = mouse.y
            wasDragged = false
            root.dragStarted(root.isSelected ? null : [root.wsNumber], root.wsNumber)
        }

        onPositionChanged: (mouse) => {
            if (shiftHeldOnPress) return

                if (mouse.buttons & Qt.LeftButton) {
                    const dx = mouse.x - startX
                    const dy = mouse.y - startY
                    if (!wasDragged && (dx * dx + dy * dy) > 25) {
                        wasDragged = true
                    }

                    if (wasDragged) {
                        let pt = wsMouse.mapToItem(root.containerItem, mouse.x, mouse.y)
                        root.dragProxyItem.x = pt.x + 8
                        root.dragProxyItem.y = pt.y - root.dragProxyItem.height + 4
                    }
                }
        }

        onReleased: (mouse) => {
            if (mouse.button === Qt.RightButton) return

                if (shiftHeldOnPress) {
                    shiftHeldOnPress = false
                    return
                }

                if (wasDragged) {
                    root.dragProxyItem.Drag.drop()
                } else {
                    root.toggleInspect(root.wsNumber)
                }

                wasDragged = false
                root.dragEnded()
        }
    }
}
