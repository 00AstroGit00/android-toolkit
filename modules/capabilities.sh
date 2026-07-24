#!/data/data/com.termux/files/usr/bin/bash
#
# capabilities.sh — Device, runtime, and feature capability detection
#
# Provides comprehensive detection of device hardware, software,
# runtime environment, and available system features.
# Every capability is probed — never assumed.
#
# All results are cached in CAP_* globals for fast subsequent access.
#
# Part of the Android Toolkit.

# ──────────────────────────────────────────────
# Capability globals (populated by cap_detect_all)
# ──────────────────────────────────────────────

# Device hardware/software
CAP_MANUFACTURER=""
CAP_BRAND=""
CAP_MODEL=""
CAP_PRODUCT=""
CAP_DEVICE=""
CAP_SOC=""
CAP_ABI=""
CAP_ANDROID_VERSION=""
CAP_SDK_VERSION=""
CAP_SECURITY_PATCH=""
CAP_KERNEL=""
CAP_BUILD_FINGERPRINT=""
CAP_BUILD_TYPE=""
CAP_IS_ROOTED=false
CAP_SELINUX_MODE=""
CAP_ONE_UI_VERSION=""
CAP_BOOTLOADER=""
CAP_BASEBAND=""

# Runtime environment
CAP_ADB_AVAILABLE=false
CAP_SHIZUKU_AVAILABLE=false
CAP_RISH_AVAILABLE=false
CAP_WIRELESS_DEBUGGING=false
CAP_USB_DEBUGGING=false
CAP_BUSYBOX_AVAILABLE=false
CAP_TOYBOX_AVAILABLE=false
CAP_TIMEOUT_AVAILABLE=false
CAP_DIALOG_AVAILABLE=false
CAP_JQ_AVAILABLE=false
CAP_CURL_AVAILABLE=false
CAP_GIT_AVAILABLE=false

# Feature support (dumpsys commands)
CAP_PM_COMPILE=false
CAP_BG_DEXOPT=false
CAP_CMD_PACKAGE=false
CAP_CMD_APPOPS=false
CAP_DEVICE_CONFIG=false
CAP_SETTINGS_NAMESPACES=false
CAP_CMD_ACTIVITY=false
CAP_CMD_NOTIFICATION=false
CAP_CMD_JOBSCHEDULER=false
CAP_CMD_SHORTCUT=false
CAP_WM=false
CAP_SVC=false
CAP_DUMPSYS_THERMAL=false
CAP_DUMPSYS_BATTERY=false
CAP_DUMPSYS_GFXINFO=false
CAP_DUMPSYS_MEMINFO=false
CAP_DUMPSYS_SURFACEFLINGER=false
CAP_DUMPSYS_DISPLAY=false
CAP_DUMPSYS_POWER=false
CAP_DUMPSYS_NETSTATS=false
CAP_DUMPSYS_PACKAGE=false
CAP_DUMPSYS_MEDIA=false
CAP_DUMPSYS_LOCATION=false
CAP_DUMPSYS_WIFI=false
CAP_DUMPSYS_BLUETOOTH=false
CAP_DUMPSYS_TELEPHONY=false
CAP_DUMPSYS_APP_OPS=false
CAP_DUMPSYS_USAGE=false
CAP_DUMPSYS_BATTERYSTATS=false
CAP_DUMPSYS_PROCSTATS=false

# Feature support (commands)
CAP_CMD_SETTINGS=false
CAP_CMD_WM=false
CAP_PM=false
CAP_AM=false
CAP_INPUT=false
CAP_MEDIA=false
CAP_NETSTAT=false
CAP_IP=false
CAP_IFCONFIG=false
CAP_PING=false
CAP_DMESG=false
CAP_LOGCAST=false
CAP_TOP=false
CAP_PS=false
CAP_DF=false
CAP_FREE=false
CAP_UPTIME=false

# Capacity plan
CAP_DETECTED=false

