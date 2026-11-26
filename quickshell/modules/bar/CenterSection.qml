import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick.Controls
import "."

Row {
    spacing: 10

    Process {
        id: merkuroProc
        command: ["merkuro-calendar"]
    }

    // Time | date. The separator is a drawn line rather than a "|" glyph,
    // because the glyph's descender hangs below the digits and looks off-centre.
    Item {
        id: clock
        implicitWidth: clockRow.implicitWidth
        implicitHeight: clockRow.implicitHeight

        function update() {
            var now = new Date();
            timeText.text = Qt.formatDateTime(now, "hh:mm AP");
            dateText.text = Qt.formatDateTime(now, "dd-MM-yyyy");
        }

        Row {
            id: clockRow
            spacing: 10
            // Digits sit ~1px lower than the bar's icons; lift to match
            transform: Translate { y: -1 }

            Text {
                id: timeText
                color: Theme.iconColor
                font.bold: true
                font.pixelSize: 13
            }

            Rectangle {
                width: 1
                height: 11
                anchors.verticalCenter: timeText.verticalCenter
                anchors.verticalCenterOffset: 1
                color: Theme.iconColor
                opacity: 0.6
            }

            Text {
                id: dateText
                color: Theme.iconColor
                font.bold: true
                font.pixelSize: 13
            }
        }

        Component.onCompleted: update()

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: clock.update()
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            onEntered: calendarPopup.visible = true
            onExited: calendarPopup.visible = false

            onClicked: {
                calendarPopup.visible = false
                merkuroProc.running = true
            }
        }
    }

    PopupWindow {
        id: calendarPopup
        visible: false
        color: "transparent"

        anchor.item: clock
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom

        implicitWidth: 230
        implicitHeight: 210

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            radius: 8
            border.color: "#44475a"
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4

                Text {
                    text: Qt.formatDateTime(new Date(), "MMMM yyyy")
                    color: "#ffffff"
                    font.bold: true
                    font.pixelSize: 13
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                DayOfWeekRow {
                    width: parent.width
                    locale: grid.locale

                    delegate: Text {
                        text: model.shortName
                        color: "#bbbbbb"
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                MonthGrid {
                    id: grid
                    width: parent.width
                    height: parent.height - 50

                    month: new Date().getMonth()
                    year: new Date().getFullYear()
                    locale: Qt.locale("en_US")

                    delegate: Text {
                        text: model.day
                        color: model.month === grid.month
                        ? (model.day === new Date().getDate() ? "#2196f3" : "#ffffff")
                        : "#666666"
                        font.pixelSize: 12
                        font.bold: model.day === new Date().getDate() && model.month === grid.month
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }
}
