import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "."

PanelWindow {
    id: oskWindow

    // Prevents the OSK window from stealing keyboard input from target windows
    focusable: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-virtual-keyboard"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    mask: Region {
        item: keyboardCard
    }

    color: "transparent"
    visible: false

    property bool fnActive: false
    property bool showExtras: false

    function toggle(): void {
        visible = !visible;
        if (!visible) {
            KeyEmitter.resetModifiers();
        }
    }

    function show(): void {
        visible = true;
    }

    function hide(): void {
        visible = false;
        KeyEmitter.resetModifiers();
    }

    IpcHandler {
        target: "virtualKeyboard"
        function toggle(): void { oskWindow.toggle(); }
        function show(): void { oskWindow.show(); }
        function hide(): void { oskWindow.hide(); }
    }

    // Floating Keyboard Container
    Rectangle {
        id: keyboardCard

        // Widened default and extended cards to give main typing area more space
        width: oskWindow.showExtras ? 1020 : 740
        height: 320

        x: oskWindow.screen ? (oskWindow.screen.width - width) / 2 : 200
        y: oskWindow.screen ? oskWindow.screen.height - height - 80 : 400

        radius: 14
        color: "#e60e0e11"
        border.color: "#33ffffff"
        border.width: 1
        clip: true

        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 5

            // Top Drag Handle & Bar
            Rectangle {
                id: topBar
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                color: dragMouse.containsMouse ? "#20ffffff" : "transparent"
                radius: 6

                MouseArea {
                    id: dragMouse
                    anchors.fill: parent
                    cursorShape: Qt.SizeAllCursor
                    hoverEnabled: true

                    drag.target: keyboardCard
                    drag.axis: Drag.XAndYAxis
                    drag.minimumX: 10
                    drag.maximumX: (oskWindow.screen ? oskWindow.screen.width : 1920) - keyboardCard.width - 10
                    drag.minimumY: 10
                    drag.maximumY: (oskWindow.screen ? oskWindow.screen.height : 1080) - keyboardCard.height - 10
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8

                    Rectangle {
                        width: 40
                        height: 4
                        radius: 2
                        color: "#55ffffff"
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "KEYBOARD"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.bold: true
                        color: "#66ffffff"
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "✕"
                        font.pixelSize: 13
                        font.bold: true
                        color: closeMouse.containsMouse ? "#ff5555" : "#77ffffff"
                        Layout.alignment: Qt.AlignVCenter

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: oskWindow.hide()
                        }
                    }
                }
            }

            // Keyboard Layout
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                // Main Alphanumeric Cluster (Expands to absorb extra room)
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    // Number / Function Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        VirtualKey {
                            label: "Esc"
                            specialKey: "Escape"
                            Layout.preferredWidth: 44
                            btnColor: "#222228"
                            fontSize: 12
                        }

                        Repeater {
                            model: oskWindow.fnActive
                            ? ["F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"]
                            : ["`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="]

                            VirtualKey {
                                label: modelData
                                specialKey: oskWindow.fnActive ? modelData : ""
                                charValue: oskWindow.fnActive ? "" : modelData
                                Layout.fillWidth: true
                                fontSize: oskWindow.fnActive ? 12 : 16
                            }
                        }

                        VirtualKey {
                            label: "⌫"
                            specialKey: "BackSpace"
                            Layout.preferredWidth: 58
                            btnColor: "#332222"
                            fontSize: 16
                        }
                    }

                    // QWERTY Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        VirtualKey {
                            label: "Tab"
                            specialKey: "Tab"
                            Layout.preferredWidth: 54
                            btnColor: "#222228"
                            fontSize: 12
                        }

                        Repeater {
                            model: ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "[", "]", "\\"]
                            VirtualKey {
                                label: KeyEmitter.shiftHeld ? KeyEmitter.getShiftedChar(modelData) : modelData
                                charValue: modelData
                                Layout.fillWidth: true
                                fontSize: 18
                            }
                        }
                    }

                    // Home Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        VirtualKey {
                            label: "Fn"
                            Layout.preferredWidth: 48
                            isToggled: oskWindow.fnActive
                            onClicked: oskWindow.fnActive = !oskWindow.fnActive
                            fontSize: 12
                        }

                        Repeater {
                            model: ["a", "s", "d", "f", "g", "h", "j", "k", "l", ";", "'"]
                            VirtualKey {
                                label: KeyEmitter.shiftHeld ? KeyEmitter.getShiftedChar(modelData) : modelData
                                charValue: modelData
                                Layout.fillWidth: true
                                fontSize: 18
                            }
                        }

                        VirtualKey {
                            label: "Enter ⏎"
                            specialKey: "Return"
                            Layout.preferredWidth: 80
                            btnColor: "#1d3324"
                            fontSize: 13
                        }
                    }

                    // Bottom Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        VirtualKey {
                            label: "Shift"
                            isToggled: KeyEmitter.shiftHeld
                            Layout.preferredWidth: 74
                            onClicked: KeyEmitter.toggleShift()
                            fontSize: 13
                        }

                        Repeater {
                            model: ["z", "x", "c", "v", "b", "n", "m", ",", ".", "/"]
                            VirtualKey {
                                label: KeyEmitter.shiftHeld ? KeyEmitter.getShiftedChar(modelData) : modelData
                                charValue: modelData
                                Layout.fillWidth: true
                                fontSize: 18
                            }
                        }

                        VirtualKey {
                            label: "Shift"
                            isToggled: KeyEmitter.shiftHeld
                            Layout.preferredWidth: 74
                            onClicked: KeyEmitter.toggleShift()
                            fontSize: 13
                        }
                    }

                    // Modifiers + Space + Extra Panel Toggle
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        VirtualKey {
                            label: "Ctrl"
                            isToggled: KeyEmitter.ctrlHeld
                            Layout.preferredWidth: 50
                            onClicked: KeyEmitter.toggleCtrl()
                            fontSize: 12
                        }

                        VirtualKey {
                            label: "Win"
                            isToggled: KeyEmitter.superHeld
                            Layout.preferredWidth: 46
                            onClicked: KeyEmitter.toggleSuper()
                            fontSize: 12
                        }

                        VirtualKey {
                            label: "Alt"
                            isToggled: KeyEmitter.altHeld
                            Layout.preferredWidth: 46
                            onClicked: KeyEmitter.toggleAlt()
                            fontSize: 12
                        }

                        VirtualKey {
                            label: "Space"
                            specialKey: "Space"
                            Layout.fillWidth: true
                            btnColor: "#1a1a1f"
                            fontSize: 13
                        }

                        VirtualKey {
                            label: "Alt"
                            isToggled: KeyEmitter.altHeld
                            Layout.preferredWidth: 46
                            onClicked: KeyEmitter.toggleAlt()
                            fontSize: 12
                        }

                        VirtualKey {
                            label: "Ctrl"
                            isToggled: KeyEmitter.ctrlHeld
                            Layout.preferredWidth: 50
                            onClicked: KeyEmitter.toggleCtrl()
                            fontSize: 12
                        }

                        VirtualKey {
                            label: oskWindow.showExtras ? "EXT ▶" : "◀ EXT"
                            isToggled: oskWindow.showExtras
                            Layout.preferredWidth: 64
                            btnColor: "#202838"
                            fontSize: 11
                            onClicked: oskWindow.showExtras = !oskWindow.showExtras
                        }
                    }
                }

                // Collapsible Extra Panels
                RowLayout {
                    visible: oskWindow.showExtras
                    Layout.fillHeight: true
                    spacing: 6

                    Rectangle {
                        width: 1
                        Layout.fillHeight: true
                        color: "#33ffffff"
                    }

                    // Navigation Cluster & Arrow Keys (Filled out to utilize vertical and horizontal room)
                    ColumnLayout {
                        Layout.preferredWidth: 90
                        Layout.fillHeight: true
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            VirtualKey { label: "Ins"; specialKey: "Insert"; Layout.fillWidth: true; fontSize: 11 }
                            VirtualKey { label: "Del"; specialKey: "Delete"; Layout.fillWidth: true; fontSize: 11 }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            VirtualKey { label: "Home"; specialKey: "Home"; Layout.fillWidth: true; fontSize: 11 }
                            VirtualKey { label: "End"; specialKey: "End"; Layout.fillWidth: true; fontSize: 11 }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            VirtualKey { label: "PgUp"; specialKey: "Prior"; Layout.fillWidth: true; fontSize: 11 }
                            VirtualKey { label: "PgDn"; specialKey: "Next"; Layout.fillWidth: true; fontSize: 11 }
                        }

                        // Arrow Up takes full width across the column
                        VirtualKey {
                            label: "▲"
                            specialKey: "Up"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            fontSize: 15
                        }

                        // Arrow Left / Down / Right split the base equally
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 3
                            VirtualKey { label: "◀"; specialKey: "Left"; Layout.fillWidth: true; Layout.fillHeight: true; fontSize: 15 }
                            VirtualKey { label: "▼"; specialKey: "Down"; Layout.fillWidth: true; Layout.fillHeight: true; fontSize: 15 }
                            VirtualKey { label: "▶"; specialKey: "Right"; Layout.fillWidth: true; Layout.fillHeight: true; fontSize: 15 }
                        }
                    }

                    Rectangle {
                        width: 1
                        Layout.fillHeight: true
                        color: "#33ffffff"
                    }

                    // Slimmer Numpad Cluster
                    ColumnLayout {
                        Layout.preferredWidth: 110
                        Layout.fillHeight: true
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            VirtualKey { label: "Num"; Layout.fillWidth: true; btnColor: "#26262b"; fontSize: 10 }
                            VirtualKey { label: "/"; specialKey: "KP_Divide"; Layout.fillWidth: true; fontSize: 13 }
                            VirtualKey { label: "*"; specialKey: "KP_Multiply"; Layout.fillWidth: true; fontSize: 13 }
                            VirtualKey { label: "-"; specialKey: "KP_Subtract"; Layout.fillWidth: true; fontSize: 13 }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            VirtualKey { label: "7"; specialKey: "KP_7"; Layout.fillWidth: true; fontSize: 15 }
                            VirtualKey { label: "8"; specialKey: "KP_8"; Layout.fillWidth: true; fontSize: 15 }
                            VirtualKey { label: "9"; specialKey: "KP_9"; Layout.fillWidth: true; fontSize: 15 }
                            VirtualKey { label: "+"; specialKey: "KP_Add"; Layout.fillWidth: true; fontSize: 14 }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            VirtualKey { label: "4"; specialKey: "KP_4"; Layout.fillWidth: true; fontSize: 15 }
                            VirtualKey { label: "5"; specialKey: "KP_5"; Layout.fillWidth: true; fontSize: 15 }
                            VirtualKey { label: "6"; specialKey: "KP_6"; Layout.fillWidth: true; fontSize: 15 }
                            VirtualKey { label: "="; charValue: "="; Layout.fillWidth: true; fontSize: 14 }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            VirtualKey { label: "1"; specialKey: "KP_1"; Layout.fillWidth: true; fontSize: 15 }
                            VirtualKey { label: "2"; specialKey: "KP_2"; Layout.fillWidth: true; fontSize: 15 }
                            VirtualKey { label: "3"; specialKey: "KP_3"; Layout.fillWidth: true; fontSize: 15 }
                            VirtualKey { label: "Ent"; specialKey: "KP_Enter"; Layout.fillWidth: true; btnColor: "#1d3324"; fontSize: 10 }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            VirtualKey { label: "0"; specialKey: "KP_0"; Layout.fillWidth: true; Layout.preferredWidth: 68; fontSize: 15 }
                            VirtualKey { label: "."; specialKey: "KP_Decimal"; Layout.fillWidth: true; Layout.preferredWidth: 34; fontSize: 15 }
                        }
                    }
                }
            }
        }
    }

    // Key Component
    component VirtualKey: Rectangle {
        id: keyRoot

        property string label: ""
        property string charValue: ""
        property string specialKey: ""
        property bool isToggled: false
        property color btnColor: "#16161b"
        property int fontSize: 16

        signal clicked()

        Layout.fillHeight: true
        Layout.minimumHeight: 36
        radius: 7
        color: isToggled
        ? "#35528c"
        : (keyArea.pressed
        ? "#444455"
        : (keyArea.containsMouse ? "#2a2a35" : btnColor))
        border.color: isToggled
        ? "#89b4fa"
        : (keyArea.containsMouse ? "#80ffffff" : "#26ffffff")
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: keyRoot.label
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: keyRoot.fontSize
            font.bold: true
            color: keyRoot.isToggled ? "#ffffff" : "#eeeeee"
        }

        MouseArea {
            id: keyArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                keyRoot.clicked();

                if (keyRoot.charValue !== "" || keyRoot.specialKey !== "") {
                    KeyEmitter.emitKey(keyRoot.charValue, keyRoot.specialKey);
                }
            }
        }
    }
}
