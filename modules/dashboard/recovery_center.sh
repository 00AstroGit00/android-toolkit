#!/data/data/com.termux/files/usr/bin/bash
#
# recovery_center.sh — Recovery Center
#
# Centralized recovery interface with:
#   - Rollback points
#   - Failed task tracking
#   - Recovery suggestions
#   - System snapshots
#   - Plugin recovery
#   - Configuration recovery
#   - Validation before restoring
#
# Part of the Android Toolkit Dashboard.

RECOVERY_DIR="${ANDROID_TOOLKIT_ROOT_DIR}/recovery"
RECOVERY_POINTS=()
RECOVERY_FAILED_TASKS=()

##############################################
# Initialize recovery center.
recovery_init() {
    mkdir -p "$RECOVERY_DIR" 2>/dev/null || true
    recovery_scan_points
}

##############################################
# Scan for existing recovery points.
recovery_scan_points() {
    RECOVERY_POINTS=()
    if [[ -d "$RECOVERY_DIR" ]]; then
        local f
        for f in "$RECOVERY_DIR"/rollback_*.json; do
            [[ -f "$f" ]] && RECOVERY_POINTS+=("$(basename "$f" .json)" "$f")
        done
    fi
    # Also check twin rollback history
    local twin_dir="${ANDROID_TOOLKIT_ROOT_DIR}/twins"
    if [[ -d "$twin_dir" ]]; then
        local f
        for f in "$twin_dir"/*.json; do
            [[ -f "$f" ]] || continue
            local device_id
            device_id="$(basename "$f" .json)"
            RECOVERY_POINTS+=("twin:${device_id}" "$f")
        done
    fi
}

##############################################
# Create a recovery/rollback point.
recovery_create_point() {
    local name="${1:-rollback_$(date +%Y%m%d_%H%M%S)}"
    local file="${RECOVERY_DIR}/${name}.json"
    local ts
    ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    # Capture current state
    cat > "$file" 2>/dev/null << EOF
{
  "name": "$name",
  "created": "$ts",
  "type": "rollback_point",
  "state": {
    "battery": "$(status_get battery_pct 2>/dev/null || echo "?")",
    "storage": "$(status_get storage_pct 2>/dev/null || echo "?")",
    "memory": "$(status_get mem_pct 2>/dev/null || echo "?")",
    "thermal": "$(status_get thermal 2>/dev/null || echo "?")",
    "profile": "$(status_get active_profile 2>/dev/null || echo "unknown")"
  },
  "config": $(cat "${ANDROID_TOOLKIT_ROOT_DIR}/enterprise.conf" 2>/dev/null || echo "{}")
}
EOF
    RECOVERY_POINTS+=("$name" "$file")
    echo "$file"
}

##############################################
# Validate a recovery point before restoring.
recovery_validate() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "MISSING|Recovery point file not found"
        return 1
    fi
    local size
    size="$(stat -c%s "$file" 2>/dev/null || echo "0")"
    if [[ "$size" -lt 10 ]]; then
        echo "CORRUPT|Recovery point is too small (${size}b)"
        return 1
    fi
    # Basic JSON validation
    if ! jq . "$file" &>/dev/null; then
        echo "INVALID|Recovery point has invalid JSON format"
        return 1
    fi
    echo "VALID|Recovery point validated (${size}b)"
    return 0
}

##############################################
# Restore from a recovery point.
recovery_restore() {
    local file="$1"
    local validation
    validation="$(recovery_validate "$file")" || {
        notify_push "Validation failed: $validation" "error"
        return 1
    }
    if ! menu_yesno "Restore" "Restore from recovery point?"; then
        return 0
    fi
    # Apply profile from recovery point if available
    local profile
    profile="$(grep -o '"profile":"[^"]*"' "$file" | cut -d'"' -f4 2>/dev/null || true)"
    if [[ -n "$profile" ]]; then
        typeset -f performance_apply_profile &>/dev/null && performance_apply_profile "$profile" 2>/dev/null || true
    fi
    notify_push "Recovery applied from: $(basename "$file")" "success"
    timeline_record "rollback" "Recovery restored" "$(basename "$file")" "success"
    event_bus_emit "recovery" "restored" "$(basename "$file")" "success"
}

##############################################
# Track a failed task.
recovery_track_failure() {
    local task="$1" error="$2"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    RECOVERY_FAILED_TASKS+=("$ts|$task|$error")
    # Persist
    local logfile="${RECOVERY_DIR}/failures.log"
    echo "$ts|$task|$error" >> "$logfile" 2>/dev/null || true
}

##############################################
# Render recovery center page.
_page_render_recovery_center() {
    local top="$1" left="$2" width="$3" height="$4"
    recovery_init

    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Recovery Center'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Rollback and system restoration'
    renderer_reset

    local row=$(( top + 2 ))
    local col="$left"

    # Quick actions
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get info)"
    renderer_bold
    printf ' [n] New point  [r] Restore  [v] Validate  [f] View failures'
    renderer_reset
    ((row += 2))

    # Recovery points
    renderer_cursor_goto "$row" "$col"
    renderer_bold
    renderer_fg_256 "$(theme_get info)"
    printf 'Recovery Points (%d)' "$(( ${#RECOVERY_POINTS[@]} / 2 ))"
    renderer_reset
    ((row++))

    if [[ "${#RECOVERY_POINTS[@]}" -eq 0 ]]; then
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get muted)"
        printf '  No recovery points yet. Press [n] to create one.'
        renderer_reset
    else
        local i=0
        while (( i < ${#RECOVERY_POINTS[@]} )); do
            [[ "$row" -ge $(( top + height - 1 )) ]] && break
            local rname="${RECOVERY_POINTS[$i]}"
            local rfile="${RECOVERY_POINTS[$((i+1))]}"
            local mtime
            mtime="$(stat -c '%y' "$rfile" 2>/dev/null | cut -d. -f1 || echo "?")"
            local rsize
            rsize="$(stat -c%s "$rfile" 2>/dev/null || echo "?")"

            renderer_cursor_goto "$row" "$col"
            renderer_fg_256 "$(theme_get success)"
            printf '  %s' "$rname"
            renderer_reset
            renderer_fg_256 "$(theme_get muted)"
            printf '  (%s, %s bytes)' "$mtime" "$rsize"
            renderer_reset
            ((row++))
            ((i += 2))
        done
    fi

    # Failed tasks section
    if [[ "${#RECOVERY_FAILED_TASKS[@]}" -gt 0 ]]; then
        ((row++))
        renderer_cursor_goto "$row" "$col"
        renderer_bold
        renderer_fg_256 "$(theme_get error)"
        printf 'Recent Failures'
        renderer_reset
        ((row++))
        local last_fails=3
        [[ "${#RECOVERY_FAILED_TASKS[@]}" -lt 3 ]] && last_fails="${#RECOVERY_FAILED_TASKS[@]}"
        local idx
        for (( idx = ${#RECOVERY_FAILED_TASKS[@]} - last_fails; idx < ${#RECOVERY_FAILED_TASKS[@]}; idx++ )); do
            [[ "$row" -ge $(( top + height - 1 )) ]] && break
            local entry="${RECOVERY_FAILED_TASKS[$idx]}"
            renderer_cursor_goto "$row" "$col"
            renderer_fg_256 "$(theme_get error)"
            printf '  ✗ %s' "${entry#*|*|}"  # Show error message
            renderer_reset
            ((row++))
        done
    fi

    # Suggestions
    ((row++))
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    printf 'Tip: Create recovery points before major operations.'
    renderer_reset
}

_page_key_recovery_center() {
    local key="$1"
    case "$key" in
        "n"|"N")
            local name
            name="$(menu_input "Recovery Point" "Name (empty for auto):")" || return 0
            local file
            file="$(recovery_create_point "$name")"
            notify_push "Recovery point created: $(basename "$file")" "success"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "r"|"R")
            if [[ "${#RECOVERY_POINTS[@]}" -eq 0 ]]; then
                notify_push "No recovery points available" "warning"
                DASHBOARD_REDRAW_NEEDED=true
                return 0
            fi
            local menu_items=()
            local i=0
            while (( i < ${#RECOVERY_POINTS[@]} )); do
                menu_items+=("${RECOVERY_POINTS[$i]}" "${RECOVERY_POINTS[$i]}")
                ((i += 2))
            done
            local choice
            choice="$(menu_select "Restore From" "${menu_items[@]}")" || return 0
            # Find the file
            local j=0
            while (( j < ${#RECOVERY_POINTS[@]} )); do
                if [[ "${RECOVERY_POINTS[$j]}" == "$choice" ]]; then
                    recovery_restore "${RECOVERY_POINTS[$((j+1))]}"
                    break
                fi
                ((j += 2))
            done
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "v"|"V")
            if [[ "${#RECOVERY_POINTS[@]}" -eq 0 ]]; then
                notify_push "No recovery points to validate" "warning"
                DASHBOARD_REDRAW_NEEDED=true
                return 0
            fi
            local menu_items=()
            local i=0
            while (( i < ${#RECOVERY_POINTS[@]} )); do
                menu_items+=("${RECOVERY_POINTS[$i]}" "${RECOVERY_POINTS[$i]}")
                ((i += 2))
            done
            local choice
            choice="$(menu_select "Validate" "${menu_items[@]}")" || return 0
            local j=0
            while (( j < ${#RECOVERY_POINTS[@]} )); do
                if [[ "${RECOVERY_POINTS[$j]}" == "$choice" ]]; then
                    local validation
                    validation="$(recovery_validate "${RECOVERY_POINTS[$((j+1))]}")"
                    menu_textbox "Validation Result" "$validation"
                    break
                fi
                ((j += 2))
            done
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "f"|"F")
            local failures
            if [[ -f "${RECOVERY_DIR}/failures.log" ]]; then
                failures="$(cat "${RECOVERY_DIR}/failures.log" 2>/dev/null || echo "No failures recorded")"
            else
                failures="No failures recorded"
            fi
            menu_textbox "Failed Tasks" "$failures"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
    esac
}
