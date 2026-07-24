#!/data/data/com.termux/files/usr/bin/bash
#
# diagnostics.sh — Advanced Diagnostics Center
#
# Comprehensive diagnostics workspace with:
#   - Battery diagnostics
#   - Thermal diagnostics
#   - Memory diagnostics
#   - Package diagnostics
#   - Permission diagnostics
#   - SELinux diagnostics
#   - Network diagnostics
#   - ADB diagnostics
#   - Shizuku diagnostics
#
# Part of the Android Toolkit Dashboard.

DIAGNOSTIC_RESULTS=""
DIAGNOSTIC_HEALTH_SCORE=0

##############################################
# Run battery diagnostics.
diagnostics_battery() {
    local result=""
    local pct="$(status_get battery_pct 2>/dev/null || echo "?")"
    local temp="$(status_get battery_temp 2>/dev/null || echo "?")"
    local health="$(status_get battery_health 2>/dev/null || echo "?")"
    local plugged="$(status_get battery_plugged 2>/dev/null || echo "false")"

    result+="═══ Battery Diagnostics ═══"$'\n'
    result+="  Level: ${pct}%"
    [[ "$pct" != "?" ]] && { [[ "$pct" -lt 20 ]] && result+=" ⚠ LOW" || result+=" ✓ OK"; }
    result+=$'\n'
    result+="  Temperature: ${temp}°C"
    [[ "$temp" != "?" ]] && { [[ "$(echo "$temp > 40" | bc -l 2>/dev/null)" -eq 1 ]] && result+=" ⚠ HIGH" || result+=" ✓ OK"; }
    result+=$'\n'
    result+="  Health: ${health}"$'\n'
    result+="  Charging: ${plugged}"$'\n'
    echo "$result"
}

##############################################
# Run thermal diagnostics.
diagnostics_thermal() {
    local result=""
    local thermal="$(status_get thermal 2>/dev/null || echo "?")"
    result+="═══ Thermal Diagnostics ═══"$'\n'
    result+="  Device temp: ${thermal}°C"
    if [[ "$thermal" != "?" ]]; then
        if [[ "$(echo "$thermal > 60" | bc -l 2>/dev/null)" -eq 1 ]]; then
            result+=" 🔴 CRITICAL"
        elif [[ "$(echo "$thermal > 45" | bc -l 2>/dev/null)" -eq 1 ]]; then
            result+=" ⚠ WARM"
        else
            result+=" ✓ NORMAL"
        fi
    fi
    result+=$'\n'
    # Check thermal zones
    local zones
    zones="$(ls /sys/class/thermal/ 2>/dev/null | grep thermal_zone | head -5 || echo "N/A")"
    result+="  Thermal zones: ${zones}"$'\n'
    echo "$result"
}

##############################################
# Run memory diagnostics.
diagnostics_memory() {
    local result=""
    local pct="$(status_get mem_pct 2>/dev/null || echo "?")"
    local total="$(status_get mem_total_mb 2>/dev/null || echo "?")"
    local avail="$(status_get mem_avail_mb 2>/dev/null || echo "?")"
    result+="═══ Memory Diagnostics ═══"$'\n'
    result+="  Usage: ${pct}%"
    [[ "$pct" != "?" ]] && { [[ "$pct" -gt 85 ]] && result+=" 🔴 HIGH" || [[ "$pct" -gt 70 ]] && result+=" ⚠ ELEVATED" || result+=" ✓ NORMAL"; }
    result+=$'\n'
    result+="  Total: ${total} MB"$'\n'
    result+="  Available: ${avail} MB"$'\n'
    echo "$result"
}

##############################################
# Run network diagnostics.
diagnostics_network() {
    local result=""
    local status="$(status_get network 2>/dev/null || echo "?")"
    result+="═══ Network Diagnostics ═══"$'\n'
    result+="  Status: ${status}"$'\n'
    result+="  Connectivity:"$'\n'
    if command -v ping &>/dev/null; then
        if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
            result+="    Internet: ✓ Connected"$'\n'
        else
            result+="    Internet: ✗ No connectivity"$'\n'
        fi
    else
        result+="    ping: not available"$'\n'
    fi
    # DNS
    if command -v nslookup &>/dev/null; then
        if nslookup google.com &>/dev/null; then
            result+="    DNS: ✓ Resolving"$'\n'
        else
            result+="    DNS: ✗ Not resolving"$'\n'
        fi
    fi
    echo "$result"
}

