#!/data/data/com.termux/files/usr/bin/bash
#
# widgets.sh — Dashboard Home Widgets
#
# Renders live data cards on the home dashboard:
#   - Device info card
#   - Battery card
#   - Memory card
#   - Storage card
#   - CPU card
#   - Network card
#   - Security card
#   - Recent activity
#
# Part of the Android Toolkit Dashboard.

WIDGET_REFRESH_INTERVAL=3

##############################################
# Render a labeled value card.
# Arguments:
#   $1: row (top)
#   $2: col (left)
#   $3: width
#   $4: title
#   $5: value (main large text)
#   $6: subtitle (small below, optional)
#   $7: status color (optional, for the value)
widget_label_card() {
    local row="$1" col="$2" width="$3" title="$4" value="$5" subtitle="${6:-}" val_color="${7:-}"

    local box_h=4
    # Background
    renderer_fill_rect "$row" "$col" "$box_h" "$width" "$(theme_get card_bg)"

    # Border
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get card_border)"
    printf '%s' "$RENDERER_TL"
    local i=0
    while (( i < width - 2 )); do printf '%s' "$RENDERER_HLINE"; ((i++)); done
    printf '%s' "$RENDERER_TR"

    renderer_cursor_goto "$((row + box_h - 1))" "$col"
    printf '%s' "$RENDERER_BL"
    i=0
    while (( i < width - 2 )); do printf '%s' "$RENDERER_HLINE"; ((i++)); done
    printf '%s' "$RENDERER_BR"

    # Title
    renderer_cursor_goto "$row" "$((col + 2))"
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    printf '%s' "$title"
    renderer_reset

    # Value
    renderer_cursor_goto "$((row + 2))" "$((col + 2))"
    if [[ -n "$val_color" ]]; then
        renderer_fg_256 "$val_color"
    else
        renderer_fg_256 "$(theme_get card_fg)"
    fi
    renderer_bold
    printf '%s' "$value"
    renderer_reset

    # Subtitle
    if [[ -n "$subtitle" ]]; then
        renderer_cursor_goto "$((row + 3))" "$((col + 2))"
        renderer_fg_256 "$(theme_get muted)"
        printf '%s' "$subtitle"
        renderer_reset
    fi
}

##############################################
# Render the battery widget.
# Arguments:
#   $1: row
#   $2: col
#   $3: width
widget_battery() {
    local row="$1" col="$2" width="$3"
    local pct temp health plugged
    pct="$(status_get battery_pct)"
    temp="$(status_get battery_temp)"
    health="$(status_get battery_health)"
    plugged="$(status_get battery_plugged)"

    local val_color display
    if [[ "$pct" == "?" ]]; then
        val_color="$(theme_get muted)"
        display="N/A"
    elif [[ "$pct" -lt 20 ]]; then
        val_color="$(theme_get error)"
        display="${pct}%"
    elif [[ "$pct" -lt 50 ]]; then
        val_color="$(theme_get warning)"
        display="${pct}%"
    else
        val_color="$(theme_get success)"
        display="${pct}%"
    fi

    local subtitle=""
    [[ "$temp" != "?" ]] && subtitle="${temp}°C"
    [[ "$plugged" == "true" ]] && subtitle+=" ⚡ Charging"

    widget_label_card "$row" "$col" "$width" "BATTERY" "$display" "$subtitle" "$val_color"

    # Mini progress bar inside the card
    if [[ "$pct" != "?" ]]; then
        renderer_draw_progress_bar "$((row + 4))" "$((col + 2))" "$((width - 4))" "$pct"
    fi
}

