#!/data/data/com.termux/files/usr/bin/bash
#
# sidebar.sh — Navigation Sidebar
#
# Renders the left sidebar with page list.
# Supports:
#   - Active page highlighting
#   - Section grouping
#   - Scroll for many items
#   - Icon indicators
#
# Part of the Android Toolkit Dashboard.

SIDEBAR_WIDTH=22
SIDEBAR_SCROLL_OFFSET=0

# Navigation items: (id, label, icon)
# Phase 3: Enterprise ADOC sidebar
SIDEBAR_ITEMS=(
    "dashboard"      "Dashboard"      "◉"
    "multi_device"   "Multi-Device"   "🖥"
    "device_compare" "Compare"        "⇔"
    "ai_assistant"   "AI Assistant"   "✦"
    "terminal"       "Terminal"       "⌨"
    "automation"     "Automation"     "⚙"
    "diagnostics"    "Diagnostics"    "🔍"
    "perf_monitor"   "Perf Monitor"   "📈"
    "optimization"   "Optimization"   "🔧"
    "packages"       "Packages"       "📦"
    "bloatware"      "Bloatware"      "🗑"
    "battery"        "Battery"        "🔋"
    "display"        "Display"        "🖥"
    "network"        "Network"        "🌐"
    "security_center" "Security Center" "🛡"
    "plugin_center"  "Plugin Center"  "🔌"
    "enterprise_settings" "Enterprise" "⚙"
    "reports"        "Reports"        "📊"
    "benchmarks"     "Benchmarks"     "📈"
    "validation"     "Validation"     "✓"
    "compatibility"  "Compatibility"  "🔄"
    "logs"           "Logs"           "📋"
    "doc_browser"    "Documentation"  "📖"
    "audit_trail"    "Audit Trail"    "📋"
    "settings"       "Settings"       "⚙"
    "session_manager" "Session"       "⏺"
    "help"           "Help"           "❓"
    "about"          "About"          "ℹ"

    # Phase 4 — Autonomous Operations & Intelligence
    "digital_twin"   "Digital Twin"   "🧬"
    "timeline"       "Timeline"       "📅"
    "health_intel"   "Health Intel"   "💚"
    "predictive"     "Predictive"     "🔮"
    "recommendations" "Recs"         "💡"
    "fleet"          "Fleet"          "🏢"
    "policies"       "Policies"       "📜"
    "report_studio"  "Report Studio"  "📊"
    "system_map"     "System Map"     "🗺"
    "workflow_recorder" "Recorder"   "⏺"
    "recovery_center" "Recovery"     "🔄"
    "knowledge_base" "Knowledge"     "📖"
    "perf_profiler"  "Profiler"       "⏱"
    "plugin_sandbox" "Plugin Sandbox" "🔒"
    "profiles"       "Profiles"       "👤"
    "offline_mode"   "Offline"        "📡"
    "event_bus"      "Event Bus"      "📨"
)

