import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: cornerTrigger

    screen: Quickshell.focusedScreen

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-osk-corner-trigger"
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        bottom: true
        right: true
        top: false
        left: false
    }

    width: 6
    height: 6

    Timer {
        id: dwellTimer
        interval: 100 // 100ms dwell delay to prevent accidental hits
        repeat: false
        onTriggered: {
            // Call the RPC toggle on the virtual keyboard
            toggleProcess.running = true;
        }
    }

    Process {
        id: toggleProcess
        command: ["qs", "ipc", "call", "virtualKeyboard", "toggle"]
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        onEntered: dwellTimer.start()
        onExited: dwellTimer.stop()
    }
}