##############################################
# Render the memory widget.
# Arguments:
#   $1: row
#   $2: col
#   $3: width
widget_memory() {
    local row="$1" col="$2" width="$3"
    local pct total avail
    pct="$(status_get mem_pct)"
    total="$(status_get mem_total_mb)"
    avail="$(status_get mem_avail_mb)"

    local val_color display
    if [[ "$pct" == "?" ]]; then
        val_color="$(theme_get muted)"
        display="N/A"
    elif [[ "$pct" -gt 85 ]]; then
        val_color="$(theme_get error)"
        display="${pct}%"
    elif [[ "$pct" -gt 70 ]]; then
        val_color="$(theme_get warning)"
        display="${pct}%"
    else
        val_color="$(theme_get success)"
        display="${pct}%"
    fi

    local subtitle=""
    [[ "$avail" != "?" ]] && subtitle="Avail: ${avail}MB"
    [[ "$total" != "?" ]] && subtitle+=" / ${total}MB"

    widget_label_card "$row" "$col" "$width" "MEMORY" "$display" "$subtitle" "$val_color"

    if [[ "$pct" != "?" ]]; then
        renderer_draw_progress_bar "$((row + 4))" "$((col + 2))" "$((width - 4))" "$pct"
    fi
}

##############################################
# Render the storage widget.
# Arguments:
#   $1: row
#   $2: col
#   $3: width
widget_storage() {
    local row="$1" col="$2" width="$3"
    local pct used total
    pct="$(status_get storage_pct)"
    used="$(status_get storage_used)"
    total="$(status_get storage_total)"

    local val_color display
    if [[ -z "$pct" || "$pct" == "?" ]]; then
        val_color="$(theme_get muted)"
        display="N/A"
    elif [[ "$pct" -gt 90 ]]; then
        val_color="$(theme_get error)"
        display="${pct}%"
    elif [[ "$pct" -gt 75 ]]; then
        val_color="$(theme_get warning)"
        display="${pct}%"
    else
        val_color="$(theme_get success)"
        display="${pct}%"
    fi

    local subtitle=""
    [[ -n "$used" ]] && subtitle="Used: $used"
    [[ -n "$total" ]] && subtitle+=" / $total"

    widget_label_card "$row" "$col" "$width" "STORAGE" "$display" "$subtitle" "$val_color"

    if [[ -n "$pct" && "$pct" != "?" ]]; then
        renderer_draw_progress_bar "$((row + 4))" "$((col + 2))" "$((width - 4))" "$pct"
    fi
}

##############################################
# Render the CPU widget.
# Arguments:
#   $1: row
#   $2: col
#   $3: width
widget_cpu() {
    local row="$1" col="$2" width="$3"
    local cores max_hz
    cores="$(status_get cpu_cores)"
    max_hz="$(status_get cpu_max_hz)"

    local display
    if [[ "$cores" != "?" ]]; then
        display="${cores} cores"
    else
        display="N/A"
    fi

    local subtitle=""
    [[ "$max_hz" != "?" ]] && subtitle="Max: ${max_hz} MHz"

    widget_label_card "$row" "$col" "$width" "CPU" "$display" "$subtitle" "$(theme_get accent)"
}

##############################################
# Render the network widget.
# Arguments:
#   $1: row
#   $2: col
#   $3: width
widget_network() {
    local row="$1" col="$2" width="$3"
    local network
    network="$(status_get network)"

    local val_color
    case "$network" in
        WiFi)    val_color="$(theme_get success)" ;;
        Mobile)  val_color="$(theme_get warning)" ;;
        *)       val_color="$(theme_get error)"; network="Disconnected" ;;
    esac

    widget_label_card "$row" "$col" "$width" "NETWORK" "$network" "" "$val_color"
}

##############################################
# Render the security widget.
# Arguments:
#   $1: row
#   $2: col
#   $3: width
widget_security() {
    local row="$1" col="$2" width="$3"
    local patch selinux root
    patch="$(status_get security_patch)"
    selinux="$(status_get selinux)"
    root="$(status_get root)"

    local display val_color
    if [[ "$root" == "true" ]]; then
        display="Rooted"
        val_color="$(theme_get warning)"
    else
        display="Secure"
        val_color="$(theme_get success)"
    fi

    local subtitle="Patch: ${patch:-?}"

    widget_label_card "$row" "$col" "$width" "SECURITY" "$display" "$subtitle" "$val_color"
}

