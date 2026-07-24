#!/data/data/com.termux/files/usr/bin/bash
#
# api.sh — Public API for the Android Toolkit
#
# Exports a stable, documented interface for:
#   - Logging and output
#   - Backend operations (ADB/rish)
#   - Capability detection
#   - Event system
#   - Plugin loading
#   - Rollback
#   - Reporting
#   - Configuration
#   - Benchmarking
#   - Package management
#
# Each function is marked as PUBLIC or PRIVATE.
# PUBLIC functions are stable across minor versions.
# PRIVATE functions may change without notice.
#
# Part of the Android Toolkit.

# ═══════════════════════════════════════════════════════════════
# LOGGING API
# ═══════════════════════════════════════════════════════════════

# PUBLIC: Log a message at the specified level.
# Usage: api_log <level> <message>
# Levels: trace, debug, info, warn, error, fatal
api_log() {
    local level="$1" msg="$2"
    if declare -f "log_${level}" &>/dev/null; then
        "log_${level}" "$msg"
    elif declare -f log_message &>/dev/null; then
        log_message "$level" "$msg"
    fi
}

# PUBLIC: Log info-level message.
# Usage: api_info <message>
api_info() { api_log "info" "$1"; }

# PUBLIC: Log warning-level message.
# Usage: api_warn <message>
api_warn() { api_log "warn" "$1"; }

# PUBLIC: Log error-level message.
# Usage: api_error <message>
api_error() { api_log "error" "$1"; }

# PUBLIC: Log success message (info-level with green styling).
# Usage: api_success <message>
api_success() {
    if declare -f log_success &>/dev/null; then
        log_success "$1"
    else
        api_log "info" "$1"
    fi
}

# PUBLIC: Log debug-level message.
# Usage: api_debug <message>
api_debug() { api_log "debug" "$1"; }

# PUBLIC: Log a section header.
# Usage: api_section <title>
api_section() {
    if declare -f log_section &>/dev/null; then
        log_section "$1"
    else
        echo ""
        echo "  == $1 =="
        echo ""
    fi
}

# ═══════════════════════════════════════════════════════════════
# OUTPUT API
# ═══════════════════════════════════════════════════════════════

# PUBLIC: Print a table header row.
# Usage: api_table_header <format_string> <col1> <col2> ...
api_table_header() {
    local fmt="$1"
    shift
    printf "$fmt" "$@"
    # Print separator (simple dashes)
    local col
    for col in "$@"; do
        printf -- "----"
    done
    echo ""
}

# PUBLIC: Print a table row.
# Usage: api_table_row <format_string> <val1> <val2> ...
api_table_row() {
    local fmt="$1"
    shift
    printf "$fmt" "$@"
}

# PUBLIC: Get current JSON output mode.
# Returns: true if JSON output is enabled
api_json_enabled() {
    [[ "${JSON_OUTPUT:-false}" == "true" ]]
}

# PUBLIC: Check if running in dry-run mode.
# Returns: true if dry-run is enabled
api_dry_run() {
    [[ "${ANDROID_TOOLKIT_DRY_RUN:-false}" == "true" ]]
}

# PUBLIC: Confirm an action with the user.
# Usage: api_confirm <prompt>
# Returns: 0 if confirmed
api_confirm() {
    if declare -f utils_confirm &>/dev/null; then
        utils_confirm "$1"
    else
        # Fallback: simple yes/no
        echo -n "  $1 [y/N] "
        local resp
        read -r resp
        [[ "$resp" =~ ^[Yy] ]]
    fi
}

# ═══════════════════════════════════════════════════════════════
# BACKEND API
# ═══════════════════════════════════════════════════════════════

# PUBLIC: Get the current backend name.
# Usage: api_backend
# Outputs: adb | rish | auto
api_backend() {
    echo "${ANDROID_TOOLKIT_BACKEND:-auto}"
}

# PUBLIC: Get the current ADB serial (if set).
# Usage: api_adb_serial
# Outputs: serial or empty
api_adb_serial() {
    echo "${ANDROID_TOOLKIT_ADB_SERIAL:-}"
}

# PUBLIC: Check if a backend is available.
# Usage: api_backend_available <backend>
# Returns: 0 if available
api_backend_available() {
    local backend="$1"
    case "$backend" in
        adb)
            command -v adb &>/dev/null
            ;;
        rish)
            command -v rish &>/dev/null || [[ -x "/data/data/com.termux/files/usr/bin/rish" ]] || [[ -x "/data/local/tmp/rish" ]]
            ;;
        *)
            false
            ;;
    esac
}