##############################################
# Run SELinux diagnostics.
diagnostics_selinux() {
    local result=""
    local status="$(status_get selinux 2>/dev/null || echo "?")"
    result+="═══ SELinux Diagnostics ═══"$'\n'
    result+="  Status: ${status}"
    if echo "$status" | grep -qi "enforcing"; then
        result+=" ✓ SECURE"
    elif echo "$status" | grep -qi "permissive"; then
        result+=" ⚠ PERMISSIVE"
    else
        result+=" ?"
    fi
    result+=$'\n'
    if command -v getenforce &>/dev/null; then
        result+="  $(getenforce 2>/dev/null || echo "N/A")"$'\n'
    fi
    echo "$result"
}

##############################################
# Run all diagnostics and generate health summary.
diagnostics_run_all() {
    local report=""
    report+="$(diagnostics_battery)"$'\n'
    report+="$(diagnostics_thermal)"$'\n'
    report+="$(diagnostics_memory)"$'\n'
    report+="$(diagnostics_network)"$'\n'
    report+="$(diagnostics_selinux)"$'\n'

    # Calculate health score (simplified)
    local score=100
    local bat="$(status_get battery_pct 2>/dev/null || echo "?")"
    local mem="$(status_get mem_pct 2>/dev/null || echo "?")"
    local temp="$(status_get thermal 2>/dev/null || echo "?")"

    [[ "$bat" != "?" && "$bat" -lt 20 ]] && score=$(( score - 20 ))
    [[ "$mem" != "?" && "$mem" -gt 85 ]] && score=$(( score - 15 ))
    [[ "$temp" != "?" && "$(echo "$temp > 45" | bc -l 2>/dev/null)" -eq 1 ]] && score=$(( score - 15 ))

    DIAGNOSTIC_HEALTH_SCORE=$score
    DIAGNOSTIC_RESULTS="$report"

    audit_record "Diagnostics" "run_all" "" "score: $score"
}

##############################################
# Render diagnostics center.
_page_render_diagnostics() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Diagnostics Center'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Health score: %d/100' "$DIAGNOSTIC_HEALTH_SCORE"
    renderer_reset

    local row=$(( top + 2 ))
    local col="$left"

    # Quick action buttons
    local actions=(
        "1" "Run All Diagnostics"
        "2" "Battery"
        "3" "Thermal"
        "4" "Memory"
        "5" "Network"
        "6" "SELinux"
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

    # Health score indicator
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get muted)"
    printf 'Health Score: '
    renderer_reset
    if [[ "$DIAGNOSTIC_HEALTH_SCORE" -ge 80 ]]; then
        renderer_fg_256 "$(theme_get success)"
    elif [[ "$DIAGNOSTIC_HEALTH_SCORE" -ge 50 ]]; then
        renderer_fg_256 "$(theme_get warning)"
    else
        renderer_fg_256 "$(theme_get error)"
    fi
    renderer_bold
    printf '%d/100' "$DIAGNOSTIC_HEALTH_SCORE"
    renderer_reset
    ((row += 2))

    # Results area
    if [[ -n "$DIAGNOSTIC_RESULTS" ]]; then
        local box_h=$(( height - (row - top) - 2 ))
        [[ "$box_h" -lt 5 ]] && box_h=5
        renderer_draw_box "$row" "$col" "$box_h" "$width" "Results"
        local content_row=$(( row + 1 ))
        local content_col=$(( col + 2 ))
        local line_count=0
        while IFS= read -r line; do
            renderer_cursor_goto "$content_row" "$content_col"
            if [[ "$line" =~ ^═══ ]]; then
                renderer_bold
                renderer_fg_256 "$(theme_get accent)"
            elif echo "$line" | grep -q "🔴\|✗\|⚠.*HIGH\|⚠.*CRITICAL\|⚠.*LOW"; then
                renderer_fg_256 "$(theme_get error)"
            elif echo "$line" | grep -q "✓"; then
                renderer_fg_256 "$(theme_get success)"
            else
                renderer_fg_256 "$(theme_get fg)"
            fi
            printf '%-*s' "$((width - 4))" "${line:0:$((width-4))}"
            renderer_reset
            ((content_row++))
            ((line_count++))
            [[ "$line_count" -ge "$box_h" ]] && break
        done <<< "$DIAGNOSTIC_RESULTS"
    fi
}

_page_key_diagnostics() {
    local key="$1"
    case "$key" in
        "1") diagnostics_run_all ;;
        "2") DIAGNOSTIC_RESULTS="$(diagnostics_battery)" ;;
        "3") DIAGNOSTIC_RESULTS="$(diagnostics_thermal)" ;;
        "4") DIAGNOSTIC_RESULTS="$(diagnostics_memory)" ;;
        "5") DIAGNOSTIC_RESULTS="$(diagnostics_network)" ;;
        "6") DIAGNOSTIC_RESULTS="$(diagnostics_selinux)" ;;
    esac
    DASHBOARD_REDRAW_NEEDED=true
}