##############################################
# Run all capability detections.
# Sets all CAP_* globals.
# Safe to call multiple times (cached via CAP_DETECTED).
##############################################
cap_detect_all() {
    [[ "$CAP_DETECTED" == "true" ]] && return 0

    log_section "Capability Detection"

    _cap_detect_device
    _cap_detect_runtime
    _cap_detect_features

    CAP_DETECTED=true

    if [[ "${LOG_LEVEL:-info}" == "debug" ]]; then
        _cap_debug_report
    fi

    log_success "Capability detection complete"
}

##############################################
# Detect device hardware and software properties.
##############################################
_cap_detect_device() {
    CAP_MANUFACTURER="$(backend_getprop ro.product.manufacturer 2>/dev/null || echo 'unknown')"
    CAP_BRAND="$(backend_getprop ro.product.brand 2>/dev/null || echo 'unknown')"
    CAP_MODEL="$(backend_getprop ro.product.model 2>/dev/null || echo 'unknown')"
    CAP_PRODUCT="$(backend_getprop ro.product.name 2>/dev/null || echo 'unknown')"
    CAP_DEVICE="$(backend_getprop ro.product.device 2>/dev/null || echo 'unknown')"
    CAP_SOC="$(backend_getprop ro.chipname 2>/dev/null || backend_getprop ro.soc.model 2>/dev/null || echo 'unknown')"
    CAP_ABI="$(backend_getprop ro.product.cpu.abi 2>/dev/null || echo 'unknown')"
    CAP_ANDROID_VERSION="$(backend_getprop ro.build.version.release 2>/dev/null || echo 'unknown')"
    CAP_SDK_VERSION="$(backend_getprop ro.build.version.sdk 2>/dev/null || echo 'unknown')"
    CAP_SECURITY_PATCH="$(backend_getprop ro.build.version.security_patch 2>/dev/null || echo 'unknown')"
    CAP_BUILD_FINGERPRINT="$(backend_getprop ro.build.fingerprint 2>/dev/null || echo 'unknown')"
    CAP_BUILD_TYPE="$(backend_getprop ro.build.type 2>/dev/null || echo 'unknown')"
    CAP_BOOTLOADER="$(backend_getprop ro.bootloader 2>/dev/null || echo 'unknown')"
    CAP_BASEBAND="$(backend_getprop ro.baseband 2>/dev/null || echo 'unknown')"

    # Kernel
    CAP_KERNEL="$(backend_exec uname -r 2>/dev/null | tr -d '\r\n' || echo 'unknown')"

    # Root status
    local su_check
    su_check="$(backend_exec which su 2>/dev/null | tr -d '\r\n' || true)"
    if [[ -n "$su_check" ]]; then
        CAP_IS_ROOTED=true
    fi

    # SELinux mode
    local selinux
    selinux="$(backend_exec getenforce 2>/dev/null | tr -d '\r\n' || true)"
    if [[ -z "$selinux" ]]; then
        selinux="$(cat /sys/fs/selinux/enforce 2>/dev/null && echo "enforcing" || echo "permissive" 2>/dev/null || true)"
    fi
    CAP_SELINUX_MODE="${selinux:-unknown}"

    # One UI version (Samsung)
    CAP_ONE_UI_VERSION="$(backend_getprop ro.build.version.oneui 2>/dev/null || true)"
    if [[ -z "$CAP_ONE_UI_VERSION" ]]; then
        CAP_ONE_UI_VERSION="$(backend_getprop ro.samsung.build.version.oneui 2>/dev/null || true)"
    fi
}