SIDEBAR_COUNT=$(( ${#SIDEBAR_ITEMS[@]} / 3 ))

##############################################
# Get item property by index.
# Arguments:
#   $1: index
#   $2: property (0=id, 1=label, 2=icon)
sidebar_item() {
    local idx=$(( $1 * 3 + $2 ))
    echo "${SIDEBAR_ITEMS[$idx]}"
}

##############################################
# Get the index of a page ID in the sidebar.
# Arguments:
#   $1: page ID
# Outputs: index or -1
sidebar_find_index() {
    local target="$1"
    local i=0
    while (( i < SIDEBAR_COUNT )); do
        if [[ "$(sidebar_item $i 0)" == "$target" ]]; then
            echo "$i"
            return 0
        fi
        ((i++))
    done
    echo "-1"
    return 1
}

##############################################
# Render the sidebar.
# Arguments:
#   $1: active page ID
#   $2: top row to start drawing
#   $3: available height in rows
sidebar_render() {
    local active_id="$1" top_row="$2" avail_height="$3"
    local theme_bg theme_fg active_bg active_fg muted
    theme_bg="$(theme_get sidebar_bg)"
    theme_fg="$(theme_get sidebar_fg)"
    active_bg="$(theme_get sidebar_active_bg)"
    active_fg="$(theme_get sidebar_active_fg)"
    muted="$(theme_get muted)"

    # Fill sidebar background
    renderer_fill_rect "$top_row" 1 "$avail_height" "$SIDEBAR_WIDTH" "$theme_bg"

    # Draw vertical separator line on the right edge
    renderer_draw_vline "$top_row" "$SIDEBAR_WIDTH" "$avail_height"
    renderer_cursor_goto "$top_row" "$SIDEBAR_WIDTH"
    renderer_fg_256 236
    printf '%s' "$RENDERER_VLINE"
    renderer_reset

    local active_idx
    active_idx="$(sidebar_find_index "$active_id")"
    [[ "$active_idx" -eq -1 ]] && active_idx=0

    # Calculate scroll
    local visible=$(( avail_height - 1 ))
    if (( active_idx < SIDEBAR_SCROLL_OFFSET )); then
        SIDEBAR_SCROLL_OFFSET=$active_idx
    elif (( active_idx >= SIDEBAR_SCROLL_OFFSET + visible )); then
        SIDEBAR_SCROLL_OFFSET=$(( active_idx - visible + 1 ))
    fi
    [[ "$SIDEBAR_SCROLL_OFFSET" -lt 0 ]] && SIDEBAR_SCROLL_OFFSET=0

    # Draw items
    local row=$top_row
    local i=$SIDEBAR_SCROLL_OFFSET
    local drawn=0
    while (( i < SIDEBAR_COUNT && drawn < visible )); do
        local label icon is_active
        label="$(sidebar_item $i 1)"
        icon="$(sidebar_item $i 2)"
        is_active=false
        [[ "$(sidebar_item $i 0)" == "$active_id" ]] && is_active=true

        if [[ "$is_active" == "true" ]]; then
            renderer_fill_rect "$row" 1 1 $(( SIDEBAR_WIDTH - 1 )) "$active_bg"
            renderer_cursor_goto "$row" 3
            renderer_fg_256 "$active_fg"
            renderer_bold
            printf '%s' "$label"
            renderer_reset
            # Active indicator arrow
            renderer_cursor_goto "$row" $(( SIDEBAR_WIDTH - 1 ))
            renderer_fg_256 "$active_bg"
            printf '%s' "$RENDERER_ARROW_R"
            renderer_reset
        else
            renderer_cursor_goto "$row" 3
            renderer_fg_256 "$theme_fg"
            printf '%s' "$label"
            renderer_reset
        fi

        ((row++))
        ((i++))
        ((drawn++))
    done

    # Scroll indicators
    if [[ "$SIDEBAR_SCROLL_OFFSET" -gt 0 ]]; then
        renderer_cursor_goto "$top_row" $(( SIDEBAR_WIDTH - 2 ))
        renderer_fg_256 "$muted"
        printf '%s' "$RENDERER_ARROW_U"
        renderer_reset
    fi
    if (( SIDEBAR_SCROLL_OFFSET + visible < SIDEBAR_COUNT )); then
        renderer_cursor_goto $(( top_row + visible - 1 )) $(( SIDEBAR_WIDTH - 2 ))
        renderer_fg_256 "$muted"
        printf '%s' "$RENDERER_ARROW_D"
        renderer_reset
    fi
}

##############################################
# Return the sidebar width.
sidebar_width() {
    echo "$SIDEBAR_WIDTH"
}

##############################################
# Navigate up in the sidebar.
# Arguments:
#   $1: current index (by reference, updated)
#   $2: total items
sidebar_nav_up() {
    local -n _idx="$1"
    local count="$2"
    (( _idx > 0 )) && (( _idx-- )) || _idx=$(( count - 1 ))
}

##############################################
# Navigate down in the sidebar.
sidebar_nav_down() {
    local -n _idx="$1"
    local count="$2"
    (( _idx < count - 1 )) && (( _idx++ )) || _idx=0
}
