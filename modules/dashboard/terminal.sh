#!/data/data/com.termux/files/usr/bin/bash
#
# terminal.sh — Embedded Terminal Console
#
# Managed terminal with command history, output filtering,
# session logging, and safe execution warnings.
#
# Part of the Android Toolkit Dashboard.

TERMINAL_HISTORY=()
TERMINAL_HISTORY_MAX=100
TERMINAL_HISTORY_IDX=-1
TERMINAL_OUTPUT=""
TERMINAL_LOG=""
TERMINAL_SAFE_MODE=true

##############################################
# Execute a command in the managed terminal.
terminal_exec() {
    local cmd="$1"
    # Safety check for dangerous commands
    if [[ "$TERMINAL_SAFE_MODE" == "true" ]]; then
        local dangerous=("reboot" "recovery" "format" "wipe" "rm -rf" "dd if=" "mkfs" "flash")
        local d
        for d in "${dangerous[@]}"; do
            if echo "$cmd" | grep -qi "$d"; then
                menu_confirm "Warning" "Command may be dangerous: $cmd\n\nContinue?" || return 0
                break
            fi
        done
    fi

    TERMINAL_HISTORY+=("$cmd")
    [[ "${#TERMINAL_HISTORY[@]}" -gt "$TERMINAL_HISTORY_MAX" ]] && TERMINAL_HISTORY=("${TERMINAL_HISTORY[@]:1}")
    TERMINAL_HISTORY_IDX="${#TERMINAL_HISTORY[@]}"

    local output
    output="$(eval "$cmd" 2>&1)" || true
    TERMINAL_OUTPUT="$output"
    TERMINAL_LOG+="$ $(date +%H:%M:%S) $cmd"$'\n'"$output"$'\n'

    # Record in audit trail
    audit_record "Terminal" "exec" "$cmd" "$([[ $? -eq 0 ]] && echo 'success' || echo 'failed')"
}

##############################################
# Render terminal console.
_page_render_terminal() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Terminal Console'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Managed shell (safe: %s)' "$([[ "$TERMINAL_SAFE_MODE" == "true" ]] && echo "ON" || echo "OFF")"
    renderer_reset

    local prompt_row=$(( top + 2 ))
    local output_start=$(( top + 3 ))
    local output_height=$(( height - 4 ))

    # Output area in bordered box
    renderer_draw_box "$output_start" "$left" "$output_height" "$width" "Output"
    local content_row=$(( output_start + 1 ))
    local content_col=$(( left + 2 ))

    if [[ -n "$TERMINAL_OUTPUT" ]]; then
        local line_count=0
        while IFS= read -r line; do
            renderer_cursor_goto "$content_row" "$content_col"
            renderer_fg_256 "$(theme_get fg)"
            # Highlight errors in red
            if echo "$line" | grep -qi "error\|failed\|denied\|not found"; then
                renderer_fg_256 "$(theme_get error)"
            elif echo "$line" | grep -qi "warning\|warn"; then
                renderer_fg_256 "$(theme_get warning)"
            fi
            printf '%-*s' "$((width - 4))" "${line:0:$((width-4))}"
            renderer_reset
            ((content_row++))
            ((line_count++))
            [[ "$line_count" -ge "$output_height" ]] && break
        done <<< "$TERMINAL_OUTPUT"
    else
        renderer_cursor_goto "$content_row" "$content_col"
        renderer_fg_256 "$(theme_get muted)"
        printf 'Type a command below and press Enter to execute.'
        renderer_reset
    fi

    # Command prompt
    renderer_cursor_goto "$prompt_row" "$left"
    renderer_fg_256 "$(theme_get success)"
    printf '$'
    renderer_reset
    renderer_fg_256 "$(theme_get fg)"
    printf ' '
    renderer_reset

    # Shortcuts
    renderer_cursor_goto "$prompt_row" $(( left + 30 ))
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    printf 'Enter: Run  |  ↑↓: History  |  C: Clear  |  S: Safe mode toggle'
    renderer_reset
}

_page_key_terminal() {
    local key="$1"
    case "$key" in
        "$KEY_UP")
            if [[ "$TERMINAL_HISTORY_IDX" -gt 0 ]]; then
                ((TERMINAL_HISTORY_IDX--))
                notify_push "History: ${TERMINAL_HISTORY[$TERMINAL_HISTORY_IDX]}" "info"
            fi
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "$KEY_DOWN")
            if [[ "$TERMINAL_HISTORY_IDX" -lt "$(( ${#TERMINAL_HISTORY[@]} - 1 ))" ]]; then
                ((TERMINAL_HISTORY_IDX++))
                notify_push "History: ${TERMINAL_HISTORY[$TERMINAL_HISTORY_IDX]}" "info"
            fi
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "$KEY_ENTER")
            local cmd
            cmd="$(menu_input "Terminal" "Command:")" || return 0
            [[ -z "$cmd" ]] && return 0
            terminal_exec "$cmd"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "c"|"C")
            TERMINAL_OUTPUT=""
            DASHBOARD_REDRAW_NEEDED=true
            notify_push "Output cleared" "info"
            ;;
        "s"|"S")
            if [[ "$TERMINAL_SAFE_MODE" == "true" ]]; then
                TERMINAL_SAFE_MODE=false
                notify_push "Safe mode OFF — dangerous commands allowed" "warning"
            else
                TERMINAL_SAFE_MODE=true
                notify_push "Safe mode ON" "success"
            fi
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "l"|"L")
            menu_textbox "Session Log" "$TERMINAL_LOG"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
    esac
}
