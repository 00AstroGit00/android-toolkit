#!/data/data/com.termux/files/usr/bin/bash
#
# timeline.sh — Historical Timeline
#
# Complete event timeline with filter, search, export,
# and replay capabilities. Tracks all significant device
# and toolkit events over time.
#
# Part of the Android Toolkit Dashboard.

declare -ga TIMELINE_EVENTS=()
TIMELINE_MAX=2000
TIMELINE_FILTER=""
TIMELINE_SEARCH=""
TIMELINE_EXPORT_DIR="${ANDROID_TOOLKIT_ROOT_DIR}/timeline"

##############################################
# Initialize timeline storage.
timeline_init() {
    mkdir -p "$TIMELINE_EXPORT_DIR" 2>/dev/null || true
    TIMELINE_EVENTS=()
}

##############################################
# Record a timeline event.
# Arguments:
#   $1: event type (device_connected|optimization|package_removed|plugin_installed|
#       benchmark|security_scan|battery_change|thermal_event|report_generated|
#       rollback|configuration_change)
#   $2: description
#   $3: detail (optional)
#   $4: severity (optional, default: info)
timeline_record() {
    local etype="$1" description="$2" detail="${3:-}" severity="${4:-info}"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local epoch
    epoch="$(date +%s)"
    local entry="${epoch}|${timestamp}|${etype}|${description}|${detail}|${severity}"
    TIMELINE_EVENTS+=("$entry")
    # Trim
    while [[ "${#TIMELINE_EVENTS[@]}" -gt "$TIMELINE_MAX" ]]; do
        TIMELINE_EVENTS=("${TIMELINE_EVENTS[@]:1}")
    done
    # Persist to disk
    local logfile="${TIMELINE_EXPORT_DIR}/timeline.log"
    echo "$entry" >> "$logfile" 2>/dev/null || true
    # Rotate at 5MB
    local size
    size="$(stat -c%s "$logfile" 2>/dev/null || echo "0")"
    if [[ "$size" -gt 5242880 ]]; then
        mv -f "$logfile" "${logfile}.old" 2>/dev/null || true
    fi
    # Emit to event bus
    typeset -f event_bus_emit &>/dev/null && event_bus_emit "timeline" "$etype" "$description" "$severity"
}

##############################################
# Query timeline events.
# Arguments:
#   $1: type filter (optional)
#   $2: search text (optional)
#   $3: max results (default: 100)
#   $4: offset (default: 0)
timeline_query() {
    local type_filter="${1:-}" search_text="${2:-}" max="${3:-100}" offset="${4:-0}"
    local count=0 matched=0
    local entry
    local i
    for (( i = ${#TIMELINE_EVENTS[@]} - 1; i >= 0; i-- )); do
        entry="${TIMELINE_EVENTS[$i]}"
        [[ -n "$type_filter" && "$entry" != *"|${type_filter}|"* ]] && continue
        if [[ -n "$search_text" ]]; then
            local lower_entry="${entry,,}"
            local lower_search="${search_text,,}"
            [[ "$lower_entry" != *"$lower_search"* ]] && continue
        fi
        ((matched++))
        [[ "$matched" -le "$offset" ]] && continue
        echo "$entry"
        ((count++))
        [[ "$count" -ge "$max" ]] && break
    done
}

##############################################
# Get timeline statistics.
timeline_stats() {
    local total="${#TIMELINE_EVENTS[@]}"
    local type_counts
    type_counts="$(timeline_query "" "" 9999 | awk -F'|' '{print $3}' | sort | uniq -c | sort -rn)"
    echo "total=$total"
    echo "types:"
    echo "$type_counts" | while read -r line; do echo "  $line"; done
}

##############################################
# Export timeline.
# Arguments:
#   $1: format (txt|csv|json)
#   $2: type filter (optional)
timeline_export() {
    local format="${1:-txt}" type_filter="${2:-}"
    local ts
    ts="$(date +%Y%m%d_%H%M%S)"
    local filename="timeline_${ts}.${format}"
    mkdir -p "$TIMELINE_EXPORT_DIR" 2>/dev/null || true

    case "$format" in
        csv)
            {
                echo "epoch,timestamp,type,description,detail,severity"
                timeline_query "$type_filter" "" 9999 | while IFS='|' read -r ep ts tp desc det sev; do
                    echo "\"$ep\",\"$ts\",\"$tp\",\"$desc\",\"$det\",\"$sev\""
                done
            } > "${TIMELINE_EXPORT_DIR}/${filename}" 2>/dev/null || return 1
            ;;
        json)
            {
                echo "["
                local sep=""
                timeline_query "$type_filter" "" 9999 | while IFS='|' read -r ep ts tp desc det sev; do
                    echo "${sep}{\"epoch\":$ep,\"timestamp\":\"$ts\",\"type\":\"$tp\",\"description\":\"$desc\",\"detail\":\"$det\",\"severity\":\"$sev\"}"
                    sep=","
                done
                echo "]"
            } > "${TIMELINE_EXPORT_DIR}/${filename}" 2>/dev/null || return 1
            ;;
        txt|*)
            {
                echo "Timeline Export — $ts"
                echo "Entries: ${#TIMELINE_EVENTS[@]}"
                echo "---"
                timeline_query "$type_filter" "" 9999 | while IFS='|' read -r ep ts tp desc det sev; do
                    echo "[$ts] [$tp] $desc — $det [$sev]"
                done
            } > "${TIMELINE_EXPORT_DIR}/${filename}" 2>/dev/null || return 1
            ;;
    esac
    echo "${TIMELINE_EXPORT_DIR}/${filename}"
}

