#!/data/data/com.termux/files/usr/bin/bash
#
# digital_twin.sh — Digital Twin Engine
#
# Maintains a complete virtual representation of every
# connected Android device, automatically updated after
# every operation. Includes hardware/software inventory,
# optimization history, benchmark/security history,
# battery degradation, storage growth, thermal history,
# and rollback checkpoints.
#
# Part of the Android Toolkit Dashboard.

TWIN_DIR="${ANDROID_TOOLKIT_ROOT_DIR}/twins"
TWIN_ACTIVE_DEVICE=""
TWIN_COMPARE_MODE=false

##############################################
# Initialize the twin directory.
twin_init() {
    mkdir -p "$TWIN_DIR" 2>/dev/null || true
}

##############################################
# Get twin file path for a device.
twin_path() {
    local device_id="${1:-$(twin_active_device)}"
    echo "${TWIN_DIR}/${device_id}.json"
}

##############################################
# Get or set active device.
twin_active_device() {
    if [[ -z "$TWIN_ACTIVE_DEVICE" ]]; then
        TWIN_ACTIVE_DEVICE="$(status_get device_id 2>/dev/null || echo "default")"
    fi
    echo "$TWIN_ACTIVE_DEVICE"
}

##############################################
# Load twin data for a device.
twin_load() {
    local device_id="${1:-$(twin_active_device)}"
    local path="${TWIN_DIR}/${device_id}.json"
    if [[ -f "$path" ]]; then
        cat "$path"
    else
        echo "{}"
    fi
}

##############################################
# Save twin data for a device.
twin_save() {
    local device_id="$1" data="$2"
    local path="${TWIN_DIR}/${device_id}.json"
    echo "$data" > "$path" 2>/dev/null || true
}

##############################################
# Update the digital twin with current device state.
twin_update() {
    local device_id="${1:-$(twin_active_device)}"
    local current
    current="$(twin_load "$device_id")"
    local ts
    ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    # Gather current state
    local model android ver oneui
    model="$(status_get model 2>/dev/null || echo "unknown")"
    android="$(status_get android_version 2>/dev/null || echo "?")"
    ver="$(status_get version 2>/dev/null || echo "?")"
    oneui="$(status_get oneui_version 2>/dev/null || echo "?")"

    local bat_pct bat_temp bat_health
    bat_pct="$(status_get battery_pct 2>/dev/null || echo "0")"
    bat_temp="$(status_get battery_temp 2>/dev/null || echo "0")"
    bat_health="$(status_get battery_health 2>/dev/null || echo "unknown")"

    local thermal storage_pct mem_pct
    thermal="$(status_get thermal 2>/dev/null || echo "0")"
    storage_pct="$(status_get storage_pct 2>/dev/null || echo "0")"
    mem_pct="$(status_get mem_pct 2>/dev/null || echo "0")"

    local security_patch selinux
    security_patch="$(status_get security_patch 2>/dev/null || echo "?")"
    selinux="$(status_get selinux 2>/dev/null || echo "?")"

    # Build JSON safely via text
    local data
    data="$current"

    # Update top-level fields
    data="$(echo "$data" | sed 's/{"last_updated":.*}/{"last_updated":"'"$ts"'"}/' 2>/dev/null || echo "{}")"

    # Create structured data using printf
    local new_data
    new_data=$(cat << TWINEOF
{
  "device_id": "$device_id",
  "last_updated": "$ts",
  "first_seen": "$(echo "$current" | grep -o '"first_seen":"[^"]*"' | cut -d'"' -f4 || echo "$ts")",
  "hardware": {
    "model": "$model",
    "android": "$android",
    "oneui": "$oneui",
    "security_patch": "$security_patch",
    "selinux": "$selinux"
  },
  "state": {
    "battery_pct": $bat_pct,
    "battery_temp": $bat_temp,
    "battery_health": "$bat_health",
    "thermal": $thermal,
    "storage_pct": $storage_pct,
    "mem_pct": $mem_pct
  },
  "history": {
    "optimizations": $(twin_history_array "$device_id" "optimization"),
    "benchmarks": $(twin_history_array "$device_id" "benchmark"),
    "security_scans": $(twin_history_array "$device_id" "security"),
    "package_changes": $(twin_history_array "$device_id" "package"),
    "reports": $(twin_history_array "$device_id" "report"),
    "rollbacks": $(twin_history_array "$device_id" "rollback")
  },
  "toolkit_version": "$ver"
}
TWINEOF
)
    twin_save "$device_id" "$new_data"
    event_bus_emit "device" "twin_updated" "$device_id" "info"
}

##############################################
# Get a history array from twin data.
twin_history_array() {
    local device_id="$1" category="$2"
    local path="${TWIN_DIR}/${device_id}.json"
    if [[ -f "$path" ]]; then
        grep -o "\"${category}\":\[.*?\]" "$path" 2>/dev/null || echo "[]"
    else
        echo "[]"
    fi
}

##############################################
# Add an entry to device history.
twin_add_history() {
    local device_id="${1:-$(twin_active_device)}" category="$2" entry="$3"
    local path="${TWIN_DIR}/${device_id}.json"
    local data
    data="$(twin_load "$device_id")"
    # Append to history array
    local hist_key="\"${category}\""
    local existing
    existing="$(echo "$data" | grep -o "\"${category}\":\[[^]]*\]" | head -1)"
    if [[ -n "$existing" ]]; then
        # Append to existing array
        local new_arr="${existing%\]}"
        new_arr="${new_arr},${entry}]"
        data="${data//$existing/$new_arr}"
    else
        # Create new array
        data="${data%\}*}"
        data="${data}, \"${category}\":[${entry}]}"
    fi
    twin_save "$device_id" "$data"
}

