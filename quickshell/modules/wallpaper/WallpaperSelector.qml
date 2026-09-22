import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "."

PanelWindow {
    id: selectorWindow

    screen: Quickshell.focusedScreen

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-wallpaper-selector"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    visible: false

    function toggle(): void {
        if (!selectorWindow.visible) show();
        else hide();
    }

    function show(): void {
        Wallpaper.refreshCategories();
        selectorWindow.visible = true;
    }

    function hide(): void {
        selectorWindow.visible = false;
    }

    IpcHandler {
        target: "wallpaperSelector"
        function toggle(): void { selectorWindow.toggle(); }
        function show(): void { selectorWindow.show(); }
        function hide(): void { selectorWindow.hide(); }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: selectorWindow.hide()
    }

    Item {
        id: contentContainer
        anchors.centerIn: parent
        width: 960
        height: 520
        focus: selectorWindow.visible

        Keys.onEscapePressed: selectorWindow.hide()
        Keys.onLeftPressed: pathView.decrementCurrentIndex()
        Keys.onRightPressed: pathView.incrementCurrentIndex()
        Keys.onReturnPressed: {
            if (pathView.currentItem) {
                Wallpaper.setCategory(pathView.model[pathView.currentIndex]);
                selectorWindow.hide();
            }
        }

        // Header indicator pill
        Rectangle {
            id: headerPill
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            width: 270
            height: 36
            radius: 18
            color: "#d9121212"
            border.color: "#33ffffff"
            border.width: 1
            z: 99

            RowLayout {
                anchors.centerIn: parent
                spacing: 10

                // Dot tracks the active center card's dominant color
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: (pathView.currentItem && pathView.currentItem.dominantColor)
                    ? pathView.currentItem.dominantColor
                    : "#5ec2c2"

                    Behavior on color { ColorAnimation { duration: 180 } }
                }

                Text {
                    text: pathView.model && pathView.model.length > 0
                    ? pathView.model[pathView.currentIndex]
                    : "No Collections"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#ffffff"
                }

                Text {
                    text: (pathView.currentItem && pathView.currentItem.totalCount !== undefined)
                    ? pathView.currentItem.totalCount + " images"
                    : ""
                    font.pixelSize: 11
                    color: "#80ffffff"
                }
            }
        }

        PathView {
            id: pathView
            anchors.fill: parent
            anchors.topMargin: 40
            model: Wallpaper.categories
            pathItemCount: 5
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightRangeMode: PathView.StrictlyEnforceRange

            path: Path {
                startX: pathView.width * 0.16
                startY: pathView.height / 2

                PathAttribute { name: "itemScale"; value: 0.82 }
                PathAttribute { name: "itemOpacity"; value: 0.45 }
                PathAttribute { name: "itemZ"; value: 2 }

                PathLine {
                    x: pathView.width * 0.5
                    y: pathView.height / 2
                }

                PathAttribute { name: "itemScale"; value: 1.0 }
                PathAttribute { name: "itemOpacity"; value: 1.0 }
                PathAttribute { name: "itemZ"; value: 20 }

                PathLine {
                    x: pathView.width * 0.84
                    y: pathView.height / 2
                }

                PathAttribute { name: "itemScale"; value: 0.82 }
                PathAttribute { name: "itemOpacity"; value: 0.45 }
                PathAttribute { name: "itemZ"; value: 1 }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: (wheel) => {
                    if (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0) {
                        pathView.incrementCurrentIndex();
                    } else {
                        pathView.decrementCurrentIndex();
                    }
                }
            }

            delegate: Item {
                id: delegateItem
                width: 300
                height: 400

                z: PathView.itemZ ?? 1
                scale: PathView.itemScale ?? 1.0
                opacity: PathView.itemOpacity ?? 1.0

                readonly property string categoryName: modelData
                readonly property bool isSelected: Wallpaper.activeCategory === categoryName
                readonly property bool isCenter: PathView.isCurrentItem

                property var previewImages: []
                property int totalCount: 0
                property color dominantColor: "#5ec2c2"

                // 1. Fetch images for this folder
                Process {
                    id: previewProc
                    command: [
                        "find",
                        (categoryName === "All" ? Wallpaper.wallpaperDir : Wallpaper.wallpaperDir + "/" + categoryName),
                        "-maxdepth", (categoryName === "All" ? "2" : "1"),
                        "-type", "f",
                        "(", "-iname", "*.jpg", "-o", "-iname", "*.png", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.webp", ")",
                        "!", "-empty"
                    ]
                    running: selectorWindow.visible && delegateItem.previewImages.length === 0
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let files = text.trim().split("\n").filter(p => p.length > 0);
                            delegateItem.totalCount = files.length;
                            delegateItem.previewImages = files.slice(0, 3);

                            if (files.length > 0) {
                                colorProc.command = [
                                    "magick", files[0],
                                    "-resize", "1x1!",
                                    "-format", "#%[hex:u.p{0,0}]\n",
                                    "info:"
                                ];
                                colorProc.running = true;
                            }
                        }
                    }
                }

                // 2. Extract dominant color
                Process {
                    id: colorProc
                    running: false
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let col = text.trim();
                            if (col.length >= 7) {
                                delegateItem.dominantColor = col.substring(0, 7);
                            }
                        }
                    }
                }

                transform: Matrix4x4 {
                    matrix: Qt.matrix4x4(
                        1.0, -0.17, 0.0, 0.0,
                        0.0,  1.00, 0.0, 0.0,
                        0.0,  0.00, 1.0, 0.0,
                        0.0,  0.00, 0.0, 1.0
                    )
                }

                // Unclipped Card Contents
                Item {
                    id: cardContent
                    anchors.fill: parent
                    visible: false

                    Rectangle {
                        anchors.fill: parent
                        color: "#181818"
                    }

                    Row {
                        anchors.fill: parent

                        Repeater {
                            model: 3
                            Item {
                                width: cardContent.width / 3
                                height: cardContent.height

                                Image {
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    smooth: true
                                    sourceSize.width: 120
                                    sourceSize.height: 400

                                    source: (delegateItem.previewImages && delegateItem.previewImages.length > index)
                                    ? "file://" + delegateItem.previewImages[index]
                                    : (delegateItem.previewImages && delegateItem.previewImages.length > 0
                                    ? "file://" + delegateItem.previewImages[0]
                                    : "")
                                }

                                Rectangle {
                                    width: 1
                                    height: parent.height
                                    anchors.right: parent.right
                                    color: "#33000000"
                                    visible: index < 2
                                }
                            }
                        }
                    }

                    // Inactive card dimming
                    Rectangle {
                        anchors.fill: parent
                        color: delegateItem.isCenter ? "transparent" : "#59000000"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    // Bottom info label gradient & text
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 64
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.5; color: "#bb000000" }
                            GradientStop { position: 1.0; color: "#f2000000" }
                        }

                        ColumnLayout {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 2

                            Text {
                                text: delegateItem.categoryName
                                font.pixelSize: 15
                                font.bold: true
                                color: "#ffffff"
                                elide: Text.ElideRight
                                Layout.maximumWidth: delegateItem.width - 24
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: delegateItem.isSelected ? "Active Collection" : "Click to apply"
                                font.pixelSize: 10
                                color: delegateItem.isCenter
                                ? delegateItem.dominantColor
                                : (delegateItem.isSelected ? "#5ec2c2" : "#99ffffff")
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }

                // Smooth Anti-Aliased Mask
                Rectangle {
                    id: cardMask
                    anchors.fill: parent
                    radius: 14
                    color: "black"
                    visible: false
                    antialiasing: true
                    smooth: true
                }

                OpacityMask {
                    id: maskedCard
                    anchors.fill: parent
                    source: cardContent
                    maskSource: cardMask
                }

                // Dynamic Outer Border (Changes for whichever card is centered as you scroll)
                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: "transparent"
                    border.color: {
                        if (delegateItem.isCenter) return delegateItem.dominantColor;
                        if (delegateItem.isSelected) return "#5ec2c2";
                        return "#22ffffff";
                    }
                    border.width: delegateItem.isCenter ? 2.5 : (delegateItem.isSelected ? 1.5 : 1.0)
                    antialiasing: true
                    smooth: true

                    Behavior on border.color {
                        ColorAnimation { duration: 180 }
                    }
                    Behavior on border.width {
                        NumberAnimation { duration: 180 }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!delegateItem.isCenter) {
                            pathView.currentIndex = index;
                        } else {
                            Wallpaper.setCategory(delegateItem.categoryName);
                            selectorWindow.hide();
                        }
                    }
                }
            }
        }
    }
}
