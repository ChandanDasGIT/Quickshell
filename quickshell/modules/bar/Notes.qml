import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool notesVisible: false

    function toggle() {
        if (notesVisible)
            autoSaveAll()
            notesVisible = !notesVisible
    }

    function autoSaveAll() {
        if (todoPane.editing) {
            todoPane.fileView.setText(todoPane.draftText)
            todoPane.editing = false
        }
        if (shortcutsPane.editing) {
            shortcutsPane.fileView.setText(shortcutsPane.draftText)
            shortcutsPane.editing = false
        }
    }

    property var anchorItem

    readonly property string todoPath: Qt.resolvedUrl("./Notes/to-do.txt")
    readonly property string shortcutsPath: Qt.resolvedUrl("./Notes/shortcuts.txt")

    FileView {
        id: todoFile
        path: root.todoPath
        watchChanges: true
        onFileChanged: reload()
    }

    FileView {
        id: shortcutsFile
        path: root.shortcutsPath
        watchChanges: true
        onFileChanged: reload()
    }

    IpcHandler {
        target: "notes"
        function toggle(): void {
            root.toggle()
        }
    }

    // ---- reusable editable note pane ----
    component NotePane: Rectangle {
        id: pane
        property string title: ""
        property var fileView
        property bool editing: false
        property string draftText: ""

        color: "#141414"
        radius: 10
        border.color: "#2a2a2a"

        onEditingChanged: {
            if (editing)
                Qt.callLater(function() { editField.forceActiveFocus() })
        }
        Shortcut {
            sequence: "Ctrl+S"
            enabled: pane.editing
            context: Qt.WindowShortcut
            onActivated: {
                pane.fileView.setText(pane.draftText)
                pane.editing = false
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: pane.title
                    color: "#888"
                    font.family: "monospace"
                    font.letterSpacing: 2
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                // pencil - enter edit mode
                Text {
                    visible: !pane.editing
                    text: "\uf044"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                    color: editArea.containsMouse ? "#ffffff" : "#777"

                    MouseArea {
                        id: editArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            pane.draftText = pane.fileView.loaded ? pane.fileView.text() : ""
                            pane.editing = true
                        }
                    }
                }

                // check - save
                Text {
                    visible: pane.editing
                    text: "\uf00c"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                    color: saveArea.containsMouse ? "#9be89b" : "#5c8f5c"

                    MouseArea {
                        id: saveArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            pane.fileView.setText(pane.draftText)
                            pane.editing = false
                        }
                    }
                }

                // x - cancel
                Text {
                    visible: pane.editing
                    text: "\uf00d"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                    color: cancelArea.containsMouse ? "#e89b9b" : "#8f5c5c"

                    MouseArea {
                        id: cancelArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: pane.editing = false
                    }
                }
            }

            // ---- read-only view ----
            Flickable {
                id: readFlick
                visible: !pane.editing
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: readText.implicitHeight
                clip: true

                Text {
                    id: readText
                    width: readFlick.width
                    text: pane.fileView && pane.fileView.loaded ? pane.fileView.text() : "loading..."
                    color: "#e0e0e0"
                    font.family: "monospace"
                    font.pixelSize: 14
                    wrapMode: Text.Wrap

                    MouseArea {
                        anchors.fill: parent
                        onDoubleClicked: {
                            pane.draftText = pane.fileView.loaded ? pane.fileView.text() : ""
                            pane.editing = true
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: "#ffffff"
                        opacity: parent.pressed ? 0.5 : (parent.hovered ? 0.35 : 0.2)
                    }
                }
            }

            // ---- edit view ----
            Flickable {
                id: editFlick
                visible: pane.editing
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: editField.implicitHeight
                clip: true

                TextArea {
                    id: editField
                    width: editFlick.width
                    text: pane.draftText
                    onTextChanged: pane.draftText = text
                    wrapMode: TextArea.Wrap
                    color: "#e0e0e0"
                    font.family: "monospace"
                    font.pixelSize: 14
                    selectByMouse: true
                    background: null
                    padding: 0

                    onCursorRectangleChanged: {
                        const r = cursorRectangle
                        if (r.y < editFlick.contentY) {
                            editFlick.contentY = r.y
                        } else if (r.y + r.height > editFlick.contentY + editFlick.height) {
                            editFlick.contentY = r.y + r.height - editFlick.height
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: "#ffffff"
                        opacity: parent.pressed ? 0.5 : (parent.hovered ? 0.35 : 0.2)
                    }
                }
            }
        }
    }

    PanelWindow {
        id: popup
        visible: root.notesVisible
        color: "transparent"
        focusable: true

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusiveZone: 0

        Rectangle {
            id: panel
            anchors.centerIn: parent
            width: parent.width * 0.7
            height: parent.height * 0.8
            color: "#0d0d0d"
            radius: 12
            border.color: "#2a2a2a"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20

                NotePane {
                    id: todoPane
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: "TO-DO"
                    fileView: todoFile
                }

                NotePane {
                    id: shortcutsPane
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: "SHORTCUTS"
                    fileView: shortcutsFile
                }
            }
        }
    }
}
