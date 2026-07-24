#!/data/data/com.termux/files/usr/bin/bash
#
# offline_mode.sh — Offline Mode
#
# Provides graceful operation without network access.
# Supports cached documentation, reports, device profiles,
# deferred synchronization, and offline notifications.
#
# Part of the Android Toolkit Dashboard.

OFFLINE_MODE=false
OFFLINE_CACHE_DIR="${ANDROID_TOOLKIT_ROOT_DIR}/cache"
OFFLINE_PENDING_SYNC=()

##############################################
# Initialize offline mode.
offline_init() {
    mkdir -p "$OFFLINE_CACHE_DIR" 2>/dev/null || true
    mkdir -p "${OFFLINE_CACHE_DIR}/docs" 2>/dev/null || true
    mkdir -p "${OFFLINE_CACHE_DIR}/reports" 2>/dev/null || true
    mkdir -p "${OFFLINE_CACHE_DIR}/twins" 2>/dev/null || true
}

##############################################
# Check if network is available.
offline_check_network() {
    if command -v ping &>/dev/null; then
        ping -c 1 -W 2 8.8.8.8 &>/dev/null && return 0
    fi
    # Fallback: check if we have any network interface
    if command -v ip &>/dev/null; then
        ip route show default &>/dev/null && return 0
    fi
    return 1
}

##############################################
# Toggle offline mode.
offline_toggle() {
    if $OFFLINE_MODE; then
        # Try to come online
        if offline_check_network; then
            OFFLINE_MODE=false
            offline_sync
            notify_push "Online mode restored" "success"
        else
            notify_push "No network available — staying offline" "warning"
        fi
    else
        if offline_check_network; then
            if menu_yesno "Offline Mode" "Network is available. Switch to offline anyway?"; then
                OFFLINE_MODE=true
                notify_push "Offline mode enabled" "info"
            fi
        else
            OFFLINE_MODE=true
            notify_push "No network detected — offline mode activated" "info"
        fi
    fi
}

##############################################
# Cache documentation for offline use.
offline_cache_docs() {
    local docs_dir="${ANDROID_TOOLKIT_ROOT_DIR}/docs"
    local cache_dir="${OFFLINE_CACHE_DIR}/docs"
    if [[ -d "$docs_dir" ]]; then
        cp -r "$docs_dir"/*.md "$cache_dir"/ 2>/dev/null || true
        echo "$(ls "$docs_dir"/*.md 2>/dev/null | wc -l) docs cached"
    fi
}

##############################################
# Defer an action for later synchronization.
offline_defer() {
    local action="$1" detail="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    OFFLINE_PENDING_SYNC+=("$timestamp|$action|$detail")
    local sync_file="${OFFLINE_CACHE_DIR}/pending_sync.log"
    echo "$timestamp|$action|$detail" >> "$sync_file" 2>/dev/null || true
}

##############################################
# Synchronize pending offline actions.
offline_sync() {
    if $OFFLINE_MODE || ! offline_check_network; then
        notify_push "Cannot sync: offline" "warning"
        return 1
    fi
    local count="${#OFFLINE_PENDING_SYNC[@]}"
    if [[ "$count" -eq 0 ]]; then
        notify_push "Nothing to sync" "info"
        return 0
    fi
    local entry
    for entry in "${OFFLINE_PENDING_SYNC[@]}"; do
        local action="${entry#*|*|}"
        event_bus_emit "system" "offline_sync" "$action" "info"
    done
    OFFLINE_PENDING_SYNC=()
    > "${OFFLINE_CACHE_DIR}/pending_sync.log" 2>/dev/null || true
    notify_push "$count actions synchronized" "success"
    timeline_record "configuration_change" "Offline sync" "$count actions" "success"
}

##############################################
# Render offline mode page.
_page_render_offline_mode() {
    local top="$1" left="$2" width="$3" height="$4"
    offline_init

    local is_online
    offline_check_network && is_online=true || is_online=false

    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Offline Mode'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Graceful offline operation'
    renderer_reset

    local row=$(( top + 2 ))
    local col="$left"

    # Network status
    renderer_cursor_goto "$row" "$col"
    if $is_online; then
        renderer_fg_256 "$(theme_get success)"
        printf ' ● Network: Connected'
    else
        renderer_fg_256 "$(theme_get error)"
        printf ' ■ Network: Disconnected'
    fi
    renderer_reset

    if $OFFLINE_MODE; then
        renderer_fg_256 "$(theme_get warning)"
        printf '  (Offline Mode: ON)'
    fi
    renderer_reset
    ((row++))

    # Actions
    local actions=()
    if $OFFLINE_MODE; then
        actions+=("t" "Go Online" "c" "Cache Docs" "s" "Sync Pending")
    else
        actions+=("t" "Go Offline" "c" "Cache Docs")
    fi
    renderer_cursor_goto "$row" "$col"
    local i=0
    while (( i < ${#actions[@]} )); do
        renderer_fg_256 "$(theme_get info)"
        renderer_bold
        printf ' [%s]' "${actions[$i]}"
        renderer_reset
        renderer_fg_256 "$(theme_get fg)"
        printf ' %s ' "${actions[$((i+1))]}"
        renderer_reset
        ((i += 2))
    done
    ((row += 2))

    # Status section
    renderer_cursor_goto "$row" "$col"
    renderer_bold
    renderer_fg_256 "$(theme_get info)"
    printf 'Offline Status'
    renderer_reset
    ((row++))

    local docs_count
    docs_count="$(ls "${OFFLINE_CACHE_DIR}/docs"/*.md 2>/dev/null | wc -l || echo "0")"
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get fg)"
    printf '  Docs cached: %d' "$docs_count"
    renderer_reset
    ((row++))

    local pending_count="${#OFFLINE_PENDING_SYNC[@]}"
    if [[ -f "${OFFLINE_CACHE_DIR}/pending_sync.log" ]]; then
        pending_count="$(wc -l < "${OFFLINE_CACHE_DIR}/pending_sync.log" 2>/dev/null || echo "0")"
    fi
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get fg)"
    printf '  Pending sync: %d items' "$pending_count"
    renderer_reset
    ((row++))

    local cache_size
    cache_size="$(du -sh "$OFFLINE_CACHE_DIR" 2>/dev/null | cut -f1 || echo "0B")"
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get fg)"
    printf '  Cache size: %s' "$cache_size"
    renderer_reset
    ((row += 2))

    # Info text
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    printf 'Offline mode caches docs, reports, and device profiles.'
    renderer_reset
    ((row++))
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    printf 'Actions are deferred and synchronized when online.'
    renderer_reset
}

_page_key_offline_mode() {
    local key="$1"
    case "$key" in
        "t"|"T")
            offline_toggle
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "c"|"C")
            local result
            result="$(offline_cache_docs)"
            notify_push "$result" "success"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "s"|"S")
            offline_sync
            DASHBOARD_REDRAW_NEEDED=true
            ;;
    esac
}