# PUBLIC: Get the currently selected backend type.
# Outputs: "adb", "rish", "local"
api_backend_type() {
    echo "${ANDROID_TOOLKIT_BACKEND_TYPE:-unknown}"
}

# PUBLIC: Execute a shell command via the backend.
# Usage: api_backend_shell <command>
api_backend_shell() {
    if declare -f backend_shell &>/dev/null; then
        backend_shell "$@"
    else
        log_error "Backend shell not available"
        return 1
    fi
}

# PUBLIC: Execute a settings put command via the backend.
# Usage: api_backend_settings_put <namespace> <key> <value>
api_backend_settings_put() {
    if declare -f backend_settings_put &>/dev/null; then
        backend_settings_put "$@"
    else
        log_error "Backend settings put not available"
        return 1
    fi
}

# PUBLIC: Read a device property.
# Usage: api_get_prop <key>
api_get_prop() {
    local key="$1"
    if declare -f backend_shell &>/dev/null; then
        backend_shell "getprop $key" 2>/dev/null | tr -d '\r'
    fi
}

# ═══════════════════════════════════════════════════════════════
# CAPABILITY API
# ═══════════════════════════════════════════════════════════════

# PUBLIC: Check if a capability is available.
# Usage: api_has_capability <name>
# Returns: 0 if available
api_has_capability() {
    local name="$1"
    if declare -f cap_graph_has &>/dev/null; then
        cap_graph_has "$name"
        return $?
    fi
    # Fallback: check CAP_ variable
    local var="CAP_$(echo "$name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')"
    [[ "${!var:-}" == "true" ]]
}

# PUBLIC: List all available capabilities.
# Usage: api_list_capabilities
api_list_capabilities() {
    if declare -f cap_graph_list &>/dev/null; then
        cap_graph_list
    else
        env | grep '^CAP_' | sed 's/^CAP_//' | sort
    fi
}

# PUBLIC: Get the Android SDK version.
# Usage: api_android_sdk
# Outputs: numeric SDK (e.g., 34)
api_android_sdk() {
    echo "${CAP_ANDROID_SDK:-${ANDROID_SDK:-0}}"
}

# PUBLIC: Get the Android version string.
# Usage: api_android_version
# Outputs: e.g., "14", "15"
api_android_version() {
    echo "${CAP_ANDROID_VERSION:-${ANDROID_VERSION:-unknown}}"
}

# PUBLIC: Get the device manufacturer.
# Usage: api_device_manufacturer
# Outputs: e.g., "samsung", "google"
api_device_manufacturer() {
    local m="${CAP_MANUFACTURER:-${ANDROID_MANUFACTURER:-}}"
    echo "${m,,}"
}

# PUBLIC: Get the device model.
# Usage: api_device_model
# Outputs: e.g., "SM-S928B"
api_device_model() {
    echo "${CAP_MODEL:-${ANDROID_MODEL:-unknown}}"
}

# PUBLIC: Get the OEM identifier.
# Usage: api_device_oem
# Outputs: e.g., "samsung", "google"
api_device_oem() {
    api_device_manufacturer
}

# ═══════════════════════════════════════════════════════════════
# EVENT API
# ═══════════════════════════════════════════════════════════════

# PUBLIC: Subscribe to an event.
# Usage: api_on <event_name> <handler_function>
api_on() {
    if declare -f events_subscribe &>/dev/null; then
        events_subscribe "$1" "$2"
    fi
}

# PUBLIC: Emit an event.
# Usage: api_emit <event_name> <payload>
api_emit() {
    if declare -f events_emit &>/dev/null; then
        events_emit "$1" "$2"
    fi
}

# ═══════════════════════════════════════════════════════════════
# PLUGIN API
# ═══════════════════════════════════════════════════════════════

# PUBLIC: Load all plugins.
# Usage: api_plugin_load_all
api_plugin_load_all() {
    if declare -f plugin_load_all &>/dev/null; then
        plugin_load_all
    fi
}

# PUBLIC: Load a single plugin.
# Usage: api_plugin_load <file> [name]
api_plugin_load() {
    if declare -f plugin_load &>/dev/null; then
        plugin_load "$@"
    fi
}

# PUBLIC: Check if a plugin is loaded.
# Usage: api_plugin_loaded <name>
# Returns: 0 if loaded
api_plugin_loaded() {
    if declare -f plugin_is_loaded &>/dev/null; then
        plugin_is_loaded "$1"
    fi
}