##############################################
# Detect runtime environment capabilities.
##############################################
_cap_detect_runtime() {
    # ADB
    if command -v adb &>/dev/null; then
        CAP_ADB_AVAILABLE=true
    fi

    # Shizuku service
    if backend_package_installed "moe.shizuku.privileged.api" 2>/dev/null; then
        CAP_SHIZUKU_AVAILABLE=true
    fi

    # rish binary
    if command -v rish &>/dev/null; then
        CAP_RISH_AVAILABLE=true
    elif [[ -x "/data/data/com.termux/files/usr/bin/rish" ]]; then
        CAP_RISH_AVAILABLE=true
    elif [[ -x "/data/local/tmp/rish" ]]; then
        CAP_RISH_AVAILABLE=true
    fi

    # Wireless debugging
    local wireless_adb
    wireless_adb="$(backend_settings_get global development_settings_enabled 2>/dev/null || true)"
    if backend_exec settings get global adb_wifi_enabled 2>/dev/null | grep -qi '1\|true' 2>/dev/null; then
        CAP_WIRELESS_DEBUGGING=true
    fi

    # USB debugging
    local usb_debug
    usb_debug="$(backend_settings_get global adb_enabled 2>/dev/null || true)"
    if [[ "$usb_debug" == "1" ]]; then
        CAP_USB_DEBUGGING=true
    fi

    # Busybox
    if command -v busybox &>/dev/null; then
        CAP_BUSYBOX_AVAILABLE=true
    elif backend_exec busybox --help 2>/dev/null | grep -qi 'busybox' 2>/dev/null; then
        CAP_BUSYBOX_AVAILABLE=true
    fi

    # Toybox
    if command -v toybox &>/dev/null; then
        CAP_TOYBOX_AVAILABLE=true
    elif backend_exec toybox --version 2>/dev/null | grep -qi 'toybox' 2>/dev/null; then
        CAP_TOYBOX_AVAILABLE=true
    fi

    # Common utilities
    command -v timeout &>/dev/null && CAP_TIMEOUT_AVAILABLE=true
    command -v dialog &>/dev/null && CAP_DIALOG_AVAILABLE=true
    command -v jq &>/dev/null && CAP_JQ_AVAILABLE=true
    command -v curl &>/dev/null && CAP_CURL_AVAILABLE=true
    command -v git &>/dev/null && CAP_GIT_AVAILABLE=true
}

