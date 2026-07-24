#!/data/data/com.termux/files/usr/bin/bash
#
# session_manager.sh — Session Manager
#
# Save and restore complete dashboard sessions:
#   - Active page and scroll position
#   - Multi-device selections
#   - Monitor data snapshots
#   - Terminal history
#   - AI conversation history
#
# Part of the Android Toolkit Dashboard.

SESSION_DIR="${ANDROID_TOOLKIT_ROOT_DIR}/sessions"
SESSION_LIST=()
SESSION_CURRENT=""

##############################################
# Initialize session directory.
session_init() {
    mkdir -p "$SESSION_DIR" 2>/dev/null || true
    session_refresh_list
}

##############################################
# Refresh session list from disk.
session_refresh_list() {
    SESSION_LIST=()
    if [[ -d "$SESSION_DIR" ]]; then
        local f
        for f in "$SESSION_DIR"/*.session; do
            [[ -f "$f" ]] && SESSION_LIST+=("$(basename "$f" .session)" "$f")
        done
    fi
}

##############################################
# Save current session.
session_save() {
    local name="${1:-}"
    [[ -z "$name" ]] && name="session_$(date +%Y%m%d_%H%M%S)"
    local file="${SESSION_DIR}/${name}.session"

    session_init
    {
        echo "# Android Toolkit Session — $(date '+%Y-%m-%d %H:%M:%S')"
        echo "SESSION_VERSION=1"
        echo "SESSION_NAME=$name"
        echo "SESSION_TIMESTAMP=$(date +%s)"
        echo ""
        echo "# Page state"
        echo "PAGE_NAME=$DASHBOARD_PAGE"
        [[ -n "$DASHBOARD_PAGE_SCROLL" ]] && echo "PAGE_SCROLL=$DASHBOARD_PAGE_SCROLL"
        echo ""
        echo "# Multi-device selections"
        echo "MULTI_DEVICES=(${SELECTED_DEVICES[*]})"
        echo ""
        echo "# Terminal history"
        local line
        for line in "${TERMINAL_HISTORY[@]}"; do
            printf '%q\n' "TERMINAL_HISTORY_ENTRY=$line"
        done
        echo ""
        echo "# AI conversation history"
        local conv_line
        if [[ -d "${ANDROID_TOOLKIT_ROOT_DIR}/tmp" ]]; then
            cat "${ANDROID_TOOLKIT_ROOT_DIR}/tmp/ai_history.txt" 2>/dev/null || true
        fi
        echo ""
        echo "# Performance data"
        echo "PERF_CPU=(${PERF_CPU_HISTORY[*]})"
        echo "PERF_MEM=(${PERF_MEM_HISTORY[*]})"
        echo "PERF_TEMP=(${PERF_TEMP_HISTORY[*]})"
        echo "# End Session"
    } > "$file"

    SESSION_CURRENT="$name"
    session_refresh_list
    notify_push "Session saved: $name" "success"
    audit_record "Session" "save" "$name" "success"
}

##############################################
# Load a saved session.
session_load() {
    local name="$1"
    local file="${SESSION_DIR}/${name}.session"
    [[ ! -f "$file" ]] && { notify_push "Session not found: $name" "error"; return 1; }

    # Source session file to load variables
    while IFS='=' read -r key val; do
        [[ -z "$key" || "$key" == "#"* ]] && continue
        case "$key" in
            PAGE_NAME)
                local new_page="$val"
                if declare -f "_page_render_${new_page}" &>/dev/null; then
                    DASHBOARD_PAGE="$new_page"
                fi
                ;;
            PAGE_SCROLL)
                DASHBOARD_PAGE_SCROLL="$val"
                ;;
            MULTI_DEVICES)
                # Parse array format: (dev1 dev2 ...)
                val="${val#\(}"
                val="${val%\)}"
                SELECTED_DEVICES=($val)
                ;;
        esac
    done < "$file"

    SESSION_CURRENT="$name"
    DASHBOARD_REDRAW_NEEDED=true
    notify_push "Session restored: $name" "success"
    audit_record "Session" "load" "$name" "success"
}

##############################################
# Delete a saved session.
session_delete() {
    local name="$1"
    local file="${SESSION_DIR}/${name}.session"
    rm -f "$file" 2>/dev/null
    [[ "$SESSION_CURRENT" == "$name" ]] && SESSION_CURRENT=""
    session_refresh_list
    notify_push "Session deleted: $name" "info"
}

##############################################
# Render session manager.
_page_render_session_manager() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Session Manager'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Save/restore dashboard state'
    renderer_reset

    session_init
    local row=$(( top + 2 ))
    local col="$left"

    # Current session indicator
    if [[ -n "$SESSION_CURRENT" ]]; then
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get success)"
        printf ' Active session: %s' "$SESSION_CURRENT"
        renderer_reset
        ((row++))
    fi

    # Quick actions
    local actions=(
        "n" "New Session"
        "s" "Save Now"
        "r" "Restore"
        "d" "Delete"
    )
    renderer_cursor_goto "$row" "$col"
    local i=0
    while (( i < ${#actions[@]} )); do
        local key="${actions[$i]}"
        local label="${actions[$((i+1))]}"
        renderer_fg_256 "$(theme_get info)"
        renderer_bold
        printf ' [%s]' "$key"
        renderer_reset
        renderer_fg_256 "$(theme_get fg)"
        printf ' %s ' "$label"
        renderer_reset
        ((i += 2))
    done
    ((row += 2))

    # Sessions list
    if [[ "${#SESSION_LIST[@]}" -eq 0 ]]; then
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get muted)"
        renderer_dim
        printf ' No saved sessions yet.'
        renderer_reset
        return
    fi

    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    printf 'Saved Sessions (%d):' $(( ${#SESSION_LIST[@]} / 2 ))
    renderer_reset
    ((row++))

    local idx=0
    while (( idx < ${#SESSION_LIST[@]} )); do
        [[ "$row" -ge $(( top + height - 1 )) ]] && break
        local sname="${SESSION_LIST[$idx]}"
        local spath="${SESSION_LIST[$((idx+1))]}"
        local active_indicator=""
        [[ "$sname" == "$SESSION_CURRENT" ]] && active_indicator=" ← active"

        local mtime
        mtime="$(stat -c '%y' "$spath" 2>/dev/null | cut -d. -f1 || echo "?")"

        renderer_cursor_goto "$row" "$col"
        if [[ "$sname" == "$SESSION_CURRENT" ]]; then
            renderer_fg_256 "$(theme_get success)"
        else
            renderer_fg_256 "$(theme_get fg)"
        fi
        printf ' %s' "$sname"
        renderer_fg_256 "$(theme_get muted)"
        printf '  (%s)%s' "$mtime" "$active_indicator"
        renderer_reset
        ((row++))
        ((idx += 2))
    done
}

_page_key_session_manager() {
    local key="$1"
    case "$key" in
        "n"|"N")
            local name
            name="$(menu_input "New Session" "Session name (leave empty for auto):")" || return 0
            session_save "$name"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "s"|"S")
            if [[ -n "$SESSION_CURRENT" ]]; then
                session_save "$SESSION_CURRENT"
            else
                session_save ""
            fi
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "r"|"R")
            if [[ "${#SESSION_LIST[@]}" -eq 0 ]]; then
                notify_push "No sessions to restore" "warning"
                DASHBOARD_REDRAW_NEEDED=true
                return 0
            fi
            local menu_items=()
            local idx=0
            while (( idx < ${#SESSION_LIST[@]} )); do
                menu_items+=("${SESSION_LIST[$idx]}" "${SESSION_LIST[$idx]}")
                ((idx += 2))
            done
            local choice
            choice="$(menu_select "Restore Session" "${menu_items[@]}")" || return 0
            session_load "$choice"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "d"|"D")
            if [[ "${#SESSION_LIST[@]}" -eq 0 ]]; then
                notify_push "No sessions to delete" "warning"
                DASHBOARD_REDRAW_NEEDED=true
                return 0
            fi
            local menu_items=()
            local idx=0
            while (( idx < ${#SESSION_LIST[@]} )); do
                menu_items+=("${SESSION_LIST[$idx]}" "${SESSION_LIST[$idx]}")
                ((idx += 2))
            done
            local choice
            choice="$(menu_select "Delete Session" "${menu_items[@]}")" || return 0
            if menu_yesno "Delete" "Delete session '$choice'?"; then
                session_delete "$choice"
            fi
            DASHBOARD_REDRAW_NEEDED=true
            ;;
    esac
}
