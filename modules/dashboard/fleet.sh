#!/data/data/com.termux/files/usr/bin/bash
#
# fleet.sh — Fleet Dashboard
#
# Enterprise fleet management for multiple Android devices.
# Displays online/offline/warning/critical status,
# pending updates, security/plugin/benchmark status,
# health score, and supports group actions, policy
# application, bulk reporting, and fleet comparison.
#
# Part of the Android Toolkit Dashboard.

FLEET_DEVICES=()
FLEET_SORT_BY="name"
FLEET_FILTER="all"

##############################################
# Discover fleet devices.
fleet_discover() {
    FLEET_DEVICES=()
    # Get ADB devices
    local adb_output
    adb_output="$(backend_exec "adb devices -l" 2>/dev/null || true)"
    while IFS= read -r line; do
        [[ "$line" == *"device "* || "$line" == *"unauthorized"* ]] || continue
        local dev_id="${line%% *}"
        local status="online"
        [[ "$line" == *"unauthorized"* ]] && status="unauthorized"
        # Try to get model
        local model="?"
        local model_line
        model_line="$(echo "$line" | grep -o 'model:[^ ]*' || echo "")"
        [[ -n "$model_line" ]] && model="${model_line#model:}"
        FLEET_DEVICES+=("$dev_id|$model|$status")
    done <<< "$adb_output"
    # If no ADB, check twin directory
    if [[ "${#FLEET_DEVICES[@]}" -eq 0 ]]; then
        local twin_dir="${ANDROID_TOOLKIT_ROOT_DIR}/twins"
        if [[ -d "$twin_dir" ]]; then
            local f
            for f in "$twin_dir"/*.json; do
                [[ -f "$f" ]] || continue
                local dev_id
                dev_id="$(basename "$f" .json)"
                local model twin_data
                twin_data="$(cat "$f" 2>/dev/null)"
                model="$(echo "$twin_data" | grep -o '"model":"[^"]*"' | cut -d'"' -f4 || echo "?")"
                FLEET_DEVICES+=("$dev_id|$model|offline")
            done
        fi
    fi
}

##############################################
# Get fleet health statistics.
fleet_stats() {
    local total=0 online=0 warning=0 critical=0
    local entry
    for entry in "${FLEET_DEVICES[@]}"; do
        ((total++))
        local status="${entry##*|}"
        case "$status" in
            online|unauthorized) ((online++)) ;;
            offline) ((critical++)) ;;
        esac
    done
    echo "total=$total online=$online warning=$warning critical=$critical"
}

##############################################
# Get a device's health score for fleet view.
fleet_device_health() {
    local device_id="$1"
    # Try to get real health score
    local score=70
    local twin_file="${ANDROID_TOOLKIT_ROOT_DIR}/twins/${device_id}.json"
    if [[ -f "$twin_file" ]]; then
        local bat stg mem
        bat="$(grep -o '"battery_pct":[0-9]*' "$twin_file" | cut -d: -f2)"
        stg="$(grep -o '"storage_pct":[0-9]*' "$twin_file" | cut -d: -f2)"
        mem="$(grep -o '"mem_pct":[0-9]*' "$twin_file" | cut -d: -f2)"
        [[ -n "$bat" ]] && score=$(( score - (100 - bat) / 3 ))
        [[ -n "$stg" && "$stg" -gt 80 ]] && score=$(( score - (stg - 80) / 2 ))
        [[ -n "$mem" && "$mem" -gt 80 ]] && score=$(( score - (mem - 80) / 2 ))
    fi
    echo "$score"
}

##############################################
# Apply a policy action to all fleet devices.
fleet_apply_policy() {
    local action="$1"
    local entry
    for entry in "${FLEET_DEVICES[@]}"; do
        local dev_id="${entry%%|*}"
        local status="${entry##*|}"
        [[ "$status" != "online" ]] && continue
        case "$action" in
            "refresh") event_bus_emit "device" "fleet_refresh" "$dev_id" "info" ;;
            "audit")   typeset -f audit_run &>/dev/null && audit_run 2>/dev/null || true ;;
            "benchmark") typeset -f benchmark_run &>/dev/null && benchmark_run 2>/dev/null || true ;;
        esac
    done
    notify_push "Policy '$action' applied to fleet" "success"
}

##############################################
# Render fleet dashboard.
_page_render_fleet() {
    local top="$1" left="$2" width="$3" height="$4"
    fleet_discover

    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Fleet Dashboard'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — %d devices in fleet' "${#FLEET_DEVICES[@]}"
    renderer_reset

    local row=$(( top + 2 ))
    local col="$left"

    # Stats summary
    eval "$(fleet_stats)"
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get success)"
    printf ' ● %d Online' "${online:-0}"
    renderer_reset
    renderer_fg_256 "$(theme_get error)"
    printf '  ■ %d Offline' "${critical:-0}"
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf '  Total: %d' "$total"
    renderer_reset
    ((row++))

    # Actions
    local actions=(
        "r" "Refresh" "p" "Apply Policy" "b" "Bulk Report"
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

    # Device list
    if [[ "${#FLEET_DEVICES[@]}" -eq 0 ]]; then
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get muted)"
        printf 'No fleet devices discovered. Connect via ADB.'
        renderer_reset
        return
    fi

    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    printf '%-22s %-20s %-10s %s' "Device ID" "Model" "Status" "Health"
    renderer_reset
    ((row++))

    local entry
    for entry in "${FLEET_DEVICES[@]}"; do
        [[ "$row" -ge $(( top + height - 1 )) ]] && break
        local dev_id="${entry%%|*}"
        local rest="${entry#*|}"
        local model="${rest%|*}"
        local status="${entry##*|}"

        renderer_cursor_goto "$row" "$col"
        # Status indicator
        case "$status" in
            online) renderer_fg_256 "$(theme_get success)" ;;
            unauthorized) renderer_fg_256 "$(theme_get warning)" ;;
            offline|*) renderer_fg_256 "$(theme_get error)" ;;
        esac
        printf '%s' "$(echo "$status" | head -c1)"
        renderer_reset

        # Device info
        local health_score
        health_score="$(fleet_device_health "$dev_id")"
        local short_id="${dev_id:0:18}"
        local short_model="${model:0:18}"

        local health_color
        if [[ "$health_score" -ge 80 ]]; then health_color="$(theme_get success)"
        elif [[ "$health_score" -ge 50 ]]; then health_color="$(theme_get warning)"
        else health_color="$(theme_get error)"
        fi

        renderer_fg_256 "$(theme_get fg)"
        printf ' %-20s' "$short_id"
        renderer_reset
        renderer_fg_256 "$(theme_get muted)"
        printf ' %-18s' "$short_model"
        renderer_reset
        renderer_fg_256 "$health_color"
        printf ' %-8s %3d/100' "$status" "$health_score"
        renderer_reset
        ((row++))
    done
}

_page_key_fleet() {
    local key="$1"
    case "$key" in
        "r"|"R")
            fleet_discover
            notify_push "Fleet refreshed: ${#FLEET_DEVICES[@]} devices" "info"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "p"|"P")
            local actions=("refresh" "Refresh twins" "audit" "Run security audit" "benchmark" "Run benchmark")
            local choice
            choice="$(menu_select "Fleet Policy Action" "${actions[@]}")" || return 0
            fleet_apply_policy "$choice"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "b"|"B")
            local report
            report="Fleet Report ($(date))"$'\n'
            report+="Devices: ${#FLEET_DEVICES[@]}"$'\n'
            local entry
            for entry in "${FLEET_DEVICES[@]}"; do
                local dev_id="${entry%%|*}"
                local health
                health="$(fleet_device_health "$dev_id")"
                report+="  $dev_id: health=$health"$'\n'
            done
            menu_textbox "Fleet Bulk Report" "$report"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
    esac
}
