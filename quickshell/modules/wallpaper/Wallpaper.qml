pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland


Item {
    id: root

    // change this to your actual wallpaper folder
    property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"

    property var images: []
    property int currentIndex: 0
    property int direction: 1   // 1 = forward/next, -1 = backward/prev
    readonly property string currentPath: images.length > 0 ? images[currentIndex] : ""

    function next() {
        if (images.length === 0) return
            direction = 1
            currentIndex = (currentIndex + 1) % images.length
            autoTimer.restart()
    }

    function prev() {
        if (images.length === 0) return
            direction = -1
            currentIndex = (currentIndex - 1 + images.length) % images.length
            autoTimer.restart()
    }

    Process {
        id: listProc
        command: ["bash", "-c",
        "find \"" + root.wallpaperDir + "\" -maxdepth 1 -type f " +
        "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.images = text.trim().split("\n").filter(p => p.length > 0)
                if (root.images.length > 0)
                    root.currentIndex = Math.floor(Math.random() * root.images.length)
            }
        }
    }

    Timer {
        id: autoTimer
        interval: 5 * 60 * 1000   // 5 minutes
        running: true
        repeat: true
        onTriggered: root.next()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: wp
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "quickshell-wallpaper"
            exclusionMode: ExclusionMode.Ignore
            focusable: false
            color: "black"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Item {
                id: switcher
                anchors.fill: parent
                clip: true

                property bool aIsFront: true

                Image {
                    id: imgA
                    y: 0
                    width: switcher.width
                    height: switcher.height
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    z: switcher.aIsFront ? 1 : 0

                    Behavior on x {
                        id: imgAXBehavior
                        NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
                    }
                }

                Image {
                    id: imgB
                    y: 0
                    width: switcher.width
                    height: switcher.height
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    z: switcher.aIsFront ? 0 : 1

                    Behavior on x {
                        id: imgBXBehavior
                        NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
                    }
                }

                Component.onCompleted: {
                    imgA.source = root.currentPath ? "file://" + root.currentPath : ""
                    imgA.x = 0
                }

                Connections {
                    target: root
                    function onCurrentPathChanged() {
                        const front = switcher.aIsFront ? imgA : imgB
                        const back = switcher.aIsFront ? imgB : imgA
                        const backBehavior = switcher.aIsFront ? imgBXBehavior : imgAXBehavior

                        const offscreenX = root.direction > 0 ? switcher.width : -switcher.width

                        // place the incoming image off-screen instantly, no animation
                        backBehavior.enabled = false
                        back.source = root.currentPath ? "file://" + root.currentPath : ""
                        back.x = offscreenX
                        backBehavior.enabled = true

                        switcher.aIsFront = !switcher.aIsFront

                            // animate both: incoming slides to center, outgoing slides fully off the other side
                            back.x = 0
                            front.x = -offscreenX
                    }
                }
            }
        }
    }
}
