pragma Singleton

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

Item {
    id: root

    property bool pickerVisible: false
    property var selectedWorkspaces: []
    property var occupiedWorkspaces: []
    property int activeWorkspace: -1
    property int hoveredWs: -1
    property int inspectedWs: -1

    property bool isDragging: false
    property var activeSources: []
    property int anchorWs: -1
    property int currentTargetIndex: -1
    property bool shiftHeld: false

    readonly property var activeWorkspaceList: {
        var toplevels = Hyprland.toplevels.values;
        var map = {};
        for (var i = 0; i < toplevels.length; i++) {
            var t = toplevels[i];
            if (t.wayland != null && t.workspace && t.workspace.id > 0) {
                map[t.workspace.id] = true;
            }
        }
        var list = Object.keys(map).map(function(k) { return parseInt(k); });
        return list.sort(function(a, b) { return a - b; });
    }

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
            inspectedWs = -1
            shiftHeld = false
            refreshState()
        }
    }

    IpcHandler {
        target: "workspaces"
        function toggle(): void { root.toggle() }
    }

    Process { id: switchProc; command: [] }

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

    Process {
        id: activeWsProc
        command: ["bash", "-c", "hyprctl activeworkspace -j | jq -r '.id'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let id = parseInt(text.trim())
                if (!isNaN(id)) root.activeWorkspace = id
            }
        }
    }

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
                } else if (line.startsWith("openwindow>>") || line.startsWith("closewindow>>") || line.startsWith("movewindow>>")) {
                    refreshTimer.start()
                }
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 200
        onTriggered: root.refreshState()
    }

    function refreshState() {
        if (occupiedProc.running) occupiedProc.running = false
            occupiedProc.running = true
            if (activeWsProc.running) activeWsProc.running = false
                activeWsProc.running = true
    }

    function pick(n) {
        root.activeWorkspace = n
        if (switchProc.running) switchProc.running = false
            let cmd = Hyprland.usingLua ? 'hyprctl dispatch "hl.dsp.focus({ workspace = \\"' + n + '\\" })"' : 'hyprctl dispatch workspace ' + n
            switchProc.command = ["bash", "-c", cmd]
                switchProc.running = true
                    refreshTimer.start()
    }

    function focusWindow(w) {
        if (!w) return
            var fullAddr = "0x" + String(w.address).replace(/^0x/, "")
            if (Hyprland.usingLua) {
                Hyprland.dispatch('hl.dsp.focus({ window = "address:' + fullAddr + '" })')
            } else {
                Hyprland.dispatch('focuswindow address:' + fullAddr)
            }
            root.hoveredWs = -1
            root.inspectedWs = -1
            root.pickerVisible = false
    }

    function killWindow(w) {
        if (!w) return
            var fullAddr = "0x" + String(w.address).replace(/^0x/, "")
            if (Hyprland.usingLua) {
                Hyprland.dispatch('hl.dsp.window.close({ window = "address:' + fullAddr + '" })')
            } else {
                Hyprland.dispatch('closewindow address:' + fullAddr)
            }
            refreshTimer.start()
    }

    function killWorkspace(n) {
        var wins = Hyprland.toplevels.values
        for (var i = 0; i < wins.length; i++) {
            var w = wins[i]
            if (w.wayland != null && w.workspace && w.workspace.id === n) {
                var fullAddr = "0x" + String(w.address).replace(/^0x/, "")
                Hyprland.dispatch('hl.dsp.window.close({ window = "address:' + fullAddr + '" })')
            }
        }
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

            // Map each dragged source to its target slot: a consecutive block
            // of workspaces (wrapping at 10) starting at the one dropped on.
            let dest = {}
            let targets = []
            for (let i = 0; i < srcList.length; i++) {
                let dst = ((targetBase - 1 + i) % 10) + 1
                targets.push(dst)
                dest[srcList[i]] = dst
            }

            // dest is a bijection sources -> targets. If a target isn't itself
            // one of the sources, whatever's currently on it still needs a
            // home so nothing gets overwritten/merged away: pair the "extra"
            // targets with the "extra" sources (in order) to close this into
            // a full permutation over the whole affected set.
            let srcSet = new Set(srcList)
            let targetSet = new Set(targets)
            let extraTargets = targets.filter(t => !srcSet.has(t))
            let extraSources = srcList.filter(s => !targetSet.has(s))
            for (let i = 0; i < extraTargets.length; i++) {
                dest[extraTargets[i]] = extraSources[i]
            }

            // Decompose the permutation into cycles. Rotating each cycle
            // through a single temp workspace is a genuine swap: every
            // workspace involved trades places, nothing is lost.
            let visited = {}
            let cycles = []
            let nodes = Object.keys(dest).map(Number)
            for (let i = 0; i < nodes.length; i++) {
                let start = nodes[i]
                if (visited[start]) continue
                    let cycle = []
                    let cur = start
                    while (!visited[cur]) {
                        visited[cur] = true
                        cycle.push(cur)
                        cur = dest[cur]
                    }
                    if (cycle.length > 1) cycles.push(cycle)
            }

            if (cycles.length > 0) WorkspaceSwap.runCycles(cycles)
                root.selectedWorkspaces = []
                refreshTimer.start()
    }

    function toggleSelection(ws) {
        let copy = [...selectedWorkspaces]
        let idx = copy.indexOf(ws)
        if (idx !== -1) copy.splice(idx, 1)
            else copy.push(ws)
                selectedWorkspaces = copy
    }

    PanelWindow {
        id: popup
        visible: root.pickerVisible
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        // On-demand focus (like the old focusable: true) rather than an
        // Exclusive grab -- Exclusive mode appears to not feed modifier
        // state into pointer/mouse events reliably on this setup, which is
        // what was breaking shift+click detection.
        WlrLayershell.keyboardFocus: root.pickerVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors { top: true; bottom: true; left: true; right: true }

        Item {
            id: keyHandler
            focus: true
            anchors.fill: parent

            Connections {
                target: root
                function onPickerVisibleChanged() {
                    if (root.pickerVisible) keyHandler.forceActiveFocus()
                        else root.shiftHeld = false
                }
            }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Shift) { root.shiftHeld = true; return }
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
            Keys.onReleased: (event) => {
                if (event.key === Qt.Key_Shift) root.shiftHeld = false
            }
        }

        MouseArea {
            id: backdropMouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: (mouse) => {
                var ptDock = mapToItem(dock, mouse.x, mouse.y)
                if (dock.visible && ptDock.x >= 0 && ptDock.x <= dock.width && ptDock.y >= 0 && ptDock.y <= dock.height) return

                    var ptCard = mapToItem(container, mouse.x, mouse.y)
                    if (ptCard.x >= 0 && ptCard.x <= container.width && ptCard.y >= 0 && ptCard.y <= container.height) return

                        var ptShelf = mapToItem(shelf, mouse.x, mouse.y)
                        if (shelf.opacity > 0 && ptShelf.x >= 0 && ptShelf.x <= shelf.width && ptShelf.y >= 0 && ptShelf.y <= shelf.height) return

                            root.inspectedWs = -1
                            root.selectedWorkspaces = []
                            root.pickerVisible = false
            }
        }

        WorkspaceDock {
            id: dock
            anchors.bottom: container.top
            anchors.bottomMargin: 14
            anchors.horizontalCenter: container.horizontalCenter
            width: container.width

            parentWindow: popup
            activeWorkspaceList: root.activeWorkspaceList
            activeWorkspace: root.activeWorkspace
            isDragging: root.isDragging

            onPick: (id) => root.pick(id)
            onFocusWindow: (w) => root.focusWindow(w)
            onKillWindow: (w) => root.killWindow(w)
        }

        WorkspaceWindowShelf {
            id: shelf
            anchors.top: container.bottom
            anchors.topMargin: 14
            anchors.horizontalCenter: container.horizontalCenter
            width: container.width

            targetWs: root.hoveredWs !== -1 ? root.hoveredWs : root.inspectedWs
            windowModel: root.getWindowsForWorkspace(targetWs)
            isDragging: root.isDragging

            onFocusWindow: (w) => root.focusWindow(w)
            onKillWindow: (w) => root.killWindow(w)
        }

        Rectangle {
            id: container
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -parent.height * 0.05

            width: Math.max(grid.implicitWidth, headerText.implicitWidth) + 64
            height: layout.implicitHeight + 48
            color: "#0d0d0d"
            radius: 16
            border.color: "#2a2a2a"
            border.width: 1

            ColumnLayout {
                id: layout
                anchors.centerIn: parent
                spacing: 18
                width: parent.width - 48

                Text {
                    id: headerText
                    text: root.selectedWorkspaces.length > 0
                    ? "DRAGGING " + root.selectedWorkspaces.length + " WORKSPACES (" + [...root.selectedWorkspaces].sort((a,b)=>a-b).join(", ") + ")"
                    : "CLICK TO SELECT · DOUBLE-CLICK TO SWITCH\nSHIFT+CLICK TO MULTI-SELECT · DRAG TO SWAP"
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
                        model: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

                        WorkspaceGridCell {
                            Layout.preferredWidth: 72
                            Layout.preferredHeight: 72

                            cellIndex: modelData - 1

                            containerItem: container
                            dragProxyItem: dragProxy
                            activeSources: root.activeSources

                            isSelected: root.selectedWorkspaces.includes(modelData)
                            isInspected: root.inspectedWs === modelData
                            hasWindows: root.occupiedWorkspaces.includes(modelData)
                            isCurrentActive: root.activeWorkspace === modelData
                            incomingWs: {
                                if (!root.isDragging || root.currentTargetIndex < 0) return -1
                                    let offset = (cellIndex - root.currentTargetIndex + 10) % 10
                                    return offset < root.activeSources.length ? root.activeSources[offset] : -1
                            }

                            onTargetHovered: (id) => root.hoveredWs = id
                            onTargetUnhovered: (id) => { if (root.hoveredWs === id) root.hoveredWs = -1 }
                            onPick: (id) => root.pick(id)
                            onKill: (id) => root.killWorkspace(id)
                            onToggleSelection: (id) => root.toggleSelection(id)
                            onToggleInspect: (id) => root.inspectedWs = (root.inspectedWs === id) ? -1 : id
                            onSwapTriggered: (sources, target) => root.swapMultiple(sources, target)

                            onDragEntered: (idx) => root.currentTargetIndex = idx
                            onDragExited: (idx) => { if (root.currentTargetIndex === idx) root.currentTargetIndex = -1 }

                            onDragStarted: (sources, anchor) => {
                                root.anchorWs = anchor
                                let list = sources ? sources : [...root.selectedWorkspaces]
                                // Keep this sorted so the incoming-ws preview shown while
                                // dragging matches the order swapMultiple() actually uses.
                                root.activeSources = [...list].sort((a, b) => a - b)
                                root.isDragging = true
                            }

                            onDragEnded: {
                                root.isDragging = false
                                root.currentTargetIndex = -1
                                dragProxy.x = -9999
                                dragProxy.y = -9999
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
                            width: 60
                            height: 60
                            radius: 10
                            color: "#1c4f82"
                            opacity: 0.3
                            border.color: "#4dabf7"
                            border.width: 1.5

                            Text {
                                anchors.centerIn: parent
                                text: modelData === 10 ? "0" : modelData
                                color: "white"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 18
                                font.bold: true
                            }
                        }
                    }
                }
            }
        }
    }

    PanelWindow {
        id: bottomTrigger
        screen: Quickshell.focusedScreen

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-workspace-trigger"
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        anchors {
            bottom: true
            top: false
            left: false
            right: false
        }

        width: 420
        height: 2
        visible: !root.pickerVisible

        Timer {
            id: triggerDelay
            interval: 80 // Requires cursor to rest on edge for 80ms to prevent accidental triggers
            repeat: false
            onTriggered: {
                if (!root.pickerVisible) {
                    root.toggle()
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: triggerDelay.start()
            onExited: triggerDelay.stop()
        }
    }
}
