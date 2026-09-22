pragma Singleton
import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: root

    property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"

    // Category / "Theme" states
    property var categories: ["All"]
    property string activeCategory: "All"

    property var images: []
    property int currentIndex: 0
    property int direction: 1   // 1 = forward/next (expand), -1 = backward/prev (shrink)
    readonly property string currentPath: images.length > 0 ? images[currentIndex] : ""

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

    // Scans top-level folders dynamically on demand
    function refreshCategories() {
        listCategoriesProc.running = true;
    }

    // Switches theme/category and immediately triggers a wallpaper load
    function setCategory(cat) {
        if (activeCategory === cat && images.length > 0) return;
        activeCategory = cat;
        loadImagesForCategory(cat);
    }

    function loadImagesForCategory(cat) {
        let targetDir = root.wallpaperDir;
        if (cat !== "All") {
            targetDir = root.wallpaperDir + "/" + cat;
        }

        // Standard find command constructed entirely via argument array (no shell wrapper needed)
        listImagesProc.command = [
            "find", targetDir,
            "-type", "f",
            "(",
            "-iname", "*.jpg", "-o",
            "-iname", "*.jpeg", "-o",
            "-iname", "*.png", "-o",
            "-iname", "*.webp",
            ")",
            "!", "-empty"
        ];
        listImagesProc.running = true;
    }

    // Timer cooldown
    Timer {
        id: cooldownTimer
        interval: 1500
        repeat: false
        onTriggered: root.canChange = true
    }

    // 1. Process to list subdirectories inside ~/Pictures/Wallpapers
    Process {
        id: listCategoriesProc
        command: ["find", root.wallpaperDir, "-mindepth", "1", "-maxdepth", "1", "-type", "d", "-printf", "%f\n"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n").filter(p => p.length > 0).sort();
                root.categories = ["All", ...lines];
            }
        }
    }

    // 2. Process to populate images based on current category
    Process {
        id: listImagesProc
        stdout: StdioCollector {
            onStreamFinished: {
                let found = text.trim().split("\n").filter(p => p.length > 0).sort();
                root.images = found;
                if (found.length > 0) {
                    root.currentIndex = Math.floor(Math.random() * found.length);
                }
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

    Component.onCompleted: {
        loadImagesForCategory("All");
    }

    // Screen Renderers
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
                        revealRadius = 0;
                        circleAnim.from = 0;
                        circleAnim.to = maximumRevealRadius;
                    } else {
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

                // 2. Transitioning Image Layer
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

                // 3. Mask: Fixed center circle
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
