#!/data/data/com.termux/files/usr/bin/bash
#
# footer.sh — Dashboard Bottom Bar
#
# Shows context-sensitive keyboard shortcuts
# and status messages.
#
# Part of the Android Toolkit Dashboard.

FOOTER_HEIGHT=2
FOOTER_MESSAGE=""
FOOTER_MESSAGE_TTL=0
FOOTER_MESSAGE_TYPE="info"

##############################################
# Set a transient footer message.
# Arguments:
#   $1: message text
#   $2: type (info|success|warning|error)
#   $3: duration in seconds (default: 5)
footer_message() {
    FOOTER_MESSAGE="$1"
    FOOTER_MESSAGE_TYPE="${2:-info}"
    local duration="${3:-5}"
    FOOTER_MESSAGE_TTL=$(( $(date +%s) + duration ))
}

##############################################
# Render the footer bar.
# Arguments:
#   $1: current page ID (for context-sensitive keys)
footer_render() {
    local page_id="${1:-dashboard}"
    local theme_bg theme_fg
    theme_bg="$(theme_get footer_bg)"
    theme_fg="$(theme_get footer_fg)"
    local success="$(theme_get success)"
    local warning="$(theme_get warning)"
    local error="$(theme_get error)"
    local info="$(theme_get info)"

    local foot_row=$(( RENDERER_HEIGHT - FOOTER_HEIGHT + 1 ))

    # Fill footer background
    renderer_fill_rect "$foot_row" 1 "$FOOTER_HEIGHT" "$RENDERER_WIDTH" "$theme_bg"

    # Top separator
    renderer_draw_separator $(( foot_row - 1 ))

    # ── Row 1: Message area ──
    local now
    now="$(date +%s)"
    renderer_cursor_goto "$foot_row" 3
    if [[ "$now" -lt "$FOOTER_MESSAGE_TTL" && -n "$FOOTER_MESSAGE" ]]; then
        case "$FOOTER_MESSAGE_TYPE" in
            success) renderer_fg_256 "$success" ;;
            warning) renderer_fg_256 "$warning" ;;
            error)   renderer_fg_256 "$error" ;;
            *)       renderer_fg_256 "$info" ;;
        esac
        printf '%s' "$FOOTER_MESSAGE"
        renderer_reset
    fi

    # ── Row 2: Shortcuts ──
    local shortcuts_str=""
    case "$page_id" in
        dashboard)
            shortcuts_str=" ↑↓ Navigate  |  Enter Select  |  F1 Help  |  F5 Refresh  |  Q Quit"
            ;;
        devices)
            shortcuts_str=" ↑↓ Select  |  Enter Switch  |  F1 Help  |  ESC Back  |  Q Quit"
            ;;
        performance|optimization|packages|bloatware|battery|display|network|security|plugins|reports|benchmarks|validation|compatibility|logs|settings|help|about)
            shortcuts_str=" ↑↓ Navigate  |  Enter Select  |  F1 Help  |  ESC Back  |  Q Quit"
            ;;
        *)
            shortcuts_str=" F1 Help  |  ESC Back  |  Q Quit"
            ;;
    esac

    renderer_cursor_goto $(( foot_row + 1 )) 3
    renderer_fg_256 "$theme_fg"
    printf '%s' "$shortcuts_str"
    renderer_reset

    # Right side: version and theme indicator
    local right_info
    right_info="v$(status_get version) | ${THEME_NAME^}"
    renderer_cursor_goto $(( foot_row + 1 )) $(( RENDERER_WIDTH - ${#right_info} - 2 ))
    renderer_fg_256 "$theme_fg"
    renderer_dim
    printf '%s' "$right_info"
    renderer_reset
}

##############################################
# Return the number of rows consumed by footer.
footer_height() {
    echo "$(( FOOTER_HEIGHT + 1 ))"  # +1 for separator
}