# PUBLIC: List loaded plugins.
# Usage: api_plugin_list
api_plugin_list() {
    if declare -f plugin_list &>/dev/null; then
        plugin_list
    fi
}

# PUBLIC: Get plugin config value.
# Usage: api_plugin_config <name> <key>
api_plugin_config() {
    if declare -f plugin_config_get &>/dev/null; then
        plugin_config_get "$1" "$2"
    fi
}

# PUBLIC: Show plugin help/info.
# Usage: api_plugin_help <name>
api_plugin_help() {
    if declare -f plugin_help &>/dev/null; then
        plugin_help "$1"
    fi
}

# ═══════════════════════════════════════════════════════════════
# ROLLBACK API
# ═══════════════════════════════════════════════════════════════

# PUBLIC: Begin a rollback transaction.
# Usage: api_rollback_begin <name>
api_rollback_begin() {
    if declare -f rollback_begin &>/dev/null; then
        rollback_begin "$1"
    fi
}

# PUBLIC: Record a rollback entry.
# Usage: api_rollback_record <namespace> <key> <old_value> <new_value>
api_rollback_record() {
    if declare -f rollback_record &>/dev/null; then
        rollback_record "$@"
    fi
}

# PUBLIC: Close and save a rollback transaction.
# Usage: api_rollback_close <name>
api_rollback_close() {
    if declare -f rollback_close &>/dev/null; then
        rollback_close "$1"
    fi
}

# PUBLIC: Perform a rollback.
# Usage: api_rollback_perform <target>
api_rollback_perform() {
    if declare -f rollback_perform &>/dev/null; then
        rollback_perform "$1"
    fi
}

# PUBLIC: List available rollback points.
# Usage: api_rollback_list
api_rollback_list() {
    if declare -f rollback_list &>/dev/null; then
        rollback_list
    fi
}

# ═══════════════════════════════════════════════════════════════
# REPORTING API
# ═══════════════════════════════════════════════════════════════

# PUBLIC: Generate a quick device status.
# Usage: api_status
api_status() {
    if declare -f reporting_status &>/dev/null; then
        reporting_status
    fi
}

# PUBLIC: Generate a full device report.
# Usage: api_report
api_report() {
    if declare -f reporting_full_report &>/dev/null; then
        reporting_full_report
    fi
}

# PUBLIC: Get the path to the most recent report.
# Usage: api_last_report
# Outputs: file path or empty
api_last_report() {
    if declare -f log_show_file &>/dev/null; then
        log_show_file 2>/dev/null | head -1
    fi
}

# ═══════════════════════════════════════════════════════════════
# CONFIGURATION API
# ═══════════════════════════════════════════════════════════════

# PUBLIC: Get a configuration value.
# Usage: api_config_get <key>
# Looks up environment variable, then config file.
api_config_get() {
    local key="$1"
    local env_var="ANDROID_TOOLKIT_$(echo "$key" | tr '[:lower:]' '[:upper:]' | tr '-' '_')"
    # Check env first
    if [[ -n "${!env_var:-}" ]]; then
        echo "${!env_var}"
        return
    fi
    # Check config_get if available
    if declare -f config_get &>/dev/null; then
        config_get "$key"
    fi
}

# PUBLIC: Get the toolkit root directory.
# Usage: api_root_dir
# Outputs: absolute path
api_root_dir() {
    echo "${ANDROID_TOOLKIT_ROOT_DIR:-}"
}

# PUBLIC: Get the toolkit version.
# Usage: api_version
# Outputs: semver string
api_version() {
    echo "${ANDROID_TOOLKIT_VERSION:-0.0.0}"
}

# ═══════════════════════════════════════════════════════════════
# BENCHMARK API
# ═══════════════════════════════════════════════════════════════

# PUBLIC: Run a benchmark.
# Usage: api_benchmark [runs]
api_benchmark() {
    if declare -f benchmark_run &>/dev/null; then
        _load_module "benchmark" 2>/dev/null || true
        if [[ -n "${1:-}" ]]; then
            benchmark_run_enhanced "$1"
        else
            benchmark_run
        fi
    fi
}

# PUBLIC: List benchmark history.
# Usage: api_benchmark_history
api_benchmark_history() {
    if declare -f benchmark_list_history &>/dev/null; then
        _load_module "benchmark" 2>/dev/null || true
        benchmark_list_history
    fi
}

