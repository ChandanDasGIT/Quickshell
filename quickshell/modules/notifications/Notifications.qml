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

    // ---- Theme / tunables ----------------------------------------------
    property color bgColor: "#1e1e2e"
    property color cardColor: "#313244"
    property color borderColor: "#45475a"
    property color textColor: "#cdd6f4"
    property color subTextColor: "#a6adc8"
    property color accentColor: "#89b4fa"
    property color criticalColor: "#f38ba8"

    property int popupWidth: 360
    property int defaultTimeoutMs: 3000
    property int lowUrgencyTimeoutMs: 1500
    property int fadeDurationMs: 300

    // ---- State ------------------------------------------------------------
    property bool centerVisible: false
    property bool dnd: false          // when true, suppress toast popups (still logged to history)
    property var poppedIds: ({})      // notification.id -> true while toast is active

    function toggleCenter() { centerVisible = !centerVisible; }
    function showCenter() { centerVisible = true; }
    function hideCenter() { centerVisible = false; }
    function toggleDnd() { dnd = !dnd; }

    function timeoutFor(n) {
        if (n.urgency === NotificationUrgency.Critical) return -1; // stays until dismissed
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
        anchors.leftMargin: 16
        anchors.margins: 10
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            IconImage {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
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
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Text {
                text: "\u2715"
                color: root.subTextColor
                font.pixelSize: 12

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: content.closeClicked()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: content.modelData.summary
            color: root.textColor
            font.pixelSize: 14
            font.bold: true
            wrapMode: Text.WordWrap
            visible: text.length > 0
        }

        Text {
            Layout.fillWidth: true
            text: content.modelData.body
            color: root.subTextColor
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            maximumLineCount: 4
            elide: Text.ElideRight
            visible: text.length > 0
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: content.modelData.actions.length > 0

            Repeater {
                model: content.modelData.actions

                delegate: Rectangle {
                    required property var modelData
                    radius: 8
                    color: root.borderColor
                    implicitWidth: actionText.implicitWidth + 16
                    implicitHeight: actionText.implicitHeight + 8

                    Text {
                        id: actionText
                        anchors.centerIn: parent
                        text: modelData.text
                        color: root.textColor
                        font.pixelSize: 11
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modelData.invoke()
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
        margins { top: 44; right: 12 }
        implicitWidth: root.popupWidth
        implicitHeight: popupColumn.implicitHeight

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:notifications:popup"

        Column {
            id: popupColumn
            width: root.popupWidth
            spacing: 8

            Repeater {
                model: ScriptModel {
                    values: [...notifServer.trackedNotifications.values].filter(n => root.poppedIds[n.id])
                }

                delegate: Rectangle {
                    id: toastCard
                    required property var modelData

                    width: root.popupWidth
                    implicitHeight: cardContent.implicitHeight + 20
                    radius: 12
                    color: root.cardColor
                    clip: true
                    opacity: 1.0

                    // Urgency accent stripe
                    Rectangle {
                        width: 4
                        height: parent.height
                        color: toastCard.modelData.urgency === NotificationUrgency.Critical
                        ? root.criticalColor
                        : root.accentColor
                    }

                    NotificationContent {
                        id: cardContent
                        modelData: toastCard.modelData
                        onCloseClicked: fadeAnim.start()
                    }

                    // Auto-timeout timer
                    Timer {
                        id: dismissTimer
                        interval: root.timeoutFor(toastCard.modelData)
                        running: interval > 0
                        repeat: false
                        onTriggered: fadeAnim.start()
                    }

                    // Smooth fade-out animation
                    NumberAnimation {
                        id: fadeAnim
                        target: toastCard
                        property: "opacity"
                        to: 0.0
                        duration: root.fadeDurationMs
                        easing.type: Easing.OutQuad
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

        anchors { top: true; bottom: true; right: true }
        margins { top: 44; bottom: 12; right: 12 }
        implicitWidth: root.popupWidth + 24

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:notifications:center"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            anchors.margins: 12
            radius: 16
            color: root.bgColor
            border.color: root.borderColor
            border.width: 1
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Notifications"
                        color: root.textColor
                        font.pixelSize: 16
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.dnd ? "DND: On" : "DND: Off"
                        color: root.dnd ? root.criticalColor : root.subTextColor
                        font.pixelSize: 12

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleDnd()
                        }
                    }

                    Text {
                        text: "Clear all"
                        color: root.subTextColor
                        font.pixelSize: 12
                        leftPadding: 12
                        visible: notifServer.trackedNotifications.values.length > 0

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.clearAll()
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: root.borderColor }

                ListView {
                    id: historyList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    model: ScriptModel {
                        values: [...notifServer.trackedNotifications.values].reverse()
                    }

                    delegate: Rectangle {
                        id: historyCard
                        required property var modelData

                        width: root.popupWidth
                        implicitHeight: historyContent.implicitHeight + 20
                        radius: 12
                        color: root.cardColor
                        clip: true

                        Rectangle {
                            width: 4
                            height: parent.height
                            color: historyCard.modelData.urgency === NotificationUrgency.Critical
                            ? root.criticalColor
                            : root.accentColor
                        }

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
                        font.pixelSize: 14
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