##############################################
# Render the device info widget.
# Arguments:
#   $1: row
#   $2: col
#   $3: width
widget_device_info() {
    local row="$1" col="$2" width="$3"
    local model android sdk abi samsung oneui
    model="$(status_get model)"
    android="$(status_get android)"
    sdk="$(status_get sdk)"
    abi="$(status_get abi)"
    samsung="$(status_get is_samsung)"
    oneui="$(status_get oneui)"

    widget_label_card "$row" "$col" "$width" "DEVICE" "$model" "${android} (API ${sdk}) · ${abi}" "$(theme_get accent)"

    # If Samsung, show One UI version
    if [[ "$samsung" == "true" && "$oneui" != "N/A" ]]; then
        renderer_cursor_goto "$((row + 1))" "$((col + width - 12))"
        renderer_fg_256 "$(theme_get success)"
        renderer_dim
        printf 'One UI %s' "$oneui"
        renderer_reset
    fi
}

##############################################
# Render the temperature widget.
# Arguments:
#   $1: row
#   $2: col
#   $3: width
widget_temperature() {
    local row="$1" col="$2" width="$3"
    local thermal bat_temp
    thermal="$(status_get thermal)"
    bat_temp="$(status_get battery_temp)"

    local display val_color
    if [[ "$thermal" != "?" ]]; then
        display="${thermal}°C"
        if (( $(echo "$thermal > 60" | bc -l 2>/dev/null || echo 0) )); then
            val_color="$(theme_get error)"
        elif (( $(echo "$thermal > 45" | bc -l 2>/dev/null || echo 0) )); then
            val_color="$(theme_get warning)"
        else
            val_color="$(theme_get success)"
        fi
    elif [[ "$bat_temp" != "?" ]]; then
        display="${bat_temp}°C"
        val_color="$(theme_get info)"
    else
        display="N/A"
        val_color="$(theme_get muted)"
    fi

    widget_label_card "$row" "$col" "$width" "TEMPERATURE" "$display" "Device temp" "$val_color"
}

##############################################
# Render the toolkit version widget.
# Arguments:
#   $1: row
#   $2: col
#   $3: width
widget_version() {
    local row="$1" col="$2" width="$3"
    local ver backend
    ver="$(status_get version)"
    backend="$(status_get backend)"

    widget_label_card "$row" "$col" "$width" "TOOLKIT" "v${ver}" "Backend: ${backend}" "$(theme_get info)"
}

##############################################
# Render the recent activity / quick actions widget.
# Arguments:
#   $1: row
#   $2: col
#   $3: width
#   $4: height
widget_recent_activity() {
    local row="$1" col="$2" width="$3" height="$4"

    renderer_fill_rect "$row" "$col" "$height" "$width" "$(theme_get card_bg)"

    # Border
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get card_border)"
    printf '%s' "$RENDERER_TL"
    local i=0
    while (( i < width - 2 )); do printf '%s' "$RENDERER_HLINE"; ((i++)); done
    printf '%s' "$RENDERER_TR"

    renderer_cursor_goto "$((row + height - 1))" "$col"
    printf '%s' "$RENDERER_BL"
    i=0
    while (( i < width - 2 )); do printf '%s' "$RENDERER_HLINE"; ((i++)); done
    printf '%s' "$RENDERER_BR"

    # Title
    renderer_cursor_goto "$row" "$((col + 2))"
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    printf 'QUICK ACTIONS'
    renderer_reset

    # Action items
    local actions=(
        "F5"  "Refresh Dashboard"
        "r"   "Run Doctor"
        "b"   "Run Benchmark"
        "s"   "Security Audit"
        "p"   "Profile Manager"
    )
    local ay=$(( row + 2 ))
    local j=0
    while (( j < ${#actions[@]} )); do
        local key="${actions[j]}"
        local desc="${actions[j+1]}"
        renderer_cursor_goto "$ay" "$((col + 2))"
        renderer_fg_256 "$(theme_get accent)"
        renderer_bold
        printf ' %s ' "$key"
        renderer_reset
        renderer_fg_256 "$(theme_get card_fg)"
        printf '%s' "$desc"
        renderer_reset
        ((ay++))
        ((j += 2))
    done
}
