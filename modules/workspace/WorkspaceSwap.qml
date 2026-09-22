pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string singleScript: [
        'TO="$1"',
        'FROM="$2"',
        'TEMP=99',
        '',
        'if [ "$FROM" = "$TO" ]; then',
        '    exit 0',
        'fi',
        '',
        'move_all() {',
        '    local from="$1" to="$2"',
        '    hyprctl clients -j | jq -r --arg from "$from" \\',
        '        \'.[] | select(.workspace.id == ($from | tonumber)) | .address\' | \\',
        '    while read -r addr; do',
        '        [ -n "$addr" ] && hyprctl dispatch "hl.dsp.window.move({ workspace = \\"$to\\", window = \\"address:$addr\\" })"',
        '    done',
        '}',
        '',
        'TARGET_COUNT=$(hyprctl clients -j | jq --arg to "$TO" \\',
        '    \'[.[] | select(.workspace.id == ($to | tonumber))] | length\')',
        '',
        'if [ "$TARGET_COUNT" -eq 0 ]; then',
        '    move_all "$FROM" "$TO"',
        'else',
        '    move_all "$FROM" "$TEMP"',
        '    move_all "$TO" "$FROM"',
        '    move_all "$TEMP" "$TO"',
        'fi'
    ].join('\n')

    readonly property string multiScript: [
        'move_all() {',
        '    local from="$1" to="$2"',
        '    hyprctl clients -j | jq -r --arg from "$from" \\',
        '        \'.[] | select(.workspace.id == ($from | tonumber)) | .address\' | \\',
        '    while read -r addr; do',
        '        [ -n "$addr" ] && hyprctl dispatch "hl.dsp.window.move({ workspace = \\"$to\\", window = \\"address:$addr\\" })"',
        '    done',
        '}',
        '',
        'declare -a SOURCES',
        'declare -a TARGETS',
        'while [ "$#" -ge 2 ]; do',
        '    SOURCES+=("$1")',
        '    TARGETS+=("$2")',
        '    shift 2',
        'done',
        '',
        'LEN=${#SOURCES[@]}',
        'BASE_TEMP=900',
        '',
        '# Step 1: Evacuate all sources to distinct temp workspaces',
        'for ((i=0; i<LEN; i++)); do',
        '    SRC="${SOURCES[$i]}"',
        '    TMP=$((BASE_TEMP + i))',
        '    move_all "$SRC" "$TMP"',
        'done',
        '',
        '# Step 2: Move from temp workspaces to final destinations',
        'for ((i=0; i<LEN; i++)); do',
        '    TMP=$((BASE_TEMP + i))',
        '    DST="${TARGETS[$i]}"',
        '    move_all "$TMP" "$DST"',
        'done'
    ].join('\n')

    Process {
        id: swapProc
        command: []
    }

    function run(to, from) {
        if (!to || !from || to === from) return
            let args = ["bash", "-c", root.singleScript, "workspace_swap", String(to), String(from)]
            if (swapProc.running) swapProc.running = false
                swapProc.command = args
                swapProc.running = true
    }

    function runMulti(pairs) {
        if (!pairs || pairs.length === 0) return
            let args = ["bash", "-c", root.multiScript, "workspace_swap"]
            for (let i = 0; i < pairs.length; i++) {
                args.push(String(pairs[i].from))
                args.push(String(pairs[i].to))
            }
            if (swapProc.running) swapProc.running = false
                swapProc.command = args
                swapProc.running = true
    }
}
