import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
 
Item {
    id: root

    // Leave empty to aggregate all interfaces (excluding lo), or set to "wlan0", "eth0", etc.
    property string targetInterface: ""
    property real rxSpeed: 0
    property real txSpeed: 0

    implicitWidth: contentRow.implicitWidth
    implicitHeight: contentRow.implicitHeight

    QtObject {
        id: tracker
        property var lastRx: 0
        property var lastTx: 0
        property bool initialized: false
    }

    // Always at most 2 digits: "9.5", "42", "0.3" — steps up a unit once
    // the value would reach 100 (e.g. 150 K/s -> 0.1 M/s).
    function formatSpeed(bytesPerSec) {
        const units = ["B", "K", "M", "G"];
        let v = bytesPerSec;
        let u = 0;
        while (v >= 99.5 && u < units.length - 1) {
            v /= 1024;
            u++;
        }
        const num = (u === 0 || v >= 9.95) ? v.toFixed(0) : v.toFixed(1);
        return num + " " + units[u] + "/s";
    }

    // Runs every second to query network statistics
    Process {
        id: netProc
        command: ["cat", "/proc/net/dev"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n");
                let totalRx = 0;
                let totalTx = 0;

                for (let i = 2; i < lines.length; i++) {
                    let line = lines[i].trim();
                    let parts = line.split(":");
                    if (parts.length < 2) continue;

                    let iface = parts[0].trim();
                    if (iface === "lo") continue;
                    if (root.targetInterface !== "" && iface !== root.targetInterface) continue;

                    let fields = parts[1].trim().split(/\s+/);
                    let rxBytes = parseInt(fields[0], 10) || 0;
                    let txBytes = parseInt(fields[8], 10) || 0;

                    totalRx += rxBytes;
                    totalTx += txBytes;
                }

                if (!tracker.initialized) {
                    tracker.lastRx = totalRx;
                    tracker.lastTx = totalTx;
                    tracker.initialized = true;
                    return;
                }

                let deltaRx = totalRx - tracker.lastRx;
                let deltaTx = totalTx - tracker.lastTx;

                tracker.lastRx = totalRx;
                tracker.lastTx = totalTx;

                root.rxSpeed = deltaRx >= 0 ? deltaRx : 0;
                root.txSpeed = deltaTx >= 0 ? deltaTx : 0;
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!netProc.running) {
                netProc.running = true;
            }
        }
    }

    RowLayout {
        id: contentRow
        spacing: 8

        RowLayout {
            spacing: 2
            Text {
                text: "↓"
                color: "#a6e3a1"
                font.pixelSize: 11
                font.bold: true
            }
            Text {
                text: root.formatSpeed(root.rxSpeed)
                color: Theme.iconColor
                font.pixelSize: 16
                font.family: "JetBrains Mono, monospace"
            }
        }

        RowLayout {
            spacing: 2
            Text {
                text: "↑"
                color: "#89b4fa"
                font.pixelSize: 11
                font.bold: true
            }
            Text {
                text: root.formatSpeed(root.txSpeed)
                color: Theme.iconColor
                font.pixelSize: 16
                font.family: "JetBrains Mono, monospace"
            }
        }
    }
}
