import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

Scope {
    id: root

    // ---- Theme / Palette ----------------------------------------------------
    property color bgColor: "#f01a1c27"
    property color cardColor: "#222538"
    property color itemHoverColor: "#2d324b"
    property color borderColor: "#353952"
    property color textColor: "#dcdfe7"
    property color subTextColor: "#7d85a0"
    property color accentColor: "#7aa2f7"

    property bool isVisible: false
    property int selectedIndex: 0

    function toggle() {
        root.isVisible = !root.isVisible;
        if (root.isVisible) {
            searchInput.text = "";
            engine.stop();
            engine.query = "";
            engine.resetFilters();
            root.selectedIndex = 0;
            searchInput.forceActiveFocus();
        } else {
            engine.stop();
        }
    }

    function hide() {
        root.isVisible = false;
        engine.stop();
    }

    function openFile(path) {
        if (!path) return;
        launcherProc.command = ["gio", "open", path];
        launcherProc.running = true;
        root.hide();
    }

    // Backend Search Engine instance
    SearchEngine {
        id: engine
    }

    Process {
        id: launcherProc
    }

    // ---- Window Layer -------------------------------------------------------
    PanelWindow {
        id: searchWindow
        visible: root.isVisible
        color: "transparent"
        focusable: true
        exclusionMode: ExclusionMode.Ignore

        anchors { top: true; bottom: true; left: true; right: true }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:search"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        // Click outside closes the spotlight search
        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
        }

        // Spotlight Card
        Rectangle {
            id: cardRect
            width: 620
            height: mainCol.implicitHeight + 28
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.20
            radius: 16
            color: root.bgColor
            border.color: root.borderColor
            border.width: 1
            clip: true

            MouseArea {
                anchors.fill: parent
            }

            Column {
                id: mainCol
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 14
                }
                spacing: 10

                // Top Input Row
                RowLayout {
                    id: searchInputRow
                    width: parent.width
                    spacing: 10

                    Text {
                        text: "\udb80\udf31"
                        font.pixelSize: 15
                        color: root.subTextColor
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        font.pixelSize: 14
                        color: root.textColor
                        selectByMouse: true
                        activeFocusOnTab: true

                        Text {
                            anchors.fill: parent
                            text: "Search files..."
                            color: root.subTextColor
                            font.pixelSize: 14
                            visible: !searchInput.text && !searchInput.activeFocus
                        }

                        onTextChanged: {
                            engine.query = text;
                            root.selectedIndex = 0;
                        }

                        Keys.onDownPressed: {
                            if (root.selectedIndex < engine.results.length - 1) {
                                root.selectedIndex++;
                                resultView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            }
                        }

                        Keys.onUpPressed: {
                            if (root.selectedIndex > 0) {
                                root.selectedIndex--;
                                resultView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            }
                        }

                        Keys.onReturnPressed: {
                            if (engine.results.length > 0 && engine.results[root.selectedIndex]) {
                                root.openFile(engine.results[root.selectedIndex].path);
                            }
                        }

                        Keys.onEscapePressed: root.hide()
                    }

                    Text {
                        text: engine.isSearching ? "Searching..." : (engine.results.length > 0 ? engine.results.length + " items" : "")
                        color: root.subTextColor
                        font.pixelSize: 11
                    }
                }

                // Category filter row
                RowLayout {
                    id: categoryRow
                    width: parent.width
                    spacing: 6

                    property var categories: [
                        { id: "all",      label: "All" },
                        { id: "folder",   label: "Folders" },
                        { id: "music",    label: "Music" },
                        { id: "video",    label: "Video" },
                        { id: "document", label: "Docs" }
                    ]

                    Repeater {
                        model: categoryRow.categories
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: 28
                            radius: 8
                            color: engine.selectedCategory === modelData.id ? root.accentColor : root.cardColor
                            border.color: root.borderColor
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: 11
                                color: engine.selectedCategory === modelData.id ? "#1a1c27" : root.subTextColor
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    engine.selectedCategory = modelData.id;
                                    engine.extFilter = "all";
                                    root.selectedIndex = 0;
                                }
                            }
                        }
                    }
                }

                // Folder sub-filter row (hidden / normal)
                // Folder sub-filter row (hidden / normal)
                Flow {
                    id: folderSubRow
                    width: parent.width
                    spacing: 6
                    visible: engine.selectedCategory === "folder"

                    property var subFilters: [
                        { id: "all",    label: "All" },
                        { id: "normal", label: "Normal" },
                        { id: "hidden", label: "Hidden" }
                    ]

                    Repeater {
                        model: folderSubRow.subFilters
                        delegate: Rectangle {
                            required property var modelData
                            radius: 6
                            color: engine.folderFilter === modelData.id ? root.itemHoverColor : "transparent"
                            border.color: root.borderColor
                            border.width: 1
                            implicitWidth: subText.implicitWidth + 14
                            implicitHeight: 22

                            Text {
                                id: subText
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: 10
                                color: root.subTextColor
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    engine.folderFilter = modelData.id;
                                    root.selectedIndex = 0;
                                }
                            }
                        }
                    }
                }

                // Extension sub-filter row — shared layout for music / video / document
                Flow {
                    id: extSubRow
                    width: parent.width
                    spacing: 6
                    visible: ["music", "video", "document"].includes(engine.selectedCategory)

                    property var extList: {
                        if (engine.selectedCategory === "music") return engine.musicExts;
                        if (engine.selectedCategory === "video") return engine.videoExts;
                        if (engine.selectedCategory === "document") return engine.docExts;
                        return [];
                    }
                    property var pills: ["all", ...extList]

                    Repeater {
                        model: extSubRow.pills
                        delegate: Rectangle {
                            required property var modelData
                            radius: 6
                            color: engine.extFilter === modelData ? root.itemHoverColor : "transparent"
                            border.color: root.borderColor
                            border.width: 1
                            implicitWidth: extText.implicitWidth + 14
                            implicitHeight: 22

                            Text {
                                id: extText
                                anchors.centerIn: parent
                                text: modelData === "all" ? "All" : modelData
                                font.pixelSize: 10
                                color: root.subTextColor
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    engine.extFilter = modelData;
                                    root.selectedIndex = 0;
                                }
                            }
                        }
                    }
                }

                // Divider line
                Rectangle {
                    width: parent.width
                    height: 1
                    color: root.borderColor
                    visible: engine.results.length > 0
                }

                // Results list
                ListView {
                    id: resultView
                    width: parent.width
                    height: Math.min(engine.results.length * 44, 350)
                    clip: true
                    spacing: 4
                    visible: engine.results.length > 0
                    model: engine.results

                    delegate: Rectangle {
                        id: itemCard
                        required property var modelData
                        required property int index

                        width: resultView.width
                        height: 40
                        radius: 8
                        color: (root.selectedIndex === index) ? root.itemHoverColor : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            Text {
                                text: {
                                    const parts = itemCard.modelData.path.split("/");
                                    return parts[parts.length - 1] || itemCard.modelData.path;
                                }
                                color: (root.selectedIndex === index) ? root.textColor : "#b8bed3"
                                font.pixelSize: 13
                                font.weight: (root.selectedIndex === index) ? Font.DemiBold : Font.Normal
                                Layout.maximumWidth: parent.width * 0.45
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: itemCard.modelData.path
                                color: root.subTextColor
                                opacity: 0.65
                                font.pixelSize: 11
                                elide: Text.ElideMiddle
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selectedIndex = itemCard.index
                            onClicked: root.openFile(itemCard.modelData.path)
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "fileSearch"
        function toggle(): void { root.toggle(); }
        function show(): void { root.toggle(); }
        function hide(): void { root.hide(); }
    }
}
