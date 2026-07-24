#!/data/data/com.termux/files/usr/bin/bash
#
# watch.sh — Watch/Monitor Module
#
# Continuously monitors device metrics at configurable intervals.
# Supports threshold-based alerts for:
#   - battery level and temperature
#   - memory usage
#   - storage usage
#   - connectivity
#   - charging state
#   - thermal throttling
#
# Part of the Android Toolkit.

WATCH_INTERVAL="${ANDROID_TOOLKIT_WATCH_INTERVAL:-5}"
WATCH_ALERTS=true

# Thresholds (can be overridden via env vars)
WATCH_BATTERY_LOW="${ANDROID_TOOLKIT_WATCH_BATTERY_LOW:-20}"
WATCH_BATTERY_HIGH_TEMP="${ANDROID_TOOLKIT_WATCH_BATTERY_HIGH_TEMP:-40}"
WATCH_MEMORY_HIGH="${ANDROID_TOOLKIT_WATCH_MEMORY_HIGH:-90}"
WATCH_STORAGE_HIGH="${ANDROID_TOOLKIT_WATCH_STORAGE_HIGH:-85}"
WATCH_TEMPERATURE_HIGH="${ANDROID_TOOLKIT_WATCH_TEMPERATURE_HIGH:-55}"

##############################################
# Read a single metric value.
# Arguments:
#   $1: metric name
# Outputs: value
##############################################
_watch_read_metric() {
    local metric="$1"

    case "$metric" in
        battery_level)
            backend_exec "dumpsys battery 2>/dev/null | grep 'level:' | awk '{print \$2}'" 2>/dev/null || echo "N/A"
            ;;
        battery_temp)
            local raw
            raw="$(backend_exec "dumpsys battery 2>/dev/null | grep 'temperature:' | awk '{print \$2}'" 2>/dev/null || echo "0")"
            echo $(( raw / 10 ))
            ;;
        battery_voltage)
            backend_exec "dumpsys battery 2>/dev/null | grep 'voltage:' | awk '{print \$2}'" 2>/dev/null || echo "N/A"
            ;;
        charging)
            local plugged
            plugged="$(backend_exec "dumpsys battery 2>/dev/null | grep 'plugged:' | awk '{print \$2}'" 2>/dev/null || echo "0")"
            if [[ "$plugged" != "0" ]]; then echo "yes"; else echo "no"; fi
            ;;
        memory_free)
            backend_exec "cat /proc/meminfo 2>/dev/null | grep MemFree | awk '{print \$2}'" 2>/dev/null || echo "N/A"
            ;;
        memory_avail)
            backend_exec "cat /proc/meminfo 2>/dev/null | grep MemAvailable | awk '{print \$2}'" 2>/dev/null || echo "N/A"
            ;;
        memory_total)
            backend_exec "cat /proc/meminfo 2>/dev/null | grep MemTotal | awk '{print \$2}'" 2>/dev/null || echo "N/A"
            ;;
        memory_pct)
            local total avail
            total="$(_watch_read_metric memory_total)"
            avail="$(_watch_read_metric memory_avail)"
            if [[ "$total" =~ ^[0-9]+$ && "$avail" =~ ^[0-9]+$ && "$total" -gt 0 ]]; then
                echo $(( (total - avail) * 100 / total ))
            else
                echo "N/A"
            fi
            ;;
        storage_free)
            backend_exec "df -k /data 2>/dev/null | tail -1 | awk '{print \$4}'" 2>/dev/null || echo "N/A"
            ;;
        storage_total)
            backend_exec "df -k /data 2>/dev/null | tail -1 | awk '{print \$2}'" 2>/dev/null || echo "N/A"
            ;;
        storage_pct)
            local total free
            total="$(_watch_read_metric storage_total)"
            free="$(_watch_read_metric storage_free)"
            if [[ "$total" =~ ^[0-9]+$ && "$free" =~ ^[0-9]+$ && "$total" -gt 0 ]]; then
                echo $(( (total - free) * 100 / total ))
            else
                echo "N/A"
            fi
            ;;
        thermal_throttling)
            local thermal
            thermal="$(backend_exec "dumpsys thermalservice 2>/dev/null | grep -i 'throttling'" 2>/dev/null || echo "")"
            if [[ -n "$thermal" ]]; then echo "yes"; else echo "no"; fi
            ;;
        connectivity)
            if backend_exec "dumpsys connectivity 2>/dev/null | grep -qi 'NetworkAgentInfo.*CONNECTED'" 2>/dev/null; then
                echo "connected"
            else
                echo "disconnected"
            fi
            ;;
        temperature_max)
            local max=0
            local zones
            zones="$(backend_exec "ls /sys/class/thermal/thermal_zone*/temp 2>/dev/null" 2>/dev/null || echo "")"
            if [[ -n "$zones" ]]; then
                while IFS= read -r zone; do
                    local t
                    t="$(backend_exec "cat '$zone' 2>/dev/null" 2>/dev/null || echo 0)"
                    t="${t%% *}"
                    t="${t//[!0-9]/}"
                    t=$(( t / 1000 ))
                    [[ "$t" -gt "$max" ]] && max="$t"
                done <<< "$zones"
            fi
            echo "$max"
            ;;
        *)
            echo "N/A"
            ;;
    esac
}

