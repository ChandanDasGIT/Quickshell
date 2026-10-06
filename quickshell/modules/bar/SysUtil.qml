import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    implicitWidth: toggle.implicitWidth
    implicitHeight: toggle.implicitHeight

    // ---- stats (polled only while the dropdown is open) ----
    property int cpuPercent: 0
    property int memPercent: 0
    property real tempC: 0
    property real _prevIdle: 0
    property real _prevTotal: 0

    function valueFor(i) {
        if (i === 0) return root.cpuPercent + "%"
            if (i === 1) return root.memPercent + "%"
                return Math.round(root.tempC) + "\u00b0C"
    }

    Timer {
        interval: 1000
        running: popup.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!cpuProc.running) cpuProc.running = true
                if (!memProc.running) memProc.running = true
                    if (!tempProc.running) tempProc.running = true
        }
    }

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

    Process {
        id: memProc
        command: ["bash", "-c", "free | awk '/Mem:/ {printf \"%.0f\", $3/$2*100}'"]
        stdout: StdioCollector {
            onStreamFinished: root.memPercent = parseInt(text) || 0
        }
    }

    Process {
        id: tempProc
        command: [
            "bash",
            "-c",
            "for d in /sys/class/hwmon/hwmon*; do if [ -f \"$d/name\" ] && grep -qE \"coretemp|k10temp|cpu_thermal\" \"$d/name\"; then cat \"$d/temp1_input\"; break; fi; done 2>/dev/null || echo 0"
        ]
        stdout: StdioCollector {
            onStreamFinished: root.tempC = (parseInt(text.trim()) || 0) / 1000
        }
    }

    // ---- bar icon ----
    Rectangle {
        id: toggle
        anchors.fill: parent
        implicitWidth: toggleIcon.implicitWidth + 16
        implicitHeight: 24
        radius: 6
        color: toggleMouse.containsMouse ? "#313244" : "transparent"

        Text {
            id: toggleIcon
            anchors.centerIn: parent
            text: "\uf085"
            color: "#cdd6f4"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
        }

        MouseArea {
            id: toggleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: popup.visible = !popup.visible
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
        implicitWidth: 180
        implicitHeight: card.implicitHeight + 6

        onVisibleChanged: { if (visible) root._prevTotal = 0 }

        Rectangle {
            id: card
            anchors.top: parent.top
            anchors.topMargin: 6
            width: parent.width
            implicitHeight: col.implicitHeight + 20
            radius: 12
            color: "#161622"
            border.color: "#2a2a3a"
            border.width: 1

            ColumnLayout {
                id: col
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Repeater {
                    model: [
                        { icon: "\uf2db", name: "CPU" },
                        { icon: "\uf0c9", name: "RAM" },
                        { icon: "\uf2c8", name: "Temp" }
                    ]

                    RowLayout {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: modelData.icon
                            color: "#89b4fa"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            Layout.preferredWidth: 18
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            text: modelData.name
                            color: "#a6adc8"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            Layout.fillWidth: true
                        }
                        Text {
                            text: root.valueFor(index)
                            color: "#cdd6f4"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }
                }
            }
        }
    }
}
