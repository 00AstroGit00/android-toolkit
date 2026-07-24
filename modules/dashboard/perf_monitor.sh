#!/data/data/com.termux/files/usr/bin/bash
#
# perf_monitor.sh — Performance Monitor
#
# Live performance monitoring with:
#   - CPU core usage visualization
#   - Memory usage graph
#   - Temperature timeline
#   - Battery discharge rate
#   - Storage I/O (when available)
#
# Part of the Android Toolkit Dashboard.

PERF_HISTORY_SIZE=60
PERF_CPU_HISTORY=()
PERF_MEM_HISTORY=()
PERF_TEMP_HISTORY=()
PERF_SNAPSHOTS=()
PERF_MONITOR_INTERVAL=2

##############################################
# Record a performance data point.
perf_record_snapshot() {
    local cpu="$(status_get cpu_cores 2>/dev/null || echo "0")"
    local mem="$(status_get mem_pct 2>/dev/null || echo "0")"
    local temp="$(status_get thermal 2>/dev/null || echo "0")"

    PERF_CPU_HISTORY+=("$cpu")
    PERF_MEM_HISTORY+=("$mem")
    PERF_TEMP_HISTORY+=("$temp")

    # Trim to max size
    [[ "${#PERF_CPU_HISTORY[@]}" -gt "$PERF_HISTORY_SIZE" ]] && PERF_CPU_HISTORY=("${PERF_CPU_HISTORY[@]:1}")
    [[ "${#PERF_MEM_HISTORY[@]}" -gt "$PERF_HISTORY_SIZE" ]] && PERF_MEM_HISTORY=("${PERF_MEM_HISTORY[@]:1}")
    [[ "${#PERF_TEMP_HISTORY[@]}" -gt "$PERF_HISTORY_SIZE" ]] && PERF_TEMP_HISTORY=("${PERF_TEMP_HISTORY[@]:1}")
}

##############################################
# Export a performance snapshot.
perf_export_snapshot() {
    local ts
    ts="$(date +%Y%m%d_%H%M%S)"
    local filename="perf_snapshot_${ts}.txt"
    {
        echo "Performance Snapshot — $ts"
        echo "CPU Cores: $(status_get cpu_cores 2>/dev/null || echo "?")"
        echo "Max Freq: $(status_get cpu_max_hz 2>/dev/null || echo "?") MHz"
        echo "Memory: $(status_get mem_pct 2>/dev/null || echo "?")% used"
        echo "Total RAM: $(status_get mem_total_mb 2>/dev/null || echo "?") MB"
        echo "Available: $(status_get mem_avail_mb 2>/dev/null || echo "?") MB"
        echo "Temperature: $(status_get thermal 2>/dev/null || echo "?")°C"
        echo "Battery: $(status_get battery_pct 2>/dev/null || echo "?")%"
        echo "Battery Temp: $(status_get battery_temp 2>/dev/null || echo "?")°C"
        echo "Storage: $(status_get storage_pct 2>/dev/null || echo "?")% used"
        echo "Network: $(status_get network 2>/dev/null || echo "?")"
        echo "---"
        echo "History (last ${#PERF_MEM_HISTORY[@]} samples):"
        local i
        for i in "${!PERF_MEM_HISTORY[@]}"; do
            echo "  $i: CPU=${PERF_CPU_HISTORY[$i]} Mem=${PERF_MEM_HISTORY[$i]}% Temp=${PERF_TEMP_HISTORY[$i]}°C"
        done
    } > "$filename"
    echo "$filename"
}

##############################################
# Render a simple ASCII bar chart.
perf_render_bar() {
    local label="$1" pct="$2" width="${3:-20}" row="$4" col="$5"
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get muted)"
    printf '%-6s' "$label"
    renderer_reset

    local filled=$(( pct * width / 100 ))
    [[ "$filled" -gt "$width" ]] && filled=$width
    [[ "$filled" -lt 0 ]] && filled=0

    local color
    if [[ "$pct" -gt 80 ]]; then color="$(theme_get error)"
    elif [[ "$pct" -gt 60 ]]; then color="$(theme_get warning)"
    else color="$(theme_get success)"
    fi

    renderer_fg_256 "$color"
    local i=0
    while (( i < filled )); do printf '█'; ((i++)); done
    renderer_fg_256 "$(theme_get muted)"
    while (( i < width )); do printf '░'; ((i++)); done
    renderer_reset
    renderer_fg_256 "$color"
    printf ' %3d%%' "$pct"
    renderer_reset
}

