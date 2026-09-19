#!/usr/bin/env bash

#THIS IS AWWW SCRIPT

# ==============================================================================
# CONFIGURATION & PATHS
# ==============================================================================
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

# State file to remember sequential wallpaper index
STATE_NORMAL="/tmp/awww_normal_index"

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================
get_wallpaper() {
    local dir="$1"
    local state_file="$2"
    local direction="$3" # "next" or "prev"

    mapfile -t files < <(find "$dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.webp" \) | sort)

    local total=${#files[@]}
    if [ "$total" -eq 0 ]; then
        return
    fi

    local index=0
    if [ -f "$state_file" ]; then
        index=$(cat "$state_file")
    fi

    # Ensure index is within safe bounds
    if [ "$index" -ge "$total" ] || [ "$index" -lt 0 ]; then
        index=0
    fi

    if [ "$direction" = "prev" ]; then
        # To go backward, we need the wallpaper *before* the current state index.
        # If state index is 2, the previous wallpaper is at index 1.
        # We subtract 2 from state index to land on the correct previous item.
        local target_index=$(( (index - 2 + total) % total ))
        echo "${files[$target_index]}"

        # The next normal click should advance from this newly shown previous wallpaper
        echo "$(( (target_index + 1) % total ))" > "$state_file"
    else
        # Standard "next" behavior
        echo "${files[$index]}"

        # Advance state for the following click
        echo "$(( (index + 1) % total ))" > "$state_file"
    fi
}

# ==============================================================================
# MAIN LOGIC
# ==============================================================================
if [ "$1" = "special" ]; then
    # Settings for Right-Click (Previous Wallpaper)
    TRANSITION_TYPE="outer"
    TRANSITION_STEP=90
    TRANSITION_FPS=60
    TRANSITION_DURATION="1"

    SELECTED_WALLPAPER=$(get_wallpaper "$WALLPAPER_DIR" "$STATE_NORMAL" "prev")
else
    # Settings for Left-Click (Next Wallpaper)
    TRANSITION_TYPE="center"
    TRANSITION_STEP=90
    TRANSITION_FPS=60
    TRANSITION_DURATION="1"

    SELECTED_WALLPAPER=$(get_wallpaper "$WALLPAPER_DIR" "$STATE_NORMAL" "next")
fi

# ==============================================================================
# EXECUTION
# ==============================================================================
if [ -n "$SELECTED_WALLPAPER" ]; then
    awww img "$SELECTED_WALLPAPER" \
        --transition-type "$TRANSITION_TYPE" \
        --transition-step "$TRANSITION_STEP" \
        --transition-duration "$TRANSITION_DURATION" \
        --transition-fps "$TRANSITION_FPS"
else
    echo "Error: No valid wallpaper image found!"
fi