##############################################
# Compare two twins.
twin_compare() {
    local id1="$1" id2="$2"
    local d1 d2
    d1="$(twin_load "$id1")"
    d2="$(twin_load "$id2")"
    echo "=== Twin Comparison: $id1 vs $id2 ==="
    echo "Last Updated: $(echo "$d1" | grep -o '"last_updated":"[^"]*"' | cut -d'"' -f4) vs $(echo "$d2" | grep -o '"last_updated":"[^"]*"' | cut -d'"' -f4)"
    echo "Model: $(echo "$d1" | grep -o '"model":"[^"]*"' | cut -d'"' -f4) vs $(echo "$d2" | grep -o '"model":"[^"]*"' | cut -d'"' -f4)"
    echo "Android: $(echo "$d1" | grep -o '"android":"[^"]*"' | cut -d'"' -f4) vs $(echo "$d2" | grep -o '"android":"[^"]*"' | cut -d'"' -f4)"
    echo "Battery: $(echo "$d1" | grep -o '"battery_pct":[^,}]*' | cut -d: -f2)% vs $(echo "$d2" | grep -o '"battery_pct":[^,}]*' | cut -d: -f2)%"
    echo "Storage: $(echo "$d1" | grep -o '"storage_pct":[^,}]*' | cut -d: -f2)% vs $(echo "$d2" | grep -o '"storage_pct":[^,}]*' | cut -d: -f2)%"
    echo "Thermal: $(echo "$d1" | grep -o '"thermal":[^,}]*' | cut -d: -f2)°C vs $(echo "$d2" | grep -o '"thermal":[^,}]*' | cut -d: -f2)°C"
}

##############################################
# Render digital twin page.
_page_render_digital_twin() {
    local top="$1" left="$2" width="$3" height="$4"
    local device_id="${TWIN_ACTIVE_DEVICE:-$(twin_active_device)}"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Digital Twin'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — %s' "$device_id"
    renderer_reset

    local row=$(( top + 2 ))
    local col="$left"

    # Quick actions
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get info)"
    renderer_bold
    printf ' [u] Update  [c] Compare  [e] Export  [r] Reset'
    renderer_reset
    ((row += 2))

    local data
    data="$(twin_load "$device_id")"
    if [[ "$data" == "{}" || -z "$data" ]]; then
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get muted)"
        printf 'No twin data yet. Press [u] to update.'
        renderer_reset
        return
    fi

    # Hardware section
    renderer_cursor_goto "$row" "$col"
    renderer_bold
    renderer_fg_256 "$(theme_get info)"
    printf 'Hardware'
    renderer_reset
    ((row++))
    local model android oneui spatch selinux
    model="$(echo "$data" | grep -o '"model":"[^"]*"' | cut -d'"' -f4)"
    android="$(echo "$data" | grep -o '"android":"[^"]*"' | cut -d'"' -f4)"
    oneui="$(echo "$data" | grep -o '"oneui":"[^"]*"' | cut -d'"' -f4)"
    spatch="$(echo "$data" | grep -o '"security_patch":"[^"]*"' | cut -d'"' -f4)"
    selinux="$(echo "$data" | grep -o '"selinux":"[^"]*"' | cut -d'"' -f4)"
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get fg)"
    printf '  Model: %s' "$model"
    renderer_reset
    ((row++))
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get fg)"
    printf '  Android: %s  One UI: %s' "$android" "$oneui"
    renderer_reset
    ((row++))
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get fg)"
    printf '  Security: %s  SELinux: %s' "$spatch" "$selinux"
    renderer_reset
    ((row++))

    # State section
    renderer_cursor_goto "$row" "$col"
    renderer_bold
    renderer_fg_256 "$(theme_get info)"
    printf 'Current State'
    renderer_reset
    ((row++))
    local bat_pct bat_temp bat_health thermal storage mem
    bat_pct="$(echo "$data" | grep -o '"battery_pct":[^,}]*' | cut -d: -f2)"
    bat_temp="$(echo "$data" | grep -o '"battery_temp":[^,}]*' | cut -d: -f2)"
    bat_health="$(echo "$data" | grep -o '"battery_health":"[^"]*"' | cut -d'"' -f4)"
    thermal="$(echo "$data" | grep -o '"thermal":[^,}]*' | cut -d: -f2)"
    storage="$(echo "$data" | grep -o '"storage_pct":[^,}]*' | cut -d: -f2)"
    mem="$(echo "$data" | grep -o '"mem_pct":[^,}]*' | cut -d: -f2)"

    local bat_color
    if [[ "$bat_pct" -gt 80 ]]; then bat_color="$(theme_get success)"
    elif [[ "$bat_pct" -gt 50 ]]; then bat_color="$(theme_get warning)"
    else bat_color="$(theme_get error)"
    fi
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$bat_color"
    printf '  Battery: %d%%  Temp: %s°C  Health: %s' "$bat_pct" "$bat_temp" "$bat_health"
    renderer_reset
    ((row++))
    local th_color
    if [[ "$(echo "$thermal > 45" | bc -l 2>/dev/null)" -eq 1 ]]; then th_color="$(theme_get error)"
    elif [[ "$(echo "$thermal > 35" | bc -l 2>/dev/null)" -eq 1 ]]; then th_color="$(theme_get warning)"
    else th_color="$(theme_get success)"
    fi
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$th_color"
    printf '  Thermal: %s°C  Storage: %d%%  Memory: %d%%' "$thermal" "$storage" "$mem"
    renderer_reset
    ((row++))

    # History counts
    ((row++))
    renderer_cursor_goto "$row" "$col"
    renderer_bold
    renderer_fg_256 "$(theme_get info)"
    printf 'History'
    renderer_reset
    ((row++))
    local cats=("optimizations" "benchmarks" "security_scans" "package_changes" "reports" "rollbacks")
    for cat in "${cats[@]}"; do
        local count
        count="$(echo "$data" | grep -o "\"${cat}\":\[[^]]*\]" | grep -o ',' | wc -l || echo "0")"
        [[ "$count" -eq 0 ]] && count="$(echo "$data" | grep -o "\"${cat}\":\[[^]]*\]" | grep -c '.' || echo "0")"
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get muted)"
        printf '  %s: %d entries' "$cat" "$count"
        renderer_reset
        ((row++))
    done

    # Last updated
    local last_up
    last_up="$(echo "$data" | grep -o '"last_updated":"[^"]*"' | cut -d'"' -f4)"
    ((row++))
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    printf 'Last updated: %s' "$last_up"
    renderer_reset
}

_page_key_digital_twin() {
    local key="$1"
    case "$key" in
        "u"|"U")
            twin_update
            notify_push "Digital twin updated" "success"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "c"|"C")
            TWIN_COMPARE_MODE=true
            local id2
            id2="$(menu_input "Twin Compare" "Second device ID:")" || { TWIN_COMPARE_MODE=false; return 0; }
            local output
            output="$(twin_compare "$(twin_active_device)" "$id2")"
            menu_textbox "Twin Comparison" "$output"
            TWIN_COMPARE_MODE=false
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "e"|"E")
            local data
            data="$(twin_load)"
            local ts
            ts="$(date +%Y%m%d_%H%M%S)"
            local file="${TWIN_DIR}/export_${ts}.json"
            echo "$data" > "$file" 2>/dev/null || true
            notify_push "Twin exported: $file" "success"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "r"|"R")
            if menu_yesno "Reset Twin" "Reset digital twin data for this device?"; then
                local device_id
                device_id="$(twin_active_device)"
                echo "{}" > "${TWIN_DIR}/${device_id}.json" 2>/dev/null || true
                notify_push "Twin reset" "info"
            fi
            DASHBOARD_REDRAW_NEEDED=true
            ;;
    esac
}
