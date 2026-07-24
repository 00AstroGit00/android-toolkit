#!/data/data/com.termux/files/usr/bin/bash
#
# Samsung.sh — Samsung One UI OEM module
#
# Registers Samsung-specific capabilities:
#   - One UI version detection
#   - Game Optimizing Service (GOS)
#   - RAM Plus management
#   - Light Performance Profile
#   - Bixby, Samsung Free, Customization Service
#   - Samsung-specific settings (refresh rate, multicore scheduler)
#
# Part of the Android Toolkit.

oem_samsung_name="Samsung"
oem_samsung_version="2.0.0"
oem_samsung_supported_android="33 34 35 36"

##############################################
# Register Samsung OEM capabilities.
##############################################
oem_samsung_register() {
    log_debug "Samsung OEM registered (One UI: ${CAP_ONE_UI_VERSION:-unknown})"
}

##############################################
# Run Samsung-specific optimizations.
# Delegates to samsung_optimize() from samsung.sh.
##############################################
oem_samsung_optimize() {
    if [[ "$CAP_MANUFACTURER" != "samsung" ]] && [[ "$(cap_get CAP_MANUFACTURER)" != "samsung" ]]; then
        log_debug "Not a Samsung device — skipping Samsung OEM optimizations"
        return 0
    fi

    _load_module "samsung" 2>/dev/null || true
    samsung_optimize 2>/dev/null || true
}

##############################################
# Samsung-specific settings validation.
# Arguments:
#   $1: key name
#   $2: proposed value
# Returns: 0 if valid for Samsung devices
##############################################
oem_samsung_validate_setting() {
    local key="$1" value="$2"

    case "$key" in
        performance_profile)
            # Samsung One UI 7+: 0=Light, 1=Standard
            [[ "$value" == "0" || "$value" == "1" ]] && return 0
            return 1
            ;;
        ram_expand_size)
            # Must be 0,2,4,6,8 (GB)
            [[ "$value" =~ ^(0|2|4|6|8)$ ]] && return 0
            return 1
            ;;
        gamesdk_version|game_home_enable|game_auto_temperature_control)
            # Must be 0 or 1
            [[ "$value" == "0" || "$value" == "1" ]] && return 0
            return 1
            ;;
        game_bixby_block)
            # Must be 0 or 1
            [[ "$value" == "0" || "$value" == "1" ]] && return 0
            return 1
            ;;
    esac

    return 0  # unknown keys pass through
}
