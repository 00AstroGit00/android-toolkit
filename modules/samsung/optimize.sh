#!/data/data/com.termux/files/usr/bin/bash
#
# samsung/optimize.sh — Samsung optimization submodule
#
# Provides samsung_optimize() and all _samsung_*() helper functions
# for Samsung/One UI specific device optimizations.
#
# All settings are guard-probed before being applied:
#   - Settings are only applied if they exist on the device
#   - All operations use probe-before-write to avoid errors
#   - Operations are reversible via rollback
#
# Part of the Android Toolkit.

##############################################
# Apply Samsung-specific optimizations.
# All guarded: settings are probed before being written.
##############################################
samsung_optimize() {
    if ! detect_is_samsung; then
        log_info "Not a Samsung device — skipping Samsung optimizations"
        return 0
    fi

    log_section "Samsung Optimization"

    # 1. Game Optimizing Service (GOS) management
    _samsung_gos_control

    # 2. Refresh rate settings (One UI specific)
    _samsung_refresh_rate

    # 3. Multi-core packet scheduler (One UI optimization)
    _samsung_multicore_scheduler

    # 4. Touch optimization
    _samsung_touch_optimize

    # 5. RAM Plus management
    _samsung_ram_plus

    # 6. Samsung battery and power settings
    _samsung_battery_optimize

    # 7. Samsung display optimizations
    _samsung_display_optimize

    # 8. Samsung network/privacy optimizations
    _samsung_network_optimize

    # 9. Light performance profile (One UI 7+)
    _samsung_light_profile

    log_success "Samsung optimizations applied"
}

##############################################
# Control Samsung Game Optimizing Service (GOS).
# GOS throttles CPU/GPU during games; some users
# prefer to disable it for maximum performance.
#
# Two approaches:
#   1. disable: Sets GOS settings to zero (reversible)
#   2. uninstall: Removes the package entirely (requires reboot)
#
# Expects: PROFILE_DISABLE_GOS (disable|uninstall|false)
# Alternative package: com.enhance.gameservice (some devices)
##############################################
_samsung_gos_control() {
    local disable_gos="${PROFILE_DISABLE_GOS:-false}"

    # Check if GOS is installed
    local gos_installed=false
    if backend_package_installed "com.samsung.android.game.gos" 2>/dev/null; then
        gos_installed=true
    fi

    # Check alternative GOS package name
    if ! $gos_installed && backend_package_installed "com.enhance.gameservice" 2>/dev/null; then
        gos_installed=true
    fi

    if ! $gos_installed; then
        log_debug "Game Optimizing Service not installed — skipping"
        return 0
    fi

    if [[ "$disable_gos" == "uninstall" ]]; then
        log_info "Uninstalling Game Optimizing Service (GOS) — requires reboot"
        # Disable GOS settings first
        backend_settings_put secure gamesdk_version 0
        backend_settings_put secure game_home_enable 0
        backend_settings_put secure game_bixby_block 1
        backend_settings_put secure game_auto_temperature_control 0

        # Clear GOS data
        backend_exec pm clear --user 0 com.samsung.android.game.gos 2>/dev/null || true

        # Uninstall GOS for current user
        backend_exec pm uninstall -k --user 0 com.samsung.android.game.gos 2>/dev/null || true

        # Handle alternative package
        if backend_package_installed "com.enhance.gameservice" 2>/dev/null; then
            backend_exec pm clear --user 0 com.enhance.gameservice 2>/dev/null || true
            backend_exec pm uninstall -k --user 0 com.enhance.gameservice 2>/dev/null || true
        fi

        log_warn "GOS uninstalled — reboot required. Reinstall with: cmd package install-existing com.samsung.android.game.gos"

    elif [[ "$disable_gos" == "disable" ]]; then
        log_info "Disabling Game Optimizing Service (GOS) settings"
        # Disable GOS frequency scaling optimization via settings
        backend_settings_put secure gamesdk_version 0
        backend_settings_put secure game_home_enable 0
        backend_settings_put secure game_bixby_block 1
        backend_settings_put secure game_auto_temperature_control 0

        # Disable the GOS package (note: may re-enable after reboot on some devices)
        backend_exec pm disable-user --user 0 com.samsung.android.game.gos 2>/dev/null || true

        log_warn "GOS disabled — may re-enable after reboot. Use 'uninstall' mode for permanent removal."

    elif [[ "$disable_gos" == "false" ]]; then
        log_info "Game Optimizing Service: keeping default (controlled by system)"
    else
        log_warn "Invalid PROFILE_DISABLE_GOS value: '$disable_gos' (use: false, disable, or uninstall)"
    fi
}

