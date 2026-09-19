import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris

RowLayout {
    id: root
    spacing: 8
    height: 24
    Layout.alignment: Qt.AlignVCenter

    readonly property string nerdFontFamily: "JetBrainsMono Nerd Font"

    // Palette matched to the Catppuccin theme in Dock.qml
    QtObject {
        id: theme
        readonly property color background: "#181825"
        readonly property color windowSurface: "#1e1e2e"
        readonly property color accent: "#89b4fa"
        readonly property color border: "#313244"
        readonly property color text: "#cdd6f4"
        readonly property color subtext: "#a6adc8"
    }

    // ---- Workspace Window Screencopy Preview Popup ----
    component WorkspaceLivePreview: PopupWindow {
        id: previewPopup
        property var workspaceData: null
        property Item anchorItem: null
        property bool isHovered: false

        visible: isHovered && workspaceData && workspaceData.toplevels && workspaceData.toplevels.values.length > 0

        anchor {
            item: anchorItem
            edges: Edges.Bottom | Edges.Left
            gravity: Edges.Bottom | Edges.Right
            margins.top: 8
        }

        // Adjust popup dimensions dynamically to accommodate multiple window previews side-by-side
        implicitWidth: previewContainer.implicitWidth + 16
        implicitHeight: 165
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: theme.background
            border.color: theme.border
            border.width: 1
            clip: true

            Row {
                id: previewContainer
                anchors.centerIn: parent
                spacing: 8

                Repeater {
                    model: (previewPopup.workspaceData && previewPopup.workspaceData.toplevels)
                    ? previewPopup.workspaceData.toplevels.values.filter(function(t) {
                        return t.wayland != null;
                    })
                    : []

                    Rectangle {
                        id: windowCard
                        required property var modelData

                        width: 200
                        height: 145
                        radius: 8
                        color: theme.windowSurface
                        border.color: modelData.activated ? theme.accent : "transparent"
                        border.width: 1
                        clip: true

                        Column {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 4

                            // Live screencopy frame
                            ScreencopyView {
                                width: parent.width
                                height: parent.height - titleText.implicitHeight - 6
                                captureSource: previewPopup.isHovered ? modelData.wayland : null
                                live: previewPopup.isHovered
                                paintCursor: false
                            }

                            // Window title bar
                            Text {
                                id: titleText
                                width: parent.width
                                text: modelData.title || "Window"
                                color: theme.text
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- Workspaces ----
    RowLayout {
        id: workspaceBar
        spacing: 4
        Layout.alignment: Qt.AlignVCenter

        property bool showWorkspaceIcons: true

        property int focusedWorkspaceId: {
            var workspaces = Hyprland.workspaces.values
            for (var i = 0; i < workspaces.length; i++) {
                if (workspaces[i].focused)
                    return workspaces[i].id
            }
            return 1
        }

        // Current workspace number
        Text {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignVCenter

            text: workspaceBar.focusedWorkspaceId
            color: "#ffffff"

            font.family: root.nerdFontFamily
            font.bold: true
            font.pixelSize: 16
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        // Workspace icons + Toggle
        RowLayout {
            id: workspaceControls
            spacing: 4
            Layout.alignment: Qt.AlignVCenter

            // Toggle Button
            Rectangle {
                id: toggleRect
                Layout.preferredWidth: 12
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignVCenter
                radius: 4

                color: toggleMouseArea.containsMouse ? "#33ffffff" : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: workspaceBar.showWorkspaceIcons ? "\u276e" : "\u276f"
                    color: "#ffffff"
                    font.family: root.nerdFontFamily
                    font.pixelSize: 20
                }

                MouseArea {
                    id: toggleMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: workspaceBar.showWorkspaceIcons = !workspaceBar.showWorkspaceIcons
                }
            }

            // Animated workspace icons
            Item {
                id: workspaceIconsContainer
                Layout.preferredHeight: 24
                Layout.preferredWidth: workspaceBar.showWorkspaceIcons ? workspaceIcons.implicitWidth : 0
                Layout.alignment: Qt.AlignVCenter
                clip: true

                Behavior on Layout.preferredWidth {
                    NumberAnimation {
                        duration: 500
                        easing.type: Easing.InOutQuad
                    }
                }

                RowLayout {
                    id: workspaceIcons
                    spacing: 2
                    Layout.preferredHeight: 24

                    Repeater {
                        model: Hyprland.workspaces.values

                        Rectangle {
                            id: wsDelegate
                            required property var modelData

                            readonly property bool hasWindows: modelData.toplevels && modelData.toplevels.values.length > 0
                            property bool isHovered: false

                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 24
                            Layout.alignment: Qt.AlignVCenter
                            radius: 4

                            color: modelData.focused
                            ? "#64727D"
                            : (wsDelegate.isHovered ? "#33ffffff" : "transparent")

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    var icons = {
                                        1: "", 2: "", 3: "", 4: "", 5: "",
                                        6: "", 7: "", 8: "", 9: "", 10: ""
                                    }
                                    return icons[wsDelegate.modelData.id] || "$"
                                }
                                color: "#ffffff"
                                font.pixelSize: 20
                            }

                            // Active/occupied underline indicator
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottomMargin: 2
                                width: parent.width * 0.7
                                height: 1
                                radius: 1
                                color: "#FFFFFF"
                                visible: wsDelegate.hasWindows
                            }

                            // Live preview popup anchored to the icon
                            WorkspaceLivePreview {
                                anchorItem: wsDelegate
                                workspaceData: wsDelegate.modelData
                                isHovered: wsDelegate.isHovered
                            }

                            MouseArea {
                                id: wsMouseArea
                                anchors.fill: parent
                                hoverEnabled: true

                                onEntered: wsDelegate.isHovered = true
                                onExited: wsDelegate.isHovered = false

                                onClicked: {
                                    if (Hyprland.usingLua) {
                                        Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsDelegate.modelData.id + " })")
                                    } else {
                                        Hyprland.dispatch("workspace " + wsDelegate.modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- Media (playerctl) ----
    Text {
        id: mediaText
        Layout.alignment: Qt.AlignVCenter

        property string playerOutput: ""

        visible: playerOutput !== ""
        text: playerOutput
        color: "#ffffff"
        font.pixelSize: 16
        elide: Text.ElideRight
        Layout.preferredWidth: Math.min(implicitWidth, 200)

        Process {
            id: playerctlProc
            command: [
                "playerctl",
                "metadata",
                "--format",
                "{{artist}} - {{title}}"
            ]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    var output = text.trim()
                    mediaText.playerOutput = output !== "" ? "󰝚  " + output : ""
                }
            }
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: playerctlProc.running = true
        }
    }

    // ---- Cava-style visualizer ----
    RowLayout {
        id: mediaSection
        spacing: 6
        Layout.preferredHeight: 30
        Layout.alignment: Qt.AlignVCenter

        Text {
            id: cavaText
            Layout.preferredWidth: 10 * 10
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignVCenter

            color: "#ffffff"
            font.pixelSize: 20
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            text: cavaOutput + " "

            property string cavaOutput: "⣀⣀⣀⣀⣀⣀⣀⣀"

            Process {
                id: cavaProc
                command: [
                    "cava",
                    "-p",
                    Quickshell.env("HOME") + "/.config/cava/config_waybar"
                ]
                running: true

                stdout: SplitParser {
                    onRead: function(line) {
                        var parts = line
                        .split(";")
                        .filter(function(s) { return s.length > 0 })

                        var glyphs = ["⣀", "⣀", "⣀", "⣤", "⣤", "⣶", "⣶", "⣿", "⣿"]
                        var output = ""

                        for (var i = 0; i < Math.min(parts.length, 10); i++) {
                            var value = parseInt(parts[i])
                            if (isNaN(value)) value = 0
                                value = Math.max(0, Math.min(8, value))
                                output += glyphs[value]
                        }

                        while (output.length < 8) {
                            output += "⣀"
                        }

                        cavaText.cavaOutput = output
                    }
                }
            }
        }
    }
}