# ═══════════════════════════════════════════════════════════════
# PACKAGE API
# ═══════════════════════════════════════════════════════════════

# PUBLIC: Disable a package.
# Usage: api_disable_package <package_name>
# Returns: 0 on success
api_disable_package() {
    if declare -f packages_disable &>/dev/null; then
        _load_module "packages" 2>/dev/null || true
        packages_disable "$1"
    fi
}

# PUBLIC: Enable a package.
# Usage: api_enable_package <package_name>
# Returns: 0 on success
api_enable_package() {
    if declare -f packages_enable &>/dev/null; then
        _load_module "packages" 2>/dev/null || true
        packages_enable "$1"
    fi
}

# PUBLIC: Check if a package is installed.
# Usage: api_package_installed <package_name>
# Returns: 0 if installed
api_package_installed() {
    local pkg="$1"
    local cmd
    cmd="$(api_backend_shell "pm list packages 2>/dev/null" 2>/dev/null || true)"
    echo "$cmd" | grep -q "package:${pkg}$"
}

# PUBLIC: Analyze installed packages and recommend actions.
# Usage: api_packages_recommend
api_packages_recommend() {
    if declare -f packages_recommend &>/dev/null; then
        _load_module "packages" 2>/dev/null || true
        packages_recommend
    fi
}

# ═══════════════════════════════════════════════════════════════
# DEVICES API
# ═══════════════════════════════════════════════════════════════

# PUBLIC: List connected devices.
# Usage: api_devices_list [format]
api_devices_list() {
    if declare -f devices_list &>/dev/null; then
        _load_module "devices" 2>/dev/null || true
        devices_list "${1:-text}"
    fi
}

# PUBLIC: Set the active device.
# Usage: api_devices_set_active <serial>
api_devices_set_active() {
    if declare -f devices_set_active &>/dev/null; then
        _load_module "devices" 2>/dev/null || true
        devices_set_active "$1"
    fi
}

# PUBLIC: Get the active device serial.
# Usage: api_devices_get_active
api_devices_get_active() {
    if declare -f devices_get_active &>/dev/null; then
        _load_module "devices" 2>/dev/null || true
        devices_get_active
    fi
}

# ═══════════════════════════════════════════════════════════════
# SETTINGS API
# ═══════════════════════════════════════════════════════════════

# PUBLIC: Look up a setting in the settings database.
# Usage: api_settings_lookup <key>
# Outputs: JSON object with setting metadata
api_settings_lookup() {
    if declare -f settings_get_field &>/dev/null; then
        settings_get_field "$1" 2>/dev/null
    fi
}

# PUBLIC: Check if a setting is writable on this device.
# Usage: api_settings_writable <key>
# Returns: 0 if writable
api_settings_writable() {
    if declare -f settings_is_writable &>/dev/null; then
        settings_is_writable "$1"
    fi
}

# ═══════════════════════════════════════════════════════════════
# UTILITY API
# ═══════════════════════════════════════════════════════════════

# PUBLIC: Get a temporary file path (cleaned up on exit).
# Usage: api_temp_file <suffix>
# Outputs: file path
api_temp_file() {
    local suffix="${1:-tmp}"
    local tmp
    tmp="$(mktemp -t "android-toolkit-${suffix}.XXXXXX")"
    echo "$tmp"
}

# PUBLIC: Get current timestamp in ISO-8601 format.
# Usage: api_timestamp
# Outputs: ISO-8601 timestamp
api_timestamp() {
    date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S%z'
}

# PUBLIC: Read a file safely (returns empty if not found).
# Usage: api_read_file <path>
api_read_file() {
    local path="$1"
    if [[ -f "$path" ]]; then
        cat "$path"
    fi
}

# PUBLIC: Write a file atomically.
# Usage: api_write_file <path> <content>
api_write_file() {
    local path="$1" content="$2"
    local dir
    dir="$(dirname "$path")"
    mkdir -p "$dir" 2>/dev/null || true
    echo "$content" > "${path}.tmp" && mv "${path}.tmp" "$path"
}

# PUBLIC: Check if a command exists.
# Usage: api_has_command <name>
# Returns: 0 if found
api_has_command() {
    command -v "$1" &>/dev/null
}

# PUBLIC: Run a command with timeout.
# Usage: api_timeout <seconds> <command> [args...]
api_timeout() {
    local timeout_secs="$1"
    shift
    timeout "$timeout_secs" "$@" 2>/dev/null || true
}
