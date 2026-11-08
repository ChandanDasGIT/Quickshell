import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

// Notepad popup.
// Every *.txt file in ./Notes is a tab. The editor is always editable and
// autosaves shortly after you stop typing (and on tab switch / close).
//
// Keys:  Ctrl+S save · Ctrl+N new note · Ctrl+F find (Enter / F3 next, Shift+F3 prev)
//        Ctrl+Tab / Ctrl+Shift+Tab switch tab · Ctrl+= / Ctrl+- / Ctrl+0 zoom · Esc close
Item {
    id: root

    property bool notesVisible: false
    property var anchorItem

    readonly property url notesDirUrl: Qt.resolvedUrl("./Notes")
    readonly property string notesDir: decodeURIComponent(String(notesDirUrl).replace(/^file:\/\//, ""))
    readonly property string iconFont: "JetBrainsMono Nerd Font"

    // ---- editor state ----
    property string currentFile: ""     // e.g. "to-do.txt"
    property string savedText: ""       // what is on disk for currentFile
    property bool ready: false          // currentFile finished loading into the editor
    property bool suppress: false       // true while we set editor.text ourselves
    readonly property bool dirty: ready && editor.text !== savedText
    property int fontSize: 14
    property string justCreated: ""
    property bool naming: false         // "new note" name field visible
    property bool finding: false        // find bar visible

    // ---- open / close ----
    function toggle() {
        if (notesVisible) {
            saveNow()
            finding = false
            naming = false
            notesVisible = false
        } else {
            notesVisible = true
            Qt.callLater(goTop)
        }
    }

    // Cursor + scroll to the start of the note (done after layout so nothing overrides it)
    function goTop() {
        editor.forceActiveFocus()
        editor.deselect()
        editor.cursorPosition = 0
        scroll.contentY = 0
    }

    // ---- file handling ----
    function saveNow() {
        autosave.stop()
        if (!ready || !currentFile) return
        if (editor.text !== savedText) {
            noteFile.setText(editor.text)
            savedText = editor.text
        }
    }

    function indexOfFile(name) {
        for (let i = 0; i < folder.count; i++)
            if (folder.get(i, "fileName") === name) return i
        return -1
    }

    function openNote(name) {
        if (!name || name === currentFile) return
        saveNow()
        ready = false
        currentFile = name
    }

    function cycleNote(step) {
        const n = folder.count
        if (n < 2) return
        const i = indexOfFile(currentFile)
        openNote(folder.get(((i < 0 ? 0 : i) + step + n) % n, "fileName"))
    }

    // Pick a tab when notes first load, or when the open note was deleted elsewhere
    function pickDefault() {
        if (folder.status !== FolderListModel.Ready) return
        if (currentFile && (indexOfFile(currentFile) >= 0 || currentFile === justCreated)) {
            if (indexOfFile(currentFile) >= 0) justCreated = ""
            return
        }
        ready = false   // never write back a file that disappeared
        currentFile = ""
        if (folder.count > 0)
            openNote(indexOfFile("to-do.txt") >= 0 ? "to-do.txt" : folder.get(0, "fileName"))
    }

    function applyLoaded(t) {
        if (ready && t === editor.text) { savedText = t; return }
        if (ready && dirty) return               // don't clobber unsaved typing
        const firstLoad = !ready
        const pos = editor.cursorPosition
        suppress = true
        editor.text = t
        suppress = false
        savedText = t
        ready = true
        if (firstLoad)
            Qt.callLater(goTop)                  // freshly opened note: start at the top
        else
            editor.cursorPosition = Math.min(pos, editor.length)   // reloaded after an outside edit: stay put
    }

    function createNote(raw) {
        let name = raw.trim().replace(/[\/\\]/g, "-").replace(/^\.+/, "")
        if (!name) return
        if (!name.toLowerCase().endsWith(".txt")) name += ".txt"
        if (indexOfFile(name) >= 0) { openNote(name); return }
        touchProc.name = name
        touchProc.command = ["touch", "--", notesDir + "/" + name]
        touchProc.running = true
    }

    // ---- find ----
    readonly property int matchCount: {
        const q = findField.text.toLowerCase()
        if (!finding || !q) return 0
        const hay = editor.text.toLowerCase()
        let n = 0, i = hay.indexOf(q)
        while (i >= 0) { n++; i = hay.indexOf(q, i + q.length) }
        return n
    }

    function findFrom(start, backwards) {
        const q = findField.text
        if (!q) return
        const hay = editor.text.toLowerCase(), needle = q.toLowerCase()
        let i
        if (!backwards) {
            i = hay.indexOf(needle, start)
            if (i < 0) i = hay.indexOf(needle)
        } else {
            i = start >= 0 ? hay.lastIndexOf(needle, start) : -1
            if (i < 0) i = hay.lastIndexOf(needle)
        }
        if (i >= 0) editor.select(i, i + q.length)
    }
    function findNext() { findFrom(editor.selectionEnd, false) }
    function findPrev() { findFrom(editor.selectionStart - 1, true) }

    function openFind() {
        naming = false
        finding = true
        if (editor.selectedText && editor.selectedText.indexOf("\n") < 0)
            findField.text = editor.selectedText
        Qt.callLater(() => { findField.forceActiveFocus(); findField.selectAll() })
    }
    function closeFind() {
        finding = false
        editor.forceActiveFocus()
    }

    // ---- caret / stats for the status bar ----
    readonly property int caretLine: editor.text.substring(0, editor.cursorPosition).split("\n").length
    readonly property int caretCol: editor.cursorPosition - editor.text.lastIndexOf("\n", editor.cursorPosition - 1)
    readonly property int wordCount: editor.text.trim() === "" ? 0 : editor.text.trim().split(/\s+/).length

    // ---- backend ----
    FolderListModel {
        id: folder
        folder: root.notesDirUrl
        nameFilters: ["*.txt"]
        showDirs: false
        sortField: FolderListModel.Name
        onStatusChanged: Qt.callLater(root.pickDefault)
        onCountChanged: Qt.callLater(root.pickDefault)
    }

    FileView {
        id: noteFile
        path: root.currentFile ? root.notesDir + "/" + root.currentFile : ""
        watchChanges: true
        printErrors: false
        onLoaded: root.applyLoaded(text())
        onLoadFailed: root.applyLoaded("")
        onFileChanged: { if (!root.dirty) reload() }   // edited outside? pick it up
    }

    Process {
        id: touchProc
        property string name: ""
        onExited: { root.justCreated = name; root.openNote(name) }
    }

    Timer {
        id: autosave
        interval: 800
        onTriggered: root.saveNow()
    }

    IpcHandler {
        target: "notes"
        function toggle(): void { root.toggle() }
    }

    FontMetrics { id: fm; font: editor.font }

    // ---- small reusable bits ----
    component IconButton: Text {
        id: btn
        property color idleColor: "#777"
        property color hoverColor: "#ffffff"
        property string tip: ""
        signal clicked()
        font.family: root.iconFont
        font.pixelSize: 14
        color: btnArea.containsMouse ? hoverColor : idleColor
        MouseArea {
            id: btnArea
            anchors.fill: parent
            anchors.margins: -5
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
        ToolTip.visible: tip !== "" && btnArea.containsMouse
        ToolTip.delay: 500
        ToolTip.text: tip
    }

    // ---- window ----
    PanelWindow {
        id: popup
        visible: root.notesVisible
        color: "transparent"
        focusable: true
        exclusiveZone: 0
        anchors { top: true; bottom: true; left: true; right: true }

        Shortcut {
            sequence: "Escape"
            context: Qt.WindowShortcut
            onActivated: {
                if (root.finding) root.closeFind()
                else if (root.naming) { root.naming = false; editor.forceActiveFocus() }
                else root.toggle()
            }
        }
        Shortcut { sequence: "Ctrl+S"; context: Qt.WindowShortcut; onActivated: root.saveNow() }
        Shortcut { sequence: "Ctrl+F"; context: Qt.WindowShortcut; onActivated: root.openFind() }
        Shortcut { sequences: ["F3", "Ctrl+G"]; context: Qt.WindowShortcut; enabled: root.finding; onActivated: root.findNext() }
        Shortcut { sequences: ["Shift+F3", "Ctrl+Shift+G"]; context: Qt.WindowShortcut; enabled: root.finding; onActivated: root.findPrev() }
        Shortcut {
            sequence: "Ctrl+N"
            context: Qt.WindowShortcut
            onActivated: { root.finding = false; root.naming = true }
        }
        Shortcut { sequences: ["Ctrl+Tab", "Ctrl+PgDown"]; context: Qt.WindowShortcut; onActivated: root.cycleNote(1) }
        Shortcut { sequences: ["Ctrl+Shift+Tab", "Ctrl+Backtab", "Ctrl+PgUp"]; context: Qt.WindowShortcut; onActivated: root.cycleNote(-1) }
        Shortcut { sequences: ["Ctrl+=", "Ctrl++"]; context: Qt.WindowShortcut; onActivated: root.fontSize = Math.min(root.fontSize + 1, 32) }
        Shortcut { sequence: "Ctrl+-"; context: Qt.WindowShortcut; onActivated: root.fontSize = Math.max(root.fontSize - 1, 8) }
        Shortcut { sequence: "Ctrl+0"; context: Qt.WindowShortcut; onActivated: root.fontSize = 14 }

        // Backdrop: click outside closes (and saves)
        MouseArea {
            anchors.fill: parent
            onClicked: root.toggle()
        }

        Rectangle {
            id: panel
            anchors.centerIn: parent
            width: Math.min(parent.width * 0.6, 1100)
            height: parent.height * 0.8
            color: "#0d0d0d"
            radius: 12
            border.color: "#2a2a2a"
            border.width: 1

            opacity: root.notesVisible ? 1 : 0
            scale: root.notesVisible ? 1 : 0.97
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            // swallow clicks so they don't hit the backdrop
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                // ---------- tab bar ----------
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Flickable {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        contentWidth: tabRow.implicitWidth
                        contentHeight: height
                        flickableDirection: Flickable.HorizontalFlick
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true

                        Row {
                            id: tabRow
                            height: parent.height
                            spacing: 4

                            Repeater {
                                model: folder
                                delegate: Rectangle {
                                    id: tab
                                    required property string fileName
                                    readonly property bool current: fileName === root.currentFile
                                    height: 30
                                    width: tabLabel.implicitWidth + 24
                                    radius: 6
                                    color: current ? "#1f1f1f" : (tabArea.containsMouse ? "#161616" : "transparent")
                                    border.color: current ? "#2e2e2e" : "transparent"

                                    Text {
                                        id: tabLabel
                                        anchors.centerIn: parent
                                        text: tab.fileName.replace(/\.txt$/i, "") + (tab.current && root.dirty ? " ●" : "")
                                        textFormat: Text.PlainText
                                        color: tab.current ? "#e0e0e0" : "#777"
                                        font.family: "monospace"
                                        font.pixelSize: 12
                                    }
                                    MouseArea {
                                        id: tabArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.openNote(tab.fileName)
                                    }
                                }
                            }

                            // new note name field
                            TextField {
                                id: nameField
                                visible: root.naming
                                height: 30
                                width: 160
                                placeholderText: "note name"
                                color: "#e0e0e0"
                                placeholderTextColor: "#555"
                                font.family: "monospace"
                                font.pixelSize: 12
                                background: Rectangle { radius: 6; color: "#161616"; border.color: "#3a3a3a" }
                                onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
                                onAccepted: {
                                    root.createNote(text)
                                    root.naming = false
                                }
                            }
                        }
                    }

                    IconButton {
                        text: ""     // plus
                        tip: "New note (Ctrl+N)"
                        onClicked: { root.finding = false; root.naming = !root.naming }
                    }
                    IconButton {
                        text: ""     // search
                        tip: "Find (Ctrl+F)"
                        onClicked: root.finding ? root.closeFind() : root.openFind()
                    }
                    IconButton {
                        text: ""     // x
                        hoverColor: "#e89b9b"
                        tip: "Close (Esc)"
                        onClicked: root.toggle()
                    }
                }

                // ---------- find bar ----------
                RowLayout {
                    visible: root.finding
                    Layout.fillWidth: true
                    spacing: 8

                    TextField {
                        id: findField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        placeholderText: "find in note"
                        color: "#e0e0e0"
                        placeholderTextColor: "#555"
                        font.family: "monospace"
                        font.pixelSize: 12
                        background: Rectangle { radius: 6; color: "#161616"; border.color: findField.activeFocus ? "#3a3a3a" : "#262626" }
                        onTextChanged: root.findFrom(editor.selectionStart, false)
                        onAccepted: root.findNext()
                        Keys.onPressed: (e) => {
                            if (e.key === Qt.Key_Return && (e.modifiers & Qt.ShiftModifier)) { root.findPrev(); e.accepted = true }
                        }
                    }
                    Text {
                        text: findField.text ? (root.matchCount + (root.matchCount === 1 ? " match" : " matches")) : ""
                        color: findField.text && root.matchCount === 0 ? "#e89b9b" : "#777"
                        font.family: "monospace"
                        font.pixelSize: 11
                    }
                    IconButton { text: ""; tip: "Previous (Shift+F3)"; onClicked: root.findPrev() }
                    IconButton { text: ""; tip: "Next (F3 / Enter)"; onClicked: root.findNext() }
                }

                // ---------- editor ----------
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#141414"
                    radius: 10
                    border.color: editor.activeFocus ? "#333" : "#242424"

                    Flickable {
                        id: scroll
                        anchors.fill: parent
                        anchors.margins: 2
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle {
                                implicitWidth: 4
                                radius: 2
                                color: "#ffffff"
                                opacity: parent.pressed ? 0.5 : (parent.hovered ? 0.35 : 0.2)
                            }
                        }

                        // attached: the TextArea fills the view and keeps the cursor scrolled into view
                        TextArea.flickable: TextArea {
                            id: editor
                            readOnly: !root.ready
                            textFormat: TextEdit.PlainText
                            wrapMode: TextArea.Wrap
                            selectByMouse: true
                            persistentSelection: true     // keep find highlight visible while typing in the find bar
                            color: "#e0e0e0"
                            selectionColor: "#3a5a8a"
                            selectedTextColor: "#ffffff"
                            placeholderText: root.currentFile ? "Start typing…" : "No notes yet. Press Ctrl+N to make one."
                            placeholderTextColor: "#444"
                            font.family: "monospace"
                            font.pixelSize: root.fontSize
                            tabStopDistance: fm.averageCharacterWidth * 4
                            leftPadding: 14
                            rightPadding: 14
                            topPadding: 12
                            bottomPadding: 12
                            background: null

                            onTextChanged: {
                                if (!root.suppress && root.ready)
                                    autosave.restart()
                            }
                        }
                    }
                }

                // ---------- status bar ----------
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Text {
                        text: !root.currentFile ? "" : (!root.ready ? "loading…" : (root.dirty ? "editing…" : "saved"))
                        color: root.dirty ? "#c8b06a" : "#5c8f5c"
                        font.family: "monospace"
                        font.pixelSize: 11
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "Ln " + root.caretLine + ", Col " + root.caretCol
                              + "   " + root.wordCount + " words   " + editor.length + " chars   "
                              + Math.round(root.fontSize / 14 * 100) + "%"
                        color: "#555"
                        font.family: "monospace"
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
