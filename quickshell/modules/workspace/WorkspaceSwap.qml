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
        '    # Read windows in reverse stack order so moving restores original order',
        '    mapfile -t addrs < <(hyprctl clients -j | jq -r --arg from "$from" \'[.[] | select(.workspace.id == ($from | tonumber)) | .address] | reverse | .[]\')',
        '    for addr in "${addrs[@]}"; do',
        '        [ -n "$addr" ] && hyprctl dispatch "hl.dsp.window.move({ workspace = \\"$to\\", window = \\"address:$addr\\" })"',
        '    done',
        '}',
        '',
        'TARGET_COUNT=$(hyprctl clients -j | jq --arg to "$TO" \'[.[] | select(.workspace.id == ($to | tonumber))] | length\')',
        '',
        'if [ "$TARGET_COUNT" -eq 0 ]; then',
        '    move_all "$FROM" "$TO"',
        'else',
        '    move_all "$FROM" "$TEMP"',
        '    move_all "$TO" "$FROM"',
        '    move_all "$TEMP" "$TO"',
        'fi'
    ].join('\n')

    // Rotates one or more disjoint permutation cycles of workspaces through a
    // single temp workspace each, so every workspace in a cycle trades its
    // content with the next one -- a genuine swap, nothing merged or lost.
    // Args are flattened as: <cycleLen> <ws> <ws> ... repeated per cycle.
    readonly property string cycleScript: [
        'move_all() {',
        '    local from="$1" to="$2"',
        '    mapfile -t addrs < <(hyprctl clients -j | jq -r --arg from "$from" \'[.[] | select(.workspace.id == ($from | tonumber)) | .address] | reverse | .[]\')',
        '    for addr in "${addrs[@]}"; do',
        '        [ -n "$addr" ] && hyprctl dispatch "hl.dsp.window.move({ workspace = \\"$to\\", window = \\"address:$addr\\" })"',
        '    done',
        '}',
        '',
        'ARGS=("$@")',
        'POS=0',
        'TEMP_BASE=900',
        'TEMP_IDX=0',
        '',
        'while [ "$POS" -lt "${#ARGS[@]}" ]; do',
        '    LEN="${ARGS[$POS]}"',
        '    POS=$((POS + 1))',
        '    CYCLE=("${ARGS[@]:$POS:$LEN}")',
        '    POS=$((POS + LEN))',
        '',
        '    K=${#CYCLE[@]}',
        '    TEMP=$((TEMP_BASE + TEMP_IDX))',
        '    TEMP_IDX=$((TEMP_IDX + 1))',
        '',
        '    # Evacuate the first node, then walk the cycle backwards moving',
        '    # each node into the position of the one before it, finally',
        '    # dropping the evacuated content into its rightful spot.',
        '    move_all "${CYCLE[0]}" "$TEMP"',
        '    for ((i=K-1; i>=1; i--)); do',
        '        NEXT=$(( (i + 1) % K ))',
        '        move_all "${CYCLE[$i]}" "${CYCLE[$NEXT]}"',
        '    done',
        '    move_all "$TEMP" "${CYCLE[1]}"',
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

    function runCycles(cycles) {
        if (!cycles || cycles.length === 0) return
            let args = ["bash", "-c", root.cycleScript, "workspace_swap_cycles"]
            for (let i = 0; i < cycles.length; i++) {
                args.push(String(cycles[i].length))
                for (let j = 0; j < cycles[i].length; j++) {
                    args.push(String(cycles[i][j]))
                }
            }
            if (swapProc.running) swapProc.running = false
                swapProc.command = args
                swapProc.running = true
    }
}
