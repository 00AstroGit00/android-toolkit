#!/data/data/com.termux/files/usr/bin/bash
#
# samsung/light.sh — Samsung light optimization submodule
#
# Provides samsung_apply_light_optimizations() which combines
# all battery-saving Samsung tweaks for maximum efficiency.
# Typically used with the "light" profile.
#
# Part of the Android Toolkit.

##############################################
# Apply Samsung-specific "light" optimizations.
# This is a convenience function that combines all
# battery-saving Samsung tweaks for maximum efficiency.
# Typically used with the "light" profile.
##############################################
samsung_apply_light_optimizations() {
    if ! detect_is_samsung; then
        log_info "Not a Samsung device — skipping Samsung light optimizations"
        return 0
    fi

    log_section "Samsung Light Optimizations"

    # Enable all Samsung battery optimizations
    PROFILE_SAMSUNG_BATTERY_OPT="true"
    _samsung_battery_optimize

    # Enable display optimizations
    PROFILE_SAMSUNG_DISPLAY_OPT="true"
    _samsung_display_optimize

    # Enable network/privacy optimizations
    PROFILE_SAMSUNG_NETWORK_OPT="true"
    _samsung_network_optimize

    # Enable light performance profile
    PROFILE_SAMSUNG_LIGHT_PERF="true"
    _samsung_light_profile

    # Disable GOS
    PROFILE_DISABLE_GOS="disable"
    _samsung_gos_control

    # Disable RAM Plus
    PROFILE_RAM_PLUS="0"
    _samsung_ram_plus

    # Enable touch optimization
    PROFILE_TOUCH_OPTIMIZE="true"
    _samsung_touch_optimize

    # Set 60Hz refresh rate
    PROFILE_PEAK_REFRESH_RATE="60.0"
    PROFILE_MIN_REFRESH_RATE="60.0"
    _samsung_refresh_rate

    # Enable multicore scheduler
    PROFILE_MULTICORE_SCHED="true"
    _samsung_multicore_scheduler

    # Restrict and whitelist apps if configured
    _samsung_restrict_background_apps
    _samsung_whitelist_never_sleep

    log_success "Samsung light optimizations applied"
    log_info "Reboot recommended for all changes to take effect"
}
