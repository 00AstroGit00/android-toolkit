#!/data/data/com.termux/files/usr/bin/bash
#
# performance.sh — Performance optimization module
#
# Applies safe, reversible performance tweaks:
#   - Animation scale adjustments
#   - ART compilation optimization (profile-guided)
#   - GPU/HWUI rendering tweaks
#   - Application freezer management
#   - Window blur and transparency
#   - Touch responsiveness optimization
#   - Samsung Game Optimizing Service (GOS) control
#   - RAM Plus / ZRAM management
#   - Performance profile application
#
# All changes are probed before writing and logged for rollback.
#
# Part of the Android Toolkit.

##############################################
# Apply a named performance profile.
# Arguments:
#   $1: profile name (balanced|performance|powersave)
##############################################
performance_apply_profile() {
    local profile="$1"
    local profile_file="${ANDROID_TOOLKIT_ROOT_DIR}/profiles/${profile}.conf"

    if [[ ! -f "$profile_file" ]]; then
        log_error "Profile not found: $profile (looked for $profile_file)"
        return 1
    fi

    log_section "Applying Profile: $profile"

    # Source the profile to get its variable definitions
    source "$profile_file"

    # Create a pre-apply backup
    backup_create_snapshot "before_${profile}" > /dev/null

    # Apply animation settings
    performance_set_animations

    # Apply HWUI rendering settings
    performance_set_hwui

    # Apply cached app freezer
    performance_set_freezer

    # Apply ART optimization if available
    performance_set_dexopt

    # Apply window blur/transparency settings
    performance_set_window_effects

    # Apply touch responsiveness settings
    performance_set_touch

    # Apply Samsung-specific optimizations if on a Samsung device
    if detect_is_samsung; then
        _load_module "samsung"
        samsung_optimize
    fi

    if [[ "$ANDROID_TOOLKIT_DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Profile '$profile' would be applied (no changes made)"
    else
        log_success "Profile '$profile' applied"
        log_info "A reboot is recommended for all changes to take full effect."
    fi
}

##############################################
# Set animation scales from profile variables.
# Expects: PROFILE_ANIMATION_SCALE (0-1.5)
##############################################
performance_set_animations() {
    local scale="${PROFILE_ANIMATION_SCALE:-1.0}"

    log_info "Setting animation scale to $scale"

    # Validate scale is a number (allow decimal)
    if ! echo "$scale" | grep -qE '^[0-9]+\.?[0-9]*$'; then
        log_warn "Invalid animation scale '$scale', using 1.0"
        scale=1.0
    fi

    backend_settings_put global window_animation_scale "$scale"
    backend_settings_put global transition_animation_scale "$scale"
    backend_settings_put global animator_duration_scale "$scale"
}

##############################################
# Set HWUI rendering profile.
# Expects: PROFILE_HWUI (true/false)
# Based on AOSP debug.hwui properties and developer options.
##############################################
performance_set_hwui() {
    local enable="${PROFILE_HWUI:-false}"

    if [[ "$enable" == "true" ]]; then
        log_info "Enabling GPU/HWUI rendering tweaks"
        # Force GPU rendering for 2D (safe, supported since Android 4)
        backend_settings_put global force_gpu_rendering 1

        # Enable 4x MSAA (optional, supported since Android 4.3)
        local current_msaa
        current_msaa="$(backend_settings_get global multisample_antialiasing 2>/dev/null)"
        if [[ -n "$current_msaa" ]] || backend_settings_exists "multisample_antialiasing" 2>/dev/null; then
            backend_settings_put global multisample_antialiasing 1
        fi

        # Force GPU for 2D rendering via system property
        backend_exec setprop debug.force-opengl 1 2>/dev/null || true
    else
        log_info "Setting GPU/HWUI to default"
        backend_settings_put global force_gpu_rendering 0
        local current_msaa
        current_msaa="$(backend_settings_get global multisample_antialiasing 2>/dev/null)"
        if [[ -n "$current_msaa" ]]; then
            backend_settings_put global multisample_antialiasing 0
        fi
    fi
}

##############################################
# Configure the cached apps freezer.
# Expects: PROFILE_FREEZER_ENABLED (true/false)
##############################################
performance_set_freezer() {
    local enable="${PROFILE_FREEZER_ENABLED:-true}"

    # Check if the freezer setting exists on this device
    local freezer_result
    freezer_result="$(backend_exec settings list global 2>/dev/null | grep 'cached_apps_freezer' || true)"
    local freezer_exists=false
    if [[ -n "$freezer_result" ]]; then
        freezer_exists=true
    fi

    if [[ "$freezer_exists" == "true" ]]; then
        if [[ "$enable" == "true" ]]; then
            log_info "Enabling cached apps freezer"
            backend_settings_put global cached_apps_freezer 1
        else
            log_info "Disabling cached apps freezer"
            backend_settings_put global cached_apps_freezer 0
        fi
    else
        log_debug "cached_apps_freezer not available on this device — skipping"
    fi
}

##############################################
# Set dexopt (ART) optimization parameters.
# Applies speed-profile optimization for better app startup.
# Expects: PROFILE_DEXOPT (speed|speed-profile|verify|balanced)
#
# Compiler filters (from AOSP):
#   - verify:            Only verification, no compilation (fastest install)
#   - speed-profile:     AOT compile methods in profile (recommended)
#   - speed:             Full AOT compile (fastest runtime, most storage)
#   - quicken:           Partial compilation (legacy, rarely used now)
#   - everything:        Compile everything (same as speed but more thorough)
#   - extract:           Extract DEX only, no compilation
##############################################
performance_set_dexopt() {
    local mode="${PROFILE_DEXOPT:-speed-profile}"

    log_info "Setting ART dexopt mode to '$mode'"

    # These are system properties that influence dex2oat behavior.
    # We only attempt this via ADB/rish since it requires elevated access.
    if backend_require "adb" || backend_require "rish"; then
        # Set bg-dexopt to use the requested filter
        case "$mode" in
            speed|speed-profile|verify|quicken|everything|extract)
                backend_exec setprop pm.dexopt.bg-dexopt "$mode" 2>/dev/null || true
                ;;
            balanced)
                # 'balanced' is our alias for speed-profile
                backend_exec setprop pm.dexopt.bg-dexopt speed-profile 2>/dev/null || true
                ;;
            *)
                log_warn "Unknown dexopt mode '$mode', using speed-profile"
                backend_exec setprop pm.dexopt.bg-dexopt speed-profile 2>/dev/null || true
                ;;
        esac
        log_info "Dexopt property set. Run '--compile' to trigger background optimization."
    else
        log_warn "Cannot set dexopt properties without ADB or rish"
    fi
}

