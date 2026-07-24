#!/data/data/com.termux/files/usr/bin/bash
#
# settings.sh — Settings Registry API
#
# Provides helper functions for querying the settings-db.json registry.
# Replaces hardcoded setting lookups with structured queries.
#
# Part of the Android Toolkit.

SETTINGS_DB_PATH="${ANDROID_TOOLKIT_ROOT_DIR}/configs/settings-db.json"
SETTINGS_CACHE=""

##############################################
# Load the settings DB into cache.
##############################################
settings_init() {
    if [[ -f "$SETTINGS_DB_PATH" ]]; then
        SETTINGS_CACHE="$(cat "$SETTINGS_DB_PATH")"
    else
        SETTINGS_CACHE="{}"
        log_warning "Settings database not found: $SETTINGS_DB_PATH"
    fi
}

##############################################
# Get all keys in the settings database.
# Outputs: one key per line
##############################################
settings_list_keys() {
    echo "$SETTINGS_CACHE" | grep -oP '"settings":\s*\{[^}]*\}' | \
        grep -oP '"[a-zA-Z_][a-zA-Z0-9_]*"\s*:' | tr -d '": ' || true
}

##############################################
# Get a field for a setting key.
# Arguments:
#   $1: key name
#   $2: field name (namespace|min_android|max_android|oem|default|recommended|risk|requires_reboot|rollback|note|type|validation|replacement|doc)
# Outputs: field value
##############################################
settings_get_field() {
    local key="$1" field="$2"

    if [[ -z "$SETTINGS_CACHE" || "$SETTINGS_CACHE" == "{}" ]]; then
        return 1
    fi

    # Extract the setting block
    local block
    block="$(echo "$SETTINGS_CACHE" | grep -oP "\"${key}\"\s*:\s*\{[^}]*\}" 2>/dev/null || true)"

    if [[ -z "$block" ]]; then
        return 1
    fi

    # Extract field
    local val
    val="$(echo "$block" | grep -oP "\"${field}\"\s*:\s*\"[^\"]*\"" | head -1 | cut -d'"' -f4 || true)"

    if [[ -z "$val" ]]; then
        # Try boolean/number (unquoted)
        val="$(echo "$block" | grep -oP "\"${field}\"\s*:\s*[^,}]+" | head -1 | cut -d: -f2- | tr -d '[:space:]' || true)"
    fi

    echo "$val"
}

##############################################
# Check if a setting can be written on this device.
# Arguments:
#   $1: key name
# Returns: 0 if writable
##############################################
settings_is_writable() {
    local key="$1"

    # Check Android version constraints
    local min_android max_android sdk
    min_android="$(settings_get_field "$key" "min_android")"
    max_android="$(settings_get_field "$key" "max_android")"
    sdk="${CAP_ANDROID_SDK:-0}"

    if [[ -n "$min_android" && "$sdk" -gt 0 && "$sdk" -lt "$min_android" ]]; then
        return 1
    fi
    if [[ -n "$max_android" && "$sdk" -gt 0 && "$sdk" -gt "$max_android" ]]; then
        return 1
    fi

    # Check OEM restrictions
    local oem
    oem="$(settings_get_field "$key" "oem")"
    if [[ -n "$oem" && "$oem" != "all" ]]; then
        local current_oem="${OEM_LOADED:-generic}"
        if ! echo "$oem" | grep -qw "$current_oem" 2>/dev/null; then
            return 1
        fi
    fi

    return 0
}

##############################################
# Get the recommended value for a setting.
# Arguments:
#   $1: key name
# Outputs: recommended value or empty
##############################################
settings_recommended() {
    settings_get_field "$1" "recommended"
}

##############################################
# Get the default value for a setting.
# Arguments:
#   $1: key name
# Outputs: default value or empty
##############################################
settings_default() {
    settings_get_field "$1" "default"
}

##############################################
# Get the namespace for a setting.
# Arguments:
#   $1: key name
# Outputs: namespace (global|secure|system)
##############################################
settings_namespace() {
    settings_get_field "$1" "namespace"
}

##############################################
# Get the risk level for a setting.
# Arguments:
#   $1: key name
# Outputs: risk level (low|medium|high)
##############################################
settings_risk() {
    settings_get_field "$1" "risk"
}

##############################################
# Check if a setting requires reboot.
# Arguments:
#   $1: key name
# Returns: 0 if reboot required
##############################################
settings_requires_reboot() {
    local val
    val="$(settings_get_field "$1" "requires_reboot")"
    [[ "$val" == "true" ]]
}

##############################################
# Get the rollback key for a setting.
# Arguments:
#   $1: key name
# Outputs: rollback key
##############################################
settings_rollback_key() {
    settings_get_field "$1" "rollback"
}

##############################################
# Get the expected data type for a setting.
# Arguments:
#   $1: key name
# Outputs: type (string|integer|boolean|float)
##############################################
settings_type() {
    settings_get_field "$1" "type"
}

##############################################
# Get the validation rule for a setting.
# Arguments:
#   $1: key name
# Outputs: validation regex or pattern
##############################################
settings_validation() {
    settings_get_field "$1" "validation"
}

##############################################
# Get the replacement key (if deprecated).
# Arguments:
#   $1: key name
# Outputs: replacement key or empty
##############################################
settings_replacement() {
    settings_get_field "$1" "replacement"
}

##############################################
# Get the documentation reference for a setting.
# Arguments:
#   $1: key name
# Outputs: doc URL or reference
##############################################
settings_doc() {
    settings_get_field "$1" "doc"
}

##############################################
# Validate a setting value against its expected type and rule.
# Arguments:
#   $1: key name
#   $2: proposed value
# Returns: 0 if valid
##############################################
settings_validate_value() {
    local key="$1" value="$2"
    local type validation

    type="$(settings_type "$key")"
    validation="$(settings_validation "$key")"

    case "$type" in
        integer)
            [[ "$value" =~ ^-?[0-9]+$ ]] || return 1
            ;;
        boolean)
            [[ "$value" =~ ^(0|1|true|false)$ ]] || return 1
            ;;
        float)
            [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || return 1
            ;;
    esac

    if [[ -n "$validation" ]]; then
        [[ "$value" =~ $validation ]] || return 1
    fi

    return 0
}

##############################################
# Get all settings applicable to the current device.
# Outputs: key=recommended_value lines
##############################################
settings_applicable() {
    local key
    for key in $(settings_list_keys); do
        if settings_is_writable "$key"; then
            local rec
            rec="$(settings_recommended "$key")"
            if [[ -n "$rec" ]]; then
                echo "${key}=${rec}"
            fi
        fi
    done
}

##############################################
# List all settings with details as JSON.
##############################################
settings_list_json() {
    if command -v jq &>/dev/null; then
        echo "$SETTINGS_CACHE" | jq '.settings' 2>/dev/null || echo "{}"
    else
        echo "$SETTINGS_CACHE"
    fi
}

# Auto-initialize
settings_init