##############################################
# Check thresholds and return alerts.
##############################################
_watch_check_thresholds() {
    local level temp mem_pct storage_pct

    level="$(_watch_read_metric battery_level)"
    temp="$(_watch_read_metric battery_temp)"
    mem_pct="$(_watch_read_metric memory_pct)"
    storage_pct="$(_watch_read_metric storage_pct)"

    if [[ "$level" =~ ^[0-9]+$ && "$level" -le "$WATCH_BATTERY_LOW" ]]; then
        echo "⚠ Battery low: ${level}% (threshold: ${WATCH_BATTERY_LOW}%)"
    fi
    if [[ "$temp" =~ ^[0-9]+$ && "$temp" -ge "$WATCH_BATTERY_HIGH_TEMP" ]]; then
        echo "⚠ Battery hot: ${temp}°C (threshold: ${WATCH_BATTERY_HIGH_TEMP}°C)"
    fi
    if [[ "$mem_pct" =~ ^[0-9]+$ && "$mem_pct" -ge "$WATCH_MEMORY_HIGH" ]]; then
        echo "⚠ Memory high: ${mem_pct}% used (threshold: ${WATCH_MEMORY_HIGH}%)"
    fi
    if [[ "$storage_pct" =~ ^[0-9]+$ && "$storage_pct" -ge "$WATCH_STORAGE_HIGH" ]]; then
        echo "⚠ Storage high: ${storage_pct}% used (threshold: ${WATCH_STORAGE_HIGH}%)"
    fi
}

##############################################
# Print a single metrics snapshot.
##############################################
_watch_print_snapshot() {
    local timestamp
    timestamp="$(date '+%H:%M:%S')"

    echo ""
    echo "  ── Snapshot at ${timestamp} ──"
    echo "  Battery:      $(_watch_read_metric battery_level)%  $(_watch_read_metric battery_temp)°C  Charge: $(_watch_read_metric charging)"
    echo "  Memory:       $(_watch_read_metric memory_pct)% used"
    echo "  Storage:      $(_watch_read_metric storage_pct)% used"
    echo "  Temperature:  $(_watch_read_metric temperature_max)°C  Throttling: $(_watch_read_metric thermal_throttling)"
    echo "  Connectivity: $(_watch_read_metric connectivity)"

    if $WATCH_ALERTS; then
        local alert
        _watch_check_thresholds | while IFS= read -r alert; do
            [[ -n "$alert" ]] && echo "  ${alert}"
        done
    fi
}

##############################################
# Main watch loop.
# Arguments:
#   $1: interval in seconds (default: 5)
##############################################
watch_run() {
    local interval="${1:-$WATCH_INTERVAL}"

    log_section "Watch Mode"
    log_info "Monitoring every ${interval}s. Press Ctrl+C to stop."
    log_info "Thresholds: Battery<${WATCH_BATTERY_LOW}% | Temp>${WATCH_BATTERY_HIGH_TEMP}°C | Memory>${WATCH_MEMORY_HIGH}% | Storage>${WATCH_STORAGE_HIGH}%"
    echo ""

    # Clear screen for cleaner display
    echo "  Starting monitor..."

    while true; do
        _watch_print_snapshot
        sleep "$interval" 2>/dev/null || sleep 1
    done
}
