#!/data/data/com.termux/files/usr/bin/bash
#
# status.sh — Device Status Collection
#
# Gathers live device data by calling existing toolkit APIs.
# Caches results to minimize backend calls.
# All data is consumed by widgets.sh for rendering.
#
# Part of the Android Toolkit Dashboard.

# ──────────────────────────────────────────────
# STATUS CACHE
# ──────────────────────────────────────────────
declare -A STATUS_CACHE=()
STATUS_CACHE_TTL=5  # seconds before refresh
STATUS_CACHE_TS=0

##############################################
# Refresh all status data from device.
status_refresh() {
    local now
    now="$(date +%s)"
    local age=$(( now - STATUS_CACHE_TS ))
    [[ "$age" -lt "$STATUS_CACHE_TTL" ]] && return 0

    STATUS_CACHE_TS="$now"

    # Device info
    STATUS_CACHE["model"]="${DEVICE_MODEL:-unknown}"
    STATUS_CACHE["manufacturer"]="${DEVICE_MANUFACTURER:-unknown}"
    STATUS_CACHE["android"]="${DEVICE_ANDROID_VERSION:-?}"
    STATUS_CACHE["sdk"]="${DEVICE_SDK_VERSION:-?}"
    STATUS_CACHE["abi"]="${DEVICE_ABI:-?}"
    STATUS_CACHE["fingerprint"]="${DEVICE_BUILD_FINGERPRINT:-unknown}"
    STATUS_CACHE["is_samsung"]="${DEVICE_IS_SAMSUNG:-false}"
    STATUS_CACHE["oneui"]="${DEVICE_ONE_UI_VERSION:-N/A}"
    STATUS_CACHE["backend"]="${ANDROID_TOOLKIT_BACKEND:-none}"
    STATUS_CACHE["version"]="${ANDROID_TOOLKIT_VERSION:-?}"

    # Battery
    local battery_data
    battery_data="$(backend_exec dumpsys battery 2>/dev/null || true)"
    local bat_level bat_scale bat_temp bat_status
    bat_level="$(echo "$battery_data" | grep 'level:' | head -1 | awk '{print $2}')"
    bat_scale="$(echo "$battery_data" | grep 'scale:' | head -1 | awk '{print $2}')"
    bat_temp="$(echo "$battery_data" | grep 'temperature:' | head -1 | awk '{print $2}')"
    bat_status="$(echo "$battery_data" | grep 'status:' | head -1 | awk '{print $2}')"

    if [[ -n "$bat_level" && -n "$bat_scale" ]] && [[ "$bat_scale" -gt 0 ]]; then
        STATUS_CACHE["battery_pct"]="$(( bat_level * 100 / bat_scale ))"
    else
        STATUS_CACHE["battery_pct"]="?"
    fi
    if [[ -n "$bat_temp" ]]; then
        STATUS_CACHE["battery_temp"]="$(echo "scale=1; $bat_temp / 10" | bc 2>/dev/null || echo "?")"
    else
        STATUS_CACHE["battery_temp"]="?"
    fi
    STATUS_CACHE["battery_plugged"]="$([[ "$bat_status" == "2" || "$bat_status" == "3" ]] && echo true || echo false)"

    # Determine battery health label
    local health_code
    health_code="$(echo "$battery_data" | grep 'health:' | head -1 | awk '{print $2}')"
    case "$health_code" in
        1) STATUS_CACHE["battery_health"]="Unknown" ;;
        2) STATUS_CACHE["battery_health"]="Good" ;;
        3) STATUS_CACHE["battery_health"]="Overheat" ;;
        4) STATUS_CACHE["battery_health"]="Dead" ;;
        5) STATUS_CACHE["battery_health"]="Over Voltage" ;;
        6) STATUS_CACHE["battery_health"]="Unspecified" ;;
        7) STATUS_CACHE["battery_health"]="Cold" ;;
        *) STATUS_CACHE["battery_health"]="?" ;;
    esac

    # Memory
    local mem_data
    mem_data="$(backend_exec meminfo 2>/dev/null || backend_exec cat /proc/meminfo 2>/dev/null || true)"
    local mem_total mem_free mem_avail
    mem_total="$(echo "$mem_data" | grep 'MemTotal:' | awk '{print $2}')"
    mem_free="$(echo "$mem_data" | grep 'MemFree:' | awk '{print $2}')"
    mem_avail="$(echo "$mem_data" | grep 'MemAvailable:' | awk '{print $2}')"

    if [[ -n "$mem_total" && "$mem_total" -gt 0 ]]; then
        STATUS_CACHE["mem_total_mb"]="$(( mem_total / 1024 ))"
        if [[ -n "$mem_avail" ]]; then
            STATUS_CACHE["mem_avail_mb"]="$(( mem_avail / 1024 ))"
            STATUS_CACHE["mem_pct"]="$(( (mem_total - mem_avail) * 100 / mem_total ))"
        elif [[ -n "$mem_free" ]]; then
            STATUS_CACHE["mem_avail_mb"]="$(( mem_free / 1024 ))"
            STATUS_CACHE["mem_pct"]="$(( (mem_total - mem_free) * 100 / mem_total ))"
        fi
    else
        STATUS_CACHE["mem_total_mb"]="?"
        STATUS_CACHE["mem_avail_mb"]="?"
        STATUS_CACHE["mem_pct"]="?"
    fi

    # Storage
    local storage_data
    storage_data="$(backend_exec df -h /data 2>/dev/null || true)"
    local storage_line
    storage_line="$(echo "$storage_data" | awk 'NR==2')"
    STATUS_CACHE["storage_used"]="$(echo "$storage_line" | awk '{print $3}')"
    STATUS_CACHE["storage_total"]="$(echo "$storage_line" | awk '{print $2}')"
    STATUS_CACHE["storage_pct"]="$(echo "$storage_line" | awk '{print $5}' | tr -d '%')"

    local kernel bootloader
    kernel="$(backend_exec getprop ro.build.version.release 2>/dev/null || true)"
    bootloader="$(backend_exec getprop ro.bootloader 2>/dev/null || true)"
    STATUS_CACHE["kernel"]="$(backend_exec uname -r 2>/dev/null || echo "?")"
    STATUS_CACHE["bootloader"]="${bootloader:-?}"

    # CPU
    local cpu_data
    cpu_data="$(backend_exec cat /proc/cpuinfo 2>/dev/null || true)"
    STATUS_CACHE["cpu_cores"]="$(echo "$cpu_data" | grep -c '^processor' || echo "?")"
    local cpu_max
    cpu_max="$(backend_exec cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null || echo "?")"
    if [[ -n "$cpu_max" && "$cpu_max" != "?" ]]; then
        STATUS_CACHE["cpu_max_hz"]="$(( cpu_max / 1000 ))"
    else
        STATUS_CACHE["cpu_max_hz"]="?"
    fi

    # Network
    local wifi_status
    wifi_status="$(backend_exec dumpsys wifi 2>/dev/null | grep 'mNetworkInfo' | head -1 || true)"
    if echo "$wifi_status" | grep -qi 'connected'; then
        STATUS_CACHE["network"]="WiFi"
    elif backend_exec dumpsys connectivity 2>/dev/null | grep -qi 'mobile.*CONNECTED'; then
        STATUS_CACHE["network"]="Mobile"
    else
        STATUS_CACHE["network"]="Disconnected"
    fi

    # Security
    local patch
    patch="$(backend_exec getprop ro.build.version.security_patch 2>/dev/null || echo "?")"
    STATUS_CACHE["security_patch"]="${patch:0:7}"
    STATUS_CACHE["selinux"]="$(backend_exec getprop ro.build.selinux 2>/dev/null || echo "?")"

    # Root
    local ro_secure
    ro_secure="$(backend_exec getprop ro.secure 2>/dev/null || echo "1")"
    if [[ "$ro_secure" == "0" ]]; then
        STATUS_CACHE["root"]="true"
    else
        STATUS_CACHE["root"]="false"
    fi

    # Temperature (thermal)
    local thermal
    thermal="$(backend_exec cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "?")"
    if [[ -n "$thermal" && "$thermal" != "?" ]]; then
        STATUS_CACHE["thermal"]="$(echo "scale=1; $thermal / 1000" | bc 2>/dev/null || echo "?")"
    else
        STATUS_CACHE["thermal"]="?"
    fi
}

##############################################
# Get a single cached status value.
# Arguments:
#   $1: key name
# Outputs: value
status_get() {
    local key="$1"
    status_refresh
    echo "${STATUS_CACHE[$key]:-?}"
}

##############################################
# Get all status as a JSON-like string.
# Outputs: key=value pairs
status_dump() {
    status_refresh
    for key in "${!STATUS_CACHE[@]}"; do
        printf '%s=%s\n' "$key" "${STATUS_CACHE[$key]}"
    done
}
