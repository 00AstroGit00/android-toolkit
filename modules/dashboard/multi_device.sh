#!/data/data/com.termux/files/usr/bin/bash
#
# multi_device.sh — Multi-Device Workspace
#
# Manages multiple connected devices simultaneously:
#   - Device cards overview
#   - Multi-select and group operations
#   - Broadcast commands
#   - Parallel execution
#
# Part of the Android Toolkit Dashboard.

MULTI_DEVICES=()
MULTI_SELECTED=()
MULTI_BROADCAST_RESULTS=()

##############################################
# Discover connected devices.
multi_device_discover() {
    MULTI_DEVICES=()
    local output
    output="$(devices_list 2>&1 || true)"
    while IFS= read -r line; do
        local serial
        serial="$(echo "$line" | awk '{print $1}')"
        [[ -n "$serial" && "$serial" != "List" && "$serial" != "No" ]] && MULTI_DEVICES+=("$serial")
    done <<< "$output"
    [[ "${#MULTI_DEVICES[@]}" -eq 0 ]] && MULTI_DEVICES=("localhost")
}

##############################################
# Toggle selection of a device by index.
multi_device_toggle() {
    local idx="$1"
    local serial="${MULTI_DEVICES[$idx]:-}"
    [[ -z "$serial" ]] && return
    local i
    for i in "${!MULTI_SELECTED[@]}"; do
        [[ "${MULTI_SELECTED[$i]}" == "$serial" ]] && { unset 'MULTI_SELECTED[$i]'; MULTI_SELECTED=("${MULTI_SELECTED[@]}"); return; }
    done
    MULTI_SELECTED+=("$serial")
}

##############################################
# Check if a device is selected.
multi_device_is_selected() {
    local serial="$1"
    local i
    for i in "${MULTI_SELECTED[@]}"; do
        [[ "$i" == "$serial" ]] && return 0
    done
    return 1
}

##############################################
# Broadcast a command to all selected devices.
multi_device_broadcast() {
    local cmd="$1"
    local results=()
    local dev
    for dev in "${MULTI_SELECTED[@]}"; do
        local out
        out="$(devices_set_active "$dev" 2>/dev/null && eval "$cmd" 2>&1 || echo "FAILED")"
        results+=("$dev: $out")
    done
    MULTI_BROADCAST_RESULTS=("${results[@]}")
}

##############################################
# Render multi-device workspace.
_page_render_multi_device() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Multi-Device Workspace'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Manage %d device(s)' "${#MULTI_DEVICES[@]}"
    renderer_reset

    multi_device_discover
    local row=$(( top + 2 ))
    local col="$left"

    # Column headers
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    renderer_cursor_goto "$row" "$col"
    printf '%-4s %-20s %-10s %-10s %-8s %-8s' "Sel" "Device" "Backend" "Android" "Battery" "Status"
    renderer_reset
    ((row++))

    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get card_border)"
    printf '%*s' "$width" "" | tr ' ' '─'
    renderer_reset
    ((row++))

    local idx=0
    local serial backend android bat model
    for serial in "${MULTI_DEVICES[@]}"; do
        [[ "$row" -ge $(( top + height - 1 )) ]] && break
        backend="${ANDROID_TOOLKIT_BACKEND:-auto}"
        android="${DEVICE_ANDROID_VERSION:-?}"
        bat="$(status_get battery_pct 2>/dev/null || echo "?")"
        model="${DEVICE_MODEL:-$serial}"

        local sel_flag=" "
        multi_device_is_selected "$serial" && sel_flag="▣" || sel_flag="□"
        [[ "$serial" == "${ANDROID_TOOLKIT_ADB_SERIAL:-}" ]] && sel_flag="●"

        renderer_cursor_goto "$row" "$col"
        if multi_device_is_selected "$serial"; then
            renderer_fg_256 "$(theme_get success)"
        else
            renderer_fg_256 "$(theme_get fg)"
        fi
        printf '%-4s %-20s %-10s %-10s %-8s %-8s' "$sel_flag" "${model:0:19}" "$backend" "${android:0:9}" "$bat%" "Online"
        renderer_reset
        ((row++))
        ((idx++))
    done

    row=$(( row + 1 ))
    renderer_cursor_goto "$row" "$left"
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    printf 'Space: Toggle  |  B: Broadcast  |  C: Compare  |  Enter: Select active'
    renderer_reset
}

_page_key_multi_device() {
    local key="$1"
    case "$key" in
        " ")
            local idx=-1
            # Find which device is at current cursor position
            # Simplified: toggle first non-active
            local i
            for i in "${!MULTI_DEVICES[@]}"; do
                if ! multi_device_is_selected "${MULTI_DEVICES[$i]}"; then
                    multi_device_toggle "$i"
                    notify_push "Toggled: ${MULTI_DEVICES[$i]}" "info"
                    DASHBOARD_REDRAW_NEEDED=true
                    return 0
                fi
            done
            # All selected, deselect all
            MULTI_SELECTED=()
            notify_push "Deselected all devices" "info"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "b"|"B")
            if [[ "${#MULTI_SELECTED[@]}" -eq 0 ]]; then
                notify_push "No devices selected for broadcast" "warning"
            else
                local cmd
                cmd="$(menu_input "Broadcast" "Command to broadcast:")" || return 0
                [[ -z "$cmd" ]] && return 0
                multi_device_broadcast "$cmd"
                local output=""
                local r
                for r in "${MULTI_BROADCAST_RESULTS[@]}"; do
                    output+="$r"$'\n'
                done
                menu_textbox "Broadcast Results" "$output"
            fi
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "c"|"C")
            dashboard_navigate "device_compare"
            ;;
    esac
}
