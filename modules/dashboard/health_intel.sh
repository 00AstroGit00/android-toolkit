#!/data/data/com.termux/files/usr/bin/bash
#
# health_intel.sh — Health Intelligence Score
#
# Weighted multi-category health scoring model.
# Replaces simple health score with comprehensive
# assessment across 10 weighted categories.
#
# Part of the Android Toolkit Dashboard.

# Category weights (sums to 100)
HEALTH_WEIGHTS=(
    "performance:15"
    "battery:15"
    "security:15"
    "storage:10"
    "thermals:10"
    "network:10"
    "configuration:10"
    "plugins:5"
    "reliability:5"
    "compatibility:5"
)

##############################################
# Calculate individual category score (0-100).
# Arguments:
#   $1: category name
health_intel_category_score() {
    local cat="$1"
    case "$cat" in
        performance)
            local cpu mem
            cpu="$(status_get cpu_cores 2>/dev/null || echo "0")"
            mem="$(status_get mem_pct 2>/dev/null || echo "0")"
            mem="${mem//%/}"
            local score=100
            [[ "$mem" -gt 80 ]] && score=$(( score - 30 ))
            [[ "$mem" -gt 90 ]] && score=$(( score - 30 ))
            [[ "$cpu" -eq 0 ]] && score=$(( score - 20 ))
            echo "$score"
            ;;
        battery)
            local pct temp health
            pct="$(status_get battery_pct 2>/dev/null || echo "0")"
            temp="$(status_get battery_temp 2>/dev/null || echo "0")"
            health="$(status_get battery_health 2>/dev/null || echo "unknown")"
            local score=100
            [[ "$pct" -lt 20 ]] && score=$(( score - 30 ))
            [[ "$pct" -lt 10 ]] && score=$(( score - 30 ))
            if [[ "$(echo "$temp > 40" | bc -l 2>/dev/null)" -eq 1 ]]; then score=$(( score - 20 )); fi
            [[ "$health" == "poor" || "$health" == "dead" ]] && score=$(( score - 40 ))
            echo "$score"
            ;;
        security)
            local audit_score
            audit_score="$(health_intel_security_score 2>/dev/null || echo "70")"
            echo "$audit_score"
            ;;
        storage)
            local pct
            pct="$(status_get storage_pct 2>/dev/null || echo "0")"
            pct="${pct//%/}"
            local score=100
            [[ "$pct" -gt 80 ]] && score=$(( score - 30 ))
            [[ "$pct" -gt 90 ]] && score=$(( score - 40 ))
            echo "$score"
            ;;
        thermals)
            local temp
            temp="$(status_get thermal 2>/dev/null || echo "0")"
            local score=100
            if [[ "$(echo "$temp > 45" | bc -l 2>/dev/null)" -eq 1 ]]; then score=$(( score - 50 ))
            elif [[ "$(echo "$temp > 40" | bc -l 2>/dev/null)" -eq 1 ]]; then score=$(( score - 30 ))
            elif [[ "$(echo "$temp > 35" | bc -l 2>/dev/null)" -eq 1 ]]; then score=$(( score - 10 ))
            fi
            echo "$score"
            ;;
        network)
            local net
            net="$(status_get network 2>/dev/null || echo "disconnected")"
            if [[ "$net" == "disconnected" || -z "$net" ]]; then
                echo "30"
            elif [[ "$net" == "wifi"* || "$net" == "mobile"* ]]; then
                echo "90"
            else
                echo "70"
            fi
            ;;
        configuration)
            # Check key configuration settings
            local score=100
            local selinux
            selinux="$(status_get selinux 2>/dev/null || echo "?")"
            [[ "$selinux" != "Enforcing" ]] && score=$(( score - 30 ))
            local dev_opts
            dev_opts="$(status_get developer_options 2>/dev/null || echo "disabled")"
            [[ "$dev_opts" == "enabled" ]] && score=$(( score - 10 ))
            echo "$score"
            ;;
        plugins)
            local count
            count="$(typeset -f plugin_list &>/dev/null && plugin_list 2>/dev/null | wc -l || echo "0")"
            local score=90
            [[ "$count" -gt 10 ]] && score=$(( score - 20 ))
            echo "$score"
            ;;
        reliability)
            # Based on uptime and history
            local uptime_s
            uptime_s="$(status_get uptime_seconds 2>/dev/null || echo "0")"
            local score=70
            [[ "$uptime_s" -gt 86400 ]] && score=$(( score + 15 ))  # >1 day uptime
            [[ "$uptime_s" -gt 604800 ]] && score=$(( score + 10 )) # >1 week
            echo "$score"
            ;;
        compatibility)
            local android
            android="$(status_get android_version 2>/dev/null || echo "0")"
            local major="${android%%.*}"
            local score=80
            [[ "$major" -ge 14 ]] && score=$(( score + 10 ))
            [[ "$major" -ge 15 ]] && score=$(( score + 5 ))
            [[ "$major" -lt 13 ]] && score=$(( score - 30 ))
            echo "$score"
            ;;
        *)
            echo "70"
            ;;
    esac
}

