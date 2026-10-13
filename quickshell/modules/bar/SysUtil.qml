import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    implicitWidth: toggle.implicitWidth
    implicitHeight: toggle.implicitHeight

    // ---- stats (polled only while the dropdown is open) ----
    property int memPercent: 0
    property string memUsage: "0/0 GB"
    property int cpuPercent: 0
    property real cpuTempC: 0
    property int gpuPercent: 0
    property real gpuTempC: 0

    property real _prevIdle: 0
    property real _prevTotal: 0
    property bool isPinned: false

    Timer {
        interval: 1000
        running: popup.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!cpuProc.running) cpuProc.running = true
                if (!memProc.running) memProc.running = true
                    if (!tempProc.running) tempProc.running = true
                        if (!gpuProc.running) gpuProc.running = true
        }
    }

    // CPU % via /proc/stat
    Process {
        id: cpuProc
        command: ["cat", "/proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
                const idle = fields[3] + fields[4]
                const total = fields.reduce((a, b) => a + b, 0)
                if (root._prevTotal > 0) {
                    const totalDiff = total - root._prevTotal
                    const idleDiff = idle - root._prevIdle
                    if (totalDiff > 0)
                        root.cpuPercent = Math.round(100 * (totalDiff - idleDiff) / totalDiff)
                }
                root._prevIdle = idle
                root._prevTotal = total
            }
        }
    }

    // RAM % and RAM Used / Total via free
    Process {
        id: memProc
        command: ["bash", "-c", "free -m | awk '/Mem:/ {printf \"%.0f %.2f %.2f\", $3/$2*100, $3/1024, $2/1024}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/)
                if (parts.length >= 3) {
                    root.memPercent = parseInt(parts[0]) || 0
                    root.memUsage = parts[1] + " / " + parts[2] + " GB"
                }
            }
        }
    }

    // CPU Temp via hwmon
    Process {
        id: tempProc
        command: [
            "bash",
            "-c",
            "for d in /sys/class/hwmon/hwmon*; do if [ -f \"$d/name\" ] && grep -qE \"coretemp|k10temp|cpu_thermal\" \"$d/name\"; then cat \"$d/temp1_input\"; break; fi; done 2>/dev/null || echo 0"
        ]
        stdout: StdioCollector {
            onStreamFinished: root.cpuTempC = (parseInt(text.trim()) || 0) / 1000
        }
    }

    // GPU % and GPU Temp (NVIDIA first, AMD sysfs fallback)
    Process {
        id: gpuProc
        command: [
            "bash",
            "-c",
            "if command -v nvidia-smi >/dev/null 2>&1; then " +
            "  nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | awk -F',' '{print $1, $2}'; " +
            "elif [ -f /sys/class/drm/card0/device/gpu_busy_percent ]; then " +
            "  busy=$(cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null || echo 0); " +
            "  t=$(cat /sys/class/drm/card0/device/hwmon/hwmon*/temp1_input 2>/dev/null | head -n1 || echo 0); " +
            "  echo \"$busy $((t / 1000))\"; " +
            "else " +
            "  echo \"0 0\"; " +
            "fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/)
                if (parts.length >= 2) {
                    root.gpuPercent = parseInt(parts[0]) || 0
                    root.gpuTempC = parseFloat(parts[1]) || 0
                }
            }
        }
    }

    // Fullscreen transparent overlay: captures clicks outside the menu
    Scope {
        PanelWindow {
            id: clickCatcher
            visible: popup.visible && !root.isPinned
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            MouseArea {
                anchors.fill: parent
                onPressed: popup.visible = false
            }
        }
    }

    // ---- bar icon ----
    Rectangle {
        id: toggle
        anchors.fill: parent
        implicitWidth: toggleIcon.implicitWidth + 16
        implicitHeight: 24
        radius: 6
        color: root.isPinned ? "#45475a" : (toggleMouse.containsMouse ? "#313244" : "transparent")

        Text {
            id: toggleIcon
            anchors.centerIn: parent
            text: "\uf085"
            color: root.isPinned ? "#f38ba8" : "#cdd6f4"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
        }

        MouseArea {
            id: toggleMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    root.isPinned = !root.isPinned
                    popup.visible = root.isPinned
                } else if (mouse.button === Qt.LeftButton) {
                    if (root.isPinned) {
                        root.isPinned = false
                        popup.visible = false
                    } else {
                        popup.visible = !popup.visible
                    }
                }
            }
        }
    }

    // ---- dropdown ----
    PopupWindow {
        id: popup
        visible: false
        color: "transparent"

        anchor {
            item: toggle
            edges: Edges.Bottom
            gravity: Edges.Bottom
        }
        implicitWidth: 240
        implicitHeight: card.implicitHeight + 6

        onVisibleChanged: {
            if (visible) {
                root._prevTotal = 0
            }
        }

        Rectangle {
            id: card
            anchors.top: parent.top
            anchors.topMargin: 6
            width: parent.width
            implicitHeight: col.implicitHeight + 20
            radius: 12
            color: "#161622"
            border.color: root.isPinned ? "#f38ba8" : "#2a2a3a"
            border.width: 1

            MouseArea {
                anchors.fill: parent
                preventStealing: true
            }

            ColumnLayout {
                id: col
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // Reusable row delegate
                component StatRow: RowLayout {
                    property string icon: ""
                    property string name: ""
                    property string value: "--"

                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: icon
                        color: "#89b4fa"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        Layout.preferredWidth: 18
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        text: name
                        color: "#a6adc8"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        Layout.fillWidth: true
                    }
                    Text {
                        text: value
                        color: "#cdd6f4"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.bold: true
                    }
                }

                // Reusable divider delegate
                component Divider: Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#313244"
                    Layout.topMargin: 2
                    Layout.bottomMargin: 2
                }

                // ---- RAM Group ----
                StatRow { icon: "\uf0c9"; name: "RAM %"; value: root.memPercent + "%" }
                StatRow { icon: "\uf0c9"; name: "RAM"; value: root.memUsage }

                Divider {}

                // ---- CPU Group ----
                StatRow { icon: "\uf2db"; name: "CPU"; value: root.cpuPercent + "%" }
                StatRow { icon: "\uf2c8"; name: "CPU Temp"; value: Math.round(root.cpuTempC) + "\u00b0C" }

                Divider {}

                // ---- GPU Group ----
                StatRow { icon: "\uf399"; name: "GPU"; value: root.gpuPercent + "%" }
                StatRow { icon: "\uf2c8"; name: "GPU Temp"; value: Math.round(root.gpuTempC) + "\u00b0C" }

                // ---- Fan Speed Component ----
                FanSpeed {
                    Layout.fillWidth: true
                    isActive: popup.visible
                }
            }
        }
    }
}
