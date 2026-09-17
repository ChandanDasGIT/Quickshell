import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// A fuzzel-style application launcher for Quickshell.
//
// Place this file at: modules/applauncher/AppLauncher.qml
//
// Usage from shell.qml (or wherever you assemble your shell):
//
//   AppLauncher {
//       id: appLauncher
//   }
//
//   GlobalShortcut {
//       name: "appLauncher"
//       description: "Toggle the app launcher"
//       onPressed: appLauncher.toggle()
//   }
//
// (GlobalShortcut needs Quickshell.Hyprland / Quickshell's global shortcut
// portal depending on your compositor -- wire it to whatever keybind
// mechanism you already use, e.g. an exec-once `qs ipc call` from Hyprland.
// You can also just call appLauncher.show()/hide()/toggle() directly.)

Scope {
    id: root

    // ---- Tunables -----------------------------------------------------
    property int launcherWidth: 600
    property int launcherHeight: 440
//    property int maxResults: 9
    property var excludedCategories: ["Settings"]
    property var excludedNames: ["Contact Sheet", "Print Theme Editor"] // add more substrings here to hide specific apps
    property real yPosition: 0.22 // fraction of screen height from top

    property color bgColor: "#1e1e2e"
    property color borderColor: "#313244"
    property color textColor: "#cdd6f4"
    property color subTextColor: "#a6adc8"
    property color selectedColor: "#313244"
    property color accentColor: "#89b4fa"

    // ---- Public API -----------------------------------------------------
    property bool isVisible: false
    property string query: ""

    function show() {
        query = "";
        isVisible = true;
    }

    function hide() {
        isVisible = false;
    }

    function toggle() {
        if (isVisible) hide(); else show();
    }

    function launch(entry) {
        if (entry === undefined || entry === null) return;
        entry.execute();
        hide();
    }

    function launchCurrent() {
        const entry = list.currentEntry();
        if (entry) launch(entry);
    }

    // Lets a compositor keybind trigger the launcher, e.g.:
    //   qs ipc call applauncher toggle
    IpcHandler {
        target: "applauncher"
        function toggle(): void { root.toggle(); }
        function show(): void { root.show(); }
        function hide(): void { root.hide(); }
    }

    // Simple subsequence-based fuzzy matcher (fzf/fuzzel style):
    // every character of "pattern" must appear in "text" in order.
    // Returns -1 for no match, otherwise a score where higher = better
    // (consecutive matches and matches near the start score higher).
    function fuzzyScore(pattern, text) {
        if (pattern.length === 0) return 0;
        let ti = 0;
        let score = 0;
        let consecutive = 0;
        for (let pi = 0; pi < pattern.length; pi++) {
            const ch = pattern[pi];
            const idx = text.indexOf(ch, ti);
            if (idx === -1) return -1;

            if (idx === ti) {
                consecutive += 1;
                score += 3 + consecutive; // reward runs of consecutive chars
            } else {
                consecutive = 0;
                score += 1;
            }
            if (idx === 0 || text[idx - 1] === " ") score += 2; // word-start bonus
            ti = idx + 1;
        }
        // Slight bonus for shorter overall strings (tighter match)
        score += Math.max(0, 20 - text.length) * 0.05;
        return score;
    }

    PanelWindow {
        id: window
        visible: root.isVisible
        color: "transparent"
        focusable: true

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell:applauncher"

        onVisibleChanged: {
            if (visible) {
                searchInput.text = "";
                searchInput.forceActiveFocus();
                list.currentIndex = 0;
            }
        }

        // Click outside the card closes the launcher.
        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
        }

        Rectangle {
            id: card
            width: root.launcherWidth
            height: root.launcherHeight
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * root.yPosition
            radius: 16
            color: root.bgColor
            border.color: root.borderColor
            border.width: 1
            clip: true

            // Eat clicks inside the card so they don't bubble to the
            // full-screen MouseArea above and close the launcher.
            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => mouse.accepted = true
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // ---- Search field --------------------------------------
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "⌕"
                        font.pixelSize: 22
                        color: root.subTextColor
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        color: root.textColor
                        font.pixelSize: 18
                        clip: true
                        selectByMouse: true

                        onTextChanged: {
                            root.query = text;
                            list.currentIndex = 0;
                        }

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Search apps…"
                            color: root.subTextColor
                            visible: searchInput.text.length === 0
                        }

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Escape) {
                                root.hide();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down) {
                                list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                list.currentIndex = Math.max(list.currentIndex - 1, 0);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.launchCurrent();
                                event.accepted = true;
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: root.borderColor
                }

                // ---- Results list ---------------------------------------
                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    currentIndex: 0
                    highlightMoveDuration: 80

                    function currentEntry() {
                        if (count === 0) return null;
                        return model.values[currentIndex];
                    }

                    model: ScriptModel {
                        values: {
                            const q = root.query.trim().toLowerCase();
                            const all = [...DesktopEntries.applications.values]
                            .filter(d => d.name && !d.noDisplay)
                            .filter(d => !(d.categories || []).some(c => root.excludedCategories.includes(c)))
                            .filter(d => !root.excludedNames.some(n => d.name.toLowerCase().includes(n.toLowerCase())));

                            if (q === "") {
                                return all
                                .sort((a, b) => a.name.localeCompare(b.name))
                                .slice(0, root.maxResults);
                            }

                            const matched = all.filter(d => {
                                const words = d.name.toLowerCase().split(/\s+/);
                                return words.some(w => w.startsWith(q));
                            });

                            matched.sort((a, b) => {
                                const aFull = a.name.toLowerCase().startsWith(q) ? 0 : 1;
                                const bFull = b.name.toLowerCase().startsWith(q) ? 0 : 1;
                                if (aFull !== bFull) return aFull - bFull;
                                return a.name.localeCompare(b.name);
                            });

                            return matched.slice(0, root.maxResults);
                        }
                    }

                    delegate: Rectangle {
                        id: delegateRoot
                        required property var modelData
                        required property int index
                        property string resolvedIcon: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""

                        width: list.width
                        height: 52
                        radius: 10
                        color: index === list.currentIndex ? root.selectedColor : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 12

                            IconImage {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                source: delegateRoot.resolvedIcon
                                visible: delegateRoot.resolvedIcon.length > 0
                            }

                            Text {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                visible: delegateRoot.resolvedIcon.length === 0
                                text: "\u25a2"
                                color: root.subTextColor
                                font.pixelSize: 30
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: root.textColor
                                    font.pixelSize: 15
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.comment || ""
                                    color: root.subTextColor
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    visible: text.length > 0
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: list.currentIndex = index
                            onClicked: root.launch(modelData)
                        }
                    }

                    // Empty state
                    Text {
                        anchors.centerIn: parent
                        visible: list.count === 0
                        text: "No matching applications"
                        color: root.subTextColor
                        font.pixelSize: 14
                    }
                }
            }
        }
    }
}
