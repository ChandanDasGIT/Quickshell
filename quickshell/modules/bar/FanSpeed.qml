import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: root
    spacing: 8

    property bool isActive: false
    property var fanModel: []

    Timer {
        interval: 2000
        running: root.isActive
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!fanProc.running) fanProc.running = true
        }
    }

    Process {
        id: fanProc
        // 1. Checks hwmon for standard fans.
        // 2. Checks nvidia-smi for GPU fan percentage and safely appends it.
        command: [
            "bash",
            "-c",
            "for f in /sys/class/hwmon/hwmon*/fan*_input; do [ -e \"$f\" ] || continue; val=$(cat \"$f\" 2>/dev/null); [ -n \"$val\" ] && [ \"$val\" -gt 0 ] || continue; label_file=\"${f%_input}_label\"; if [ -e \"$label_file\" ]; then name=$(cat \"$label_file\"); else hwmon_name=$(cat \"${f%/*}/name\" 2>/dev/null || echo \"Fan\"); fan_num=$(echo \"$f\" | grep -o 'fan[0-9]*' | sed 's/fan//'); name=\"${hwmon_name} ${fan_num}\"; fi; max_file=\"${f%_input}_max\"; if [ -e \"$max_file\" ]; then max=$(cat \"$max_file\" 2>/dev/null); if [ -n \"$max\" ] && [ \"$max\" -gt 0 ]; then pct=$(( val * 100 / max )); echo \"$name;$pct;$val\"; else echo \"$name;0;$val\"; fi; else echo \"$name;0;$val\"; fi; done; if command -v nvidia-smi >/dev/null 2>&1; then gpu=$(nvidia-smi --query-gpu=fan.speed --format=csv,noheader,nounits 2>/dev/null | tr -d '[:space:]'); if [[ \"$gpu\" =~ ^[0-9]+$ ]]; then echo \"GPU Fan;$gpu;N/A\"; fi; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                let newModel = []
                for (let i = 0; i < lines.length; i++) {
                    if (lines[i].length === 0) continue
                        const parts = lines[i].split(";")
                        if (parts.length >= 3) {
                            newModel.push({
                                name: parts[0],
                                pct: parseInt(parts[1]) || 0,
                                          rpm: parts[2]
                            })
                        }
                }
                root.fanModel = newModel
            }
        }
    }

    // Fallback if absolutely nothing is found
    Text {
        visible: root.fanModel.length === 0
        text: "No fans detected"
        color: "#6c7086"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
        font.italic: true
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
    }

    Repeater {
        model: root.fanModel

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "\uf863"
                color: "#89b4fa"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                Layout.preferredWidth: 18
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                text: modelData.name.charAt(0).toUpperCase() + modelData.name.slice(1)
                color: "#a6adc8"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Text {
                // Dynamically formats the text depending on if we have RPM, Percentage, or both
                text: {
                    if (modelData.rpm === "N/A") {
                        return modelData.pct + "%"
                    } else if (modelData.pct > 0 && modelData.pct <= 100) {
                        return modelData.pct + "% (" + modelData.rpm + " RPM)"
                    } else {
                        return modelData.rpm + " RPM"
                    }
                }
                color: "#cdd6f4"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.bold: true
            }
        }
    }
}