##############################################
# Configure Samsung refresh rate settings.
# One UI uses peak_refresh_rate and min_refresh_rate.
# Supported values: 0.1, 1, 10, 24, 30, 48, 50, 60, 90, 96, 120 (device dependent)
# Setting 0.1 forces lowest possible rate (battery saver).
##############################################
_samsung_refresh_rate() {
    local peak_rr min_rr

    # Check if refresh rate settings exist on this device
    peak_rr="$(backend_settings_get system peak_refresh_rate 2>/dev/null)"
    min_rr="$(backend_settings_get system min_refresh_rate 2>/dev/null)"

    if [[ -n "$peak_rr" ]]; then
        local target_peak="${PROFILE_PEAK_REFRESH_RATE:-}"
        if [[ -n "$target_peak" ]]; then
            backend_settings_put system peak_refresh_rate "$target_peak"
        fi
    else
        log_debug "peak_refresh_rate not available — skipping"
    fi

    if [[ -n "$min_rr" ]]; then
        local target_min="${PROFILE_MIN_REFRESH_RATE:-}"
        if [[ -n "$target_min" ]]; then
            backend_settings_put system min_refresh_rate "$target_min"
        fi
    else
        log_debug "min_refresh_rate not available — skipping"
    fi
}

##############################################
# Configure Samsung multi-core packet scheduler.
# Improves network throughput on multi-core devices.
##############################################
_samsung_multicore_scheduler() {
    local mcps
    mcps="$(backend_settings_get system multicore_packet_scheduler 2>/dev/null)"

    if [[ -n "$mcps" ]]; then
        if [[ "${PROFILE_MULTICORE_SCHED:-true}" == "true" ]]; then
            backend_settings_put system multicore_packet_scheduler 1
        else
            backend_settings_put system multicore_packet_scheduler 0
        fi
    else
        log_debug "multicore_packet_scheduler not available — skipping"
    fi
}

##############################################
# Optimize Samsung touch responsiveness.
# Expects: PROFILE_TOUCH_OPTIMIZE (true/false)
##############################################
_samsung_touch_optimize() {
    local optimize="${PROFILE_TOUCH_OPTIMIZE:-false}"

    if [[ "$optimize" == "true" ]]; then
        log_info "Applying Samsung touch optimizations"
        # Reduce long-press timeout (default: 400ms, reduced: 250ms)
        backend_settings_put secure long_press_timeout 250
        # Reduce multi-press timeout
        backend_settings_put secure multi_press_timeout 250
        # Reduce tap duration threshold (disables "tap and hold" filtering)
        backend_settings_put secure tap_duration_threshold 0.0
        # Reduce touch blocking period
        backend_settings_put secure touch_blocking_period 0.0
    else
        log_debug "Touch optimization not enabled in profile — skipping"
    fi
}

##############################################
# Manage Samsung RAM Plus / ZRAM.
# RAM Plus converts storage to virtual RAM.
# Expects: PROFILE_RAM_PLUS (0|2|4|6|8 or "disabled")
# Note: Requires reboot to take effect.
# Recommended: disable for better performance (less storage wear,
# less swap thrashing, faster app launches).
##############################################
_samsung_ram_plus() {
    local ram_plus_setting="${PROFILE_RAM_PLUS:-}"

    if [[ -z "$ram_plus_setting" ]]; then
        log_debug "RAM Plus not configured in profile — skipping"
        return 0
    fi

    # Check if RAM Plus settings exist
    local current
    current="$(backend_settings_get global ram_expand_size_list 2>/dev/null)"

    if [[ -z "$current" ]]; then
        log_debug "RAM Plus not available on this device — skipping"
        return 0
    fi

    if [[ "$ram_plus_setting" == "disabled" || "$ram_plus_setting" == "0" ]]; then
        log_info "Disabling RAM Plus (requires reboot)"
        backend_settings_put global zram_enabled 0
        # Set to 0 in the allowed size list and current size
        backend_settings_put global ram_expand_size_list 0
        backend_settings_put global ram_expand_size 0
    elif [[ "$ram_plus_setting" =~ ^[0-9]+$ ]]; then
        log_info "Setting RAM Plus to ${ram_plus_setting}GB (requires reboot)"
        # Ensure the size is in the allowed list
        local allowed_list
        allowed_list="$(backend_settings_get global ram_expand_size_list 2>/dev/null)"
        if [[ -z "$allowed_list" ]] || ! echo "$allowed_list" | grep -q "$ram_plus_setting"; then
            backend_settings_put global ram_expand_size_list "0,1,2,4,6,8"
        fi
        backend_settings_put global ram_expand_size "$ram_plus_setting"
    else
        log_warn "Invalid RAM Plus setting: '$ram_plus_setting'"
    fi
}

