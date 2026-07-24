#!/data/data/com.termux/files/usr/bin/bash
#
# plugin.sh — Plugin system loader with SDK v3.0
#
# Auto-loads plugins from the plugins/ directory.
# Plugin API v3.0 supports:
#   Core (v2.0):
#     - plugin_register()       — Called once at load time
#     - plugin_pre_run()        — Called before plugin_run() (optional)
#     - plugin_run()            — Called when plugin is executed
#     - plugin_post_run()       — Called after plugin_run() (optional)
#     - plugin_cleanup()        — Called on exit/error (optional)
#     - plugin_config()         — Return default config as KEY=VALUE lines (optional)
#     - plugin_dependencies()   — Return space-separated dependency names (optional)
#   Enhanced (v2.1):
#     - plugin_config_schema()  — Return JSON schema for config validation (optional)
#     - plugin_commands()       — Return array of custom command registrations (optional)
#     - plugin_on_event()       — Called on internal events: "$event_name" "$payload" (optional)
#     - plugin_priority         — Numeric priority (lower = earlier), default 50
#   Certification (v3.0):
#     - plugin_min_toolkit      — Minimum toolkit version string (e.g., "4.0.0") (optional)
#     - plugin_permissions      — Space-separated permission names (optional)
#     - plugin_events_subscribe — Space-separated event names (optional)
#     - plugin_description      — Human-readable description (optional)
#     - plugin_author           — Author name (optional)
#     - plugin_certified        — Set to "true" after certification (optional)
#
# Required variables:
#   plugin_name              — Human-readable name
#   plugin_version           — Semver string (e.g., "1.0.0")
#   plugin_supported_oems    — Space-separated OEM list or "all"
#   plugin_supported_android — Space-separated SDK list (33 34 35 36)
#
# Part of the Android Toolkit.

PLUGIN_DIR="${ANDROID_TOOLKIT_ROOT_DIR}/plugins"
PLUGIN_REGISTERED=()
declare -gA PLUGIN_METADATA
declare -gA PLUGIN_CONFIG

