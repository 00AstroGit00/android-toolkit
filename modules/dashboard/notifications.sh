#!/data/data/com.termux/files/usr/bin/bash
#
# notifications.sh — Toast Notification System
#
# Provides transient notification popups:
#   - Stack up to 5 notifications
#   - Auto-dismiss after timeout
#   - Color-coded by type (success, warning, error, info, progress)
#   - Drawn in the top-right corner
#
# Part of the Android Toolkit Dashboard.

NOTIFY_MAX=5
NOTIFY_STACK=()
NOTIFY_IDS=()
NOTIFY_TYPES=()
NOTIFY_TIMESTAMPS=()
NOTIFY_NEXT_ID=0

##############################################
# Push a notification.
# Arguments:
#   $1: message
#   $2: type (info|success|warning|error|progress)
#   $3: duration in seconds (default: 4)
notify_push() {
    local msg="$1" type="${2:-info}" duration="${3:-4}"
    local id=$(( NOTIFY_NEXT_ID++ ))
    local now
    now="$(date +%s)"

    NOTIFY_STACK+=("$msg")
    NOTIFY_TYPES+=("$type")
    NOTIFY_IDS+=("$id")
    NOTIFY_TIMESTAMPS+=("$(( now + duration ))")

    # Trim old notifications
    while [[ "${#NOTIFY_STACK[@]}" -gt "$NOTIFY_MAX" ]]; do
        NOTIFY_STACK=("${NOTIFY_STACK[@]:1}")
        NOTIFY_TYPES=("${NOTIFY_TYPES[@]:1}")
        NOTIFY_IDS=("${NOTIFY_IDS[@]:1}")
        NOTIFY_TIMESTAMPS=("${NOTIFY_TIMESTAMPS[@]:1}")
    done

    # Trigger redraw
    renderer_refresh
}

##############################################
# Render active notifications in top-right corner.
notify_render() {
    local now
    now="$(date +%s)"
    local i=0
    local row=3  # Below header
    local col=$(( RENDERER_WIDTH - 40 ))
    [[ "$col" -lt 1 ]] && col=1
    local max_width=38

    while (( i < ${#NOTIFY_STACK[@]} )); do
        if (( now > NOTIFY_TIMESTAMPS[i] )); then
            # Expired — remove
            NOTIFY_STACK=("${NOTIFY_STACK[@]:0:i}" "${NOTIFY_STACK[@]:i+1}")
            NOTIFY_TYPES=("${NOTIFY_TYPES[@]:0:i}" "${NOTIFY_TYPES[@]:i+1}")
            NOTIFY_IDS=("${NOTIFY_IDS[@]:0:i}" "${NOTIFY_IDS[@]:i+1}")
            NOTIFY_TIMESTAMPS=("${NOTIFY_TIMESTAMPS[@]:0:i}" "${NOTIFY_TIMESTAMPS[@]:i+1}")
            continue
        fi

        local msg="${NOTIFY_STACK[i]}"
        local type="${NOTIFY_TYPES[i]}"
        local color icon

        case "$type" in
            success) color="$(theme_get success)"; icon="$RENDERER_CHECK" ;;
            warning) color="$(theme_get warning)"; icon="!" ;;
            error)   color="$(theme_get error)";   icon="$RENDERER_CROSS_MARK" ;;
            progress) color="$(theme_get info)";   icon="⟳" ;;
            *)       color="$(theme_get info)";    icon="$RENDERER_BULLET" ;;
        esac

        # Truncate message
        local display="${msg:0:max_width}"

        # Clear line area
        renderer_cursor_goto "$row" "$col"
        renderer_fill_rect "$row" "$col" 1 "$max_width"

        # Draw notification
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$color"
        printf ' %s %s' "$icon" "$display"
        renderer_reset

        ((row++))
        ((i++))
    done
}

##############################################
# Clear all notifications immediately.
notify_clear_all() {
    NOTIFY_STACK=()
    NOTIFY_TYPES=()
    NOTIFY_IDS=()
    NOTIFY_TIMESTAMPS=()
    renderer_refresh
}