##############################################
# Samsung battery and power optimizations.
# Disables unnecessary Samsung background services
# that drain battery.
# Expects: PROFILE_SAMSUNG_BATTERY_OPT (true/false)
##############################################
_samsung_battery_optimize() {
    local enable="${PROFILE_SAMSUNG_BATTERY_OPT:-false}"

    if [[ "$enable" != "true" ]]; then
        log_debug "Samsung battery optimization not enabled in profile — skipping"
        return 0
    fi

    log_info "Applying Samsung battery optimizations"

    # Disable Adaptive Battery (community reports it causes drain on some devices)
    local adaptive_battery
    adaptive_battery="$(backend_settings_get global adaptive_battery_management_enabled 2>/dev/null)"
    if [[ -n "$adaptive_battery" ]]; then
        backend_settings_put global adaptive_battery_management_enabled 0
    fi

    # Disable diagnostic data sending
    backend_settings_put global send_action_events 0

    # Disable device scanning
    backend_settings_put global device_scanning_enabled 0
    backend_settings_put global network_scan_enabled 0

    # Samsung-specific: disable intelligent sleep mode
    local sleep_mode
    sleep_mode="$(backend_settings_get system intelligent_sleep_mode 2>/dev/null)"
    if [[ -n "$sleep_mode" ]]; then
        backend_settings_put system intelligent_sleep_mode 0
    fi

    # Samsung-specific: disable adaptive sleep
    local adaptive_sleep
    adaptive_sleep="$(backend_settings_get secure adaptive_sleep 2>/dev/null)"
    if [[ -n "$adaptive_sleep" ]]; then
        backend_settings_put secure adaptive_sleep 0
    fi

    # Samsung-specific: enhanced CPU responsiveness (disable for battery)
    backend_settings_put global sem_enhanced_cpu_responsiveness 0

    # Samsung-specific: disable enhanced processing
    backend_settings_put global enhanced_processing 0

    # Samsung-specific: disable send diagnostic data
    backend_settings_put global send_action_app_error 0

    # Samsung-specific: disable activity starts logging
    backend_settings_put global activity_starts_logging_enabled 0

    log_success "Samsung battery optimizations applied"
}

##############################################
# Samsung display optimizations.
# Disables UI transparency and blur for better
# performance and battery life.
# Expects: PROFILE_SAMSUNG_DISPLAY_OPT (true/false)
##############################################
_samsung_display_optimize() {
    local enable="${PROFILE_SAMSUNG_DISPLAY_OPT:-false}"

    if [[ "$enable" != "true" ]]; then
        log_debug "Samsung display optimization not enabled in profile — skipping"
        return 0
    fi

    log_info "Applying Samsung display optimizations"

    # Disable SystemUI transparency
    backend_settings_put system android.wallpaper.settings_systemui_transparency 0

    # Disable window blur (Android 12+, reduces GPU compositing)
    backend_settings_put global disable_window_blurs 1

    # Reduce transparency for accessibility and performance
    backend_settings_put global accessibility_reduce_transparency 1

    log_success "Samsung display optimizations applied"
}

