import QtQuick
import QtQuick.Layouts
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

Scope {
    id: root

    // ---- Tunables -----------------------------------------------------
    property int launcherWidth: 600
    property int launcherHeight: 440
    property int maxResults: 10
    property int maxRecentApps: 10
    property var excludedCategories: ["Settings"]
    property var excludedNames: ["Contact Sheet", "Print Theme Editor"]
    property real yPosition: 0.22 // fraction of screen height from top

    property color bgColor: "#1e1e2e"
    property color borderColor: "#313244"
    property color textColor: "#cdd6f4"
    property color subTextColor: "#a6adc8"
    property color selectedColor: "#313244"
    property color accentColor: "#89b4fa"

    // ---- Persistent Recent Apps Storage ---------------------------------
    Settings {
        id: recentStore
        category: "AppLauncher"
        property var recentAppIds: []
        property bool showAll: false    // last chosen view: all-apps grid (true) vs recents (false)
    }

    property var recentAppIds: recentStore.recentAppIds || []

    function recordRecentApp(appId) {
        if (!appId) return;
        let list = [...root.recentAppIds].filter(id => id !== appId);
        list.unshift(appId);
        if (list.length > root.maxRecentApps) {
            list = list.slice(0, root.maxRecentApps);
        }
        root.recentAppIds = list;
        recentStore.recentAppIds = list;
    }

    // ---- Public API -----------------------------------------------------
    property bool isVisible: false
    property string query: ""
    property bool showAll: recentStore.showAll  // grid of every app instead of recents; remembered
    property int gridColumns: 5

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

    function launch(item) {
        if (!item) return;
        const entry = item.entry || item;
        const appId = entry.id || entry.name;
        recordRecentApp(appId);
        entry.execute();
        hide();
    }

    function launchCurrent() {
        const item = showAll ? grid.currentEntry() : list.currentEntry();
        if (item) launch(item);
    }

    function toggleShowAll() {
        showAll = !showAll;
        recentStore.showAll = showAll;
        list.currentIndex = 0;
        grid.currentIndex = 0;
        searchInput.forceActiveFocus();
    }

    // Every launchable app after the exclusion filters
    function visibleApps() {
        return [...DesktopEntries.applications.values]
            .filter(d => d.name && !d.noDisplay)
            .filter(d => !(d.categories || []).some(c => root.excludedCategories.includes(c)))
            .filter(d => !root.excludedNames.some(n => d.name.toLowerCase().includes(n.toLowerCase())));
    }

    // Apps with a word starting with q; full-name prefix matches first
    function matchApps(apps, q) {
        const matched = apps.filter(d => {
            const words = d.name.toLowerCase().split(/\s+/);
            return words.some(w => w.startsWith(q));
        });
        matched.sort((a, b) => {
            const aFull = a.name.toLowerCase().startsWith(q) ? 0 : 1;
            const bFull = b.name.toLowerCase().startsWith(q) ? 0 : 1;
            if (aFull !== bFull) return aFull - bFull;
            return a.name.localeCompare(b.name);
        });
        return matched;
    }

    IpcHandler {
        target: "applauncher"
        function toggle(): void { root.toggle(); }
        function show(): void { root.show(); }
        function hide(): void { root.hide(); }
    }

    // Subsequence-based fuzzy matcher
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
                score += 3 + consecutive;
            } else {
                consecutive = 0;
                score += 1;
            }
            if (idx === 0 || text[idx - 1] === " ") score += 2;
            ti = idx + 1;
        }
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
                grid.currentIndex = 0;
            }
        }

        // Click outside closes the launcher
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
                            grid.currentIndex = 0;
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
                            } else if (root.showAll && event.key === Qt.Key_Down) {
                                grid.moveCurrentIndexDown();
                                event.accepted = true;
                            } else if (root.showAll && event.key === Qt.Key_Up) {
                                grid.moveCurrentIndexUp();
                                event.accepted = true;
                            } else if (root.showAll && event.key === Qt.Key_Right
                                       && searchInput.cursorPosition === searchInput.text.length) {
                                grid.moveCurrentIndexRight();
                                event.accepted = true;
                            } else if (root.showAll && event.key === Qt.Key_Left && searchInput.text.length === 0) {
                                grid.moveCurrentIndexLeft();
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

                    // Show-all toggle
                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        Layout.alignment: Qt.AlignVCenter
                        radius: 8
                        color: root.showAll
                            ? Qt.alpha(root.accentColor, allMouse.containsMouse ? 0.3 : 0.18)
                            : (allMouse.containsMouse ? root.selectedColor : "transparent")
                        border.color: root.showAll ? Qt.alpha(root.accentColor, 0.4) : "transparent"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "\uf00a"   // grid
                            color: root.showAll ? root.accentColor : root.subTextColor
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                        }

                        MouseArea {
                            id: allMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleShowAll()
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
                    visible: !root.showAll
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
                            const all = root.visibleApps();

                            // When empty query: display up to 10 recent apps first, fill remainder alphabetically
                            if (q === "") {
                                const recentIds = root.recentAppIds;
                                const recentItems = [];
                                const remainingApps = [];

                                for (const app of all) {
                                    const appId = app.id || app.name;
                                    const recIdx = recentIds.indexOf(appId);
                                    if (recIdx !== -1) {
                                        recentItems.push({ entry: app, isRecent: true, order: recIdx });
                                    } else {
                                        remainingApps.push({ entry: app, isRecent: false, order: 9999 });
                                    }
                                }

                                recentItems.sort((a, b) => a.order - b.order);
                                remainingApps.sort((a, b) => a.entry.name.localeCompare(b.entry.name));

                                const combined = recentItems.slice(0, root.maxRecentApps);
                                if (combined.length < root.maxResults) {
                                    combined.push(...remainingApps.slice(0, root.maxResults - combined.length));
                                }

                                return combined;
                            }

                            // When typing: filter matched apps (without recent tag)
                            return root.matchApps(all, q).slice(0, root.maxResults).map(d => ({ entry: d, isRecent: false }));
                        }
                    }

                    delegate: Rectangle {
                        id: delegateRoot
                        required property var modelData
                        required property int index

                        readonly property var appEntry: modelData.entry
                        readonly property bool isRecent: modelData.isRecent
                        property string resolvedIcon: (appEntry && appEntry.icon) ? Quickshell.iconPath(appEntry.icon, true) : ""

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
                                    text: delegateRoot.appEntry.name
                                    color: root.textColor
                                    font.pixelSize: 15
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: delegateRoot.appEntry.comment || ""
                                    color: root.subTextColor
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    visible: text.length > 0
                                }
                            }

                            // ---- "Recent" Badge Tag ----
                            Rectangle {
                                visible: delegateRoot.isRecent
                                Layout.alignment: Qt.AlignVCenter
                                Layout.rightMargin: 4
                                implicitWidth: recentTagText.implicitWidth + 12
                                implicitHeight: 20
                                radius: 5
                                color: Qt.alpha(root.accentColor, 0.18)
                                border.color: Qt.alpha(root.accentColor, 0.4)
                                border.width: 1

                                Text {
                                    id: recentTagText
                                    anchors.centerIn: parent
                                    text: "Recent"
                                    color: root.accentColor
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: list.currentIndex = index
                            onClicked: root.launch(delegateRoot.modelData)
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

                // ---- All apps grid --------------------------------------
                GridView {
                    id: grid
                    visible: root.showAll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    cellWidth: Math.floor(width / root.gridColumns)
                    cellHeight: 96
                    currentIndex: 0
                    highlightMoveDuration: 80
                    boundsBehavior: Flickable.StopAtBounds

                    function currentEntry() {
                        if (count === 0) return null;
                        return model.values[currentIndex];
                    }

                    // Alphabetical when empty; filtered (no result cap) while typing
                    model: ScriptModel {
                        values: {
                            if (!root.showAll) return [];
                            const q = root.query.trim().toLowerCase();
                            const all = root.visibleApps();
                            const apps = q === ""
                                ? all.sort((a, b) => a.name.localeCompare(b.name))
                                : root.matchApps(all, q);
                            return apps.map(d => ({ entry: d, isRecent: false }));
                        }
                    }

                    delegate: Item {
                        id: cell
                        required property var modelData
                        required property int index

                        readonly property var appEntry: modelData.entry
                        readonly property string resolvedIcon: (appEntry && appEntry.icon) ? Quickshell.iconPath(appEntry.icon, true) : ""

                        width: grid.cellWidth
                        height: grid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 3
                            radius: 10
                            color: cell.index === grid.currentIndex ? root.selectedColor : "transparent"

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 6

                                IconImage {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    source: cell.resolvedIcon
                                    visible: cell.resolvedIcon.length > 0
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    visible: cell.resolvedIcon.length === 0
                                    text: "\u25a2"
                                    color: root.subTextColor
                                    font.pixelSize: 36
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    text: cell.appEntry.name
                                    color: root.textColor
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignTop
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: grid.currentIndex = cell.index
                            onClicked: root.launch(cell.modelData)
                        }
                    }

                    // Empty state
                    Text {
                        anchors.centerIn: parent
                        visible: grid.count === 0
                        text: "No matching applications"
                        color: root.subTextColor
                        font.pixelSize: 14
                    }
                }
            }
        }
    }
}
