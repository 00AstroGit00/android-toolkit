#!/data/data/com.termux/files/usr/bin/bash
#
# detection.sh — Device capability detection
#
# Reads system properties to detect:
#   - Android version
#   - Device model and manufacturer
#   - Build fingerprint
#   - One UI version (Samsung)
#   - API level
#   - Available sensors and features
#
# Part of the Android Toolkit.

# Global device info variables (populated by detect_device_info)
DEVICE_ANDROID_VERSION=""
DEVICE_SDK_VERSION=""
DEVICE_MANUFACTURER=""
DEVICE_MODEL=""
DEVICE_BUILD_FINGERPRINT=""
DEVICE_ONE_UI_VERSION=""
DEVICE_IS_SAMSUNG=false
DEVICE_IS_WEARABLE=false
DEVICE_ABI=""

##############################################
# Populate device info globals by reading system properties.
# Arguments: none
# Globals set: DEVICE_*
##############################################
detect_device_info() {
    log_section "Device Detection"

    DEVICE_MANUFACTURER="$(backend_getprop ro.product.manufacturer)"
    DEVICE_MODEL="$(backend_getprop ro.product.model)"
    DEVICE_ANDROID_VERSION="$(backend_getprop ro.build.version.release)"
    DEVICE_SDK_VERSION="$(backend_getprop ro.build.version.sdk)"
    DEVICE_BUILD_FINGERPRINT="$(backend_getprop ro.build.fingerprint)"
    DEVICE_ABI="$(backend_getprop ro.product.cpu.abi)"

    # Samsung-specific
    local samsung_name
    samsung_name="$(backend_getprop ro.product.name 2>/dev/null)"
    if echo "$DEVICE_MANUFACTURER" | grep -qi "samsung"; then
        DEVICE_IS_SAMSUNG=true
    fi

    # One UI version
    DEVICE_ONE_UI_VERSION="$(backend_getprop ro.build.version.oneui 2>/dev/null)"
    if [[ -z "$DEVICE_ONE_UI_VERSION" ]]; then
        DEVICE_ONE_UI_VERSION="$(backend_getprop ro.samsung.build.version.oneui 2>/dev/null)"
    fi

    # Detect wearable
    if echo "$DEVICE_MODEL" | grep -qiE '(watch|gear|fitbit|wear)' 2>/dev/null; then
        DEVICE_IS_WEARABLE=true
    fi

    # Display info
    log_info "Manufacturer: ${DEVICE_MANUFACTURER:-unknown}"
    log_info "Model: ${DEVICE_MODEL:-unknown}"
    log_info "Android: ${DEVICE_ANDROID_VERSION:-unknown} (SDK ${DEVICE_SDK_VERSION:-unknown})"
    log_info "ABI: ${DEVICE_ABI:-unknown}"
    if [[ "$DEVICE_IS_SAMSUNG" == true ]]; then
        log_info "One UI: ${DEVICE_ONE_UI_VERSION:-unknown}"
    fi
    if [[ -n "$DEVICE_BUILD_FINGERPRINT" ]]; then
        log_debug "Fingerprint: $DEVICE_BUILD_FINGERPRINT"
    fi
}

##############################################
# Compare Android version against a target.
# Arguments:
#   $1: comparison operator (ge, le, eq, gt, lt)
#   $2: target version (e.g., "14")
# Returns: 0 if condition holds
##############################################
detect_android_version_at_least() {
    local target="$1"
    local current="${DEVICE_ANDROID_VERSION:-0}"
    # Simple numeric comparison (major version only)
    local current_major="${current%%.*}"
    local target_major="${target%%.*}"
    [[ "$current_major" -ge "$target_major" ]] 2>/dev/null
}

##############################################
# Compare SDK version against a target.
# Arguments:
#   $1: target SDK (e.g., 34 for Android 14)
# Returns: 0 if SDK >= target
##############################################
detect_sdk_at_least() {
    local target="$1"
    [[ "${DEVICE_SDK_VERSION:-0}" -ge "$target" ]] 2>/dev/null
}

##############################################
# Check if the device is a Samsung Galaxy device.
# Returns: 0 if Samsung
##############################################
detect_is_samsung() {
    [[ "$DEVICE_IS_SAMSUNG" == true ]]
}

##############################################
# Return a human-readable device summary.
##############################################
detect_device_summary() {
    local summary=""
    summary+="${DEVICE_MANUFACTURER:-Unknown} "
    summary+="${DEVICE_MODEL:-Unknown} • "
    summary+="Android ${DEVICE_ANDROID_VERSION:-?}"
    if [[ -n "$DEVICE_ONE_UI_VERSION" ]]; then
        summary+=" (One UI ${DEVICE_ONE_UI_VERSION})"
    fi
    summary+=" • SDK ${DEVICE_SDK_VERSION:-?}"
    echo "$summary"
}
