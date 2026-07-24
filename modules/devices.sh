#!/data/data/com.termux/files/usr/bin/bash
#
# devices.sh — Multi-Device Manager Module
#
# Enumerate, select, and execute commands across multiple
# simultaneously connected ADB devices.
#
# Features:
#   - List all connected devices with details
#   - Select active device (persistent)
#   --device SERIAL   Run on specific device
#   --all-devices     Run on all connected devices
#   - Filter by OEM, Android version
#
# Part of the Android Toolkit.

DEVICES_CACHE_FILE="${ANDROID_TOOLKIT_ROOT_DIR}/.active_device"
DEVICES_LIST_CACHE=()
DEVICES_DETAILS_CACHE=""

##############################################
# Enumerate all connected ADB devices.
# Populates DEVICES_LIST_CACHE.
# Returns: 0 if any devices found
##############################################
devices_enumerate() {
    DEVICES_LIST_CACHE=()
    DEVICES_DETAILS_CACHE=""

    if ! command -v adb &>/dev/null; then
        log_debug "ADB not available — cannot enumerate devices"
        return 1
    fi

    local output
    output="$(adb devices 2>/dev/null | grep -v 'List of devices attached' | grep -v '^$')"

    if [[ -z "$output" ]]; then
        return 1
    fi

    while IFS= read -r line; do
        local serial status
        serial="$(echo "$line" | awk '{print $1}')"
        status="$(echo "$line" | awk '{print $2}')"
        if [[ "$status" == "device" ]]; then
            DEVICES_LIST_CACHE+=("$serial")
        fi
    done <<< "$output"

    [[ ${#DEVICES_LIST_CACHE[@]} -gt 0 ]]
}

##############################################
# Get details for a device.
# Arguments:
#   $1: device serial
# Outputs: JSON object with manufacturer, model, android_version, sdk
##############################################
devices_get_details() {
    local serial="$1"

    local manufacturer model android_version sdk
    manufacturer="$(adb -s "$serial" shell getprop ro.product.manufacturer 2>/dev/null | tr -d '\r' | tr '[:upper:]' '[:lower:]')"
    model="$(adb -s "$serial" shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
    android_version="$(adb -s "$serial" shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')"
    sdk="$(adb -s "$serial" shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r')"

    jq -n \
        --arg serial "$serial" \
        --arg manufacturer "${manufacturer:-unknown}" \
        --arg model "${model:-unknown}" \
        --arg android "${android_version:-unknown}" \
        --arg sdk "${sdk:-0}" \
        '{
            serial: $serial,
            manufacturer: $manufacturer,
            model: $model,
            android_version: $android,
            sdk: ($sdk | tonumber)
        }' 2>/dev/null || echo "{\"serial\":\"$serial\",\"manufacturer\":\"${manufacturer:-unknown}\",\"model\":\"${model:-unknown}\",\"android_version\":\"${android_version:-unknown}\"}"
}

##############################################
# List all connected devices with details.
# Arguments:
#   $1: output format (text|json) — default: text
##############################################
devices_list() {
    local format="${1:-text}"

    if ! devices_enumerate; then
        log_warning "No ADB devices connected"
        return 1
    fi

    if [[ "$format" == "json" ]] && command -v jq &>/dev/null; then
        local json_arr="[]"
        local serial
        for serial in "${DEVICES_LIST_CACHE[@]}"; do
            local details
            details="$(devices_get_details "$serial")"
            json_arr="$(echo "$json_arr" | jq --argjson d "$details" '. + [$d]' 2>/dev/null)"
        done
        echo "$json_arr"
        return 0
    fi

    # Text format
    log_section "Connected Devices"
    echo ""
    printf "  %-25s %-15s %-25s %-10s\n" "Serial" "Manufacturer" "Model" "Android"
    printf "  %-25s %-15s %-25s %-10s\n" "─────────────────────" "───────────────" "─────────────────────────" "──────────"

    local serial
    for serial in "${DEVICES_LIST_CACHE[@]}"; do
        local details
        details="$(devices_get_details "$serial")"
        local manuf model android
        manuf="$(echo "$details" | jq -r '.manufacturer' 2>/dev/null || echo "?")"
        model="$(echo "$details" | jq -r '.model' 2>/dev/null || echo "?")"
        android="$(echo "$details" | jq -r '.android_version' 2>/dev/null || echo "?")"

        local marker=""
        if [[ "$serial" == "$(devices_get_active)" ]]; then
            marker=" *"
        fi
        printf "  %-25s %-15s %-25s %-10s\n" "${serial}${marker}" "$manuf" "$model" "$android"
    done

    local active
    active="$(devices_get_active)"
    if [[ -n "$active" ]]; then
        echo ""
        log_info "Active device: $active"
    fi
}

##############################################
# Get or set the active device.
# Arguments:
#   $1: serial (optional) — set active device
# Outputs: current active device serial
##############################################
devices_get_active() {
    if [[ -f "$DEVICES_CACHE_FILE" ]]; then
        cat "$DEVICES_CACHE_FILE" 2>/dev/null || true
    fi
}

devices_set_active() {
    local serial="$1"

    if [[ -z "$serial" ]]; then
        log_error "Usage: --device <serial>"
        return 1
    fi

    # Verify device exists
    if ! devices_enumerate; then
        log_error "No ADB devices connected"
        return 1
    fi

    local found=false
    local s
    for s in "${DEVICES_LIST_CACHE[@]}"; do
        if [[ "$s" == "$serial" ]]; then
            found=true
            break
        fi
    done

    if ! $found; then
        log_error "Device not found: $serial"
        return 1
    fi

    echo "$serial" > "$DEVICES_CACHE_FILE"
    log_success "Active device set to: $serial"

    if declare -f events_emit &>/dev/null; then
        events_emit "device_selected" "{\"serial\":\"$serial\"}" 2>/dev/null || true
    fi
}

##############################################
# Execute a command on one or more devices.
# Arguments:
#   $1: target type (single|all|oem)
#   $2: command string or function name
#   $@: additional args
##############################################
devices_execute() {
    local target_type="$1" command_name="$2"
    shift 2

    local targets=()

    case "$target_type" in
        single)
            local serial
            serial="$(devices_get_active)"
            if [[ -z "$serial" ]]; then
                log_error "No active device set. Use --device <serial> first."
                return 1
            fi
            targets=("$serial")
            ;;
        all)
            if ! devices_enumerate; then
                log_error "No devices connected"
                return 1
            fi
            targets=("${DEVICES_LIST_CACHE[@]}")
            ;;
        oem)
            local oem_filter="$command_name"
            command_name="$1"
            shift
            if ! devices_enumerate; then
                log_error "No devices connected"
                return 1
            fi
            local serial
            for serial in "${DEVICES_LIST_CACHE[@]}"; do
                local details manuf
                details="$(devices_get_details "$serial")"
                manuf="$(echo "$details" | jq -r '.manufacturer' 2>/dev/null || echo "")"
                if [[ "$manuf" == "$oem_filter" ]]; then
                    targets+=("$serial")
                fi
            done
            ;;
        *)
            log_error "Unknown target type: $target_type"
            return 1
            ;;
    esac

    if [[ ${#targets[@]} -eq 0 ]]; then
        log_warning "No matching devices found"
        return 1
    fi

    local serial
    for serial in "${targets[@]}"; do
        log_info "Executing on $serial..."
        ANDROID_TOOLKIT_ADB_SERIAL="$serial" \
        ANDROID_TOOLKIT_BACKEND="adb" \
        "$command_name" "$@" 2>/dev/null || {
            log_warning "Command failed on $serial"
        }
    done
}

##############################################
# Main entry point for --device flag.
# Sets active device and optionally executes a command.
# Arguments:
#   $1: device serial
#   $@: remaining args passed through
##############################################
devices_handle_device_flag() {
    local serial="$1"
    shift

    devices_set_active "$serial" || return 1

    # If there's a remaining action, execute on the selected device
    if [[ -n "${ACTION:-}" ]]; then
        ANDROID_TOOLKIT_ADB_SERIAL="$serial"
        ANDROID_TOOLKIT_BACKEND="adb"
        # Re-run _main with the device set
        _main
    fi
}

##############################################
# Handle --all-devices: run on all connected devices.
# Arguments:
#   $@: remaining args (action)
##############################################
devices_handle_all_flag() {
    if ! devices_enumerate; then
        log_error "No devices connected"
        return 1
    fi

    local serial
    for serial in "${DEVICES_LIST_CACHE[@]}"; do
        echo ""
        log_info "═══ Device: $serial ═══"
        ANDROID_TOOLKIT_ADB_SERIAL="$serial"
        ANDROID_TOOLKIT_BACKEND="adb"
        _main 2>/dev/null || log_warning "Failed on $serial"
    done
}

# Cleanup
trap 'rm -f "$DEVICES_CACHE_FILE" 2>/dev/null || true' EXIT INT TERM
