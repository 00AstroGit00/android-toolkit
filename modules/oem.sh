#!/data/data/com.termux/files/usr/bin/bash
#
# oem.sh — OEM framework loader
#
# Handles OEM-specific logic by detecting the manufacturer
# and loading the appropriate OEM module.
# Settings validation respects the OEM field in settings-db.json.
#
# Each OEM module in modules/oem/ registers capabilities
# and ensures Samsung code never runs on non-Samsung devices.
#
# Part of the Android Toolkit.

OEM_DIR="${ANDROID_TOOLKIT_ROOT_DIR}/modules/oem"
OEM_LOADED=""

##############################################
# Detect and load the appropriate OEM module.
# Sets OEM_LOADED to the detected manufacturer.
# Returns: 0 if OEM module loaded, 1 if not found
##############################################
oem_load() {
    local manufacturer
    manufacturer="$(cap_get CAP_MANUFACTURER 2>/dev/null || echo 'unknown')"
    manufacturer="$(echo "$manufacturer" | tr '[:upper:]' '[:lower:]')"

    local oem_file=""
    case "$manufacturer" in
        samsung)                         oem_file="Samsung.sh" ;;
        google|*pixel*)                  oem_file="Google.sh" ;;
        oneplus)                         oem_file="OnePlus.sh" ;;
        nothing)                         oem_file="Nothing.sh" ;;
        xiaomi|redmi|poco)              oem_file="Xiaomi.sh" ;;
        motorola)                        oem_file="Motorola.sh" ;;
        oppo|realme)                     oem_file="Oppo.sh" ;;
        vivo|iqoo)                       oem_file="Vivo.sh" ;;
        *)
            log_debug "No specific OEM module for: $manufacturer"
            return 1
            ;;
    esac

    local oem_path="${OEM_DIR}/${oem_file}"
    if [[ -f "$oem_path" ]]; then
        source "$oem_path"
        OEM_LOADED="$manufacturer"
        log_debug "OEM module loaded: $oem_file"
        return 0
    fi

    log_debug "OEM module not found: $oem_file"
    return 1
}

##############################################
# Check if the current device matches a specific OEM.
# Arguments:
#   $1: oem name (samsung, google, oneplus, etc.)
# Returns: 0 if matches
##############################################
oem_is() {
    local target="$1"
    [[ "$OEM_LOADED" == "$target" ]]
}

##############################################
# Get the currently loaded OEM name.
# Returns: OEM name or "generic"
##############################################
oem_name() {
    echo "${OEM_LOADED:-generic}"
}

##############################################
# Check if a setting in settings-db.json is applicable
# to the current device's OEM.
# Arguments:
#   $1: namespace
#   $2: key
# Returns: 0 if applicable to this OEM
##############################################
oem_setting_applicable() {
    local ns="$1" key="$2"
    local db_path="${ANDROID_TOOLKIT_ROOT_DIR}/configs/settings-db.json"

    if [[ ! -f "$db_path" ]]; then
        return 0  # assume applicable if db missing
    fi

    # Extract the OEM field for this setting
    local setting_block
    setting_block="$(grep -A 15 "\"${key}\":" "$db_path" 2>/dev/null | head -16 || true)"
    local setting_oem
    setting_oem="$(echo "$setting_block" | grep '"oem":' | head -1 | cut -d'"' -f4 || echo "all")"

    if [[ "$setting_oem" == "all" ]]; then
        return 0
    fi

    if [[ "$setting_oem" == "$OEM_LOADED" ]]; then
        return 0
    fi

    return 1
}
