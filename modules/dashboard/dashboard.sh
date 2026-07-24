#!/data/data/com.termux/files/usr/bin/bash
#
# dashboard.sh — Interactive Dashboard Main Controller
#
# Full-screen terminal dashboard with live device monitoring,
# categorized navigation, and instant access to all toolkit actions.
#
# Architecture:
#   dashboard.sh      — Entry point, event loop, page routing
#   renderer.sh       — Low-level ANSI rendering
#   themes.sh         — Color scheme management
#   status.sh         — Device data collection
#   header.sh         — Top status bar
#   sidebar.sh        — Left navigation
#   footer.sh         — Bottom shortcut bar
#   widgets.sh        — Home dashboard widgets
#   menus.sh          — Dialog/confirmation menus
#   notifications.sh  — Toast notifications
#   shortcuts.sh      — Keyboard input handling
#
# Part of the Android Toolkit Dashboard.

DASHBOARD_ACTIVE=true
DASHBOARD_CURRENT_PAGE="dashboard"
DASHBOARD_PREV_PAGE=""
DASHBOARD_SIDEBAR_IDX=0
DASHBOARD_REDRAW_NEEDED=true
DASHBOARD_RUNNING=true

# ──────────────────────────────────────────────
# PAGE HANDLER REGISTRY
# ──────────────────────────────────────────────
# Each page registers a render function and a key handler.
# Format: dashboard_pages["page_id"]="render_func|key_handler_func"
declare -A DASHBOARD_PAGES=()

##############################################
# Register a page handler.
# Arguments:
#   $1: page ID
#   $2: render function name
#   $3: key handler function name (optional)
dashboard_register_page() {
    DASHBOARD_PAGES["$1"]="$2|${3:-}"
}

##############################################
# Navigate to a page.
# Arguments:
#   $1: page ID
dashboard_navigate() {
    local target="$1"
    [[ "$target" == "$DASHBOARD_CURRENT_PAGE" ]] && return
    DASHBOARD_PREV_PAGE="$DASHBOARD_CURRENT_PAGE"
    DASHBOARD_CURRENT_PAGE="$target"
    DASHBOARD_REDRAW_NEEDED=true

    # Update sidebar index
    local idx
    idx="$(sidebar_find_index "$target")"
    [[ "$idx" -ge 0 ]] && DASHBOARD_SIDEBAR_IDX=$idx
}

##############################################
# Go back to previous page.
dashboard_go_back() {
    if [[ -n "$DASHBOARD_PREV_PAGE" ]]; then
        local prev="$DASHBOARD_PREV_PAGE"
        DASHBOARD_PREV_PAGE="$DASHBOARD_CURRENT_PAGE"
        DASHBOARD_CURRENT_PAGE="$prev"
        DASHBOARD_REDRAW_NEEDED=true
    fi
}

# ──────────────────────────────────────────────
# FULL REDRAW
# ──────────────────────────────────────────────

##############################################
# Full screen redraw — called on every render cycle.
_dashboard_redraw() {
    # Clear screen
    renderer_hide_cursor
    renderer_clear_screen

    # Layout dimensions
    local header_h
    header_h="$(header_height)"
    local sidebar_w
    sidebar_w="$(sidebar_width)"
    local footer_h
    footer_h="$(footer_height)"
    local content_top=$(( header_h + 1 ))
    local content_height=$(( RENDERER_HEIGHT - header_h - footer_h - 2 ))

    # Render persistent chrome
    header_render
    sidebar_render "$DASHBOARD_CURRENT_PAGE" "$content_top" "$content_height"

    # Render page content (right of sidebar)
    local content_left=$(( sidebar_w + 1 ))
    local content_width=$(( RENDERER_WIDTH - sidebar_w - 1 ))

    # Fill content area background
    renderer_fill_rect "$content_top" "$content_left" "$content_height" "$content_width" "$(theme_get bg)"

    # Check if page has a registered render function
    local page_entry="${DASHBOARD_PAGES[$DASHBOARD_CURRENT_PAGE]:-}"
    if [[ -n "$page_entry" ]]; then
        local render_func="${page_entry%%|*}"
        if typeset -f "$render_func" &>/dev/null; then
            # Calculate content area (with padding)
            local pad_top=$(( content_top + 1 ))
            local pad_left=$(( content_left + 2 ))
            local pad_width=$(( content_width - 4 ))
            local pad_height=$(( content_height - 2 ))
            "$render_func" "$pad_top" "$pad_left" "$pad_width" "$pad_height"
        fi
    fi

    # Render notifications (top-right, over content)
    notify_render

    # Render footer
    footer_render "$DASHBOARD_CURRENT_PAGE"

    DASHBOARD_REDRAW_NEEDED=false
}

# ──────────────────────────────────────────────
# GENERIC KEY HANDLER
# ──────────────────────────────────────────────