##############################################
# Detect feature support via dumpsys and commands.
# Each feature is probed with a lightweight check.
##############################################
_cap_detect_features() {
    # pm commands
    if backend_exec pm --help 2>/dev/null | grep -qi 'compile' 2>/dev/null; then
        CAP_PM_COMPILE=true
    fi
    if backend_exec cmd package bg-dexopt-job 2>/dev/null; then
        CAP_BG_DEXOPT=true
    fi
    if [[ "$CAP_PM_COMPILE" == "true" ]]; then
        CAP_PM=true
    fi

    # cmd package
    if backend_exec cmd package --help 2>/dev/null | grep -qi 'compile\|install' 2>/dev/null; then
        CAP_CMD_PACKAGE=true
    fi

    # cmd appops
    if backend_exec cmd appops --help 2>/dev/null | grep -qi 'get\|set' 2>/dev/null; then
        CAP_CMD_APPOPS=true
    fi

    # device_config
    if backend_exec device_config --help 2>/dev/null | grep -qi 'get\|put' 2>/dev/null; then
        CAP_DEVICE_CONFIG=true
    fi

    # settings namespaces
    if backend_exec settings list global 2>/dev/null | head -1 | grep -q '='; then
        CAP_SETTINGS_NAMESPACES=true
    fi

    # cmd activity
    if backend_exec cmd activity --help 2>/dev/null | grep -qi 'start\|broadcast' 2>/dev/null; then
        CAP_CMD_ACTIVITY=true
    fi

    # cmd notification
    if backend_exec cmd notification --help 2>/dev/null | grep -qi 'post\|list' 2>/dev/null; then
        CAP_CMD_NOTIFICATION=true
    fi

    # cmd jobscheduler
    if backend_exec cmd jobscheduler --help 2>/dev/null | grep -qi 'run\|cancel' 2>/dev/null; then
        CAP_CMD_JOBSCHEDULER=true
    fi

    # cmd shortcut
    if backend_exec cmd shortcut --help 2>/dev/null | grep -qi 'list\|reset' 2>/dev/null; then
        CAP_CMD_SHORTCUT=true
    fi

    # wm
    if backend_exec wm size 2>/dev/null | grep -qi 'physical' 2>/dev/null; then
        CAP_WM=true
    fi
    CAP_CMD_WM="$CAP_WM"

    # svc
    if backend_exec svc --help 2>/dev/null | grep -qi 'wifi\|data' 2>/dev/null; then
        CAP_SVC=true
    fi

    # settings
    if backend_exec settings --help 2>/dev/null | grep -qi 'get\|put\|list' 2>/dev/null; then
        CAP_CMD_SETTINGS=true
    fi

    # am
    if backend_exec am --help 2>/dev/null | grep -qi 'start\|force-stop' 2>/dev/null; then
        CAP_AM=true
    fi

    # input
    if backend_exec input --help 2>/dev/null | grep -qi 'keyevent\|tap' 2>/dev/null; then
        CAP_INPUT=true
    fi

    # media
    if backend_exec media --help 2>/dev/null | grep -qi 'volume\|record' 2>/dev/null; then
        CAP_MEDIA=true
    fi

    # Dumpsys services — probe each with a brief timeout
    local dump_services=(
        "thermalservice:thermalservice"
        "battery:battery"
        "gfxinfo:gfxinfo"
        "meminfo:meminfo"
        "SurfaceFlinger:surfaceflinger"
        "display:display"
        "power:power"
        "netstats:netstats"
        "package:package"
        "media:media"
        "location:location"
        "wifi:wifi"
        "bluetooth:bluetooth"
        "telephony:telephony"
        "appops:appops"
        "usage:usage"
        "batterystats:batterystats"
        "procstats:procstats"
    )

    for entry in "${dump_services[@]}"; do
        local service="${entry%%:*}"
        local varname="${entry##*:}"
        local var="CAP_DUMPSYS_$(echo "$varname" | tr '[:lower:]' '[:upper:]')"

        if backend_exec dumpsys "$service" 2>/dev/null | head -5 | grep -qi '.' 2>/dev/null; then
            printf -v "$var" "true"
        fi
    done

    # Common shell commands on device
    command -v netstat &>/dev/null && CAP_NETSTAT=true
    command -v ip &>/dev/null && CAP_IP=true
    command -v ifconfig &>/dev/null && CAP_IFCONFIG=true
    command -v ping &>/dev/null && CAP_PING=true
    command -v dmesg &>/dev/null && CAP_DMESG=true
    command -v logcat &>/dev/null && CAP_LOGCAST=true
    command -v top &>/dev/null && CAP_TOP=true
    command -v ps &>/dev/null && CAP_PS=true
    command -v df &>/dev/null && CAP_DF=true
    command -v free &>/dev/null && CAP_FREE=true
    command -v uptime &>/dev/null && CAP_UPTIME=true
}

