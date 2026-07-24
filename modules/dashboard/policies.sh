#!/data/data/com.termux/files/usr/bin/bash
#
# policies.sh — Policy Engine
#
# Configurable device policies that trigger notifications
# when violated. Supports minimum battery, security patch,
# maximum temperature, required plugins, version requirements,
# storage/memory thresholds, and more.
#
# Part of the Android Toolkit Dashboard.

POLICY_FILE="${ANDROID_TOOLKIT_ROOT_DIR}/policies.conf"
declare -gA POLICIES=()
declare -ga POLICY_VIOLATIONS=()

##############################################
# Load policies from config file.
policies_load() {
    POLICIES=()
    if [[ -f "$POLICY_FILE" ]]; then
        while IFS='=' read -r key val; do
            key="${key// /}"
            [[ -z "$key" || "$key" == "#"* ]] && continue
            POLICIES["$key"]="$val"
        done < "$POLICY_FILE"
    fi
    # Set defaults
    [[ -z "${POLICIES[min_battery]}" ]]       && POLICIES["min_battery"]="20"
    [[ -z "${POLICIES[min_patch]}" ]]         && POLICIES["min_patch"]="2025-01"
    [[ -z "${POLICIES[max_temp]}" ]]          && POLICIES["max_temp"]="45"
    [[ -z "${POLICIES[required_plugins]}" ]]  && POLICIES["required_plugins"]=""
    [[ -z "${POLICIES[min_android]}" ]]       && POLICIES["min_android"]="13"
    [[ -z "${POLICIES[min_oneui]}" ]]         && POLICIES["min_oneui"]="5"
    [[ -z "${POLICIES[max_storage]}" ]]       && POLICIES["max_storage"]="90"
    [[ -z "${POLICIES[max_memory]}" ]]        && POLICIES["max_memory"]="90"
}

##############################################
# Save policies to config file.
policies_save() {
    {
        echo "# Android Toolkit Policy Configuration"
        echo "# Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "# Minimum battery percentage before warning"
        echo "min_battery=${POLICIES[min_battery]}"
        echo ""
        echo "# Minimum security patch level (YYYY-MM)"
        echo "min_patch=${POLICIES[min_patch]}"
        echo ""
        echo "# Maximum safe temperature (°C)"
        echo "max_temp=${POLICIES[max_temp]}"
        echo ""
        echo "# Required plugins (comma-separated)"
        echo "required_plugins=${POLICIES[required_plugins]}"
        echo ""
        echo "# Minimum Android version"
        echo "min_android=${POLICIES[min_android]}"
        echo ""
        echo "# Minimum One UI version"
        echo "min_oneui=${POLICIES[min_oneui]}"
        echo ""
        echo "# Maximum storage usage % before warning"
        echo "max_storage=${POLICIES[max_storage]}"
        echo ""
        echo "# Maximum memory usage % before warning"
        echo "max_memory=${POLICIES[max_memory]}"
    } > "$POLICY_FILE"
    notify_push "Policies saved" "success"
}

##############################################
# Check policies against current device state.
policies_check() {
    POLICY_VIOLATIONS=()
    local violations=0

    # Check battery
    local bat
    bat="$(status_get battery_pct 2>/dev/null || echo "100")"
    local min_bat="${POLICIES[min_battery]}"
    if [[ "$bat" -lt "$min_bat" ]]; then
        POLICY_VIOLATIONS+=("battery|Battery at ${bat}% (policy: ≥${min_bat}%)|warning")
        ((violations++))
    fi

    # Check temperature
    local temp
    temp="$(status_get thermal 2>/dev/null || echo "0")"
    local max_t="${POLICIES[max_temp]}"
    if [[ "$(echo "$temp > $max_t" | bc -l 2>/dev/null)" -eq 1 ]]; then
        POLICY_VIOLATIONS+=("thermal|Temperature at ${temp}°C (policy: ≤${max_t}°C)|error")
        ((violations++))
    fi

    # Check storage
    local storage
    storage="$(status_get storage_pct 2>/dev/null || echo "0")"
    storage="${storage//%/}"
    local max_s="${POLICIES[max_storage]}"
    if [[ "$storage" -gt "$max_s" ]]; then
        POLICY_VIOLATIONS+=("storage|Storage at ${storage}% (policy: ≤${max_s}%)|warning")
        ((violations++))
    fi

    # Check memory
    local memory
    memory="$(status_get mem_pct 2>/dev/null || echo "0")"
    memory="${memory//%/}"
    local max_m="${POLICIES[max_memory]}"
    if [[ "$memory" -gt "$max_m" ]]; then
        POLICY_VIOLATIONS+=("memory|Memory at ${memory}% (policy: ≤${max_m}%)|warning")
        ((violations++))
    fi

    # Check Android version
    local android
    android="$(status_get android_version 2>/dev/null || echo "0")"
    local min_a="${POLICIES[min_android]}"
    if [[ "$(echo "$android < $min_a" | bc -l 2>/dev/null)" -eq 1 ]]; then
        POLICY_VIOLATIONS+=("android|Android ${android} (policy: ≥${min_a})|warning")
        ((violations++))
    fi

    echo "$violations violations found"
    return "$violations"
}

