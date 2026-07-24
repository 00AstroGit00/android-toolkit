#!/data/data/com.termux/files/usr/bin/bash
#
# event_bus.sh — Advanced Event Bus
#
# Centralized event stream for inter-module communication.
# Tracks all dashboard/device/plugin/automation/report/security events
# with subscription support for internal modules.
#
# Part of the Android Toolkit Dashboard.

declare -gA EVENT_BUS_SUBSCRIBERS=()
declare -ga EVENT_BUS_STREAM=()
EVENT_BUS_MAX=1000
EVENT_BUS_ID=0

##############################################
# Initialize the event bus.
event_bus_init() {
    EVENT_BUS_SUBSCRIBERS=()
    EVENT_BUS_STREAM=()
    EVENT_BUS_ID=0
}

##############################################
# Emit an event to the bus.
# Arguments:
#   $1: category (navigation|device|plugin|automation|report|recovery|security|system)
#   $2: action name
#   $3: detail string (optional)
#   $4: severity (info|success|warning|error) (optional, default: info)
# Returns: event_id
event_bus_emit() {
    local category="$1" action="$2" detail="${3:-}" severity="${4:-info}"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local event_id=$(( EVENT_BUS_ID++ ))
    local entry="[${timestamp}] [${category}] ${action}"
    [[ -n "$detail" ]] && entry+=" — ${detail}"
    entry+=" [${severity}]"
    EVENT_BUS_STREAM+=("$event_id|$timestamp|$category|$action|$detail|$severity")
    # Trim
    while [[ "${#EVENT_BUS_STREAM[@]}" -gt "$EVENT_BUS_MAX" ]]; do
        EVENT_BUS_STREAM=("${EVENT_BUS_STREAM[@]:1}")
    done
    # Notify subscribers
    local key pat sub
    for key in "${!EVENT_BUS_SUBSCRIBERS[@]}"; do
        pat="${key%%|*}"
        sub="${key#*|}"
        if [[ "$category" == "$pat" || "$pat" == "*" ]]; then
            typeset -f "$sub" &>/dev/null && "$sub" "$category" "$action" "$detail" "$severity" "$event_id"
        fi
    done
    # Also record to audit trail
    typeset -f audit_record &>/dev/null && audit_record "EventBus:${category}" "$action" "$detail" "$severity"
    echo "$event_id"
}

##############################################
# Subscribe to events.
# Arguments:
#   $1: category pattern (* for all)
#   $2: callback function name
event_bus_subscribe() {
    local pattern="$1" callback="$2"
    EVENT_BUS_SUBSCRIBERS["${pattern}|${callback}"]=1
}

##############################################
# Unsubscribe from events.
event_bus_unsubscribe() {
    local pattern="$1" callback="$2"
    unset EVENT_BUS_SUBSCRIBERS["${pattern}|${callback}"]
}

##############################################
# Query events from the stream.
# Arguments:
#   $1: category filter (optional)
#   $2: severity filter (optional)
#   $3: max results (optional, default: 50)
event_bus_query() {
    local cat_filter="${1:-}" sev_filter="${2:-}" max="${3:-50}"
    local count=0
    local entry
    # Iterate in reverse (most recent first)
    local i
    for (( i = ${#EVENT_BUS_STREAM[@]} - 1; i >= 0; i-- )); do
        entry="${EVENT_BUS_STREAM[$i]}"
        [[ -n "$cat_filter" && "$entry" != *"|${cat_filter}|"* ]] && continue
        [[ -n "$sev_filter" && "$entry" != *"|${sev_filter}" ]] && continue
        echo "$entry"
        ((count++))
        [[ "$count" -ge "$max" ]] && break
    done
}

##############################################
# Get event stream statistics.
event_bus_stats() {
    local total="${#EVENT_BUS_STREAM[@]}"
    local cats sevs
    cats="$(event_bus_query "" "" 9999 | awk -F'|' '{print $3}' | sort | uniq -c | sort -rn | head -10)"
    sevs="$(event_bus_query "" "" 9999 | awk -F'|' '{print $6}' | sort | uniq -c | sort -rn)"
    echo "total=$total"
    echo "categories:"
    echo "$cats" | while read -r line; do echo "  $line"; done
    echo "severities:"
    echo "$sevs" | while read -r line; do echo "  $line"; done
}

##############################################
# Clear the event stream.
event_bus_clear() {
    EVENT_BUS_STREAM=()
    notify_push "Event stream cleared" "info"
}

##############################################
# Render event bus page.
_page_render_event_bus() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Advanced Event Bus'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — %d events recorded' "${#EVENT_BUS_STREAM[@]}"
    renderer_reset

    local row=$(( top + 2 ))
    local col="$left"

    # Stats summary
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    printf 'Stream: %d events  |  Max: %d  |  ID: %d' "${#EVENT_BUS_STREAM[@]}" "$EVENT_BUS_MAX" "$EVENT_BUS_ID"
    renderer_reset
    ((row++))

    # Quick actions
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get info)"
    renderer_bold
    printf ' [c] Clear  [s] Stats  [1-5] Filter category'
    renderer_reset
    ((row += 2))

    # Category filter buttons
    local cats=("navigation" "device" "plugin" "automation" "report" "recovery" "security" "system")
    local ci=0
    for cat in "${cats[@]}"; do
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get info)"
        renderer_bold
        printf ' [%d] %s' $((ci+1)) "$cat"
        renderer_reset
        ((row++))
        ((ci++))
    done

    # Recent events
    ((row++))
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    printf 'Recent events (last %d):' $(( height - row + top - 2 ))
    renderer_reset
    ((row++))

    local max_rows=$(( top + height - row - 1 ))
    local events
    events="$(event_bus_query "" "" "$max_rows")"
    while IFS= read -r line; do
        [[ "$row" -ge $(( top + height - 1 )) ]] && break
        renderer_cursor_goto "$row" "$col"
        local sev="${line##*|}"
        case "$sev" in
            error)   renderer_fg_256 "$(theme_get error)" ;;
            warning) renderer_fg_256 "$(theme_get warning)" ;;
            success) renderer_fg_256 "$(theme_get success)" ;;
            *)       renderer_fg_256 "$(theme_get muted)" ;;
        esac
        # Parse: id|ts|cat|action|detail|sev
        local action="${line#*|*|*|}"
        action="${action%|*}"
        action="${action%|*}"
        printf ' %s' "$action"
        renderer_reset
        ((row++))
    done <<< "$events"
}

_page_key_event_bus() {
    local key="$1"
    case "$key" in
        "c"|"C") event_bus_clear; DASHBOARD_REDRAW_NEEDED=true ;;
        "s"|"S")
            local stats
            stats="$(event_bus_stats)"
            menu_textbox "Event Bus Statistics" "$stats"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        [1-8])
            local cats=("navigation" "device" "plugin" "automation" "report" "recovery" "security" "system")
            local idx=$((key - 1))
            local cat="${cats[$idx]}"
            local output
            output="$(event_bus_query "$cat" "" 50)"
            menu_textbox "Events: $cat" "${output:-No events in this category}"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
    esac
}
