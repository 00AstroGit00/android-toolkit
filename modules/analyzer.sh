#!/data/data/com.termux/files/usr/bin/bash
#
# analyzer.sh — Performance analyzer module
#
# Collects comprehensive device health data and produces:
#   - Performance score
#   - Battery score
#   - Stability score
#   - Overall health score
#   - Recommendations
#
# Part of the Android Toolkit.

ANALYZER_RESULTS=()

##############################################
# Collect memory metrics.
# Outputs: memory score (0-100)
##############################################
_analyzer_memory() {
    local mem_total mem_free mem_avail swap_total swap_free
    local score=100

    mem_total="$(backend_exec "cat /proc/meminfo 2>/dev/null | grep MemTotal" 2>/dev/null | awk '{print $2}' || echo 0)"
    mem_free="$(backend_exec "cat /proc/meminfo 2>/dev/null | grep MemFree" 2>/dev/null | awk '{print $2}' || echo 0)"
    mem_avail="$(backend_exec "cat /proc/meminfo 2>/dev/null | grep MemAvailable" 2>/dev/null | awk '{print $2}' || echo 0)"
    swap_total="$(backend_exec "cat /proc/meminfo 2>/dev/null | grep SwapTotal" 2>/dev/null | awk '{print $2}' || echo 0)"
    swap_free="$(backend_exec "cat /proc/meminfo 2>/dev/null | grep SwapFree" 2>/dev/null | awk '{print $2}' || echo 0)"

    mem_total="${mem_total:-0}"
    mem_avail="${mem_avail:-0}"
    swap_total="${swap_total:-0}"

    if [[ "$mem_total" -gt 0 ]]; then
        local avail_pct=$(( mem_avail * 100 / mem_total ))
        if [[ "$avail_pct" -lt 10 ]]; then
            score=$(( score - 30 ))
        elif [[ "$avail_pct" -lt 25 ]]; then
            score=$(( score - 15 ))
        elif [[ "$avail_pct" -lt 40 ]]; then
            score=$(( score - 5 ))
        fi
    fi

    if [[ "$swap_total" -gt 0 ]]; then
        local swap_used_pct=$(( (swap_total - swap_free) * 100 / swap_total ))
        if [[ "$swap_used_pct" -gt 80 ]]; then
            score=$(( score - 10 ))
        fi
    fi

    ANALYZER_RESULTS+=("memory|$score|MemAvailable: ${mem_avail}kB / ${mem_total}kB")
    echo "$score"
}

##############################################
# Collect thermal metrics.
# Outputs: thermal score (0-100)
##############################################
_analyzer_thermal() {
    local score=100
    local temps=()

    # Read thermal zones
    local thermal_zones
    thermal_zones="$(backend_exec "ls /sys/class/thermal/thermal_zone*/temp 2>/dev/null" 2>/dev/null || echo "")"

    if [[ -n "$thermal_zones" ]]; then
        while IFS= read -r zone; do
            local temp
            temp="$(backend_exec "cat '$zone' 2>/dev/null" 2>/dev/null || echo 0)"
            temp="${temp%% *}"
            temp="${temp//[!0-9]/}"
            if [[ -n "$temp" && "$temp" -gt 0 ]]; then
                temps+=("$(( temp / 1000 ))")
            fi
        done <<< "$thermal_zones"
    fi

    # Also try dumpsys thermalservice
    local thermal_service
    thermal_service="$(backend_exec "dumpsys thermalservice 2>/dev/null | grep -i 'temperature'" 2>/dev/null || echo "")"

    if [[ -n "$temps" ]]; then
        local max_temp=0
        for t in "${temps[@]}"; do
            [[ "$t" -gt "$max_temp" ]] && max_temp="$t"
        done

        if [[ "$max_temp" -gt 70 ]]; then
            score=$(( score - 40 ))
        elif [[ "$max_temp" -gt 55 ]]; then
            score=$(( score - 20 ))
        elif [[ "$max_temp" -gt 45 ]]; then
            score=$(( score - 10 ))
        fi

        ANALYZER_RESULTS+=("thermal|$score|Max temp: ${max_temp}°C")
    else
        ANALYZER_RESULTS+=("thermal|50|Thermal data unavailable")
        score=50
    fi

    echo "$score"
}

