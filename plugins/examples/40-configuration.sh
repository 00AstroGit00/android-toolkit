#!/data/data/com.termux/files/usr/bin/bash
#
# 40-configuration.sh — Example: Configuration Plugin
#
# Demonstrates persistent configuration, user settings,
# and safe defaults with toolkit integration.
#
# Plugin SDK v3.0 feature.
#
# Usage:
#   toolkit.sh --plugin config-example [key] [value]
#
# Examples:
#   toolkit.sh --plugin config-example          — Show all config
#   toolkit.sh --plugin config-example theme    — Get a value
#   toolkit.sh --plugin config-example theme dark — Set a value
#
# Part of the Android Toolkit — Plugin Examples.
# Licensed under MIT.

plugin_name="Configuration Example"
plugin_version="1.0.0"
plugin_supported_oems="all"
plugin_supported_android="33 34 35 36"

##############################################
# Register plugin.
##############################################
plugin_register() {
    log_debug "Configuration example registered"
}

##############################################
# Default configuration.
# These are loaded on first run or when config file is missing.
##############################################
plugin_config() {
    cat <<CONFIG
config_example.theme=auto
config_example.refresh_interval=60
config_example.show_notifications=true
config_example.max_results=100
CONFIG
}

##############################################
# Config schema for validation.
##############################################
plugin_config_schema() {
    cat <<SCHEMA
{
    "config_example.theme": "string",
    "config_example.refresh_interval": "integer",
    "config_example.show_notifications": "boolean",
    "config_example.max_results": "integer"
}
SCHEMA
}

##############################################
# Main execution.
#
# Arguments:
#   $1: config key (optional — if omitted, list all)
#   $2: config value (optional — if provided, set key=value)
##############################################
plugin_run() {
    local key="$1"
    local value="$2"

    if [[ -n "$key" && -n "$value" ]]; then
        # Set a config value
        if plugin_config_set "config-example" "${key}" "${value}" 2>/dev/null; then
            log_success "Configuration updated: ${key}=${value}"
        else
            log_error "Failed to set ${key}=${value}"
            return 1
        fi
    elif [[ -n "$key" ]]; then
        # Get a single config value
        local current
        current="$(plugin_config_get "config-example" "${key}" 2>/dev/null || echo "(not set)")"
        echo "${key}=${current}"
    else
        # List all configuration
        echo "Configuration for ${plugin_name} v${plugin_version}"
        echo ""

        local keys="theme refresh_interval show_notifications max_results"
        for k in $keys; do
            local full_key="config_example.${k}"
            local val
            val="$(plugin_config_get "config-example" "${full_key}" 2>/dev/null || echo "(default)")"
            printf "  %-25s = %s\n" "${full_key}" "${val}"
        done

        echo ""
        echo "Use: toolkit.sh --plugin config-example <key> [value]"
    fi

    return 0
}

##############################################
# Post-run: show what was done.
##############################################
plugin_post_run() {
    local exit_code="$1"
    if [[ "$exit_code" -eq 0 ]]; then
        log_trace "Configuration example: operation successful"
    fi
}

##############################################
# Cleanup.
##############################################
plugin_cleanup() {
    log_trace "Configuration example cleaned up"
}