##############################################
# Emit a debug report of all capabilities.
##############################################
_cap_debug_report() {
    log_debug "===== CAPABILITY REPORT ====="

    _cap_debug_section "DEVICE"
    _cap_debug_val "Manufacturer" "$CAP_MANUFACTURER"
    _cap_debug_val "Brand" "$CAP_BRAND"
    _cap_debug_val "Model" "$CAP_MODEL"
    _cap_debug_val "Product" "$CAP_PRODUCT"
    _cap_debug_val "Device" "$CAP_DEVICE"
    _cap_debug_val "SOC" "$CAP_SOC"
    _cap_debug_val "ABI" "$CAP_ABI"
    _cap_debug_val "Android" "$CAP_ANDROID_VERSION"
    _cap_debug_val "SDK" "$CAP_SDK_VERSION"
    _cap_debug_val "Security Patch" "$CAP_SECURITY_PATCH"
    _cap_debug_val "Kernel" "$CAP_KERNEL"
    _cap_debug_val "Build Type" "$CAP_BUILD_TYPE"
    _cap_debug_val "Bootloader" "$CAP_BOOTLOADER"
    _cap_debug_val "Baseband" "$CAP_BASEBAND"
    _cap_debug_val "One UI" "$CAP_ONE_UI_VERSION"
    _cap_debug_val "Rooted" "$CAP_IS_ROOTED"
    _cap_debug_val "SELinux" "$CAP_SELINUX_MODE"

    _cap_debug_section "RUNTIME"
    _cap_debug_val "ADB" "$CAP_ADB_AVAILABLE"
    _cap_debug_val "Shizuku" "$CAP_SHIZUKU_AVAILABLE"
    _cap_debug_val "rish" "$CAP_RISH_AVAILABLE"
    _cap_debug_val "Wireless Debug" "$CAP_WIRELESS_DEBUGGING"
    _cap_debug_val "USB Debug" "$CAP_USB_DEBUGGING"
    _cap_debug_val "Busybox" "$CAP_BUSYBOX_AVAILABLE"
    _cap_debug_val "Toybox" "$CAP_TOYBOX_AVAILABLE"
    _cap_debug_val "timeout" "$CAP_TIMEOUT_AVAILABLE"
    _cap_debug_val "dialog" "$CAP_DIALOG_AVAILABLE"
    _cap_debug_val "jq" "$CAP_JQ_AVAILABLE"
    _cap_debug_val "curl" "$CAP_CURL_AVAILABLE"
    _cap_debug_val "git" "$CAP_GIT_AVAILABLE"

    _cap_debug_section "FEATURES"
    _cap_debug_val "pm compile" "$CAP_PM_COMPILE"
    _cap_debug_val "bg-dexopt-job" "$CAP_BG_DEXOPT"
    _cap_debug_val "cmd package" "$CAP_CMD_PACKAGE"
    _cap_debug_val "cmd appops" "$CAP_CMD_APPOPS"
    _cap_debug_val "device_config" "$CAP_DEVICE_CONFIG"
    _cap_debug_val "settings" "$CAP_CMD_SETTINGS"
    _cap_debug_val "cmd activity" "$CAP_CMD_ACTIVITY"
    _cap_debug_val "cmd notification" "$CAP_CMD_NOTIFICATION"
    _cap_debug_val "cmd jobscheduler" "$CAP_CMD_JOBSCHEDULER"
    _cap_debug_val "cmd shortcut" "$CAP_CMD_SHORTCUT"
    _cap_debug_val "wm" "$CAP_WM"
    _cap_debug_val "svc" "$CAP_SVC"
    _cap_debug_val "Dumpsys thermal" "$CAP_DUMPSYS_THERMAL"
    _cap_debug_val "Dumpsys battery" "$CAP_DUMPSYS_BATTERY"
    _cap_debug_val "Dumpsys gfxinfo" "$CAP_DUMPSYS_GFXINFO"
    _cap_debug_val "Dumpsys meminfo" "$CAP_DUMPSYS_MEMINFO"
    _cap_debug_val "Dumpsys SurfaceFlinger" "$CAP_DUMPSYS_SURFACEFLINGER"
    _cap_debug_val "Dumpsys display" "$CAP_DUMPSYS_DISPLAY"
    _cap_debug_val "Dumpsys power" "$CAP_DUMPSYS_POWER"
    _cap_debug_val "Dumpsys package" "$CAP_DUMPSYS_PACKAGE"
    _cap_debug_val "Dumpsys batterystats" "$CAP_DUMPSYS_BATTERYSTATS"
    _cap_debug_val "Dumpsys procstats" "$CAP_DUMPSYS_PROCSTATS"
}

_cap_debug_section() {
    log_debug "--- $1 ---"
}
_cap_debug_val() {
    log_debug "  $1: $2"
}