##############################################
# Collect CPU metrics.
# Outputs: CPU score (0-100)
##############################################
_analyzer_cpu() {
    local score=100

    local cpu_cores
    cpu_cores="$(backend_exec "cat /sys/devices/system/cpu/online 2>/dev/null" 2>/dev/null || echo "0")"
    local governor
    governor="$(backend_exec "cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null" 2>/dev/null || echo "unknown")"

    # Check CPU load
    local load_1m
    load_1m="$(backend_exec "cat /proc/loadavg 2>/dev/null | awk '{print \$1}'" 2>/dev/null || echo 0)"

    if [[ "$load_1m" != "0" ]]; then
        # Approximate: load should be < core count
        local cores_available
        cores_available="$(echo "$cpu_cores" | awk -F- '{print $2 + 1}')"
        cores_available="${cores_available:-4}"

        local load_int
        load_int="$(echo "$load_1m" | cut -d. -f1)"
        load_int="${load_int:-0}"

        if [[ "$load_int" -gt "$(( cores_available * 2 ))" ]]; then
            score=$(( score - 30 ))
        elif [[ "$load_int" -gt "$cores_available" ]]; then
            score=$(( score - 15 ))
        fi
    fi

    ANALYZER_RESULTS+=("cpu|$score|Governor: ${governor}, Cores: ${cpu_cores}, Load: ${load_1m}")
    echo "$score"
}

##############################################
# Collect battery metrics.
# Outputs: battery score (0-100)
##############################################
_analyzer_battery() {
    local score=100
    local level temp voltage

    level="$(backend_exec "dumpsys battery 2>/dev/null | grep 'level:' | awk '{print \$2}'" 2>/dev/null || echo 50)"
    temp="$(backend_exec "dumpsys battery 2>/dev/null | grep 'temperature:' | awk '{print \$2}'" 2>/dev/null || echo 0)"
    voltage="$(backend_exec "dumpsys battery 2>/dev/null | grep 'voltage:' | awk '{print \$2}'" 2>/dev/null || echo 0)"

    level="${level:-50}"
    temp="${temp:-0}"
    voltage="${voltage:-0}"

    # Temperature scoring (tenths of degrees Celsius)
    local temp_c=$(( temp / 10 ))
    if [[ "$temp_c" -gt 45 ]]; then
        score=$(( score - 30 ))
    elif [[ "$temp_c" -gt 40 ]]; then
        score=$(( score - 15 ))
    elif [[ "$temp_c" -gt 37 ]]; then
        score=$(( score - 5 ))
    fi

    # Level scoring
    if [[ "$level" -lt 10 ]]; then
        score=$(( score - 10 ))
    fi

    ANALYZER_RESULTS+=("battery|$score|Level: ${level}%, Temp: ${temp_c}°C, Voltage: ${voltage}mV")
    echo "$score"
}

##############################################
# Collect storage metrics.
# Outputs: storage score (0-100)
##############################################
_analyzer_storage() {
    local score=100

    local data_total data_used data_free
    local total_kb=0 used_kb=0 free_kb=0

    # Try statfs-based approach
    local df_output
    df_output="$(backend_exec "df -k /data 2>/dev/null" 2>/dev/null || echo "")"
    if [[ -n "$df_output" ]]; then
        local stats
        stats="$(echo "$df_output" | tail -1)"
        total_kb="$(echo "$stats" | awk '{print $2}')"
        used_kb="$(echo "$stats" | awk '{print $3}')"
        free_kb="$(echo "$stats" | awk '{print $4}')"
    fi

    total_kb="${total_kb:-0}"
    used_kb="${used_kb:-0}"

    if [[ "$total_kb" -gt 0 ]]; then
        local used_pct=$(( used_kb * 100 / total_kb ))
        if [[ "$used_pct" -gt 95 ]]; then
            score=$(( score - 30 ))
        elif [[ "$used_pct" -gt 85 ]]; then
            score=$(( score - 15 ))
        elif [[ "$used_pct" -gt 75 ]]; then
            score=$(( score - 5 ))
        fi
        ANALYZER_RESULTS+=("storage|$score|${used_pct}% used (${free_kb}kB free)")
    else
        ANALYZER_RESULTS+=("storage|50|Storage data unavailable")
        score=50
    fi

    echo "$score"
}

