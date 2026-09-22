pragma Singleton
import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: root

    // Change this to your actual wallpaper folder
    property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"

    property var images: []
    property int currentIndex: 0
    property int direction: 1   // 1 = forward/next (expand), -1 = backward/prev (shrink)
    readonly property string currentPath: images.length > 0 ? images[currentIndex] : ""

    // Debounce guard to prevent rapid clicking
    property bool canChange: true

    function next() {
        if (images.length === 0 || !canChange) return;
        canChange = false;
        direction = 1;
        currentIndex = (currentIndex + 1) % images.length;
        cooldownTimer.restart();
        autoTimer.restart();
    }

    function prev() {
        if (images.length === 0 || !canChange) return;
        canChange = false;
        direction = -1;
        currentIndex = (currentIndex - 1 + images.length) % images.length;
        cooldownTimer.restart();
        autoTimer.restart();
    }

    // 2-second cooldown timer before wallpaper can be changed again
    Timer {
        id: cooldownTimer
        interval: 1500
        repeat: false
        onTriggered: root.canChange = true
    }

    Process {
        id: listProc
        command: ["bash", "-c",
        "find \"" + root.wallpaperDir + "\" -maxdepth 1 -type f " +
        "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.images = text.trim().split("\n").filter(p => p.length > 0);
                if (root.images.length > 0)
                    root.currentIndex = Math.floor(Math.random() * root.images.length);
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

                property url displayedSource: ""
                property url incomingSource: ""
                property bool isTransitioning: false

                readonly property real centerX: switcher.width / 2
                readonly property real centerY: switcher.height / 2
                property real revealRadius: 0
                readonly property real maximumRevealRadius: Math.sqrt(centerX * centerX + centerY * centerY) + 16

                function startReveal() {
                    if (root.direction >= 0) {
                        // Forward: Expand from center out (0 -> max)
                        revealRadius = 0;
                        circleAnim.from = 0;
                        circleAnim.to = maximumRevealRadius;
                    } else {
                        // Backward: Shrink from outside in (max -> 0)
                        revealRadius = maximumRevealRadius;
                        circleAnim.from = maximumRevealRadius;
                        circleAnim.to = 0;
                    }

                    isTransitioning = true;
                    circleAnim.restart();
                }

                function finishTransition() {
                    displayedSource = incomingSource;
                    incomingSource = "";
                    isTransitioning = false;
                    revealRadius = 0;
                }

                // 1. Base Layer
                Image {
                    id: baseImage
                    anchors.fill: parent
                    source: (root.direction < 0 && switcher.isTransitioning)
                    ? switcher.incomingSource
                    : switcher.displayedSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    mipmap: true
                }

                // 2. Transitioning Image Layer (rendered offscreen for masking)
                Image {
                    id: transitionImage
                    anchors.fill: parent
                    source: (root.direction < 0)
                    ? switcher.displayedSource
                    : switcher.incomingSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    mipmap: true
                    visible: false

                    onStatusChanged: {
                        if (status === Image.Ready && switcher.incomingSource !== "" && !switcher.isTransitioning) {
                            switcher.startReveal();
                        }
                    }
                }

                // 3. Mask: A circle fixed exactly in the center
                Item {
                    id: maskContainer
                    anchors.fill: parent
                    visible: false

                    Rectangle {
                        x: switcher.centerX - switcher.revealRadius
                        y: switcher.centerY - switcher.revealRadius
                        width: Math.max(0, switcher.revealRadius * 2)
                        height: Math.max(0, switcher.revealRadius * 2)
                        radius: switcher.revealRadius
                        color: "white"
                        antialiasing: true
                    }
                }

                // 4. Alpha Mask compositor
                OpacityMask {
                    anchors.fill: parent
                    source: transitionImage
                    maskSource: maskContainer
                    visible: switcher.isTransitioning
                }

                // Longer animation with an InOut curve for a smoother feel
                NumberAnimation {
                    id: circleAnim
                    target: switcher
                    property: "revealRadius"
                    duration: 1400
                    easing.type: Easing.InOutCubic
                    onFinished: switcher.finishTransition()
                }

                Component.onCompleted: {
                    if (root.currentPath)
                        displayedSource = "file://" + root.currentPath;
                }

                Connections {
                    target: root
                    function onCurrentPathChanged() {
                        const nextUrl = root.currentPath ? "file://" + root.currentPath : "";
                        if (!nextUrl || nextUrl === switcher.displayedSource.toString())
                            return;

                        if (switcher.displayedSource === "") {
                            switcher.displayedSource = nextUrl;
                            return;
                        }

                        switcher.incomingSource = nextUrl;

                        if (transitionImage.status === Image.Ready && !switcher.isTransitioning) {
                            switcher.startReveal();
                        }
                    }
                }
            }
        }
    }
}
