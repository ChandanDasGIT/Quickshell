#!/usr/bin/env bash
# usage: workspace_swap.sh <target_workspace>
TO="$1"
TEMP=99   # scratch workspace, pick a number you never use normally

FROM=$(hyprctl activeworkspace -j | jq -r '.id')

if [ "$FROM" = "$TO" ]; then
    exit 0
fi

move_all() {
    local from="$1" to="$2"
    hyprctl clients -j | jq -r --arg from "$from" \
        '.[] | select(.workspace.id == ($from | tonumber)) | .address' | \
    while read -r addr; do
        [ -n "$addr" ] && hyprctl dispatch "hl.dsp.window.move({ workspace = \"$to\", window = \"address:$addr\" })"
    done
}

TARGET_COUNT=$(hyprctl clients -j | jq --arg to "$TO" \
    '[.[] | select(.workspace.id == ($to | tonumber))] | length')

if [ "$TARGET_COUNT" -eq 0 ]; then
    move_all "$FROM" "$TO"
else
    move_all "$FROM" "$TEMP"
    move_all "$TO" "$FROM"
    move_all "$TEMP" "$TO"
fi

hyprctl dispatch "hl.dsp.focus({ workspace = \"$TO\" })"
