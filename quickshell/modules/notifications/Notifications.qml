import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications

// Notification daemon for Quickshell — a swaync replacement.
// Place this file at: modules/notifications/Notifications.qml

Scope {
    id: root

    // ---- Theme / Palette ----------------------------------------------------
    property color bgColor: "#e61a1c27"          // Deep slate navy translucent
    property color cardColor: "#222538"         // Elevated card base
    property color popupCardColor: "#f01c1e2d"   // Toast card background
    property color borderColor: "#353952"       // Subtle highlight border
    property color buttonHoverColor: "#333852"  // Interactive button background
    property color textColor: "#dcdfe7"         // Soft off-white
    property color subTextColor: "#7d85a0"      // Muted slate gray
    property color criticalColor: "#f7768e"     // Red warning/error accent

    property int popupWidth: 380
    property int defaultTimeoutMs: 3500
    property int lowUrgencyTimeoutMs: 1500
    property int fadeDurationMs: 250

    // ---- State ------------------------------------------------------------
    property bool centerVisible: false
    property bool dnd: false                    // Suppress toasts when active
    property var poppedIds: ({})                // notification.id -> true while toast is active

    function toggleCenter() { centerVisible = !centerVisible; }
    function showCenter() { centerVisible = true; }
    function hideCenter() { centerVisible = false; }
    function toggleDnd() { dnd = !dnd; }

    function timeoutFor(n) {
        if (n.urgency === NotificationUrgency.Critical) return -1;
        if (n.expireTimeout > 0) return n.expireTimeout * 1000;
        if (n.urgency === NotificationUrgency.Low) return root.lowUrgencyTimeoutMs;
        return root.defaultTimeoutMs;
    }

    function removePoppedId(id) {
        const p = Object.assign({}, root.poppedIds);
        delete p[id];
        root.poppedIds = p;
    }

    function clearAll() {
        for (const n of [...notifServer.trackedNotifications.values]) n.dismiss();
    }

    // ---- Server -------------------------------------------------------------
    NotificationServer {
        id: notifServer
        keepOnReload: true
        bodySupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: true
        persistenceSupported: true

        onNotification: (notification) => {
            notification.tracked = true;

            if (!root.dnd) {
                const p = Object.assign({}, root.poppedIds);
                p[notification.id] = true;
                root.poppedIds = p;
            }
        }
    }

    // ---- Shared Card Body ---------------------------------------------------
    component NotificationContent: ColumnLayout {
        id: content
        property var modelData
        signal closeClicked()

        anchors.fill: parent
        anchors.margins: 14
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            IconImage {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                source: {
                    if (content.modelData.image !== "") return content.modelData.image;
                    if (content.modelData.appIcon !== "") return Quickshell.iconPath(content.modelData.appIcon, true);
                    return "";
                }
            }

            Text {
                Layout.fillWidth: true
                text: content.modelData.appName || "Notification"
                color: root.subTextColor
                font.pixelSize: 11
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Rectangle {
                width: 22
                height: 22
                radius: 11
                color: closeHover.containsMouse ? root.borderColor : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "\u2715"
                    color: closeHover.containsMouse ? root.textColor : root.subTextColor
                    font.pixelSize: 11
                }

                MouseArea {
                    id: closeHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: content.closeClicked()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: content.modelData.summary
            color: root.textColor
            font.pixelSize: 13
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
            visible: text.length > 0
        }

        Text {
            Layout.fillWidth: true
            text: content.modelData.body
            color: root.subTextColor
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            visible: text.length > 0
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: content.modelData.actions.length > 0

            Repeater {
                model: content.modelData.actions

                delegate: Rectangle {
                    id: actBtn
                    required property var modelData
                    radius: 8
                    color: actArea.containsMouse ? root.buttonHoverColor : root.bgColor
                    border.color: root.borderColor
                    border.width: 1
                    implicitWidth: actionText.implicitWidth + 16
                    implicitHeight: actionText.implicitHeight + 10

                    Text {
                        id: actionText
                        anchors.centerIn: parent
                        text: actBtn.modelData.text
                        color: root.textColor
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: actArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: actBtn.modelData.invoke()
                    }
                }
            }
        }
    }

    // ---- Toast popups, top-right --------------------------------------------
    PanelWindow {
        id: popupWindow
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; right: true }
        margins { top: 46; right: 16 }
        implicitWidth: root.popupWidth
        implicitHeight: popupColumn.implicitHeight

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:notifications:popup"

        Column {
            id: popupColumn
            width: root.popupWidth
            spacing: 10

            Repeater {
                model: ScriptModel {
                    values: [...notifServer.trackedNotifications.values].filter(n => root.poppedIds[n.id])
                }

                delegate: Rectangle {
                    id: toastCard
                    required property var modelData

                    width: root.popupWidth
                    implicitHeight: cardContent.implicitHeight + 24
                    radius: 14
                    color: root.popupCardColor
                    border.color: root.borderColor
                    border.width: 1
                    clip: true
                    opacity: 1.0

                    NotificationContent {
                        id: cardContent
                        modelData: toastCard.modelData
                        onCloseClicked: fadeAnim.start()
                    }

                    Timer {
                        id: dismissTimer
                        interval: root.timeoutFor(toastCard.modelData)
                        running: interval > 0
                        repeat: false
                        onTriggered: fadeAnim.start()
                    }

                    NumberAnimation {
                        id: fadeAnim
                        target: toastCard
                        property: "opacity"
                        to: 0.0
                        duration: root.fadeDurationMs
                        easing.type: Easing.OutCubic
                        onFinished: root.removePoppedId(toastCard.modelData.id)
                    }
                }
            }
        }
    }

    // ---- History drawer, right-side panel ----------------------------------
    PanelWindow {
        id: centerWindow
        visible: root.centerVisible
        color: "transparent"
        focusable: false
        exclusionMode: ExclusionMode.Ignore

        anchors { top: true; bottom: true; left: true; right: true }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:notifications:center"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Fullscreen backdrop area to dismiss on outside click
        MouseArea {
            anchors.fill: parent
            onClicked: root.hideCenter()
        }

        // Drawer Container
        Rectangle {
            width: root.popupWidth + 24
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
                margins: 14
                topMargin: 46
            }
            radius: 16
            color: root.bgColor
            border.color: root.borderColor
            border.width: 1
            clip: true

            // Blocks clicks inside the drawer from closing it
            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Notifications"
                        color: root.textColor
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        height: 24
                        implicitWidth: dndLabel.implicitWidth + 16
                        radius: 12
                        color: dndArea.containsMouse ? root.buttonHoverColor : root.cardColor
                        border.color: root.borderColor
                        border.width: 1

                        Text {
                            id: dndLabel
                            anchors.centerIn: parent
                            text: root.dnd ? "DND On" : "DND Off"
                            color: root.dnd ? root.criticalColor : root.subTextColor
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: dndArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleDnd()
                        }
                    }

                    Rectangle {
                        height: 24
                        implicitWidth: clearLabel.implicitWidth + 16
                        radius: 12
                        visible: notifServer.trackedNotifications.values.length > 0
                        color: clearArea.containsMouse ? root.buttonHoverColor : root.cardColor
                        border.color: root.borderColor
                        border.width: 1

                        Text {
                            id: clearLabel
                            anchors.centerIn: parent
                            text: "Clear all"
                            color: root.subTextColor
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.clearAll()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: root.borderColor
                }

                ListView {
                    id: historyList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 10
                    model: ScriptModel {
                        values: [...notifServer.trackedNotifications.values].reverse()
                    }

                    delegate: Rectangle {
                        id: historyCard
                        required property var modelData

                        width: root.popupWidth
                        implicitHeight: historyContent.implicitHeight + 24
                        radius: 12
                        color: root.cardColor
                        border.color: root.borderColor
                        border.width: 1
                        clip: true

                        NotificationContent {
                            id: historyContent
                            modelData: historyCard.modelData
                            onCloseClicked: historyCard.modelData.dismiss()
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: historyList.count === 0
                        text: "No notifications"
                        color: root.subTextColor
                        font.pixelSize: 13
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void { root.toggleCenter(); }
        function show(): void { root.showCenter(); }
        function hide(): void { root.hideCenter(); }
        function clearAll(): void { root.clearAll(); }
        function toggleDnd(): void { root.toggleDnd(); }
    }
}
