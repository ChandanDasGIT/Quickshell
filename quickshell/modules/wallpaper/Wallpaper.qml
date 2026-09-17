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
    readonly property string currentPath: images.length > 0 ? images[currentIndex] : ""

    function next() {
        if (images.length === 0) return
        currentIndex = (currentIndex + 1) % images.length
        autoTimer.restart()
    }

    function prev() {
        if (images.length === 0) return
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

            Image {
                anchors.fill: parent
                source: root.currentPath ? "file://" + root.currentPath : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }
        }
    }
}
