//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
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
                color: Theme.iconColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: seg.iconSize
            }
            Text {
                text: seg.label
                visible: seg.label.length > 0
                color: Theme.iconColor
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
        // ================= Virtual Keyboard toggle =====================
        Segment {
            icon: "\uf11c"   // keyboard glyph
            tooltip: "Toggle Virtual Keyboard"
            onClicked: Quickshell.execDetached(["qs", "ipc", "call", "virtualKeyboard", "toggle"])
        }
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
                color: Theme.iconColor
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


        SysUtil {}
        // ================= tray =======================================
        Tray{}

        // ================= battery ===================

        Segment {
            id: batterySegment
            property var device: UPower.displayDevice
            property int capacity: Math.round((device?.percentage ?? 0) * 100)
            property bool charging: device?.state === UPowerDeviceState.Charging
            property bool plugged: device?.state === UPowerDeviceState.PendingCharge || charging

            icon: charging ? "\uf0e7"
            : capacity <= 15 ? "\uf244"
            : capacity <= 30 ? "\uf243"
            : capacity <= 60 ? "\uf242"
            : capacity <= 90 ? "\uf241"
            : "\uf240"

            label: device ? capacity + "%" : "--"

            ToolTip.visible: hovered
            ToolTip.delay: 400
            ToolTip.text: {
                if (!device) return "No battery detected"
                    var status = charging ? "Charging" : (plugged ? "Plugged in" : "Discharging")
                    var timeLeft = charging ? device.timeToFull : device.timeToEmpty
                    var timeStr = timeLeft > 0
                    ? Math.floor(timeLeft / 3600) + "h " + Math.floor((timeLeft % 3600) / 60) + "m"
                    : "calculating..."
                    return status + "\n" + (charging ? "Time to full: " : "Time remaining: ") + timeStr
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: batterySegment.hovered = true
                onExited: batterySegment.hovered = false
            }
        }

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
            anchor.rect.y: powerSeg.height + 6
            implicitWidth: 145
            implicitHeight: menuCol.implicitHeight + 16
            color: "transparent"
            visible: false

            HyprlandFocusGrab {
                id: grab
                windows: [powerMenu]
                onActiveChanged: {
                    if (!active) {
                        powerMenu.visible = false;
                    }
                }
            }

            onVisibleChanged: {
                if (visible) {
                    Qt.callLater(function() { grab.active = true; });
                } else {
                    grab.active = false;
                }
            }

            // Minimalist Black & White / Frosted Glass card
            Rectangle {
                anchors.fill: parent
                color: "#e60d0d0d"       // Deep matte obsidian/black (90% opacity)
                radius: 10
                border.width: 1
                border.color: "#38ffffff" // Subtle frosted white edge

                ColumnLayout {
                    id: menuCol
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 3

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
}