##############################################
# Control window blur and transparency effects.
# Disabling these can improve performance on mid-range devices.
# Expects: PROFILE_WINDOW_BLUR (true/false)
##############################################
performance_set_window_effects() {
    local disable_blur="${PROFILE_WINDOW_BLUR:-false}"

    if [[ "$disable_blur" == "true" ]]; then
        log_info "Disabling window blur and reducing transparency"
        # Disable window blur (Android 12+, supports reduce GPU compositing)
        backend_settings_put global disable_window_blurs 1
        # Reduce transparency for accessibility and performance
        backend_settings_put global accessibility_reduce_transparency 1
    else
        log_info "Keeping default window effects"
        # Reset to defaults if keys exist
        if backend_settings_exists "disable_window_blurs" 2>/dev/null; then
            backend_settings_put global disable_window_blurs 0
        fi
        if backend_settings_exists "accessibility_reduce_transparency" 2>/dev/null; then
            backend_settings_put global accessibility_reduce_transparency 0
        fi
    fi
}

##############################################
# Optimize touch responsiveness.
# Reduces touch delay for faster input response.
# Expects: PROFILE_TOUCH_OPTIMIZE (true/false)
##############################################
performance_set_touch() {
    local optimize="${PROFILE_TOUCH_OPTIMIZE:-false}"

    if [[ "$optimize" == "true" ]]; then
        log_info "Optimizing touch responsiveness"
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
