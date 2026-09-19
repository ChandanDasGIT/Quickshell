//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import Quickshell.DBusMenu
import "./notes"
import "../wallpaper"
import "../workspace"

Item {
    id: rightBar
    implicitHeight: 26
    implicitWidth: row.implicitWidth

    readonly property string nerdFontFamily: "JetBrainsMono Nerd Font"

    // ---- reusable pill/segment building block ------------------------
    component Segment: Rectangle {
        id: seg
        property string icon: ""
        property string label: ""
        property string tooltip: ""
        property int iconSize: 14
        signal clicked()
        signal rightClicked()

        color: mouseArea.containsMouse ? "#33ffffff" : "transparent"
        radius: 4
        implicitHeight: 24
        implicitWidth: content.implicitWidth + 12
        z: mouseArea.containsMouse ? 100 : 0 // keep the bubble above neighboring segments

        RowLayout {
            id: content
            anchors.centerIn: parent
            spacing: 4
            Text {
                text: seg.icon
                visible: seg.icon.length > 0
                color: "white"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: seg.iconSize
            }
            Text {
                text: seg.label
                visible: seg.label.length > 0
                color: "white"
                font.pixelSize: 16
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) seg.rightClicked()
                    else seg.clicked()
            }
        }

        // ---- quiet hover bubble ----
        PopupWindow {
            id: tipBubble
            anchor.item: seg
            anchor.edges: Edges.Bottom | Edges.Left
            anchor.gravity: Edges.Bottom | Edges.Right
            anchor.rect.x: 0
            anchor.rect.y: seg.height + 4
            implicitWidth: tipLabel.implicitWidth + 20
            implicitHeight: tipLabel.implicitHeight + 12
            color: "transparent"
            visible: mouseArea.containsMouse && seg.tooltip.length > 0

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: "#cc1a1a1a"
                border.color: "#22ffffff"
                border.width: 1

                Text {
                    id: tipLabel
                    anchors.centerIn: parent
                    text: seg.tooltip
                    color: "#ffffff"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 4

        // ================= NetSpeedMeter =====================
        NetSpeedMeter{}
        // ================= Workspace Swapper =====================
        Segment {
            icon: "\uf00a"   // grid-style glyph, swap for whatever you prefer
            tooltip: "Swap/Move Workspace"
            onClicked: WorkspacePicker.toggle()
        }

        // ================= To-Do list and Shortcuts =====================
        Notes {
            id: notes
            anchorItem: notesIcon   // pass the icon item as the popup anchor
        }

        Rectangle {
            id: notesIcon
            implicitHeight: 24
            implicitWidth: iconText.implicitWidth + 12
            radius: 4
            color: notesMouseArea.containsMouse ? "#33ffffff" : "transparent"

            Text {
                id: iconText
                anchors.centerIn: parent
                text: "\uf0ca"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                color: "white"
            }

            MouseArea {
                id: notesMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: notes.toggle()
            }

            PopupWindow {
                id: notesTip
                anchor.item: notesIcon
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom
                anchor.rect.x: 0
                anchor.rect.y: notesIcon.height + 4
                implicitWidth: notesTipLabel.implicitWidth + 20
                implicitHeight: notesTipLabel.implicitHeight + 12
                color: "transparent"
                visible: notesMouseArea.containsMouse

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: "#cc1a1a1a"
                    border.color: "#22ffffff"
                    border.width: 1

                    Text {
                        id: notesTipLabel
                        anchors.centerIn: parent
                        text: "TO-DO list and SHORTCUTS"
                        color: "#ffffff"
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        // ================= wallpaper change ==================
        Segment {
            icon: "\uf03e"
            tooltip: "Left Click: Next Wallpaper\nRight Click: Prev Wallpaper"
            onClicked: Wallpaper.next()
            onRightClicked: Wallpaper.prev()
        }

        // ================= pulseaudio ===============================
        PwObjectTracker {
            objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
        }

        Segment {
            id: audioSegment
            property var sink: Pipewire.defaultAudioSink
            property real vol: sink?.audio?.volume ?? 0
            property bool muted: sink?.audio?.muted ?? false

            icon: muted || vol === 0 ? "\uf6a9" : (vol > 0.66 ? "\uf028" : (vol > 0.33 ? "\uf027" : "\uf026"))
            label: sink ? Math.round(vol * 100) + "%" : "--"

            // Toggle audio mixer on left click
            onClicked: pavucontrolProc.running = !pavucontrolProc.running

            // Mouse wheel controls for volume adjustment
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onWheel: (wheel) => {
                    if (!audioSegment.sink?.audio) return;
                    var step = 0.02; // 2% per scroll notch
                    var newVol = audioSegment.vol + (wheel.angleDelta.y > 0 ? step : -step);
                    audioSegment.sink.audio.volume = Math.max(0.0, Math.min(1.0, newVol));
                }

                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        // Toggle mute on right click
                        if (audioSegment.sink?.audio) {
                            audioSegment.sink.audio.muted = !audioSegment.sink.audio.muted;
                        }
                    } else {
                        pavucontrolProc.running = !pavucontrolProc.running;
                    }
                }
            }
        }

        Process {
            id: pavucontrolProc
            command: ["pavucontrol"]
            onExited: pavucontrolProc.running = false
        }


        // ================= group/hardware (drawer) ==================
        Segment {
            id: drawerToggle
            icon: hwDrawer.open ? "\u276f" : "\u276e" // ❯ / ❮
            iconSize: 20 // <-- INSERTED: Set the icon font size to 20 for this toggle arrow
            onClicked: hwDrawer.open = !hwDrawer.open
        }

        Item {
            id: hwDrawer
            property bool open: false
            clip: true
            implicitHeight: 24
            implicitWidth: open ? hwRow.implicitWidth : 0
            Behavior on implicitWidth { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }

            RowLayout {
                id: hwRow
                spacing: 4



                Segment {
                    icon: "\uf2db"
                    label: hwStats.cpuPercent + "%"
                    tooltip: "CPU Usage %"
                }
                Segment {
                    icon: "\uf0c9"
                    label: hwStats.memPercent + "%"
                    tooltip: "RAM Usage %"
                }
                // =================CPU temperature ===============================
                QtObject {
                    id: tempState
                    property real celsius: 0
                }

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    triggeredOnStart: true

                    onTriggered: {
                        if (!tempProc.running)
                            tempProc.running = true
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
                        onStreamFinished: {
                            tempState.celsius = (parseInt(text.trim()) || 0) / 1000
                        }
                    }
                }

                Segment {
                    icon: "\uf2c8"
                    label: Math.round(tempState.celsius) + "\u00b0C"
                    tooltip: "CPU Temp"
                }

            }
        }

        // cpu/mem polling, standing in for waybar's "cpu"/"memory" modules
        QtObject {
            id: hwStats
            property int cpuPercent: 0
            property int memPercent: 0
            property var _prevIdle: 0
            property var _prevTotal: 0
        }
        Timer {
            interval: 2000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: { cpuProc.running = true; memProc.running = true }
        }
        Process {
            id: cpuProc
            command: ["cat", "/proc/stat"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const fields = text.split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
                    const idle = fields[3] + fields[4]
                    const total = fields.reduce((a, b) => a + b, 0)
                    if (hwStats._prevTotal > 0) {
                        const totalDiff = total - hwStats._prevTotal
                        const idleDiff = idle - hwStats._prevIdle
                        if (totalDiff > 0)
                            hwStats.cpuPercent = Math.round(100 * (totalDiff - idleDiff) / totalDiff)
                    }
                    hwStats._prevIdle = idle
                    hwStats._prevTotal = total
                }
            }
        }
        Process {
            id: memProc
            command: ["bash", "-c", "free | awk '/Mem:/ {printf \"%.0f\", $3/$2*100}'"]
            stdout: StdioCollector {
                onStreamFinished: hwStats.memPercent = parseInt(text) || 0
            }
        }

        // ================= tray =======================================
        Tray{}

        // ================= custom/power ==============================
        Segment {
            id: powerSeg
            icon: "\u23fb"
            onClicked: powerMenu.visible = !powerMenu.visible
        }
        PopupWindow {
            id: powerMenu
            anchor.item: powerSeg
            anchor.edges: Edges.Bottom | Edges.Right
            anchor.gravity: Edges.Bottom | Edges.Left
            anchor.rect.x: powerSeg.width
            anchor.rect.y: powerSeg.height + 4
            implicitWidth: 140
            implicitHeight: menuCol.implicitHeight + 8
            color: "#cc1a1a1a"
            visible: false

            ColumnLayout {
                id: menuCol
                anchors.fill: parent
                anchors.margins: 4
                spacing: 2

                Segment {
                    Layout.fillWidth: true
                    label: "Shutdown"
                    onClicked: {
                        Quickshell.execDetached(["systemctl", "poweroff"]);
                        powerMenu.visible = false;
                    }
                }

                Segment {
                    Layout.fillWidth: true
                    label: "Reboot"
                    onClicked: {
                        Quickshell.execDetached(["systemctl", "reboot"]);
                        powerMenu.visible = false;
                    }
                }

                Segment {
                    Layout.fillWidth: true
                    label: "Suspend"
                    onClicked: {
                        Quickshell.execDetached(["systemctl", "suspend"]);
                        powerMenu.visible = false;
                    }
                }

                Segment {
                    Layout.fillWidth: true
                    label: "Hibernate"
                    onClicked: {
                        Quickshell.execDetached(["systemctl", "hibernate"]);
                        powerMenu.visible = false;
                    }
                }
            }
        }
    }
}