##############################################
# Calculate security audit score.
health_intel_security_score() {
    local score=100
    local root usb_debug dev_opts unknown screen_lock encryption
    root="$(status_get root_status 2>/dev/null || echo "unknown")"
    usb_debug="$(status_get usb_debug 2>/dev/null || echo "unknown")"
    dev_opts="$(status_get developer_options 2>/dev/null || echo "unknown")"
    unknown="$(status_get unknown_sources 2>/dev/null || echo "unknown")"
    screen_lock="$(status_get lock_screen 2>/dev/null || echo "unknown")"
    encryption="$(status_get encryption 2>/dev/null || echo "unknown")"
    [[ "$root" == "yes" ]] && score=$(( score - 30 ))
    [[ "$usb_debug" == "enabled" ]] && score=$(( score - 10 ))
    [[ "$dev_opts" == "enabled" ]] && score=$(( score - 10 ))
    [[ "$unknown" == "enabled" ]] && score=$(( score - 10 ))
    [[ "$screen_lock" == "none" ]] && score=$(( score - 20 ))
    [[ "$encryption" == "disabled" ]] && score=$(( score - 20 ))
    echo "$score"
}

##############################################
# Calculate overall health score.
# Outputs: composite_score category_scores
health_intel_score() {
    local total_weight=0 total_score=0
    local results=""
    local entry name weight score contrib
    for entry in "${HEALTH_WEIGHTS[@]}"; do
        name="${entry%%:*}"
        weight="${entry#*:}"
        score="$(health_intel_category_score "$name")"
        contrib=$(( score * weight / 100 ))
        total_weight=$(( total_weight + weight ))
        total_score=$(( total_score + contrib ))
        results+="  $name: ${score} (weight ${weight}%, contrib ${contrib})"$'\n'
    done
    local composite=$(( total_score * 100 / total_weight ))
    echo "overall=$composite"
    echo "categories:"
    echo "$results"
}

##############################################
# Get health intelligence category scores as array.
health_intel_categories() {
    local entry name score
    for entry in "${HEALTH_WEIGHTS[@]}"; do
        name="${entry%%:*}"
        score="$(health_intel_category_score "$name")"
        echo "$name:$score"
    done
}

##############################################
# Render health intelligence page.
_page_render_health_intel() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Health Intelligence'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Weighted multi-category scoring'
    renderer_reset

    local row=$(( top + 2 ))
    local col="$left"

    # Calculate scores
    local overall
    overall="$(health_intel_score)"
    local overall_score
    overall_score="$(echo "$overall" | grep "^overall=" | cut -d= -f2)"

    # Overall score with large display
    renderer_cursor_goto "$row" "$col"
    renderer_bold
    local score_color
    if [[ "$overall_score" -ge 80 ]]; then score_color="$(theme_get success)"
    elif [[ "$overall_score" -ge 50 ]]; then score_color="$(theme_get warning)"
    else score_color="$(theme_get error)"
    fi
    renderer_fg_256 "$score_color"
    printf 'Device Reliability Index: %d/100' "$overall_score"
    renderer_reset

    # Bar visualization
    ((row++))
    renderer_cursor_goto "$row" "$col"
    local bar_w=30
    local filled=$(( overall_score * bar_w / 100 ))
    [[ "$filled" -gt "$bar_w" ]] && filled=$bar_w
    renderer_fg_256 "$score_color"
    local bi=0
    while (( bi < filled )); do printf '█'; ((bi++)); done
    renderer_fg_256 "$(theme_get muted)"
    while (( bi < bar_w )); do printf '░'; ((bi++)); done
    renderer_reset
    ((row += 2))

    # Category breakdown
    renderer_cursor_goto "$row" "$col"
    renderer_bold
    renderer_fg_256 "$(theme_get info)"
    printf 'Category Breakdown'
    renderer_reset
    ((row++))

    local entry name weight score cat_color
    for entry in "${HEALTH_WEIGHTS[@]}"; do
        [[ "$row" -ge $(( top + height - 1 )) ]] && break
        name="${entry%%:*}"
        weight="${entry#*:}"
        score="$(health_intel_category_score "$name")"

        if [[ "$score" -ge 80 ]]; then cat_color="$(theme_get success)"
        elif [[ "$score" -ge 50 ]]; then cat_color="$(theme_get warning)"
        else cat_color="$(theme_get error)"
        fi

        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$cat_color"
        printf ' %-15s %3d/100' "$name" "$score"
        renderer_reset
        # Mini bar
        renderer_fg_256 "$cat_color"
        local mini_filled=$(( score * 10 / 100 ))
        local mi=0
        while (( mi < mini_filled )); do printf '█'; ((mi++)); done
        renderer_fg_256 "$(theme_get muted)"
        while (( mi < 10 )); do printf '░'; ((mi++)); done
        renderer_reset
        renderer_fg_256 "$(theme_get muted)"
        printf ' (w:%s%%)' "$weight"
        renderer_reset
        ((row++))
    done

    # Legend
    ((row++))
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get success)"
    printf ' █ 80-100 Excellent'
    renderer_reset
    renderer_fg_256 "$(theme_get warning)"
    printf '  █ 50-79 Warning'
    renderer_reset
    renderer_fg_256 "$(theme_get error)"
    printf '  █ 0-49 Critical'
    renderer_reset
}

_page_key_health_intel() {
    local key="$1"
    case "$key" in
        "r"|"R")
            DASHBOARD_REDRAW_NEEDED=true
            ;;
    esac
}