##############################################
# Render policy engine page.
_page_render_policies() {
    local top="$1" left="$2" width="$3" height="$4"
    policies_load

    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Policy Engine'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Device compliance policies'
    renderer_reset

    local row=$(( top + 2 ))
    local col="$left"

    # Check current violations
    policies_check
    local vcount="${#POLICY_VIOLATIONS[@]}"

    # Status bar
    if [[ "$vcount" -gt 0 ]]; then
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get error)"
        renderer_bold
        printf ' ⚠ %d policy violation(s) detected' "$vcount"
        renderer_reset
    else
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get success)"
        renderer_bold
        printf ' ✓ All policies passed'
        renderer_reset
    fi
    ((row++))

    # Actions
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get info)"
    renderer_bold
    printf ' [c] Check now  [s] Save  [1-8] Edit policy'
    renderer_reset
    ((row += 2))

    # Policy list
    local policies_list=(
        "1" "Min Battery"   "min_battery"   "${POLICIES[min_battery]}%"
        "2" "Min Patch"     "min_patch"     "${POLICIES[min_patch]}"
        "3" "Max Temp"      "max_temp"      "${POLICIES[max_temp]}°C"
        "4" "Required Plugins" "required_plugins" "${POLICIES[required_plugins]:-none}"
        "5" "Min Android"   "min_android"   "${POLICIES[min_android]}"
        "6" "Min One UI"    "min_oneui"     "${POLICIES[min_oneui]}"
        "7" "Max Storage"   "max_storage"   "${POLICIES[max_storage]}%"
        "8" "Max Memory"    "max_memory"    "${POLICIES[max_memory]}%"
    )

    local i=0
    while (( i < ${#policies_list[@]} )); do
        renderer_cursor_goto "$row" "$col"
        local num="${policies_list[$i]}"
        local label="${policies_list[$((i+1))]}"
        local val="${policies_list[$((i+3))]}"
        renderer_fg_256 "$(theme_get info)"
        renderer_bold
        printf ' [%s]' "$num"
        renderer_reset
        renderer_fg_256 "$(theme_get fg)"
        printf ' %-20s %s' "$label" "$val"
        renderer_reset
        ((row++))
        ((i += 4))
    done

    # Violations list
    if [[ "$vcount" -gt 0 ]]; then
        ((row++))
        renderer_cursor_goto "$row" "$col"
        renderer_bold
        renderer_fg_256 "$(theme_get error)"
        printf 'Active Violations:'
        renderer_reset
        ((row++))
        local violation
        for violation in "${POLICY_VIOLATIONS[@]}"; do
            [[ "$row" -ge $(( top + height - 1 )) ]] && break
            local vcat="${violation%%|*}"
            local vdesc="${violation#*|}"
            local vsev="${vdesc##*|}"
            vdesc="${vdesc%|*}"
            local vcolor
            case "$vsev" in
                error)   vcolor="$(theme_get error)" ;;
                warning) vcolor="$(theme_get warning)" ;;
                *)       vcolor="$(theme_get muted)" ;;
            esac
            renderer_cursor_goto "$row" "$col"
            renderer_fg_256 "$vcolor"
            printf '  • %s' "$vdesc"
            renderer_reset
            ((row++))
        done
    fi
}

_page_key_policies() {
    local key="$1"
    case "$key" in
        "c"|"C")
            policies_check
            if [[ "${#POLICY_VIOLATIONS[@]}" -eq 0 ]]; then
                notify_push "All policies passed" "success"
            else
                notify_push "${#POLICY_VIOLATIONS[@]} violation(s) found" "warning"
            fi
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "s"|"S")
            policies_save
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        [1-8])
            local keys=("min_battery" "min_patch" "max_temp" "required_plugins" "min_android" "min_oneui" "max_storage" "max_memory")
            local labels=("Min Battery %" "Min Security Patch (YYYY-MM)" "Max Temperature °C" "Required Plugins (comma-sep)" "Min Android Version" "Min One UI Version" "Max Storage %" "Max Memory %")
            local idx=$((key - 1))
            local current="${POLICIES[${keys[$idx]}]}"
            local val
            val="$(menu_input "${labels[$idx]}" "New value:" "$current")" || return 0
            [[ -n "$val" ]] && POLICIES["${keys[$idx]}"]="$val"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
    esac
}