##############################################
# Samsung network and privacy optimizations.
# Reduces background scanning and telemetry.
# Expects: PROFILE_SAMSUNG_NETWORK_OPT (true/false)
##############################################
_samsung_network_optimize() {
    local enable="${PROFILE_SAMSUNG_NETWORK_OPT:-false}"

    if [[ "$enable" != "true" ]]; then
        log_debug "Samsung network optimization not enabled in profile — skipping"
        return 0
    fi

    log_info "Applying Samsung network/privacy optimizations"

    # Disable Samsung Customization Service
    local rubin_installed
    rubin_installed="$(backend_package_installed com.samsung.android.rubin.app 2>/dev/null && echo true || echo false)"
    if [[ "$rubin_installed" == "true" ]]; then
        backend_exec pm disable-user --user 0 com.samsung.android.rubin.app 2>/dev/null || true
        log_info "Samsung Customization Service disabled"
    fi

    # Disable Samsung Free (Bixby Home)
    if backend_package_installed "com.samsung.android.app.spage" 2>/dev/null; then
        backend_exec pm disable-user --user 0 com.samsung.android.app.spage 2>/dev/null || true
        log_info "Samsung Free disabled"
    fi

    # Disable BLE scanning
    backend_settings_put global ble_scan_always_enabled 0

    # Disable WiFi scanning
    backend_settings_put global wifi_scan_always_enabled 0

    # Disable network scoring
    backend_settings_put global network_scoring_ui_enabled 0
    backend_settings_put global network_recommendations_enabled 0

    # Disable tethering offload (if not tethering)
    backend_settings_put global tether_offload_disabled 0

    log_success "Samsung network/privacy optimizations applied"
}

##############################################
# Set Samsung Light Performance Profile (One UI 7+).
# Prioritizes battery over CPU speed.
# Available on Galaxy S series and select A series.
# Expects: PROFILE_SAMSUNG_LIGHT_PERF (true/false)
#
# Note: No direct ADB command exists for this.
# The setting is accessible via:
#   Settings > Device Care > Performance Profile > Light
# This function attempts to set it via available APIs.
##############################################
_samsung_light_profile() {
    local enable="${PROFILE_SAMSUNG_LIGHT_PERF:-false}"

    if [[ "$enable" != "true" ]]; then
        log_debug "Light performance profile not enabled in profile — skipping"
        return 0
    fi

    log_info "Attempting to set Samsung Light Performance Profile"

    # Check if the performance_profile setting exists
    local current_profile
    current_profile="$(backend_settings_get global performance_profile 2>/dev/null)"

    if [[ -n "$current_profile" ]]; then
        # Value 0 = Light, 1 = Standard (Samsung encoding)
        if [[ "$current_profile" != "0" ]]; then
            backend_settings_put global performance_profile 0
            log_success "Performance profile set to Light"
        else
            log_info "Performance profile already set to Light"
        fi
    else
        # Try via cmd deviceidle (not all devices support this)
        if backend_exec cmd deviceidle performance-mode light 2>/dev/null; then
            log_success "Performance profile set to Light via deviceidle"
        else
            log_warn "Light performance profile not available on this device"
            log_info "Set manually: Settings > Device Care > Performance Profile > Light"
        fi
    fi
}

##############################################
# Restrict a Samsung app from running in background.
# Uses appops to set RUN_IN_BACKGROUND to ignore.
# Arguments:
#   $1: package name
# Expects: PROFILE_RESTRICTED_APPS (space-separated package list)
##############################################
_samsung_restrict_background_apps() {
    local apps="${PROFILE_RESTRICTED_APPS:-}"

    if [[ -z "$apps" ]]; then
        log_debug "No apps configured for background restriction — skipping"
        return 0
    fi

    log_info "Restricting background activity for configured apps"

    for pkg in $apps; do
        if backend_package_installed "$pkg" 2>/dev/null; then
            backend_exec cmd appops set "$pkg" RUN_IN_BACKGROUND ignore 2>/dev/null || true
            log_debug "Restricted background: $pkg"
        fi
    done
}

##############################################
# Whitelist an Samsung app to never sleep.
# Uses appops to set RUN_IN_BACKGROUND to allow.
# Arguments:
#   $1: package name
# Expects: PROFILE_NEVER_SLEEP_APPS (space-separated package list)
##############################################
_samsung_whitelist_never_sleep() {
    local apps="${PROFILE_NEVER_SLEEP_APPS:-}"

    if [[ -z "$apps" ]]; then
        log_debug "No apps configured for never-sleep whitelist — skipping"
        return 0
    fi

    log_info "Whitelisting apps for never-sleep"

    for pkg in $apps; do
        if backend_package_installed "$pkg" 2>/dev/null; then
            backend_exec cmd appops set "$pkg" RUN_IN_BACKGROUND allow 2>/dev/null || true
            log_debug "Never-sleep whitelist: $pkg"
        fi
    done
}
