#!/data/data/com.termux/files/usr/bin/bash
#
# config.sh — Unified configuration engine
#
# Supports layered configuration with the following priority (highest first):
#   1. CLI overrides (set via --config-key=value or environment)
#   2. Environment variables (ANDROID_TOOLKIT_*)
#   3. User config ($ANDROID_TOOLKIT_ROOT_DIR/configs/user.conf)
#   4. Profile config (profiles/<name>.conf)
#   5. Global config ($ANDROID_TOOLKIT_ROOT_DIR/configs/default.conf)
#   6. Built-in defaults
#
# Supports:
#   - INI-style config files (key=value)
#   - JSON config files (via jq if available)
#   - Environment variable overrides
#   - CLI --key=value overrides
#   - Config validation against known keys
#
# Part of the Android Toolkit.

CONFIG_KNOWN_KEYS=(
    ANDROID_TOOLKIT_LOG_LEVEL
    ANDROID_TOOLKIT_DEFAULT_BACKEND
    ANDROID_TOOLKIT_SHOW_BLOATWARE
    ANDROID_TOOLKIT_LOG_RETENTION_DAYS
    ANDROID_TOOLKIT_AUTO_ROLLBACK
    ANDROID_TOOLKIT_VALIDATION_STRICT
    ANDROID_TOOLKIT_TIMEOUT
    ANDROID_TOOLKIT_DRY_RUN
    ANDROID_TOOLKIT_TELEMETRY_ENABLED
    ANDROID_TOOLKIT_SCHEDULER_ENABLED
)

CONFIG_VALUES=()

##############################################
# Initialize config engine.
# Loads global, user, and profile configs in order.
# Arguments:
#   $1: optional profile name to load
##############################################
config_init() {
    local profile="${1:-}"

    # Start with built-in defaults
    config_set_internal "ANDROID_TOOLKIT_LOG_LEVEL" "info"
    config_set_internal "ANDROID_TOOLKIT_DEFAULT_BACKEND" "auto"
    config_set_internal "ANDROID_TOOLKIT_SHOW_BLOATWARE" "true"
    config_set_internal "ANDROID_TOOLKIT_LOG_RETENTION_DAYS" "30"
    config_set_internal "ANDROID_TOOLKIT_AUTO_ROLLBACK" "true"
    config_set_internal "ANDROID_TOOLKIT_VALIDATION_STRICT" "false"
    config_set_internal "ANDROID_TOOLKIT_TIMEOUT" "300"
    config_set_internal "ANDROID_TOOLKIT_DRY_RUN" "false"
    config_set_internal "ANDROID_TOOLKIT_TELEMETRY_ENABLED" "true"
    config_set_internal "ANDROID_TOOLKIT_SCHEDULER_ENABLED" "true"

    # Load global config
    config_load_file "global" "${ANDROID_TOOLKIT_ROOT_DIR}/configs/default.conf"

    # Load user config if exists
    if [[ -f "${ANDROID_TOOLKIT_ROOT_DIR}/configs/user.conf" ]]; then
        config_load_file "user" "${ANDROID_TOOLKIT_ROOT_DIR}/configs/user.conf"
    fi

    # Load profile config if specified
    if [[ -n "$profile" ]]; then
        local profile_path="${ANDROID_TOOLKIT_ROOT_DIR}/profiles/${profile}.conf"
        if [[ -f "$profile_path" ]]; then
            config_load_file "profile" "$profile_path"
        fi
    fi

    # Apply environment variable overrides
    config_load_env

    log_debug "Config initialized (profile: ${profile:-none})"
}

##############################################
# Load a config file (INI format: KEY=VALUE).
# Arguments:
#   $1: source label (global|user|profile)
#   $2: file path
##############################################
config_load_file() {
    local source_label="$1" file_path="$2"

    if [[ ! -f "$file_path" ]]; then
        return 0
    fi

    local line key value
    while IFS='=' read -r key value; do
        # Strip whitespace
        key="$(echo "$key" | tr -d '[:space:]')"
        value="$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

        # Skip comments and empty lines
        [[ -z "$key" || "$key" =~ ^# ]] && continue

        config_set "$key" "$value" "$source_label"
    done < "$file_path"
}

##############################################
# Load environment variable overrides.
# Looks for ANDROID_TOOLKIT_* vars.
##############################################
config_load_env() {
    local key value
    for key in "${CONFIG_KNOWN_KEYS[@]}"; do
        value="${!key:-}"
        if [[ -n "$value" ]]; then
            config_set "$key" "$value" "env"
        fi
    done
}

##############################################
# Set a config value internally (no source tracking).
# Arguments:
#   $1: key
#   $2: value
##############################################
config_set_internal() {
    local key="$1" value="$2"
    CONFIG_VALUES["$key"]="$value"
}

##############################################
# Set a config value with source tracking.
# Higher-priority sources override lower.
# Arguments:
#   $1: key
#   $2: value
#   $3: source (default|global|user|profile|env|cli)
##############################################
config_set() {
    local key="$1" value="$2" source="${3:-cli}"

    # Priority map
    local -A priority=(
        ["default"]=0
        ["global"]=1
        ["user"]=2
        ["profile"]=3
        ["env"]=4
        ["cli"]=5
    )

    local current_source="${CONFIG_SOURCES[$key]:-default}"
    if [[ "${priority[$source]:-0}" -ge "${priority[$current_source]:-0}" ]]; then
        CONFIG_VALUES["$key"]="$value"
        CONFIG_SOURCES["$key"]="$source"
    fi
}

##############################################
# Get a config value.
# Arguments:
#   $1: key
# Outputs: value, or empty string if unset
##############################################
config_get() {
    local key="$1"
    echo "${CONFIG_VALUES[$key]:-}"
}

##############################################
# Get a config value with default fallback.
# Arguments:
#   $1: key
#   $2: default value
# Outputs: value
##############################################
config_get_default() {
    local key="$1" default="$2"
    local val="${CONFIG_VALUES[$key]}"
    echo "${val:-$default}"
}

##############################################
# Load config from a JSON file using jq.
# Arguments:
#   $1: file path
# Returns: 0 on success
##############################################
config_load_json() {
    local file_path="$1"

    if [[ ! -f "$file_path" ]]; then
        return 0
    fi

    if ! command -v jq &>/dev/null; then
        log_warning "jq not available — cannot load JSON config: $file_path"
        return 1
    fi

    local key value
    while IFS=$'\t' read -r key value; do
        [[ -n "$key" ]] || continue
        config_set "$key" "$value" "global"
    done < <(jq -r 'to_entries[] | [.key, (.value | tostring)] | @tsv' "$file_path" 2>/dev/null)
}

##############################################
# Export all config as JSON (for reporting).
##############################################
config_export_json() {
    local first=true
    echo "{"
    for key in "${!CONFIG_VALUES[@]}"; do
        $first || echo ","
        first=false
        printf '  "%s": "%s"' "$key" "${CONFIG_VALUES[$key]}"
    done
    echo ""
    echo "}"
}

##############################################
# List all config keys and their sources.
##############################################
config_list() {
    printf "  %-45s %-15s %s\n" "Key" "Source" "Value"
    printf "  %-45s %-15s %s\n" "───" "──────" "─────"
    for key in "${CONFIG_KNOWN_KEYS[@]}"; do
        local val="${CONFIG_VALUES[$key]:-}"
        local src="${CONFIG_SOURCES[$key]:-default}"
        printf "  %-45s %-15s %s\n" "$key" "$src" "$val"
    done
}
