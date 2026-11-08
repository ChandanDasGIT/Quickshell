import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Item {
    id: netRoot
    implicitWidth: netSeg.implicitWidth
    implicitHeight: netSeg.implicitHeight

    // ---- Network state ----
    property bool wifiEnabled: false
    property bool flightMode: false
    property string netType: "none"
    property string netName: "Offline"
    property string netDevice: ""
    property int wifiSignal: 0
    property string netIp: "--"

    // ---- UI state ----
    property bool linkBusy: false
    property bool wifiBusy: false
    property bool flightBusy: false
    property bool hotspotActive: false
    property string hotspotDevice: ""        // interface the hotspot runs on
    property var hotspotClientList: []       // [{ mac, ip, name }]
    readonly property int hotspotClients: hotspotClientList.length
    property bool hotspotClientsOpen: false  // device list dropdown
    property bool hotspotBusy: false
    property bool hotspotSettingsOpen: false
    property bool hotspotEditing: false      // password field unlocked for typing
    property bool hotspotShowPass: false     // reveal password in the field
    property string hotspotSavedPass: ""     // last known saved password
    property string hotspotSavedSsid: ""     // last known saved SSID
    readonly property string hotspotProfile: "Hotspot"
    property string busySsid: ""        // network currently connecting/disconnecting
    property string expandedSsid: ""    // row with its action area open
    property string lastError: ""
    property bool refreshQueued: false
    property var pendingEntries: null   // list update deferred while a row is open
    readonly property bool isScanning: wifiRescanProc.running || rescanWait.running

    onHotspotSettingsOpenChanged: {
        hotspotEditing = false;
        hotspotShowPass = false;
        if (hotspotSettingsOpen && !hotspotReadProc.running) hotspotReadProc.running = true;
    }

    // Leaving edit mode (save or Escape) restores the saved password in the field
    onHotspotEditingChanged: {
        if (!hotspotEditing) {
            hotspotSsidInput.text = hotspotSavedSsid;
            hotspotPassInput.text = hotspotSavedPass;
        }
    }

    onExpandedSsidChanged: {
        if (expandedSsid === "" && pendingEntries !== null) {
            const e = pendingEntries;
            pendingEntries = null;
            syncModel(e);
        }
    }

    // ================= HELPERS =================

    // Split an `nmcli -t` line on unescaped ':' and unescape "\:" and "\\"
    function splitTerse(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length) {
                cur += line[i + 1];
                i++;
            } else if (c === ":") {
                out.push(cur);
                cur = "";
            } else {
                cur += c;
            }
        }
        out.push(cur);
        return out;
    }

    function refresh() {
        if (netCheckProc.running) refreshQueued = true;
        else netCheckProc.running = true;
    }

    function listWifi() {
        if (!wifiListProc.running) wifiListProc.running = true;
    }

    function rescan() {
        if (isScanning || !wifiEnabled) return;
        wifiRescanProc.running = true;
    }

    function connectTo(ssid, pass) {
        if (wifiConnectProc.running) return;
        lastError = "";
        busySsid = ssid;
        expandedSsid = "";
        wifiConnectProc.ssid = ssid;
        wifiConnectProc.pass = pass;
        wifiConnectProc.running = true;
    }

    // function disconnectCurrent(ssid) {
    //     if (wifiDisconnectProc.running) return;
    //     lastError = "";
    //     busySsid = ssid;
    //     expandedSsid = "";
    //     wifiDisconnectProc.running = true;
    // }

    function forgetNetwork(ssid) {
        if (wifiForgetProc.running) return;
        lastError = "";
        busySsid = ssid;
        expandedSsid = "";
        wifiForgetProc.ssid = ssid;
        wifiForgetProc.running = true;
    }
    function toggleLink() {
        if (linkProc.running) return;
        lastError = "";
        linkBusy = true;
        linkProc.connectMode = (netType === "none");
        linkProc.running = true;
    }

    function toggleHotspot() {
        if (hotspotToggleProc.running) return;
        lastError = "";
        hotspotBusy = true;
        hotspotToggleProc.enable = !hotspotActive;
        hotspotToggleProc.running = true;
    }

    function saveHotspot(ssid, pass) {
        if (hotspotPassProc.running) return;
        ssid = ssid.trim();
        if (ssid.length < 1 || ssid.length > 32) {
            lastError = "Hotspot name must be 1-32 characters";
            errorTimer.restart();
            return;
        }
        if (pass.length < 8 || pass.length > 63) {
            lastError = "Hotspot password must be 8-63 characters";
            errorTimer.restart();
            return;
        }
        lastError = "";
        hotspotPassProc.ssid = ssid;
        hotspotPassProc.pass = pass;
        hotspotPassProc.running = true;
    }

    // Parse saved profiles + visible networks into a model-ready list
    function applyWifiList(text) {
        const saved = new Set();
        const best = new Map();
        let section = "";

        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (line === "@@SAVED" || line === "@@WIFI") { section = line; continue; }
            if (!line) continue;

            const p = splitTerse(line);
            if (section === "@@SAVED") {
                if (p.length >= 2 && p[1] === "802-11-wireless") saved.add(p[0]);
            } else if (section === "@@WIFI") {
                if (p.length < 4) continue;
                const ssid = p[3];
                if (ssid === "" || ssid === "--") continue;

                const e = {
                    ssid: ssid,
                    strength: parseInt(p[1]) || 0,
                    secured: (p[2] !== "" && p[2] !== "--"),
                    inUse: (p[0] === "*"),
                    saved: saved.has(ssid)
                };
                const old = best.get(ssid);
                if (!old || e.inUse || (!old.inUse && e.strength > old.strength))
                    best.set(ssid, e);
            }
        }

        const entries = Array.from(best.values());
        entries.sort(function(a, b) {
            if (a.inUse !== b.inUse) return a.inUse ? -1 : 1;
            return b.strength - a.strength;
        });
        syncModel(entries);
    }

    // Update rows in place when the set of networks is unchanged, so the open
    // row, typed password and scroll position survive refreshes.
    function syncModel(entries) {
        const keep = new Set(entries.map(function(e) { return e.ssid }));
        for (let i = wifiModel.count - 1; i >= 0; i--) {
            if (!keep.has(wifiModel.get(i).ssid)) wifiModel.remove(i);
        }
        for (let i = 0; i < entries.length; i++) {
            let from = -1;
            for (let j = i; j < wifiModel.count; j++) {
                if (wifiModel.get(j).ssid === entries[i].ssid) { from = j; break; }
            }
            if (from === -1) {
                wifiModel.insert(i, entries[i]);
            } else {
                if (from !== i) wifiModel.move(from, i, 1);
                wifiModel.set(i, entries[i]);
            }
        }
    }

    // ================= TIMERS =================
    Timer { id: refreshDebounce; interval: 300; onTriggered: netRoot.refresh() }
    Timer { id: monitorRestart; interval: 2000; onTriggered: nmMonitor.running = true }
    Timer { id: rescanWait; interval: 3000; onTriggered: netRoot.listWifi() }
    Timer { id: errorTimer; interval: 6000; onTriggered: netRoot.lastError = "" }

    // Signal strength doesn't emit NM events, so poll lightly while visible
    Timer {
        interval: 5000
        running: netPopup.visible
        repeat: true
        onTriggered: netRoot.refresh()
    }

    // ================= DATA =================
    ListModel { id: wifiModel }

    // ================= PROCESSES =================

    // Event-driven refresh instead of constant polling
    Process {
        id: nmMonitor
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: refreshDebounce.restart() }
        onExited: monitorRestart.start()
    }

    // Radio state + device list
    Process {
        id: netCheckProc
        command: [
            "bash", "-c",
            "echo \"$(nmcli radio wifi 2>/dev/null)\";" +
            "echo \"$(nmcli radio wwan 2>/dev/null)\";" +
            "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev status 2>/dev/null"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const wifiOn = (lines[0] || "").trim() === "enabled";
                const wwanOn = (lines[1] || "").trim() === "enabled";

                const ignored = ["loopback", "bridge", "veth", "tun", "dummy", "wifi-p2p"];
                const rank = { "ethernet": 0, "wifi": 1 };
                let best = null;
                let hotspot = false;

                for (let i = 2; i < lines.length; i++) {
                    if (!lines[i]) continue;
                    const p = netRoot.splitTerse(lines[i]); // DEVICE, TYPE, STATE, CONNECTION
                    if (p.length < 4 || !p[2].startsWith("connected")) continue;
                    if (p[1] === "wifi" && p[3] === netRoot.hotspotProfile) {
                        hotspot = true;
                        netRoot.hotspotDevice = p[0];
                    }
                    if (ignored.indexOf(p[1]) >= 0) continue;
                    const r = rank[p[1]] !== undefined ? rank[p[1]] : 2;
                    if (!best || r < best.rank) best = { dev: p[0], type: p[1], name: p[3], rank: r };
                }

                netRoot.wifiEnabled = wifiOn;
                netRoot.hotspotActive = hotspot;
                if (!hotspot) {
                    netRoot.hotspotDevice = "";
                    netRoot.hotspotClientList = [];
                } else if (netPopup.visible && !hotspotClientsProc.running) {
                    hotspotClientsProc.running = true;
                }
                netRoot.flightMode = !wifiOn && !wwanOn;

                if (best) {
                    netRoot.netType = best.type;
                    netRoot.netName = best.name;
                    netRoot.netDevice = best.dev;
                    if (!netDetailsProc.running) netDetailsProc.running = true;
                } else {
                    netRoot.netType = "none";
                    netRoot.netName = "Offline";
                    netRoot.netDevice = "";
                    netRoot.netIp = "--";
                    netRoot.wifiSignal = 0;
                }

                if (!wifiOn) {
                    wifiModel.clear();
                    netRoot.pendingEntries = null;
                } else if (netPopup.visible) {
                    netRoot.listWifi();
                }
            }
        }
        onExited: {
            if (netRoot.refreshQueued) {
                netRoot.refreshQueued = false;
                Qt.callLater(netRoot.refresh);
            }
        }
    }

    // IP + signal of the active device
    Process {
        id: netDetailsProc
        command: [
            "bash", "-c",
            "ip=$(nmcli -g IP4.ADDRESS dev show \"$1\" 2>/dev/null | head -n1 | cut -d'|' -f1 | cut -d/ -f1);" +
            "sig=$(nmcli -t -f IN-USE,SIGNAL dev wifi list ifname \"$1\" --rescan no 2>/dev/null | awk -F: '$1==\"*\"{print $2; exit}');" +
            "echo \"$ip\"; echo \"$sig\"",
            "--", netRoot.netDevice
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                netRoot.netIp = (lines[0] || "").trim() || "--";
                netRoot.wifiSignal = parseInt(lines[1]) || 0;
            }
        }
    }

    Process {
        id: wifiToggleProc
        property bool enable: true
        command: ["nmcli", "radio", "wifi", enable ? "on" : "off"]
        onExited: { netRoot.wifiBusy = false; netRoot.refresh(); }
    }

    Process {
        id: flightToggleProc
        property bool enable: true   // true = radios on (leave airplane mode)
        command: ["nmcli", "radio", "all", enable ? "on" : "off"]
        onExited: { netRoot.flightBusy = false; netRoot.refresh(); }
    }

    // Hotspot on: reuse the saved "Hotspot" profile if there is one, otherwise let
    // NetworkManager create it (random password, readable later via the gear).
    Process {
        id: hotspotToggleProc
        property bool enable: true
        environment: ({ "NM_HS": netRoot.hotspotProfile })
        command: [
            "bash", "-c",
            enable
            ? "nmcli radio wifi on;" +
              "if nmcli -g NAME c show | grep -Fxq -- \"$NM_HS\"; then nmcli c up id \"$NM_HS\";" +
              "else nmcli dev wifi hotspot con-name \"$NM_HS\"; fi"
            : "nmcli c down id \"$NM_HS\""
        ]
        onExited: (code) => {
            if (code !== 0) {
                netRoot.lastError = enable ? "Couldn't start hotspot" : "Couldn't stop hotspot";
                errorTimer.restart();
            }
            netRoot.hotspotBusy = false;
            netRoot.refresh();
        }
    }

    // List authorized stations on the hotspot interface (works unprivileged).
    // MAC -> IP via the neighbour table, IP -> hostname via a reverse lookup
    // against NM's dnsmasq, which knows the names clients sent over DHCP.
    // Output: one "mac<TAB>ip<TAB>name" line per client.
    Process {
        id: hotspotClientsProc
        environment: ({ "NM_DEV": netRoot.hotspotDevice })
        command: [
            "bash", "-c",
            "gw=$(ip -4 -o addr show dev \"$NM_DEV\" | awk '{print $4; exit}' | cut -d/ -f1);" +
            "iw dev \"$NM_DEV\" station dump 2>/dev/null" +
            " | awk '/^Station/{mac=$2} /authorized:[[:space:]]*yes/{print mac}'" +
            " | while read -r mac; do" +
            "   ip=$(ip -4 neigh show dev \"$NM_DEV\" | awk -v m=\"$mac\" 'tolower($3)==tolower(m){print $1; exit}');" +
            "   name=;" +
            "   if [ -n \"$ip\" ] && [ -n \"$gw\" ]; then" +
            "     name=$(dig +short +time=1 +tries=1 @\"$gw\" -x \"$ip\" 2>/dev/null | grep -v '^;' | head -n1 | sed 's/\\.$//');" +
            "   fi;" +
            "   printf '%s\\t%s\\t%s\\n' \"$mac\" \"$ip\" \"$name\";" +
            " done"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    if (!lines[i]) continue;
                    const p = lines[i].split("\t");
                    list.push({ mac: p[0] || "", ip: p[1] || "", name: p[2] || "" });
                }
                list.sort(function(a, b) {
                    return (a.name || a.mac).localeCompare(b.name || b.mac);
                });
                netRoot.hotspotClientList = list;
                if (list.length === 0) netRoot.hotspotClientsOpen = false;
            }
        }
    }

    // Clients joining/leaving don't emit NM events, so poll while visible
    Timer {
        interval: 3000
        running: netPopup.visible && netRoot.hotspotActive
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!hotspotClientsProc.running) hotspotClientsProc.running = true }
    }

    // Read the saved hotspot password to prefill the settings field
    Process {
        id: hotspotReadProc
        environment: ({ "NM_HS": netRoot.hotspotProfile })
        // Line 1: SSID (defaults to <hostname>-hotspot if no profile yet), line 2: password
        command: [
            "bash", "-c",
            "ssid=$(nmcli -g 802-11-wireless.ssid c show id \"$NM_HS\" 2>/dev/null);" +
            "[ -n \"$ssid\" ] || ssid=\"$(hostname)-hotspot\";" +
            "psk=$(nmcli -s -g 802-11-wireless-security.psk c show id \"$NM_HS\" 2>/dev/null);" +
            "printf '%s\\n%s\\n' \"$ssid\" \"$psk\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                // -g escapes ':' and '\\'; splitTerse undoes that
                netRoot.hotspotSavedSsid = netRoot.splitTerse(lines[0] || "").join(":");
                netRoot.hotspotSavedPass = (lines[1] || "");
                if (!netRoot.hotspotEditing) {
                    hotspotSsidInput.text = netRoot.hotspotSavedSsid;
                    hotspotPassInput.text = netRoot.hotspotSavedPass;
                }
            }
        }
    }

    // Set the hotspot SSID + password: modify the profile, or create one if missing.
    // Restarts the hotspot if it's running so the new settings take effect.
    // Note: nmcli has no stdin option for `c modify/add`, so the psk is briefly
    // visible in this process's argv.
    Process {
        id: hotspotPassProc
        property string ssid: ""
        property string pass: ""
        environment: ({ "NM_HS": netRoot.hotspotProfile, "NM_SSID": ssid, "NM_PASS": pass })
        command: [
            "bash", "-c",
            "if nmcli -g NAME c show | grep -Fxq -- \"$NM_HS\"; then" +
            "  nmcli c modify id \"$NM_HS\" 802-11-wireless.ssid \"$NM_SSID\" wifi-sec.key-mgmt wpa-psk wifi-sec.psk \"$NM_PASS\" || exit 1;" +
            "  if nmcli -g NAME c show --active | grep -Fxq -- \"$NM_HS\"; then nmcli c up id \"$NM_HS\"; fi;" +
            "else" +
            "  nmcli c add type wifi con-name \"$NM_HS\" autoconnect no ssid \"$NM_SSID\"" +
            "    wifi.mode ap wifi.band bg ipv4.method shared ipv6.method ignore" +
            "    wifi-sec.key-mgmt wpa-psk wifi-sec.proto rsn wifi-sec.pairwise ccmp wifi-sec.group ccmp" +
            "    wifi-sec.psk \"$NM_PASS\";" +
            "fi"
        ]
        onExited: (code) => {
            if (code !== 0) {
                netRoot.lastError = "Couldn't save hotspot settings";
                errorTimer.restart();
            } else {
                netRoot.hotspotSavedSsid = ssid;
                netRoot.hotspotSavedPass = pass;
                netRoot.hotspotEditing = false;
            }
            pass = "";
            netRoot.refresh();
        }
    }

    // Disconnect: drops every connected ethernet/wifi device at once.
    // Connect: brings every ethernet/wifi device up (saved networks only for wifi).
    Process {
        id: linkProc
        property bool connectMode: false
        command: [
            "bash", "-c",
            connectMode
            ? "for d in $(nmcli -t -f DEVICE,TYPE dev status | awk -F: '$2==\"ethernet\"||$2==\"wifi\"{print $1}'); do nmcli dev connect \"$d\" & done; wait"
            : "for d in $(nmcli -t -f DEVICE,TYPE,STATE dev status | awk -F: '($2==\"ethernet\"||$2==\"wifi\") && $3 ~ /^connected/ {print $1}'); do nmcli dev disconnect \"$d\" & done; wait"
        ]
        onExited: {
            netRoot.linkBusy = false;
            netRoot.refresh();
            netRoot.listWifi();
        }
    }

    // Saved profiles + visible networks (cached results, returns instantly)
    Process {
        id: wifiListProc
        command: [
            "bash", "-c",
            "echo @@SAVED; nmcli -t -f NAME,TYPE c show 2>/dev/null;" +
            "echo @@WIFI; nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID dev wifi list --rescan no 2>/dev/null"
        ]
        stdout: StdioCollector { onStreamFinished: netRoot.applyWifiList(text) }
    }

    // Ask the radio for a fresh scan; results land a few seconds later
    Process {
        id: wifiRescanProc
        command: ["nmcli", "dev", "wifi", "rescan"]
        onExited: rescanWait.start()
    }

    // Always targets the connected Wi-Fi device, never ethernet
    // Process {
    //     id: wifiDisconnectProc
    //     command: [
    //         "bash", "-c",
    //         "dev=$(nmcli -t -f DEVICE,TYPE,STATE dev status | awk -F: '$2==\"wifi\" && $3 ~ /^connected/ {print $1; exit}');" +
    //         "[ -n \"$dev\" ] && nmcli dev disconnect \"$dev\""
    //     ]
    //     onExited: (code) => {
    //         if (code !== 0) {
    //             netRoot.lastError = "Couldn't disconnect";
    //             errorTimer.restart();
    //         }
    //         netRoot.busySsid = "";
    //         netRoot.refresh();
    //         netRoot.listWifi();
    //     }
    // }

    // Deletes every saved Wi-Fi profile for this SSID (matched by SSID, not profile name)
    Process {
        id: wifiForgetProc
        property string ssid: ""
        environment: ({ "NM_SSID": ssid })
        command: [
            "bash", "-c",
            "rc=0;" +
            "for u in $(nmcli -g UUID,TYPE c show | awk -F: '$2==\"802-11-wireless\"{print $1}'); do" +
            "  s=$(nmcli -g 802-11-wireless.ssid c show uuid \"$u\");" +
            "  if [ \"$s\" = \"$NM_SSID\" ]; then nmcli c delete uuid \"$u\" || rc=1; fi;" +
            "done; exit $rc"
        ]
        onExited: (code) => {
            if (code !== 0) {
                netRoot.lastError = "Couldn't forget " + ssid;
                errorTimer.restart();
            }
            netRoot.busySsid = "";
            netRoot.refresh();
            netRoot.listWifi();
        }
    }

    // Password travels via env + stdin, never on a command line
    Process {
        id: wifiConnectProc
        property string ssid: ""
        property string pass: ""
        environment: ({ "NM_SSID": ssid, "NM_PASS": pass })
        command: [
            "bash", "-c",
            "if [ -n \"$NM_PASS\" ]; then" +
            "  printf '%s\\n' \"$NM_PASS\" | nmcli --ask dev wifi connect \"$NM_SSID\";" +
            "elif nmcli -g NAME c show | grep -Fxq -- \"$NM_SSID\"; then" +
            "  nmcli c up id \"$NM_SSID\";" +
            "else" +
            "  nmcli dev wifi connect \"$NM_SSID\";" +
            "fi"
        ]
        onExited: (code) => {
            if (code !== 0) {
                netRoot.lastError = "Couldn't connect to " + ssid;
                errorTimer.restart();
            }
            pass = "";
            netRoot.busySsid = "";
            netRoot.refresh();
            netRoot.listWifi();
        }
    }

    // ================= REUSABLE STYLED COMPONENTS =================
    component ActionButton: Rectangle {
        id: btnRoot
        property string icon: ""
        property string text: ""
        property bool active: false
        property bool busy: false
        signal clicked()

        Layout.fillWidth: true
        implicitHeight: 32
        radius: 6
        color: btnMouse.containsMouse && !busy
        ? (active ? "#b4befe" : "#313244")
        : (active ? "#89b4fa" : "#1e1e2e")

        RowLayout {
            anchors.centerIn: parent
            spacing: 8
            Text {
                visible: !btnRoot.busy
                text: btnRoot.icon
                color: btnRoot.active ? "#11111b" : "#cdd6f4"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
            }
            Text {
                id: spinner
                visible: btnRoot.busy
                text: "\uf110"
                color: btnRoot.active ? "#11111b" : "#cdd6f4"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                RotationAnimator on rotation {
                    from: 0; to: 360; duration: 1000
                    loops: Animation.Infinite; running: spinner.visible
                }
            }
            Text {
                text: btnRoot.text
                color: btnRoot.active ? "#11111b" : "#cdd6f4"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true
            }
        }
        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: btnRoot.busy ? Qt.WaitCursor : Qt.PointingHandCursor
            onClicked: { if (!btnRoot.busy) btnRoot.clicked() }
        }
    }

    component InfoRow: RowLayout {
        property string icon: ""
        property string name: ""
        property string value: "--"

        Layout.fillWidth: true
        spacing: 8
        Text {
            text: icon; color: "#89b4fa"
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
            Layout.preferredWidth: 18; horizontalAlignment: Text.AlignHCenter
        }
        Text {
            text: name; color: "#a6adc8"
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
            Layout.fillWidth: true
        }
        Text {
            text: value; color: "#cdd6f4"
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true
            horizontalAlignment: Text.AlignRight
            Layout.maximumWidth: 160
            elide: Text.ElideRight
        }
    }

    // Hotspot settings field: read-only until clicked, then the whole form unlocks
    component HotspotField: TextField {
        id: hsField
        property string label: ""
        signal editRequested()

        Layout.fillWidth: true
        readOnly: !netRoot.hotspotEditing
        leftPadding: 48
        placeholderTextColor: "#6c7086"
        color: netRoot.hotspotEditing ? "#cdd6f4" : "#a6adc8"
        font.pixelSize: 12
        background: Rectangle {
            color: netRoot.hotspotEditing ? "#1e1e2e" : "#181825"; radius: 4
            border.color: netRoot.hotspotEditing && hsField.activeFocus ? "#89b4fa" : "#313244"
            Text {
                anchors.left: parent.left; anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: hsField.label
                color: "#6c7086"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true
            }
        }
        Keys.onEscapePressed: netRoot.hotspotEditing = false

        MouseArea {
            anchors.fill: parent
            visible: !netRoot.hotspotEditing
            cursorShape: Qt.IBeamCursor
            onClicked: {
                netRoot.hotspotEditing = true;
                hsField.editRequested();
                hsField.cursorPosition = hsField.text.length;
            }
        }
    }

    // ================= NETWORK DELEGATE =================
    component WifiDelegate: ColumnLayout {
        id: delRoot
        required property int index
        required property string ssid
        required property int strength
        required property bool secured
        required property bool inUse
        required property bool saved

        readonly property bool isSelected: netRoot.expandedSsid === ssid
        readonly property bool isBusy: netRoot.busySsid === ssid
        readonly property bool needsPassword: secured && !saved && !inUse

        width: ListView.view.width
        spacing: 4

        function submit() {
            if (passInput.text === "") return;
            const p = passInput.text;
            passInput.text = "";
            netRoot.connectTo(ssid, p);
        }

        onIsSelectedChanged: {
            if (isSelected) { if (needsPassword) passInput.forceActiveFocus(); }
            else passInput.text = "";
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: 6
            color: rowMouse.containsMouse || delRoot.isSelected ? "#313244" : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Text {
                    text: "\uf1eb"
                    color: delRoot.inUse ? "#a6e3a1" : "#cdd6f4"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                }
                Text {
                    text: delRoot.ssid
                    color: delRoot.inUse ? "#a6e3a1" : "#cdd6f4"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                    font.bold: delRoot.inUse
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Text {
                    id: rowSpinner
                    visible: delRoot.isBusy
                    text: "\uf110"; color: "#89b4fa"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                    RotationAnimator on rotation {
                        from: 0; to: 360; duration: 1000
                        loops: Animation.Infinite; running: rowSpinner.visible
                    }
                }
                Text {
                    visible: delRoot.secured && !delRoot.inUse && !delRoot.isBusy
                    text: "\uf023"; color: "#a6adc8"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                }
            }
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (delRoot.inUse && !delRoot.saved) return;
                    const view = delRoot.ListView.view;
                    netRoot.expandedSsid = delRoot.isSelected ? "" : delRoot.ssid;
                    Qt.callLater(function() { view.positionViewAtIndex(delRoot.index, ListView.Contain) });
                }
            }
        }

        // Expandable action area
        RowLayout {
            visible: delRoot.isSelected && !delRoot.isBusy
            Layout.fillWidth: true
            spacing: 4

            // Disconnect (active network)
            // Rectangle {
            //     visible: delRoot.inUse
            //     Layout.fillWidth: true
            //     Layout.preferredHeight: 32
            //     radius: 4
            //     color: disMouse.containsMouse ? "#f38ba8" : "#eba0ac"
            //     Text {
            //         anchors.centerIn: parent; text: "Disconnect"; color: "#11111b"
            //         font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true
            //     }
            //     MouseArea {
            //         id: disMouse
            //         anchors.fill: parent
            //         hoverEnabled: true
            //         cursorShape: Qt.PointingHandCursor
            //         onClicked: netRoot.disconnectCurrent(delRoot.ssid)
            //     }
            // }

            // Password field (secured, not yet saved)
            TextField {
                id: passInput
                visible: delRoot.needsPassword
                Layout.fillWidth: true
                placeholderText: "Password..."
                placeholderTextColor: "#6c7086"
                color: "#cdd6f4"
                echoMode: TextInput.Password
                font.pixelSize: 12
                background: Rectangle {
                    color: "#1e1e2e"; radius: 4
                    border.color: passInput.activeFocus ? "#89b4fa" : "#313244"
                }
                onAccepted: delRoot.submit()
            }

            // Connect (with password)
            Rectangle {
                visible: delRoot.needsPassword
                Layout.preferredWidth: 70
                Layout.preferredHeight: passInput.height
                radius: 4
                color: pwConnMouse.containsMouse ? "#b4befe" : "#89b4fa"
                Text {
                    anchors.centerIn: parent; text: "Connect"; color: "#11111b"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true
                }
                MouseArea {
                    id: pwConnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: delRoot.submit()
                }
            }

            // Connect (open or already-saved network)
            Rectangle {
                visible: !delRoot.inUse && !delRoot.needsPassword
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: 4
                color: connMouse.containsMouse ? "#b4befe" : "#89b4fa"
                Text {
                    anchors.centerIn: parent; text: "Connect"; color: "#11111b"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true
                }
                MouseArea {
                    id: connMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: netRoot.connectTo(delRoot.ssid, "")
                }
            }
            // Forget (saved networks only)
            Rectangle {
                visible: delRoot.saved
                Layout.fillWidth: delRoot.inUse
                Layout.preferredWidth: delRoot.inUse ? -1 : 80
                Layout.preferredHeight: 32
                radius: 4
                color: forgetMouse.containsMouse ? "#f38ba8" : "#313244"
                Text {
                    anchors.centerIn: parent
                    text: "Forget"
                    color: forgetMouse.containsMouse ? "#11111b" : "#f38ba8"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true
                }
                MouseArea {
                    id: forgetMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: netRoot.forgetNetwork(delRoot.ssid)
                }
            }
        }
    }

    // ================= MAIN BAR WIDGET =================
    Rectangle {
        id: netSeg
        color: netMouseArea.containsMouse ? "#33ffffff" : "transparent"
        radius: 4
        implicitHeight: 24
        implicitWidth: netIcon.implicitWidth + 12

        Text {
            id: netIcon
            anchors.centerIn: parent
            text: {
                if (netRoot.flightMode) return "\uf072";            // airplane
                if (netRoot.netType === "ethernet") return "\uf108";
                return "\uf1eb";                                    // wi-fi
            }
            color: {
                if (netRoot.flightMode) return "#eba0ac";
                if (netRoot.netType === "none") return "#585b70";   // dim when offline
                return Theme.iconColor;
            }
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
        }
        MouseArea {
            id: netMouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: netPopup.visible = !netPopup.visible
        }
    }

    PopupWindow {
        id: netPopup
        visible: false
        color: "transparent"

        anchor {
            item: netSeg
            edges: Edges.Bottom
            gravity: Edges.Bottom
        }
        implicitWidth: 280
        implicitHeight: 480   // fixed; the card animates inside it
        mask: Region { item: netCard }

        HyprlandFocusGrab {
            id: netGrab
            windows: [netPopup]
            onActiveChanged: { if (!active) netPopup.visible = false }
        }

        onVisibleChanged: {
            if (visible) {
                Qt.callLater(function() { netGrab.active = true });
                netRoot.refresh();
                if (netRoot.wifiEnabled) netRoot.listWifi();
            } else {
                netGrab.active = false;
                netRoot.expandedSsid = "";
                netRoot.lastError = "";
                netRoot.hotspotSettingsOpen = false;
                netRoot.hotspotClientsOpen = false;
            }
        }

        Rectangle {
            id: netCard
            anchors.top: parent.top
            anchors.topMargin: 6
            width: parent.width
            height: netCol.implicitHeight + 20
            clip: true
            radius: 12
            color: "#161622"
            border.color: "#2a2a3a"
            border.width: 1

            Behavior on height {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                id: netCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 10
                spacing: 8

                // Top toggles
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ActionButton {
                        icon: netRoot.wifiEnabled ? "\uf205" : "\uf204"
                        text: "Wi-Fi"
                        active: netRoot.wifiEnabled
                        busy: netRoot.wifiBusy
                        onClicked: {
                            netRoot.wifiBusy = true;
                            wifiToggleProc.enable = !netRoot.wifiEnabled;
                            wifiToggleProc.running = true;
                        }
                    }

                    ActionButton {
                        icon: "\uf072"
                        text: "Airplane"
                        active: netRoot.flightMode
                        busy: netRoot.flightBusy
                        onClicked: {
                            netRoot.flightBusy = true;
                            flightToggleProc.enable = netRoot.flightMode; // on -> leave airplane mode
                            flightToggleProc.running = true;
                        }
                    }
                }

                // Hotspot + settings gear | Connect/Disconnect
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1   // split the row evenly with Disconnect
                        spacing: 4

                        ActionButton {
                            icon: "\uf1eb"
                            text: "Hotspot"
                            active: netRoot.hotspotActive
                            busy: netRoot.hotspotBusy
                            onClicked: netRoot.toggleHotspot()
                        }

                        Rectangle {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 32
                            radius: 6
                            color: gearMouse.containsMouse || netRoot.hotspotSettingsOpen ? "#313244" : "#1e1e2e"
                            Text {
                                anchors.centerIn: parent
                                text: "\uf013"
                                color: netRoot.hotspotSettingsOpen ? "#89b4fa" : "#a6adc8"
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                            }
                            MouseArea {
                                id: gearMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: netRoot.hotspotSettingsOpen = !netRoot.hotspotSettingsOpen
                            }
                        }
                    }

                    ActionButton {
                        Layout.preferredWidth: 1
                        icon: netRoot.netType === "none" ? "\uf0c1" : "\uf127"
                        text: netRoot.netType === "none" ? "Connect" : "Disconnect"
                        active: netRoot.netType !== "none"
                        busy: netRoot.linkBusy
                        onClicked: netRoot.toggleLink()
                    }
                }

                // Hotspot settings dropdown: fields are read-only until clicked
                ColumnLayout {
                    visible: netRoot.hotspotSettingsOpen
                    Layout.fillWidth: true
                    spacing: 4

                    HotspotField {
                        id: hotspotSsidInput
                        label: "SSID"
                        placeholderText: netRoot.hotspotEditing ? "Network name..." : "Not set (click to edit)"
                        onAccepted: { if (netRoot.hotspotEditing) hotspotPassInput.forceActiveFocus() }
                        onEditRequested: hotspotSsidInput.forceActiveFocus()
                    }

                    HotspotField {
                        id: hotspotPassInput
                        label: "Pass"
                        placeholderText: netRoot.hotspotEditing ? "New password..." : "Not set (click to edit)"
                        echoMode: netRoot.hotspotShowPass ? TextInput.Normal : TextInput.Password
                        onAccepted: { if (netRoot.hotspotEditing) netRoot.saveHotspot(hotspotSsidInput.text, text) }
                        onEditRequested: hotspotPassInput.forceActiveFocus()
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        // Save (only does something while editing)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 28
                            radius: 4
                            opacity: netRoot.hotspotEditing ? 1 : 0.4
                            color: hsSaveMouse.containsMouse && netRoot.hotspotEditing ? "#b4befe" : "#89b4fa"
                            Text {
                                anchors.centerIn: parent; text: "Save"; color: "#11111b"
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true
                            }
                            MouseArea {
                                id: hsSaveMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: !netRoot.hotspotEditing ? Qt.ArrowCursor
                                           : hotspotPassProc.running ? Qt.WaitCursor : Qt.PointingHandCursor
                                onClicked: {
                                    if (netRoot.hotspotEditing)
                                        netRoot.saveHotspot(hotspotSsidInput.text, hotspotPassInput.text);
                                }
                            }
                        }

                        // Show / hide password
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 28
                            radius: 4
                            color: hsShowMouse.containsMouse ? "#45475a" : "#313244"
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: netRoot.hotspotShowPass ? "" : ""
                                    color: "#cdd6f4"
                                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                                }
                                Text {
                                    text: netRoot.hotspotShowPass ? "Hide password" : "Show password"
                                    color: "#cdd6f4"
                                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true
                                }
                            }
                            MouseArea {
                                id: hsShowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: netRoot.hotspotShowPass = !netRoot.hotspotShowPass
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#313244" }

                InfoRow {
                    icon: "\uf0c1"; name: "Type"
                    value: netRoot.netType === "wifi" ? "Wi-Fi"
                    : netRoot.netType === "ethernet" ? "Ethernet"
                    : netRoot.netType === "none" ? "None" : "Other"
                }
                InfoRow { icon: "\uf012"; name: "Network"; value: netRoot.netName }
                InfoRow { icon: "\uf0eb"; name: "IP Addr"; value: netRoot.netIp }
                InfoRow {
                    icon: "\uf201"; name: "Signal"
                    value: netRoot.wifiSignal + "%"
                    visible: netRoot.netType === "wifi" && !netRoot.hotspotActive
                }
                // Hotspot clients: click to show device names
                ColumnLayout {
                    visible: netRoot.hotspotActive
                    Layout.fillWidth: true
                    spacing: 4

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: clientsRow.implicitHeight

                        InfoRow {
                            id: clientsRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            icon: "\uf0c0"; name: "Hotspot Clients"
                            value: netRoot.hotspotClients +
                                   (netRoot.hotspotClients > 0
                                    ? (netRoot.hotspotClientsOpen ? "  \uf077" : "  \uf078") : "")
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: netRoot.hotspotClients > 0
                            cursorShape: Qt.PointingHandCursor
                            onClicked: netRoot.hotspotClientsOpen = !netRoot.hotspotClientsOpen
                        }
                    }

                    Repeater {
                        model: netRoot.hotspotClientsOpen ? netRoot.hotspotClientList : []

                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 26
                            radius: 4
                            color: "#1e1e2e"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    text: "\uf10b"; color: "#a6e3a1"
                                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                                }
                                Text {
                                    text: modelData.name || modelData.mac
                                    color: "#cdd6f4"
                                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                                    font.bold: modelData.name !== ""
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: modelData.ip || "--"
                                    color: "#a6adc8"
                                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: netRoot.lastError !== ""
                    text: netRoot.lastError
                    color: "#f38ba8"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true; height: 1; color: "#313244"
                    visible: netRoot.wifiEnabled
                }

                // Available networks header
                RowLayout {
                    visible: netRoot.wifiEnabled
                    Layout.fillWidth: true

                    Text {
                        text: "Available Networks"
                        color: "#cdd6f4"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        radius: 4
                        color: scanMouse.containsMouse ? "#313244" : "transparent"

                        Text {
                            id: scanIcon
                            anchors.centerIn: parent
                            text: "\uf021"
                            color: netRoot.isScanning ? "#89b4fa" : "#a6adc8"
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12

                            RotationAnimator on rotation {
                                from: 0; to: 360; duration: 1000
                                loops: Animation.Infinite; running: netRoot.isScanning
                            }
                        }
                        MouseArea {
                            id: scanMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: netRoot.rescan()
                        }
                    }
                }

                ListView {
                    id: wifiList
                    readonly property int maxRows: 5
                    readonly property real maxListHeight: maxRows * 32 + (maxRows - 1) * spacing

                    visible: netRoot.wifiEnabled && count > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, maxListHeight)
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    model: wifiModel
                    delegate: WifiDelegate {}

                    add: Transition {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 }
                    }
                    remove: Transition {
                        NumberAnimation { property: "opacity"; to: 0; duration: 120 }
                    }
                    displaced: Transition {
                        NumberAnimation { property: "y"; duration: 180; easing.type: Easing.OutCubic }
                    }

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                }
            }
        }
    }
}