##############################################
# Run the full performance analysis.
##############################################
analyzer_run() {
    log_section "Performance Analysis"

    echo ""
    log_info "Collecting device metrics..."

    local mem_score thermal_score cpu_score battery_score storage_score

    mem_score="$(_analyzer_memory)"
    thermal_score="$(_analyzer_thermal)"
    cpu_score="$(_analyzer_cpu)"
    battery_score="$(_analyzer_battery)"
    storage_score="$(_analyzer_storage)"

    # Calculate overall scores
    local perf_score=0
    local batt_score="$battery_score"
    local stability_score=0
    local count=0

    # Performance = CPU + Memory + Storage
    for s in "$cpu_score" "$mem_score" "$storage_score"; do
        perf_score=$(( perf_score + s ))
        count=$(( count + 1 ))
    done
    perf_score=$(( count > 0 ? perf_score / count : 0 ))

    # Stability = CPU + Thermal + Memory
    count=0
    for s in "$cpu_score" "$thermal_score" "$mem_score"; do
        stability_score=$(( stability_score + s ))
        count=$(( count + 1 ))
    done
    stability_score=$(( count > 0 ? stability_score / count : 0 ))

    # Overall health
    local overall=$(( (perf_score + batt_score + stability_score) / 3 ))

    echo ""
    echo "  ─────────────────────────────────────────────"
    echo "  Health Scores"
    echo "  ─────────────────────────────────────────────"
    _analyzer_print_score "Performance" "$perf_score"
    _analyzer_print_score "Battery" "$batt_score"
    _analyzer_print_score "Stability" "$stability_score"
    _analyzer_print_score "Overall Health" "$overall"
    echo ""

    # Detailed results
    echo "  Component Details:"
    for result in "${ANALYZER_RESULTS[@]}"; do
        local name val detail
        name="$(echo "$result" | cut -d'|' -f1)"
        val="$(echo "$result" | cut -d'|' -f2)"
        detail="$(echo "$result" | cut -d'|' -f3)"
        printf "    %-15s %3d/100  %s\n" "$name:" "$val" "$detail"
    done

    echo ""
    echo "  Recommendations:"
    if [[ "$overall" -lt 50 ]]; then
        echo "    • Device health is poor. Consider the following:"
    elif [[ "$overall" -lt 75 ]]; then
        echo "    • Device health is fair. Minor improvements available:"
    else
        echo "    • Device health is good. No major issues detected."
    fi

    if [[ "$storage_score" -lt 50 ]]; then
        echo "    • Free up storage space — device is nearly full"
    fi
    if [[ "$thermal_score" -lt 50 ]]; then
        echo "    • Device is running hot — close apps and let it cool"
    fi
    if [[ "$battery_score" -lt 50 ]]; then
        echo "    • Battery health needs attention — consider replacement"
    fi
    if [[ "$cpu_score" -lt 50 ]]; then
        echo "    • High CPU load — check for background processes"
    fi
    echo ""
}

##############################################
# Print a colored score line.
# Arguments:
#   $1: label
#   $2: score (0-100)
##############################################
_analyzer_print_score() {
    local label="$1" score="$2"
    local color bar_len filled

    bar_len=20
    filled=$(( score * bar_len / 100 ))
    [[ "$filled" -gt "$bar_len" ]] && filled="$bar_len"

    if [[ "$score" -ge 80 ]]; then
        color="\033[32m"
    elif [[ "$score" -ge 50 ]]; then
        color="\033[33m"
    else
        color="\033[31m"
    fi

    printf "  %-20s ${color}%3d/100\033[0m [" "$label" "$score"
    for ((i=0; i<bar_len; i++)); do
        [[ "$i" -lt "$filled" ]] && printf "#" || printf "·"
    done
    echo "]"
}