##############################################
# Load all available plugins from the plugins directory.
# Sources each plugin script and calls plugin_register() if it exists.
# Validates OEM and Android version constraints.
##############################################
plugin_load_all() {
    if [[ ! -d "$PLUGIN_DIR" ]]; then
        mkdir -p "$PLUGIN_DIR" 2>/dev/null || true
        log_debug "Plugin directory created: $PLUGIN_DIR"
        return 0
    fi

    local loaded=0

    for plugin_file in "$PLUGIN_DIR"/*.sh; do
        [[ -f "$plugin_file" ]] || continue

        local plugin_basename
        plugin_basename="$(basename "$plugin_file" .sh)"

        # Skip if already loaded
        plugin_is_loaded "$plugin_basename" && continue

        if ! _plugin_load_single "$plugin_file" "$plugin_basename"; then
            continue
        fi

        loaded=$((loaded + 1))
    done

    if [[ "$loaded" -gt 0 ]]; then
        log_debug "Loaded $loaded plugin(s)"
    fi
}

##############################################
# Load a single plugin by file path.
# Arguments:
#   $1: path to plugin file
#   $2: plugin basename (optional, derived from filename if omitted)
# Returns: 0 on success
##############################################
plugin_load() {
    local plugin_file="$1"
    local plugin_basename="${2:-$(basename "$plugin_file" .sh)}"

    if [[ ! -f "$plugin_file" ]]; then
        log_error "Plugin file not found: $plugin_file"
        return 1
    fi

    _plugin_load_single "$plugin_file" "$plugin_basename"
}

##############################################
# Internal single-plugin loader.
# Arguments:
#   $1: plugin file path
#   $2: plugin basename
# Returns: 0 on success
##############################################
_plugin_load_single() {
    local plugin_file="$1" plugin_basename="$2"

    # Source the plugin
    source "$plugin_file" 2>/dev/null || {
        log_debug "Failed to load plugin: $plugin_basename"
        return 1
    }

    # Validate required fields
    if ! _plugin_validate "$plugin_basename"; then
        return 1
    fi

    # Check Android version constraints
    if ! _plugin_check_android "$plugin_basename"; then
        log_debug "Plugin '$plugin_basename' requires Android SDK ${plugin_supported_android:-} — skipping"
        return 1
    fi

    # Check OEM constraints
    if ! _plugin_check_oem "$plugin_basename"; then
        log_debug "Plugin '$plugin_basename' not supported on ${OEM_LOADED:-generic} — skipping"
        return 1
    fi

    # Check dependencies
    if ! _plugin_check_deps "$plugin_basename"; then
        log_debug "Plugin '$plugin_basename' has unmet dependencies — skipping"
        return 1
    fi

    # Load config (if plugin_config is defined)
    _plugin_load_config "$plugin_basename"

    # Validate config against schema (if plugin_config_schema is defined)
    _plugin_validate_config "$plugin_basename" || {
        log_warning "Plugin '$plugin_basename' config validation failed — loaded anyway"
    }

    # Register custom commands (if plugin_commands is defined)
    if declare -f plugin_commands &>/dev/null; then
        _plugin_register_commands "$plugin_basename"
    fi

    # Subscribe to events (if plugin_on_event is defined)
    if declare -f plugin_on_event &>/dev/null; then
        if declare -f events_subscribe &>/dev/null; then
            events_subscribe "*" "_plugin_event_dispatch"
        fi
    fi

    # Register the plugin
    PLUGIN_REGISTERED+=("$plugin_basename")

    # Store metadata
    _plugin_set_meta "$plugin_basename" "version" "${plugin_version:-0.0.0}"
    _plugin_set_meta "$plugin_basename" "oems" "${plugin_supported_oems:-all}"
    _plugin_set_meta "$plugin_basename" "android" "${plugin_supported_android:-all}"
    _plugin_set_meta "$plugin_basename" "file" "$plugin_file"
    _plugin_set_meta "$plugin_basename" "loaded_at" "$(date +%s)"
    _plugin_set_meta "$plugin_basename" "priority" "${plugin_priority:-50}"

    # Call register hook
    if declare -f plugin_register &>/dev/null; then
        plugin_register 2>/dev/null || true
    fi

    log_debug "Plugin loaded: $plugin_basename (${plugin_version:-unknown})"
    return 0
}

##############################################
# Validate that a plugin has required fields.
# Arguments:
#   $1: plugin name
# Returns: 0 if valid
##############################################
_plugin_validate() {
    local name="$1"

    if ! declare -f plugin_run &>/dev/null; then
        log_debug "Plugin '$name' missing plugin_run() — skipping"
        return 1
    fi

    if [[ -z "${plugin_name:-}" ]]; then
        log_debug "Plugin '$name' missing plugin_name — using basename"
        # Not fatal, just use the filename
    fi

    if [[ -z "${plugin_version:-}" ]]; then
        log_debug "Plugin '$name' missing plugin_version — defaulting to 0.0.0"
    fi

    # Certification checks (v3.0)
    if ! _plugin_certify "$name"; then
        return 1
    fi

    return 0
}

##############################################
# Plugin certification validation (v3.0).
# Checks minimum toolkit version, permissions, event subscriptions.
# Arguments:
#   $1: plugin name
# Returns: 0 if certified
##############################################
_plugin_certify() {
    local name="$1"

    # Check minimum toolkit version
    local min_tk="${plugin_min_toolkit:-}"
    if [[ -n "$min_tk" ]]; then
        if ! _plugin_check_version "$min_tk"; then
            log_warning "Plugin '$name' requires toolkit v${min_tk}+ (current: ${ANDROID_TOOLKIT_VERSION:-unknown})"
            return 1
        fi
    fi

    # Validate permissions (if declared)
    local perms="${plugin_permissions:-}"
    if [[ -n "$perms" ]]; then
        local p
        for p in $perms; do
            case "$p" in
                adb|rish|shell|settings_read|settings_write|package_disable|package_enable)
                    # Known permissions — no further check needed
                    ;;
                *)
                    log_warning "Plugin '$name' declares unknown permission: $p"
                    ;;
            esac
        done
    fi

    # Validate event subscriptions
    local events="${plugin_events_subscribe:-}"
    if [[ -n "$events" ]]; then
        if ! declare -f events_subscribe &>/dev/null; then
            log_debug "Plugin '$name' subscribes to events but event system not loaded"
        fi
    fi

    # Verify supported OEM/android are declared
    if [[ -z "${plugin_supported_oems:-}" ]]; then
        log_warning "Plugin '$name' missing plugin_supported_oems — assuming all"
    fi
    if [[ -z "${plugin_supported_android:-}" ]]; then
        log_warning "Plugin '$name' missing plugin_supported_android — assuming all"
    fi

    # Store certification metadata
    _plugin_set_meta "$name" "min_toolkit" "${min_tk:-any}"
    _plugin_set_meta "$name" "permissions" "${perms:-none}"
    _plugin_set_meta "$name" "events" "${plugin_events_subscribe:-none}"
    _plugin_set_meta "$name" "description" "${plugin_description:-}"
    _plugin_set_meta "$name" "author" "${plugin_author:-unknown}"
    _plugin_set_meta "$name" "certified" "true"

    return 0
}

##############################################
# Check if the current toolkit version meets a minimum.
# Arguments:
#   $1: required version string (e.g., "4.0.0")
# Returns: 0 if current >= required
##############################################
_plugin_check_version() {
    local required="$1"
    local current="${ANDROID_TOOLKIT_VERSION:-0.0.0}"

    # Simple semver comparison using sort -V
    printf '%s\n%s\n' "$required" "$current" | sort -V | head -1 | grep -q "^${required}$" || [[ "$current" == "$required" ]]
    return $?
}

##############################################
# Check if plugin supports the current Android version.
# Arguments:
#   $1: plugin name
# Returns: 0 if supported
##############################################
_plugin_check_android() {
    local name="$1"
    local supported="${plugin_supported_android:-}"
    local sdk="${CAP_ANDROID_SDK:-}"

    [[ -z "$supported" || "$supported" == "all" ]] && return 0
    [[ -z "$sdk" ]] && return 0  # Can't check, allow through

    local s
    for s in $supported; do
        [[ "$s" == "$sdk" ]] && return 0
    done
    return 1
}

##############################################
# Check if plugin supports the current OEM.
# Arguments:
#   $1: plugin name
# Returns: 0 if supported
##############################################
_plugin_check_oem() {
    local name="$1"
    local supported="${plugin_supported_oems:-}"
    local oem="${OEM_LOADED:-generic}"

    [[ -z "$supported" || "$supported" == "all" ]] && return 0

    local o
    for o in $supported; do
        [[ "$o" == "$oem" ]] && return 0
    done
    return 1
}

##############################################
# Check plugin dependencies.
# Arguments:
#   $1: plugin name
# Returns: 0 if all deps met
##############################################
_plugin_check_deps() {
    local name="$1"

    if ! declare -f plugin_dependencies &>/dev/null; then
        return 0  # No dependencies defined
    fi

    local deps
    deps="$(plugin_dependencies 2>/dev/null)" || return 0

    local dep
    for dep in $deps; do
        if ! plugin_is_loaded "$dep"; then
            log_debug "Plugin '$name' requires '$dep' which is not loaded"
            return 1
        fi
    done

    return 0
}

##############################################
# Load plugin configuration (if plugin_config is defined).
# Arguments:
#   $1: plugin name
##############################################
_plugin_load_config() {
    local name="$1"

    if ! declare -f plugin_config &>/dev/null; then
        return 0
    fi

    local config_lines
    config_lines="$(plugin_config 2>/dev/null)" || return 0

    local line
    while IFS='=' read -r key value; do
        key="$(echo "$key" | tr -d '[:space:]')"
        value="$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        PLUGIN_CONFIG["${name}.${key}"]="$value"
    done <<< "$config_lines"
}

##############################################
# Validate plugin config against optional schema.
# Arguments:
#   $1: plugin name
# Returns: 0 if valid or no schema
##############################################
_plugin_validate_config() {
    local name="$1"

    if ! declare -f plugin_config_schema &>/dev/null; then
        return 0
    fi

    local schema
    schema="$(plugin_config_schema 2>/dev/null)" || return 0

    if [[ -z "$schema" ]]; then
        return 0
    fi

    # Quick validation without requiring jq
    local errors=0
    local key expected_type actual_val

    while IFS= read -r line; do
        key="$(echo "$line" | cut -d: -f1 | tr -d ' "')"
        expected_type="$(echo "$line" | cut -d: -f2 | tr -d ' ",' )"
        [[ -z "$key" || "$key" == "{" || "$key" == "}" ]] && continue

        actual_val="${PLUGIN_CONFIG["${name}.${key}"]:-}"

        case "$expected_type" in
            integer|number)
                if [[ -n "$actual_val" && ! "$actual_val" =~ ^-?[0-9]+$ ]]; then
                    log_warning "  Plugin '$name' config '$key': expected $expected_type, got '$actual_val'"
                    errors=$((errors + 1))
                fi
                ;;
            boolean)
                if [[ -n "$actual_val" && ! "$actual_val" =~ ^(true|false|0|1)$ ]]; then
                    log_warning "  Plugin '$name' config '$key': expected boolean, got '$actual_val'"
                    errors=$((errors + 1))
                fi
                ;;
            string)
                # Any value is fine
                ;;
            required)
                if [[ -z "$actual_val" ]]; then
                    log_warning "  Plugin '$name' config '$key': required but not set"
                    errors=$((errors + 1))
                fi
                ;;
        esac
    done <<< "$schema"

    return $(( errors > 0 ? 1 : 0 ))
}

##############################################
# Register plugin CLI commands via --plugin <name> <args>.
# Arguments:
#   $1: plugin name
##############################################
_plugin_register_commands() {
    local name="$1"
    local commands
    commands="$(plugin_commands 2>/dev/null)" || return 0

    if [[ -z "$commands" ]]; then
        return 0
    fi

    local cmd
    while IFS= read -r cmd; do
        [[ -z "$cmd" || "$cmd" == "#"* ]] && continue
        local cmd_name cmd_desc cmd_handler
        cmd_name="$(echo "$cmd" | cut -d: -f1 | tr -d '[:space:]')"
        cmd_desc="$(echo "$cmd" | cut -d: -f2-)"

        if [[ -n "$cmd_name" ]]; then
            _plugin_set_meta "$name" "cmd_${cmd_name}" "${cmd_desc:-${name} command}"
            log_debug "Plugin '$name' registered command: $cmd_name"
        fi
    done <<< "$commands"
}

##############################################
# Event dispatch bridge — calls plugin_on_event on loaded plugins.
# Arguments:
#   $1: event name
#   $2: payload (JSON string)
##############################################
_plugin_event_dispatch() {
    local event_name="$1" payload="${2:-}"
    local name

    for name in "${PLUGIN_REGISTERED[@]}"; do
        if declare -f plugin_on_event &>/dev/null; then
            # plugin_on_event is expected to filter by event name internally
            plugin_on_event "$event_name" "$payload" 2>/dev/null || true
        fi
    done
}

##############################################
# Store plugin metadata.
# Arguments:
#   $1: plugin name
#   $2: key
#   $3: value
##############################################
_plugin_set_meta() {
    local name="$1" key="$2" value="$3"
    PLUGIN_METADATA["${name}.${key}"]="$value"
}

##############################################
# Get plugin metadata.
# Arguments:
#   $1: plugin name
#   $2: key
# Outputs: value
##############################################
_plugin_get_meta() {
    local name="$1" key="$2"
    echo "${PLUGIN_METADATA["${name}.${key}"]:-}"
}

##############################################
# Check if a plugin is loaded.
# Arguments:
#   $1: plugin name
# Returns: 0 if loaded
##############################################
plugin_is_loaded() {
    local name="$1"
    local p
    for p in "${PLUGIN_REGISTERED[@]}"; do
        [[ "$p" == "$name" ]] && return 0
    done
    return 1
}

##############################################
# Plugin execution isolation configuration.
# Set ANDROID_TOOLKIT_PLUGIN_SAFE=true for restricted execution.
# Set ANDROID_TOOLKIT_PLUGIN_TIMEOUT seconds (default: 60).
##############################################
PLUGIN_SAFE_MODE="${ANDROID_TOOLKIT_PLUGIN_SAFE:-false}"
PLUGIN_TIMEOUT="${ANDROID_TOOLKIT_PLUGIN_TIMEOUT:-60}"

##############################################
# Execute a plugin function with isolation.
# Runs in a subshell to prevent plugin failures from affecting toolkit.
# Arguments:
#   $1: plugin name (for logging)
#   $2: function name to call (plugin_run, plugin_pre_run, etc.)
#   $@: remaining args passed to the function
# Returns: exit code from the plugin function (0-127), or 128+ for isolation failures
##############################################
_plugin_exec_isolated() {
    local plugin_name="$1"
    local func_name="$2"
    shift 2

    # Verify the function exists
    if ! declare -f "$func_name" &>/dev/null; then
        log_warning "Plugin '$plugin_name' has no $func_name() — skipping"
        return 0
    fi

    if [[ "$PLUGIN_SAFE_MODE" == "true" ]]; then
        # Safe mode: execute in a restricted subshell
        # Only essential commands are available
        local exit_code=0
        (
            # Trap errors in subshell
            set -e
            # Restricted PATH
            PATH="/system/bin:/system/xbin:/data/data/com.termux/files/usr/bin"
            export PATH
            # Clear potentially dangerous variables
            unset LD_PRELOAD LD_LIBRARY_PATH 2>/dev/null || true
            # Execute with timeout if available
            if command -v timeout &>/dev/null; then
                timeout "$PLUGIN_TIMEOUT" "$func_name" "$@" 2>/dev/null
                exit $?
            else
                "$func_name" "$@" 2>/dev/null
                exit $?
            fi
        )
        exit_code=$?
        return $exit_code
    else
        # Standard isolation: execute in subshell with error trapping
        local exit_code=0
        (
            set +e
            # Trap any error during execution
            trap 'exit 127' ERR
            # Execute the plugin function
            "$func_name" "$@" 2>&1
            exit $?
        )
        exit_code=$?
        return $exit_code
    fi
}

##############################################
# Run a specific plugin's main function with isolation.
# Calls plugin_pre_run() before and plugin_post_run() after if they exist.
# Plugin failures are caught and reported without aborting toolkit.
# Arguments:
#   $1: plugin name
#   $@: remaining args passed to plugin_run
##############################################
plugin_run() {
    local name="$1"
    shift

    if ! plugin_is_loaded "$name"; then
        log_error "Plugin not loaded: $name"
        return 1
    fi

    local exit_code=0

    # Pre-run hook (isolated)
    _plugin_exec_isolated "$name" "plugin_pre_run" "$@" || true

    # Main execution (isolated)
    if declare -f plugin_run &>/dev/null; then
        _plugin_exec_isolated "$name" "plugin_run" "$@"
        exit_code=$?
    else
        log_error "Plugin '$name' has no plugin_run() function"
        return 1
    fi

    # Post-run hook (isolated)
    _plugin_exec_isolated "$name" "plugin_post_run" "$exit_code" || true

    # Report isolation failures
    if [[ "$exit_code" -ge 128 ]]; then
        log_warning "Plugin '$name' execution failed (exit $exit_code)"
        if [[ "$exit_code" -eq 124 ]]; then
            log_warning "Plugin '$name' timed out after ${PLUGIN_TIMEOUT}s"
        fi
    elif [[ "$exit_code" -ne 0 ]]; then
        log_warning "Plugin '$name' returned error exit code $exit_code"
    fi

    return $exit_code
}

##############################################
# Run cleanup on all loaded plugins.
##############################################
plugin_cleanup_all() {
    local name
    for name in "${PLUGIN_REGISTERED[@]}"; do
        if declare -f plugin_cleanup &>/dev/null; then
            plugin_cleanup 2>/dev/null || true
        fi
    done
}

##############################################
# List all loaded plugins with metadata.
##############################################
plugin_list() {
    log_section "Loaded Plugins"

    if [[ ${#PLUGIN_REGISTERED[@]} -eq 0 ]]; then
        log_info "No plugins loaded"
        return 0
    fi

    # Sort by priority
    local sorted
    sorted="$(for p in "${PLUGIN_REGISTERED[@]}"; do
        local prio
        prio="$(_plugin_get_meta "$p" "priority")"
        echo "${prio:-50} $p"
    done | sort -n | awk '{print $2}')"

    printf "  %-25s %-10s %-10s %-8s %-15s %s\n" "Name" "Version" "Priority" "Cert" "OEM" "Android"
    printf "  %-25s %-10s %-10s %-8s %-15s %s\n" "────" "───────" "────────" "────" "───" "───────"
    local name
    for name in $sorted; do
        local ver prio oem android cert
        ver="$(_plugin_get_meta "$name" "version")"
        prio="$(_plugin_get_meta "$name" "priority")"
        oem="$(_plugin_get_meta "$name" "oems")"
        android="$(_plugin_get_meta "$name" "android")"
        cert="$(_plugin_get_meta "$name" "certified")"
        [[ "$cert" == "true" ]] && cert="✓" || cert="─"
        printf "  %-25s %-10s %-10s %-8s %-15s %s\n" "$name" "$ver" "$prio" "$cert" "$oem" "$android"
    done
}

##############################################
# Get a plugin's configuration value.
# Arguments:
#   $1: plugin name
#   $2: key
# Outputs: config value or empty string
##############################################
plugin_config_get() {
    local name="$1" key="$2"
    echo "${PLUGIN_CONFIG["${name}.${key}"]:-}"
}

##############################################
# Set a plugin's config value at runtime.
# Arguments:
#   $1: plugin name
#   $2: key
#   $3: value
##############################################
plugin_config_set() {
    local name="$1" key="$2" value="$3"
    PLUGIN_CONFIG["${name}.${key}"]="$value"
}

##############################################
# Get plugin metadata (public API).
# Arguments:
#   $1: plugin name
#   $2: key (version|oems|android|file|priority|loaded_at|cmd_*)
# Outputs: value
##############################################
plugin_meta() {
    local name="$1" key="$2"
    _plugin_get_meta "$name" "$key"
}

##############################################
# Unload a specific plugin.
# Arguments:
#   $1: plugin name
# Returns: 0 on success
##############################################
plugin_unload() {
    local name="$1"

    if ! plugin_is_loaded "$name"; then
        log_warning "Plugin not loaded: $name"
        return 1
    fi

    # Run cleanup
    if declare -f plugin_cleanup &>/dev/null; then
        plugin_cleanup 2>/dev/null || true
    fi

    # Remove from registered list
    local new_list=()
    local p
    for p in "${PLUGIN_REGISTERED[@]}"; do
        [[ "$p" != "$name" ]] && new_list+=("$p")
    done
    PLUGIN_REGISTERED=("${new_list[@]}")

    # Clear metadata
    for key in "${!PLUGIN_METADATA[@]}"; do
        [[ "$key" == "${name}."* ]] && unset "PLUGIN_METADATA[$key]"
    done

    # Clear config
    for key in "${!PLUGIN_CONFIG[@]}"; do
        [[ "$key" == "${name}."* ]] && unset "PLUGIN_CONFIG[$key]"
    done

    log_debug "Plugin unloaded: $name"
    return 0
}

##############################################
# Reload a specific plugin.
# Arguments:
#   $1: plugin name
# Returns: 0 on success
##############################################
plugin_reload() {
    local name="$1"
    local file
    file="$(_plugin_get_meta "$name" "file")"

    if [[ -z "$file" ]]; then
        log_error "Cannot reload: no file path for plugin '$name'"
        return 1
    fi

    # Unload first, then load again
    plugin_unload "$name"
    plugin_load "$file" "$name"
}

##############################################
# Show plugin help/info for a specific plugin.
# Arguments:
#   $1: plugin name
##############################################
plugin_help() {
    local name="$1"

    if ! plugin_is_loaded "$name"; then
        log_error "Plugin not loaded: $name"
        return 1
    fi

    echo ""
    echo "  Plugin: $(_plugin_get_meta "$name" "name" 2>/dev/null || echo "$name")"
    echo "  Version: $(_plugin_get_meta "$name" "version")"
    echo "  Priority: $(_plugin_get_meta "$name" "priority")"
    echo "  OEMs: $(_plugin_get_meta "$name" "oems")"
    echo "  Android: $(_plugin_get_meta "$name" "android")"
    echo "  File: $(_plugin_get_meta "$name" "file")"

    # List config
    local has_config=false
    local key
    for key in "${!PLUGIN_CONFIG[@]}"; do
        if [[ "$key" == "${name}."* ]]; then
            if ! $has_config; then
                echo ""
                echo "  Config:"
                has_config=true
            fi
            local k="${key#"${name}".}"
            echo "    $k = ${PLUGIN_CONFIG[$key]}"
        fi
    done

    # List custom commands
    local has_cmds=false
    for key in "${!PLUGIN_METADATA[@]}"; do
        if [[ "$key" == "${name}.cmd_"* ]]; then
            if ! $has_cmds; then
                echo ""
                echo "  Commands:"
                has_cmds=true
            fi
            local cmd_name="${key#"${name}".cmd_}"
            local cmd_desc="${PLUGIN_METADATA[$key]}"
            echo "    $cmd_name — $cmd_desc"
        fi
    done
}

# Trap handler
trap plugin_cleanup_all EXIT INT TERM
