#!/bin/bash
# Log errors for debugging (check /tmp/eww-toggle.log if it fails)
exec 2> /tmp/eww-toggle.log

# Ensure absolute and explicit home path resolution
USER_HOME="${HOME:-$(getent passwd "$USER" diretory | cut -d: -f6)}"
TODO="$USER_HOME/.config/scripts/to-do.txt"
SHORTCUTS="$USER_HOME/.config/scripts/shortcuts.txt"

# Use absolute path for eww
EWW_BIN="$(command -v eww)"

if [ -z "$EWW_BIN" ]; then
    notify-send "EWW Error" "eww binary not found in PATH"
    exit 1
fi

if ! pgrep -x eww >/dev/null 2>&1; then
    "$EWW_BIN" daemon >/dev/null 2>&1
    sleep 0.5
fi

# Safe file check and content extraction
if [ -f "$TODO" ]; then
    TODO_CONTENT="$(fold -s -w 45 "$TODO")"
else
    TODO_CONTENT="To-do file not found at $TODO"
    notify-send "EWW Warning" "Could not locate to-do.txt"
fi

if [ -f "$SHORTCUTS" ]; then
    SHORTCUTS_CONTENT="$(fold -s -w 45 "$SHORTCUTS")"
else
    SHORTCUTS_CONTENT="Shortcuts file not found at $SHORTCUTS"
fi

# Update eww variables
"$EWW_BIN" update todo="$TODO_CONTENT"
"$EWW_BIN" update shortcuts="$SHORTCUTS_CONTENT"

# Toggle the notes window
if "$EWW_BIN" active-windows 2>/dev/null | grep -qw "notes"; then
    "$EWW_BIN" close notes
else
    "$EWW_BIN" open notes
fi