##############################################
# Render performance monitor.
_page_render_perf_monitor() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Performance Monitor'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Live metrics (recording: %d samples)' "${#PERF_MEM_HISTORY[@]}"
    renderer_reset

    local row=$(( top + 2 ))
    local col="$left"

    # Record a data point
    perf_record_snapshot

    # Get current values
    local mem_pct="$(status_get mem_pct 2>/dev/null || echo "0")"
    local storage_pct="$(status_get storage_pct 2>/dev/null || echo "0")"
    local bat_pct="$(status_get battery_pct 2>/dev/null || echo "0")"
    local temp="$(status_get thermal 2>/dev/null || echo "0")"
    local cpu_cores="$(status_get cpu_cores 2>/dev/null || echo "0")"
    local mem_total="$(status_get mem_total_mb 2>/dev/null || echo "0")"

    # CPU Info
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get fg)"
    printf 'CPU Cores: %s  |  Max Freq: %s MHz' \
        "$cpu_cores" \
        "$(status_get cpu_max_hz 2>/dev/null || echo "?")"
    renderer_reset
    ((row++))

    # Memory bar
    perf_render_bar "Memory" "${mem_pct//%/}" 25 "$row" "$col"
    ((row++))
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get muted)"
    printf '  Total: %s MB  |  Avail: %s MB' \
        "$mem_total" \
        "$(status_get mem_avail_mb 2>/dev/null || echo "?")"
    renderer_reset
    ((row++))

    # Storage bar
    perf_render_bar "Storage" "${storage_pct//%/}" 25 "$row" "$col"
    ((row++))

    # Battery bar
    perf_render_bar "Battery" "${bat_pct//%/}" 25 "$row" "$col"
    ((row++))

    # Temperature
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get muted)"
    printf 'Temperature: '
    renderer_reset
    if [[ "$temp" != "?" && -n "$temp" ]]; then
        if [[ "$(echo "$temp > 45" | bc -l 2>/dev/null)" -eq 1 ]]; then
            renderer_fg_256 "$(theme_get error)"
        elif [[ "$(echo "$temp > 35" | bc -l 2>/dev/null)" -eq 1 ]]; then
            renderer_fg_256 "$(theme_get warning)"
        else
            renderer_fg_256 "$(theme_get success)"
        fi
        printf '%s°C' "$temp"
    else
        renderer_fg_256 "$(theme_get muted)"
        printf 'N/A'
    fi
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf '  |  Battery Temp: %s°C' "$(status_get battery_temp 2>/dev/null || echo "?")"
    renderer_reset
    ((row += 2))

    # History sparkline (simplified)
    if [[ "${#PERF_MEM_HISTORY[@]}" -gt 1 ]]; then
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get muted)"
        renderer_dim
        printf 'Memory Trend (last %d samples):' "${#PERF_MEM_HISTORY[@]}"
        renderer_reset
        ((row++))

        local spark_w=$(( width - 4 ))
        [[ "$spark_w" -gt 60 ]] && spark_w=60
        renderer_cursor_goto "$row" "$col"
        local s
        local vals=("${PERF_MEM_HISTORY[@]: -$spark_w}")
        for s in "${vals[@]}"; do
            local s_val="${s//%/}"
            if [[ "$s_val" -gt 80 ]]; then
                renderer_fg_256 "$(theme_get error)"
                printf '█'
            elif [[ "$s_val" -gt 60 ]]; then
                renderer_fg_256 "$(theme_get warning)"
                printf '▓'
            elif [[ "$s_val" -gt 40 ]]; then
                renderer_fg_256 "$(theme_get info)"
                printf '▒'
            else
                renderer_fg_256 "$(theme_get success)"
                printf '░'
            fi
            renderer_reset
        done
        renderer_reset
        ((row++))
    fi

    # Snapshot button
    ((row++))
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    printf 'S: Save snapshot  |  R: Reset history  |  Auto-refresh every %ds' "$PERF_MONITOR_INTERVAL"
    renderer_reset
}

_page_key_perf_monitor() {
    local key="$1"
    case "$key" in
        "s"|"S")
            local file
            file="$(perf_export_snapshot)"
            notify_push "Snapshot saved: $file" "success"
            audit_record "Performance" "snapshot" "$file" "success"
            ;;
        "r"|"R")
            PERF_CPU_HISTORY=()
            PERF_MEM_HISTORY=()
            PERF_TEMP_HISTORY=()
            notify_push "History reset" "info"
            ;;
    esac
    DASHBOARD_REDRAW_NEEDED=true
}
