#!/data/data/com.termux/files/usr/bin/bash
#
# battery.sh — Battery status and optimization module
#
# Reads battery statistics via dumpsys battery.
# Applies safe battery optimization settings.
#
# Part of the Android Toolkit.

##############################################
# Display current battery status.
##############################################
battery_status() {
    log_section "Battery Status"

    # Get battery info via dumpsys
    local battery_info
    battery_info="$(backend_exec dumpsys battery 2>/dev/null)"

    if [[ -z "$battery_info" ]]; then
        log_error "Cannot read battery info"
        return 1
    fi

    # Parse key values (use anchored patterns to avoid history lines)
    local level scale temp status tech power
    level="$(echo "$battery_info" | grep '^[[:space:]]*level:' | head -1 | awk '{print $2}')"
    scale="$(echo "$battery_info" | grep '^[[:space:]]*scale:' | head -1 | awk '{print $2}')"
    temp="$(echo "$battery_info" | grep '^[[:space:]]*temperature:' | head -1 | awk '{print $2}')"
    status="$(echo "$battery_info" | grep '^[[:space:]]*status:' | head -1 | awk '{print $2}')"
    tech="$(echo "$battery_info" | grep '^[[:space:]]*technology:' | head -1 | awk '{print $2}')"
    power="$(echo "$battery_info" | grep '^[[:space:]]*powered:' | head -1 | awk '{print $2}')"

    # Calculate percentage (validate values are numeric first)
    local pct="?"
    if [[ -n "$level" && -n "$scale" ]] \
        && [[ "$level" =~ ^[0-9]+$ ]] \
        && [[ "$scale" =~ ^[0-9]+$ ]] \
        && [[ "$scale" -gt 0 ]]; then
        pct="$(( level * 100 / scale ))%"
    elif [[ -n "$level" ]]; then
        pct="${level}%"
    fi

    # Temperature in tenths of °C
    local temp_display="?"
    if [[ -n "$temp" ]]; then
        temp_display="$(echo "scale=1; $temp / 10" | bc 2>/dev/null || echo "${temp}?")°C"
    fi

    # Status mapping
    local status_text="?"
    case "$status" in
        1) status_text="Unknown" ;;
        2) status_text="Charging" ;;
        3) status_text="Discharging" ;;
        4) status_text="Not charging" ;;
        5) status_text="Full" ;;
    esac

    utils_print_kv "Level" "$pct"
    utils_print_kv "Status" "$status_text"
    utils_print_kv "Temperature" "$temp_display"
    utils_print_kv "Technology" "${tech:-unknown}"
    utils_print_kv "Powered" "${power:-?}"

    # Additional stats from batterystats
    local batterystats
    batterystats="$(backend_exec dumpsys batterystats --charged 2>/dev/null | head -20 || true)"
    if [[ -n "$batterystats" ]]; then
        local est_time
        est_time="$(echo "$batterystats" | grep 'Estimated power' || true)"
        if [[ -n "$est_time" ]]; then
            utils_print_kv "Estimated" "$(echo "$est_time" | sed 's/.*://')"
        fi
    fi
}

##############################################
# Apply battery optimization settings.
##############################################
battery_optimize() {
    log_section "Battery Optimization"

    if [[ "$ANDROID_TOOLKIT_DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would apply battery optimization settings"
        return 0
    fi

    # 1. Enable battery saver mode (if profile requests it)
    if [[ "${PROFILE_BATTERY_SAVER:-false}" == "true" ]]; then
        backend_settings_put global low_power 1
    fi

    # 2. Enable automatic power save mode if available
    local auto_ps
    auto_ps="$(backend_settings_get global automatic_power_save_mode 2>/dev/null)"
    if [[ -n "$auto_ps" ]]; then
        backend_settings_put global automatic_power_save_mode 1
    else
        log_debug "automatic_power_save_mode not available — skipping"
    fi

    # 3. Enable dynamic power savings if available (Samsung feature)
    local dynamic_ps
    dynamic_ps="$(backend_settings_get global dynamic_power_savings_enabled 2>/dev/null)"
    if [[ -n "$dynamic_ps" ]]; then
        backend_settings_put global dynamic_power_savings_enabled 1
    else
        log_debug "dynamic_power_savings_enabled not available — skipping"
    fi

    # 4. Enable app restriction if available
    local app_restrict
    app_restrict="$(backend_settings_get global app_restriction_enabled 2>/dev/null)"
    if [[ -n "$app_restrict" ]]; then
        backend_settings_put global app_restriction_enabled 1
    else
        log_debug "app_restriction_enabled not available — skipping"
    fi

    log_success "Battery optimization settings applied"
}

##############################################
# Enable battery saver mode manually.
##############################################
battery_saver_on() {
    log_info "Enabling battery saver mode..."
    backend_settings_put global low_power 1
}

##############################################
# Disable battery saver mode manually.
##############################################
battery_saver_off() {
    log_info "Disabling battery saver mode..."
    backend_settings_put global low_power 0
}
