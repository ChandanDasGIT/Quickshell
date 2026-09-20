pragma Singleton

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    property bool pickerVisible: false
    property var selectedWorkspaces: []
    property var occupiedWorkspaces: []

    // Drag tracking state
    property bool isDragging: false
    property var activeSources: []
    property int anchorWs: -1
    property int currentTargetIndex: -1 // 0-based cell index under cursor

    function toggle() {
        pickerVisible = !pickerVisible
        if (pickerVisible) {
            selectedWorkspaces = []
            isDragging = false
            currentTargetIndex = -1
            refreshOccupied()
        }
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

    // Process to query occupied workspaces (workspaces with at least one window)
    Process {
        id: occupiedProc
        command: ["bash", "-c", "hyprctl workspaces -j | jq -r '[.[] | select(.windows > 0) | .id] | @csv'"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.trim().length === 0) {
                    root.occupiedWorkspaces = []
                    return
                }
                root.occupiedWorkspaces = text.trim().replace(/\"/g, "").split(",")
                .map(x => parseInt(x))
                .filter(x => !isNaN(x))
            }
        }
    }

    function refreshOccupied() {
        occupiedProc.running = true
    }

    // Normal switch / focus
    function pick(n) {
        runProc.command = ["bash", "-c", Quickshell.env("HOME") + "/.config/scripts/workspace_swap.sh " + n]
        runProc.running = true
        root.pickerVisible = false
    }

    // Multi-workspace silent swap
    function swapMultiple(sources, targetBase) {
        if (!sources || sources.length === 0) return

            let srcList = [...sources].sort((a, b) => a - b)

            if (srcList.length === 1) {
                if (srcList[0] === targetBase) return
                    runProc.command = ["bash", "-c", Quickshell.env("HOME") + "/.config/scripts/workspace_swap.sh " + targetBase + " " + srcList[0]]
                    runProc.running = true
                    root.pickerVisible = false
                    return
            }

            let scriptPath = Quickshell.env("HOME") + "/.config/scripts/workspace_swap.sh"
            let cmds = []

            for (let i = 0; i < srcList.length; i++) {
                let src = srcList[i]
                // Wrap 1-10 modularly: if targetBase is 10 (0) and offset is 1, dst becomes 1
                let dst = ((targetBase - 1 + i) % 10) + 1
                if (src !== dst) {
                    cmds.push(scriptPath + " " + dst + " " + src)
                }
            }

            if (cmds.length > 0) {
                runProc.command = ["bash", "-c", cmds.join(" && ")]
                runProc.running = true
            }
            root.selectedWorkspaces = []
            root.pickerVisible = false
    }

    function toggleSelection(ws) {
        let copy = [...selectedWorkspaces]
        let idx = copy.indexOf(ws)
        if (idx !== -1) {
            copy.splice(idx, 1)
        } else {
            copy.push(ws)
        }
        selectedWorkspaces = copy
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

        // Number keys (1-9 switch to 1-9, 0 switches to 10)
        Item {
            focus: root.pickerVisible
            anchors.fill: parent

            Keys.onPressed: (event) => {
                if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                    root.pick(event.key - Qt.Key_0)
                    event.accepted = true
                } else if (event.key === Qt.Key_0) {
                    root.pick(10)
                    event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
                    root.pickerVisible = false
                    event.accepted = true
                }
            }
        }

        // Click outside backdrop to dismiss
        MouseArea {
            anchors.fill: parent
            onClicked: root.pickerVisible = false
        }

        Rectangle {
            id: container
            anchors.centerIn: parent
            width: Math.max(grid.implicitWidth + 48, 440)
            height: layout.implicitHeight + 48
            color: "#0d0d0d"
            radius: 16
            border.color: "#2a2a2a"
            border.width: 1

            MouseArea {
                anchors.fill: parent
                onClicked: {} // Swallow clicks so background dismiss doesn't trigger
            }

            ColumnLayout {
                id: layout
                anchors.centerIn: parent
                spacing: 16
                width: parent.width - 48

                Text {
                    id: headerText
                    text: root.selectedWorkspaces.length > 0
                    ? "DRAGGING " + root.selectedWorkspaces.length + " WORKSPACES (" + root.selectedWorkspaces.sort((a,b)=>a-b).join(", ") + ")"
                    : "CLICK OR 1-9 TO SWITCH\nRIGHT-CLICK TO MULTI-SELECT & DRAG"
                    color: root.selectedWorkspaces.length > 0 ? "#4dabf7" : "#888888"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    font.letterSpacing: 1
                    lineHeight: 1.35
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                }

                GridLayout {
                    id: grid
                    columns: 5
                    rowSpacing: 12
                    columnSpacing: 12
                    Layout.alignment: Qt.AlignHCenter

                    Repeater {
                        id: cellRepeater
                        model: 10

                        DropArea {
                            id: dropTarget
                            width: 60
                            height: 60

                            readonly property int cellIndex: index
                            readonly property int wsNumber: index + 1
                            keys: ["workspace"]

                            onEntered: {
                                root.currentTargetIndex = cellIndex
                            }

                            onExited: {
                                if (root.currentTargetIndex === cellIndex) {
                                    root.currentTargetIndex = -1
                                }
                            }

                            // Base slot tile
                            Rectangle {
                                id: baseSlot
                                anchors.fill: parent
                                radius: 10
                                color: isSelected ? "#163859" : (wsMouse.containsMouse ? "#262626" : "#171717")
                                border.color: isSelected ? "#339af0" : (incomingWs !== -1 ? "#4dabf7" : "#2a2a2a")
                                border.width: isSelected || incomingWs !== -1 ? 2 : 1

                                readonly property bool isSelected: root.selectedWorkspaces.includes(dropTarget.wsNumber)
                                readonly property bool hasWindows: root.occupiedWorkspaces.includes(dropTarget.wsNumber)
                                readonly property int incomingWs: {
                                    if (!root.isDragging || root.currentTargetIndex < 0) return -1

                                        // Calculates circular distance forward from current hovered target index
                                        let offset = (dropTarget.cellIndex - root.currentTargetIndex + 10) % 10
                                        if (offset < root.activeSources.length) {
                                            return root.activeSources[offset]
                                        }
                                        return -1
                                }

                                // Subtle fill tint during hover
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 10
                                    color: "#228be6"
                                    opacity: baseSlot.incomingWs !== -1 ? 0.22 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 120 } }
                                }

                                // Stacked text: Workspace number on top, incoming badge cleanly below
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 1

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: dropTarget.wsNumber === 10 ? "0" : dropTarget.wsNumber
                                        color: baseSlot.isSelected ? "#ffffff" : (baseSlot.incomingWs !== -1 ? "#d0d0d0" : "#aaaaaa")
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: baseSlot.incomingWs !== -1 ? 16 : 18
                                        font.bold: true
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        visible: baseSlot.incomingWs !== -1
                                        text: "(" + (baseSlot.incomingWs === 10 ? "0" : baseSlot.incomingWs) + ")"
                                        color: "#74c0fc"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                }

                                // Active window indicator dot at bottom-right corner
                                Rectangle {
                                    anchors {
                                        right: parent.right
                                        bottom: parent.bottom
                                        margins: 6
                                    }
                                    width: 5
                                    height: 5
                                    radius: 2.5
                                    color: "#4dabf7"
                                    visible: baseSlot.hasWindows
                                }

                                MouseArea {
                                    id: wsMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    drag.target: dragProxy

                                    property real startX: 0
                                    property real startY: 0
                                    property bool wasDragged: false

                                    onPressed: (mouse) => {
                                        if (mouse.button === Qt.RightButton) return
                                            startX = mouse.x
                                            startY = mouse.y
                                            wasDragged = false

                                            if (root.selectedWorkspaces.includes(dropTarget.wsNumber)) {
                                                root.activeSources = [...root.selectedWorkspaces].sort((a,b) => a - b)
                                            } else {
                                                root.activeSources = [dropTarget.wsNumber]
                                            }
                                            root.anchorWs = dropTarget.wsNumber
                                    }

                                    onPositionChanged: {
                                        if (drag.active) {
                                            const dx = mouse.x - startX
                                            const dy = mouse.y - startY
                                            if ((dx * dx + dy * dy) > 16) {
                                                wasDragged = true
                                                root.isDragging = true

                                                let globalPoint = wsMouse.mapToItem(container, mouse.x, mouse.y)
                                                // Anchor to lower-left corner with an 8px offset so the arrow doesn't obscure the card
                                                dragProxy.x = globalPoint.x + 8
                                                dragProxy.y = globalPoint.y - dragProxy.height + 4
                                            }
                                        }
                                    }

                                    onReleased: (mouse) => {
                                        if (mouse.button === Qt.RightButton) {
                                            root.toggleSelection(dropTarget.wsNumber)
                                            return
                                        }

                                        if (wasDragged) {
                                            dragProxy.Drag.drop()
                                        } else {
                                            root.pick(dropTarget.wsNumber)
                                        }

                                        root.isDragging = false
                                        root.currentTargetIndex = -1
                                        wasDragged = false
                                        dragProxy.x = -9999
                                        dragProxy.y = -9999
                                    }
                                }
                            }

                            onDropped: (drop) => {
                                if (root.activeSources && root.activeSources.length > 0) {
                                    root.swapMultiple(root.activeSources, dropTarget.wsNumber)
                                }
                            }
                        }
                    }
                }
            }

            // Floating drag cluster tracking cursor
            Item {
                id: dragProxy
                x: -9999
                y: -9999
                width: proxyRow.implicitWidth
                height: proxyRow.implicitHeight
                z: 999
                visible: root.isDragging

                Drag.active: root.isDragging
                Drag.source: dragProxy
                Drag.keys: ["workspace"]
                // Set hotSpot to lower-left corner
                Drag.hotSpot.x: 0
                Drag.hotSpot.y: height

                Row {
                    id: proxyRow
                    spacing: 8

                    Repeater {
                        model: root.activeSources

                        Rectangle {
                            width: 54
                            height: 54
                            radius: 8
                            color: "#1c4f82"
                            opacity: 0.3
                            border.color: "#4dabf7"
                            border.width: 1.5

                            Text {
                                anchors.centerIn: parent
                                text: modelData === 10 ? "0" : modelData
                                color: "white"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 17
                                font.bold: true
                            }
                        }
                    }
                }
            }
        }
    }
}
