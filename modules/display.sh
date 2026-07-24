#!/data/data/com.termux/files/usr/bin/bash
#
# display.sh — Display settings and diagnostics module
#
# Reads and optionally adjusts:
#   - Screen resolution and density
#   - Refresh rate
#   - Display metrics (dumpsys display)
#
# Part of the Android Toolkit.

##############################################
# Report display status.
##############################################
display_status() {
    log_section "Display Status"

    # Physical size and density via wm
    local wm_info
    wm_info="$(backend_exec wm size 2>/dev/null)"
    local density_info
    density_info="$(backend_exec wm density 2>/dev/null)"

    local phys_size="$(echo "$wm_info" | grep -i 'physical' | awk '{print $3}')"
    local phys_density="$(echo "$density_info" | grep -i 'physical' | awk '{print $3}')"
    local override_size="$(echo "$wm_info" | grep -i 'override' | awk '{print $3}')"
    local override_density="$(echo "$density_info" | grep -i 'override' | awk '{print $3}')"

    utils_print_kv "Physical Resolution" "${phys_size:-unknown}"
    utils_print_kv "Physical Density" "${phys_density:-unknown}"
    if [[ -n "$override_size" ]]; then
        utils_print_kv "Override Resolution" "$override_size"
    fi
    if [[ -n "$override_density" ]]; then
        utils_print_kv "Override Density" "$override_density"
    fi

    # Refresh rate via dumpsys display or settings
    local peak_rr min_rr
    peak_rr="$(backend_settings_get system peak_refresh_rate 2>/dev/null)"
    min_rr="$(backend_settings_get system min_refresh_rate 2>/dev/null)"

    if [[ -n "$peak_rr" ]]; then
        utils_print_kv "Peak Refresh Rate" "${peak_rr} Hz"
    fi
    if [[ -n "$min_rr" ]]; then
        utils_print_kv "Min Refresh Rate" "${min_rr} Hz"
    fi

    # Try dumpsys display for more detail (may not be available on all devices)
    local display_info
    display_info="$(backend_exec dumpsys display 2>/dev/null | head -30 || true)"
    if echo "$display_info" | grep -q 'mDefaultMode'; then
        local mode
        mode="$(echo "$display_info" | grep 'mDefaultMode' | head -1)"
        utils_print_kv "Display Mode" "$(echo "$mode" | sed 's/.*://')"
    fi
}

##############################################
# Set resolution and density (requires elevated access).
# Arguments:
#   $1: resolution (e.g., "1080x2340")
#   $2: density (e.g., "420")
##############################################
display_set_resolution() {
    local resolution="$1" density="$2"

    if [[ -z "$resolution" ]]; then
        log_error "Resolution required (e.g., 1080x2340)"
        return 1
    fi

    log_section "Display Resolution Change"
    log_warn "Changing resolution affects all apps and may require a reboot to revert."

    if [[ "$ANDROID_TOOLKIT_DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would set resolution to $resolution${density:+ and density to $density}"
        return 0
    fi

    if ! utils_confirm "Set resolution to $resolution${density:+ and density to $density}?"; then
        log_info "Cancelled"
        return 0
    fi

    # Save current resolution for rollback
    local original_size
    original_size="$(backend_exec wm size 2>/dev/null | grep 'Physical size' | awk '{print $3}')"
    if [[ -n "$original_size" ]]; then
        log_info "Original resolution: $original_size"
        # Store in backup
        echo "display_original_resolution=$original_size" >> \
            "$(backup_filename "display_rollback")"
    fi

    # Apply
    if backend_exec wm size "$resolution" 2>/dev/null; then
        log_success "Resolution set to $resolution"
    else
        log_error "Failed to set resolution"
        return 1
    fi

    if [[ -n "$density" ]]; then
        local original_density
        original_density="$(backend_exec wm density 2>/dev/null | grep 'Physical density' | awk '{print $3}')"
        if [[ -n "$original_density" ]]; then
            echo "display_original_density=$original_density" >> \
                "$(backup_filename "display_rollback")"
        fi

        if backend_exec wm density "$density" 2>/dev/null; then
            log_success "Density set to $density"
        else
            log_warn "Failed to set density"
        fi
    fi
}

##############################################
# Reset display to physical defaults.
##############################################
display_reset() {
    log_section "Reset Display"

    if [[ "$ANDROID_TOOLKIT_DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would reset resolution and density to defaults"
        return 0
    fi

    if backend_exec wm size reset 2>/dev/null; then
        log_success "Resolution reset to physical default"
    else
        log_warn "Could not reset resolution"
    fi

    if backend_exec wm density reset 2>/dev/null; then
        log_success "Density reset to physical default"
    else
        log_warn "Could not reset density"
    fi
}