##############################################
# Check if a specific capability is available.
# Usage: cap_available "CAP_ADB_AVAILABLE"
# Returns: 0 if true, 1 if false/unknown
##############################################
cap_available() {
    local cap_name="$1"
    [[ "${!cap_name:-false}" == "true" ]]
}

##############################################
# Get a capability value as string.
# Usage: cap_get "CAP_ANDROID_VERSION"
# Returns: value or "unknown"
##############################################
cap_get() {
    local cap_name="$1"
    echo "${!cap_name:-unknown}"
}

##############################################
# Check if a dumpsys service is available.
# Usage: cap_has_dumpsys "battery"
# Returns: 0 if available
##############################################
cap_has_dumpsys() {
    local service="$1"
    local var="CAP_DUMPSYS_$(echo "$service" | tr '[:lower:]' '[:upper:]')"
    [[ "${!var:-false}" == "true" ]]
}

##############################################
# Return a JSON object of all capabilities.
# Requires jq for pretty output; falls back to raw.
##############################################
cap_to_json() {
    local json="{"

    # Device
    json+="\"device\":{"
    json+="\"manufacturer\":\"${CAP_MANUFACTURER}\","
    json+="\"brand\":\"${CAP_BRAND}\","
    json+="\"model\":\"${CAP_MODEL}\","
    json+="\"product\":\"${CAP_PRODUCT}\","
    json+="\"device\":\"${CAP_DEVICE}\","
    json+="\"soc\":\"${CAP_SOC}\","
    json+="\"abi\":\"${CAP_ABI}\","
    json+="\"android\":\"${CAP_ANDROID_VERSION}\","
    json+="\"sdk\":\"${CAP_SDK_VERSION}\","
    json+="\"securityPatch\":\"${CAP_SECURITY_PATCH}\","
    json+="\"kernel\":\"${CAP_KERNEL}\","
    json+="\"buildType\":\"${CAP_BUILD_TYPE}\","
    json+="\"oneUi\":\"${CAP_ONE_UI_VERSION}\","
    json+="\"isRooted\":${CAP_IS_ROOTED},"
    json+="\"selinux\":\"${CAP_SELINUX_MODE}\""
    json+="},"

    # Runtime
    json+="\"runtime\":{"
    json+="\"adb\":${CAP_ADB_AVAILABLE},"
    json+="\"shizuku\":${CAP_SHIZUKU_AVAILABLE},"
    json+="\"rish\":${CAP_RISH_AVAILABLE},"
    json+="\"wirelessDebugging\":${CAP_WIRELESS_DEBUGGING},"
    json+="\"usbDebugging\":${CAP_USB_DEBUGGING},"
    json+="\"busybox\":${CAP_BUSYBOX_AVAILABLE},"
    json+="\"toybox\":${CAP_TOYBOX_AVAILABLE},"
    json+="\"timeout\":${CAP_TIMEOUT_AVAILABLE},"
    json+="\"dialog\":${CAP_DIALOG_AVAILABLE},"
    json+="\"jq\":${CAP_JQ_AVAILABLE},"
    json+="\"curl\":${CAP_CURL_AVAILABLE},"
    json+="\"git\":${CAP_GIT_AVAILABLE}"
    json+="},"

    # Features
    json+="\"features\":{"
    json+="\"pmCompile\":${CAP_PM_COMPILE},"
    json+="\"bgDexopt\":${CAP_BG_DEXOPT},"
    json+="\"cmdPackage\":${CAP_CMD_PACKAGE},"
    json+="\"cmdAppops\":${CAP_CMD_APPOPS},"
    json+="\"deviceConfig\":${CAP_DEVICE_CONFIG},"
    json+="\"settings\":${CAP_CMD_SETTINGS},"
    json+="\"wm\":${CAP_WM},"
    json+="\"svc\":${CAP_SVC}"
    json+="}"
    json+="}"

    if command -v jq &>/dev/null; then
        echo "$json" | jq . 2>/dev/null || echo "$json"
    else
        echo "$json"
    fi
}