##############################################
# Handle a keypress — dispatches to page handler
# or handles global shortcuts.
# Arguments:
#   $1: key sequence
# Returns: 0 to continue, 1 to exit
_dashboard_handle_key() {
    local key="$1"

    # Global shortcuts (always active)
    case "$key" in
        "$KEY_Q"|"$KEY_CTRL_C")
            dashboard_confirm_quit
            return $?
            ;;
        "$KEY_F1")
            dashboard_navigate "help"
            return 0
            ;;
        "$KEY_F5"|"$KEY_CTRL_R")
            status_refresh
            DASHBOARD_REDRAW_NEEDED=true
            return 0
            ;;
        "$KEY_CTRL_L")
            DASHBOARD_REDRAW_NEEDED=true
            return 0
            ;;
        "$KEY_TAB")
            # Next page in sidebar
            sidebar_nav_down DASHBOARD_SIDEBAR_IDX "$SIDEBAR_COUNT"
            local pid
            pid="$(sidebar_item "$DASHBOARD_SIDEBAR_IDX" 0)"
            dashboard_navigate "$pid"
            return 0
            ;;
        "$KEY_ESC")
            # Escape at home page asks to quit, otherwise go back
            if [[ "$DASHBOARD_CURRENT_PAGE" == "dashboard" ]]; then
                dashboard_confirm_quit
                return $?
            else
                dashboard_go_back
                return 0
            fi
            ;;
    esac

    # Page-specific handler
    local page_entry="${DASHBOARD_PAGES[$DASHBOARD_CURRENT_PAGE]:-}"
    if [[ -n "$page_entry" ]]; then
        local handler="${page_entry#*|}"
        if [[ -n "$handler" ]] && typeset -f "$handler" &>/dev/null; then
            "$handler" "$key"
            return $?
        fi
    fi

    return 0
}

##############################################
# Confirm quit dialog.
dashboard_confirm_quit() {
    if menu_confirm "\\Z1Quit\\Zn" "Exit the Android Toolkit Dashboard?"; then
        DASHBOARD_RUNNING=false
        return 1
    fi
    return 0
}

# ──────────────────────────────────────────────
# MAIN EVENT LOOP
# ──────────────────────────────────────────────

##############################################
# Main event loop — reads keys and updates display.
dashboard_event_loop() {
    # Initial render
    status_refresh
    _dashboard_redraw

    local last_refresh=0
    local refresh_interval=3

    while "$DASHBOARD_RUNNING"; do
        # Periodic auto-refresh
        local now
        now="$(date +%s)"
        if (( now - last_refresh >= refresh_interval )); then
            status_refresh
            DASHBOARD_REDRAW_NEEDED=true
            last_refresh=$now
        fi

        # Redraw if needed
        if [[ "$DASHBOARD_REDRAW_NEEDED" == "true" ]]; then
            _dashboard_redraw
        fi

        # Read a keypress (with timeout for refresh)
        local key
        key="$(shortcuts_read_key 2>/dev/null)"

        if [[ -n "$key" ]]; then
            _dashboard_handle_key "$key" || break
        fi
    done
}

# ──────────────────────────────────────────────
# PAGE RENDERERS
# ──────────────────────────────────────────────

##############################################
# Home Dashboard — shows live widget grid.
_page_render_dashboard() {
    local top="$1" left="$2" width="$3" height="$4"

    # Title
    renderer_cursor_goto "$top" "$left"
    renderer_fg_256 "$(theme_get accent)"
    renderer_bold
    printf 'Dashboard'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Live Device Overview'
    renderer_reset

    # Layout: 3 columns of widgets
    local card_w=$(( (width - 4) / 3 ))
    local card_w2=$(( (width - 4) / 3 ))
    local card_w3=$(( width - 4 - card_w - card_w2 - 2 ))
    local row1=$(( top + 2 ))
    local row2=$(( row1 + 6 ))

    # Row 1
    widget_device_info "$row1" "$left" "$card_w"
    local col2=$(( left + card_w + 1 ))
    widget_battery "$row1" "$col2" "$card_w2"
    local col3=$(( col2 + card_w2 + 1 ))
    widget_memory "$row1" "$col3" "$card_w3"

    # Row 2
    widget_storage "$row2" "$left" "$card_w"
    widget_cpu "$row2" "$col2" "$card_w2"
    widget_network "$row2" "$col3" "$card_w3"

    # Row 3: temperature + security + version
    local row3=$(( row2 + 6 ))
    widget_temperature "$row3" "$left" "$card_w"
    widget_security "$row3" "$col2" "$card_w2"
    widget_version "$row3" "$col3" "$card_w3"

    # Recent activity / quick actions below
    local row4=$(( row3 + 6 ))
    local act_height=$(( height - (row4 - top) ))
    [[ "$act_height" -lt 4 ]] && act_height=4
    widget_recent_activity "$row4" "$left" "$width" "$act_height"
}

# ──────────────────────────────────────────────
# GENERIC TEXT PAGE RENDERER
# ──────────────────────────────────────────────

##############################################
# Render a page that shows the output of a command.
# Arguments:
#   $1: page title
#   $2: command to run (captures output)
_page_render_command_output() {
    local top="$1" left="$2" width="$3" height="$4"
    local title="$5" cmd="$6"

    renderer_cursor_goto "$top" "$left"
    renderer_fg_256 "$(theme_get accent)"
    renderer_bold
    printf '%s' "$title"
    renderer_reset

    local output
    output="$(eval "$cmd" 2>&1 | head -$(( height - 2 )))"

    local row=$(( top + 2 ))
    while IFS= read -r line; do
        renderer_cursor_goto "$row" "$left"
        renderer_fg_256 "$(theme_get fg)"
        printf '%-*s' "$width" "${line:0:width}"
        renderer_reset
        ((row++))
    done <<< "$output"
}

# ──────────────────────────────────────────────
# INITIALIZATION
# ──────────────────────────────────────────────

##############################################
# Initialize and start the dashboard.
dashboard_run() {
    # Initialize subsystems
    renderer_init
    menu_detect
    theme_load "${THEME_NAME:-dark}"

    # Register all page handlers
    dashboard_register_all_pages

    # Set backtitle for dialog menus
    TUI_BACKTITLE="Android Toolkit v$(status_get version) | $(status_get model)"

    # Enter alternate screen
    renderer_enter_alt_screen

    # Trap cleanup on exit
    trap 'renderer_cleanup; exit 0' EXIT INT TERM HUP

    # Start event loop
    dashboard_event_loop

    # Cleanup
    renderer_cleanup
    trap - EXIT INT TERM HUP
}
