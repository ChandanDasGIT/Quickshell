pragma Singleton

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

Item {
    id: root
    property bool pickerVisible: false
    property var selectedWorkspaces: []
    property var occupiedWorkspaces: []
    property int activeWorkspace: -1
    property int hoveredWs: -1

    // Drag tracking state
    property bool isDragging: false
    property var activeSources: []
    property int anchorWs: -1
    property int currentTargetIndex: -1

    function getWindowsForWorkspace(wsId) {
        if (wsId < 0) return []
            return Hyprland.toplevels.values.filter(function(t) {
                return t.wayland != null && t.workspace && t.workspace.id === wsId;
            });
    }

    function toggle() {
        pickerVisible = !pickerVisible
        if (pickerVisible) {
            selectedWorkspaces = []
            isDragging = false
            currentTargetIndex = -1
            hoveredWs = -1
            refreshState()
        }
    }

    IpcHandler {
        target: "workspaces"
        function toggle(): void {
            root.toggle()
        }
    }

    Process {
        id: switchProc
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

    // Initial query on picker reveal
    Process {
        id: activeWsProc
        command: ["bash", "-c", "hyprctl activeworkspace -j | jq -r '.id'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let id = parseInt(text.trim())
                if (!isNaN(id)) {
                    root.activeWorkspace = id
                }
            }
        }
    }

    // Real-time event listener to track active workspace updates instantly
    Process {
        id: eventListenerProc
        running: true
        command: ["bash", "-c", "socat -U - UNIX-CONNECT:\"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock\""]
        stdout: SplitParser {
            onRead: data => {
                let line = data.trim()
                if (line.startsWith("workspace>>")) {
                    let ws = parseInt(line.replace("workspace>>", "").trim())
                    if (!isNaN(ws)) {
                        root.activeWorkspace = ws
                        refreshTimer.start()
                    }
                } else if (line.startsWith("focusedmon>>")) {
                    let parts = line.replace("focusedmon>>", "").split(",")
                    if (parts.length > 1) {
                        let ws = parseInt(parts[1].trim())
                        if (!isNaN(ws)) {
                            root.activeWorkspace = ws
                            refreshTimer.start()
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 250
        onTriggered: root.refreshState()
    }

    function refreshState() {
        if (occupiedProc.running) occupiedProc.running = false
            occupiedProc.running = true

            if (activeWsProc.running) activeWsProc.running = false
                activeWsProc.running = true
    }

    // Disables cursor jump/warp when changing workspaces from the picker
    function pick(n) {
        root.activeWorkspace = n
        if (switchProc.running) switchProc.running = false

            let cmd = [
                'hyprctl --batch "',
                'keyword cursor:warp_on_change_workspace 0 ; ',
                'dispatch hl.dsp.focus({ workspace = \\"' + n + '\\" }) ; ',
                'keyword cursor:warp_on_change_workspace 1"'
            ].join('')

            switchProc.command = ["bash", "-c", cmd]
                switchProc.running = true
                    refreshTimer.start()
    }

    function swapMultiple(sources, targetBase) {
        if (!sources || sources.length === 0) return

            let srcList = [...sources].sort((a, b) => a - b)

            if (srcList.length === 1) {
                if (srcList[0] === targetBase) return
                    WorkspaceSwap.run(targetBase, srcList[0])
                    refreshTimer.start()
                    return
            }

            let pairs = []
            for (let i = 0; i < srcList.length; i++) {
                let src = srcList[i]
                let dst = ((targetBase - 1 + i) % 10) + 1
                if (src !== dst) {
                    pairs.push({ from: src, to: dst })
                }
            }

            if (pairs.length > 0) {
                WorkspaceSwap.runMulti(pairs)
            }
            root.selectedWorkspaces = []
            refreshTimer.start()
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

    // Closes all toplevel client windows on workspace n using your Lua dispatcher
    function killWorkspace(n) {
        var wins = Hyprland.toplevels.values;
        for (var i = 0; i < wins.length; i++) {
            var w = wins[i];
            if (w.wayland != null && w.workspace && w.workspace.id === n) {
                var cleanAddr = String(w.address).replace(/^0x/, "");
                var fullAddr = "0x" + cleanAddr;
                Hyprland.dispatch('hl.dsp.window.close({ window = "address:' + fullAddr + '" })');
            }
        }
        refreshTimer.start();
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

        MouseArea {
            anchors.fill: parent
            onClicked: root.pickerVisible = false
        }

        // --- Overhead preview shelf (Alt-Tab Style) ---
        Item {
            id: previewShelf
            anchors.bottom: container.top
            anchors.bottomMargin: 16
            anchors.horizontalCenter: container.horizontalCenter
            height: 145
            width: previewRow.implicitWidth

            opacity: (!root.isDragging && previewRepeater.count > 0) ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 140 } }

            Row {
                id: previewRow
                anchors.centerIn: parent
                spacing: 12

                Repeater {
                    id: previewRepeater
                    model: root.getWindowsForWorkspace(root.hoveredWs)

                    Rectangle {
                        id: previewCard
                        required property var modelData

                        width: 220
                        height: 140
                        radius: 12
                        color: "#181825"
                        border.color: modelData.activated ? "#339af0" : "#2a2a2a"
                        border.width: modelData.activated ? 2 : 1
                        clip: true

                        property string appId: modelData.wayland ? modelData.wayland.appId : ""
                        property var entry: {
                            if (appId) {
                                var byAppId = DesktopEntries.byId(appId) || DesktopEntries.heuristicLookup(appId);
                                if (byAppId) return byAppId;
                            }
                            return DesktopEntries.heuristicLookup(modelData.title) || null;
                        }

                        function resolveIconPath() {
                            var candidates = [];
                            if (entry && entry.icon) candidates.push(entry.icon);
                            if (appId) {
                                candidates.push(appId, appId.toLowerCase());
                                if (appId.indexOf(".") !== -1) {
                                    var tail = appId.split(".").pop();
                                    candidates.push(tail, tail.toLowerCase());
                                }
                            }
                            for (var i = 0; i < candidates.length; i++) {
                                var path = Quickshell.iconPath(candidates[i], true);
                                if (path.length > 0) return path;
                            }
                            return Quickshell.iconPath("image-missing");
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            ScreencopyView {
                                width: parent.width
                                height: parent.height - headerRow.implicitHeight - 6
                                captureSource: modelData.wayland
                                live: root.pickerVisible && root.hoveredWs !== -1
                                paintCursor: false
                            }

                            Row {
                                id: headerRow
                                width: parent.width
                                spacing: 6
                                anchors.horizontalCenter: parent.horizontalCenter

                                IconImage {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 16
                                    height: 16
                                    source: previewCard.resolveIconPath()
                                    asynchronous: true
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 22
                                    text: {
                                        var appName = previewCard.entry && previewCard.entry.name ? previewCard.entry.name : previewCard.appId;
                                        if (appName && modelData.title) {
                                            return appName + " - " + modelData.title;
                                        }
                                        return modelData.title || appName || "Window";
                                    }
                                    color: "#cdd6f4"
                                    font.pixelSize: 11
                                    font.family: "JetBrainsMono Nerd Font"
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }

        // --- Main workspace selection container ---
        Rectangle {
            id: container
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: parent.height * 0.08

            width: Math.max(grid.implicitWidth, headerText.implicitWidth) + 56
            height: layout.implicitHeight + 48
            color: "#0d0d0d"
            radius: 16
            border.color: "#2a2a2a"
            border.width: 1

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                id: layout
                anchors.centerIn: parent
                spacing: 16
                width: parent.width - 48

                Text {
                    id: headerText
                    text: root.selectedWorkspaces.length > 0
                    ? "DRAGGING " + root.selectedWorkspaces.length + " WORKSPACES (" + [...root.selectedWorkspaces].sort((a,b)=>a-b).join(", ") + ")"
                    : "CLICK OR 1-9 TO SWITCH\nSHIFT+CLICK TO MULTI-SELECT\nDRAG TO SWAP · RIGHT-CLICK TO CLOSE"
                    color: root.selectedWorkspaces.length > 0 ? "#4dabf7" : "#888888"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.letterSpacing: 0.5
                    lineHeight: 1.35
                    wrapMode: Text.WordWrap
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

                        Item {
                            id: cellWrapper
                            width: 60
                            height: 60

                            readonly property int cellIndex: index
                            readonly property int wsNumber: index + 1

                            DropArea {
                                id: dropTarget
                                anchors.fill: parent
                                keys: ["workspace"]

                                onEntered: {
                                    root.currentTargetIndex = cellWrapper.cellIndex
                                }

                                onExited: {
                                    if (root.currentTargetIndex === cellWrapper.cellIndex) {
                                        root.currentTargetIndex = -1
                                    }
                                }

                                onDropped: (drop) => {
                                    if (root.activeSources && root.activeSources.length > 0) {
                                        root.swapMultiple(root.activeSources, cellWrapper.wsNumber)
                                    }
                                }
                            }

                            Rectangle {
                                id: baseSlot
                                anchors.fill: parent
                                radius: 10
                                clip: true
                                color: isSelected
                                ? "#163859"
                                : (wsMouse.containsMouse ? "#262626" : "#171717")
                                border.color: isSelected
                                ? "#339af0"
                                : (incomingWs !== -1 ? "#4dabf7" : "#2a2a2a")
                                border.width: isSelected || incomingWs !== -1 ? 2 : 1

                                readonly property bool isSelected: root.selectedWorkspaces.includes(cellWrapper.wsNumber)
                                readonly property bool hasWindows: root.occupiedWorkspaces.includes(cellWrapper.wsNumber)
                                readonly property bool isCurrentActive: root.activeWorkspace === cellWrapper.wsNumber
                                readonly property int incomingWs: {
                                    if (!root.isDragging || root.currentTargetIndex < 0) return -1

                                        let offset = (cellWrapper.cellIndex - root.currentTargetIndex + 10) % 10
                                        if (offset < root.activeSources.length) {
                                            return root.activeSources[offset]
                                        }
                                        return -1
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 10
                                    color: "#228be6"
                                    opacity: baseSlot.incomingWs !== -1 ? 0.22 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 120 } }
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 3
                                    height: 18
                                    radius: 1.5
                                    color: "#339af0"
                                    visible: baseSlot.isCurrentActive
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 1

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: cellWrapper.wsNumber === 10 ? "0" : cellWrapper.wsNumber
                                        color: baseSlot.isSelected
                                        ? "#ffffff"
                                        : (baseSlot.incomingWs !== -1 ? "#d0d0d0" : "#aaaaaa")
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 16
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

                                onEntered: {
                                    root.hoveredWs = cellWrapper.wsNumber
                                }

                                onExited: {
                                    if (root.hoveredWs === cellWrapper.wsNumber) {
                                        root.hoveredWs = -1
                                    }
                                }

                                onPressed: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        root.killWorkspace(cellWrapper.wsNumber)
                                        return
                                    }

                                    if (mouse.modifiers & Qt.ShiftModifier) {
                                        root.toggleSelection(cellWrapper.wsNumber)
                                        return
                                    }

                                    startX = mouse.x
                                    startY = mouse.y
                                    wasDragged = false

                                    if (root.selectedWorkspaces.includes(cellWrapper.wsNumber)) {
                                        root.activeSources = [...root.selectedWorkspaces].sort((a,b) => a - b)
                                    } else {
                                        root.activeSources = [cellWrapper.wsNumber]
                                    }
                                    root.anchorWs = cellWrapper.wsNumber
                                }

                                onPositionChanged: (mouse) => {
                                    if (mouse.buttons & Qt.LeftButton && !(mouse.modifiers & Qt.ShiftModifier)) {
                                        const dx = mouse.x - startX
                                        const dy = mouse.y - startY
                                        if (!wasDragged && (dx * dx + dy * dy) > 25) {
                                            wasDragged = true
                                            root.isDragging = true
                                        }

                                        if (wasDragged) {
                                            let globalPoint = wsMouse.mapToItem(container, mouse.x, mouse.y)
                                            dragProxy.x = globalPoint.x + 8
                                            dragProxy.y = globalPoint.y - dragProxy.height + 4
                                        }
                                    }
                                }

                                onReleased: (mouse) => {
                                    if (mouse.button === Qt.RightButton || (mouse.modifiers & Qt.ShiftModifier)) {
                                        return
                                    }

                                    if (wasDragged) {
                                        dragProxy.Drag.drop()
                                    } else {
                                        root.pick(cellWrapper.wsNumber)
                                    }

                                    root.isDragging = false
                                    root.currentTargetIndex = -1
                                    wasDragged = false
                                    dragProxy.x = -9999
                                    dragProxy.y = -9999
                                }
                            }
                        }
                    }
                }
            }

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