##############################################
# Replay timeline events (emit them again).
timeline_replay() {
    local type_filter="${1:-}"
    local count=0
    local entry
    local i
    for (( i = 0; i < ${#TIMELINE_EVENTS[@]}; i++ )); do
        entry="${TIMELINE_EVENTS[$i]}"
        [[ -n "$type_filter" && "$entry" != *"|${type_filter}|"* ]] && continue
        local tp desc det sev
        tp="$(echo "$entry" | cut -d'|' -f3)"
        desc="$(echo "$entry" | cut -d'|' -f4)"
        det="$(echo "$entry" | cut -d'|' -f5)"
        sev="$(echo "$entry" | cut -d'|' -f6)"
        event_bus_emit "timeline_replay" "$tp" "$desc" "$sev"
        ((count++))
    done
    echo "$count events replayed"
}

##############################################
# Render timeline page.
_page_render_timeline() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Historical Timeline'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — %d events' "${#TIMELINE_EVENTS[@]}"
    renderer_reset

    local row=$(( top + 2 ))
    local col="$left"

    # Quick actions
    local actions=(
        "e" "Export" "f" "Filter" "/" "Search" "r" "Replay"
    )
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

    # Filter indicators
    if [[ -n "$TIMELINE_FILTER" ]]; then
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get warning)"
        printf ' Type: %s' "$TIMELINE_FILTER"
        renderer_reset
        ((row++))
    fi
    if [[ -n "$TIMELINE_SEARCH" ]]; then
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get warning)"
        printf ' Search: %s' "$TIMELINE_SEARCH"
        renderer_reset
        ((row++))
    fi

    # Type filter buttons
    local types=("device_connected" "optimization" "benchmark" "security_scan" "rollback" "configuration_change")
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    printf 'Types: '
    renderer_reset
    local ti=0
    for t in "${types[@]}"; do
        renderer_fg_256 "$(theme_get info)"
        renderer_bold
        printf '[%d]%s ' "$((ti+1))" "$t"
        renderer_reset
        ((ti++))
    done
    ((row += 2))

    # Event list
    local max_rows=$(( height - (row - top) - 1 ))
    [[ "$max_rows" -lt 3 ]] && max_rows=3
    local events
    events="$(timeline_query "$TIMELINE_FILTER" "$TIMELINE_SEARCH" "$max_rows")"
    if [[ -z "$events" ]]; then
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get muted)"
        printf 'No events matching current filters.'
        renderer_reset
        return
    fi

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
        local ts_desc="${line#*|}"
        ts_desc="${ts_desc#*|}"
        local etype="${ts_desc%%|*}"
        ts_desc="${ts_desc#*|}"
        local desc="${ts_desc%%|*}"
        local display="[${etype}] ${desc}"
        printf ' %-*s' "$((width - 2))" "${display:0:$((width - 2))}"
        renderer_reset
        ((row++))
    done <<< "$events"
}

_page_key_timeline() {
    local key="$1"
    case "$key" in
        "e"|"E")
            local fmt
            fmt="$(menu_select "Export Format" "" "txt" "Text" "csv" "CSV" "json" "JSON")" || return 0
            local file
            file="$(timeline_export "$fmt" "$TIMELINE_FILTER")"
            menu_textbox "Timeline Export" "Exported to: $file"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "f"|"F")
            local types=("" "All" "device_connected" "Device Connected" "optimization" "Optimization" "benchmark" "Benchmark" "security_scan" "Security Scan" "rollback" "Rollback")
            local choice
            choice="$(menu_select "Filter by Type" "${types[@]}")" || return 0
            TIMELINE_FILTER="$choice"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "/")
            local search
            search="$(menu_input "Search Timeline" "Search text:")" || return 0
            TIMELINE_SEARCH="$search"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "r"|"R")
            if menu_yesno "Replay" "Replay all timeline events?"; then
                local result
                result="$(timeline_replay "$TIMELINE_FILTER")"
                notify_push "Timeline replayed: $result" "success"
            fi
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        [1-6])
            local types=("device_connected" "optimization" "benchmark" "security_scan" "rollback" "configuration_change")
            local idx=$((key - 1))
            TIMELINE_FILTER="${types[$idx]}"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
    esac
}
