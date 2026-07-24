#!/data/data/com.termux/files/usr/bin/bash
#
# 10-command-extension.sh — Example: Command Extension Plugin
#
# Demonstrates how to register custom CLI commands using plugin_commands().
# Plugin SDK v3.0 feature.
#
# When loaded, this plugin adds the following commands:
#   plugin:custom <name>   — Greet a user
#   plugin:health          — Show plugin health status
#
# These commands appear in --help output and can be run via:
#   toolkit.sh plugin:custom "World"
#   toolkit.sh plugin:health
#
# Part of the Android Toolkit — Plugin Examples.
# Licensed under MIT.

plugin_name="Command Extension Example"
plugin_version="1.0.0"
plugin_supported_oems="all"
plugin_supported_android="33 34 35 36"

##############################################
# Register plugin metadata and capabilities.
##############################################
plugin_register() {
    log_debug "Command Extension example registered"
}

##############################################
# Define custom CLI commands.
#
# Returns lines in the format:
#   command_name|description|category
#
# The toolkit registers these as top-level commands.
##############################################
plugin_commands() {
    cat <<CMDS
plugin:custom|Greet a user by name|Plugin Examples
plugin:health|Show plugin system health|Plugin Examples
CMDS
}

##############################################
# Execute a custom command.
#
# Arguments:
#   $@: the full command line after the plugin name
#       e.g., "plugin:custom World" → $1=plugin:custom, $2=World
##############################################
plugin_run() {
    local subcommand="$1"
    shift

    case "$subcommand" in
        plugin:custom)
            local name="${1:-stranger}"
            echo "Hello, ${name}! This is the Command Extension plugin."
            echo "Toolkit version: ${ANDROID_TOOLKIT_VERSION:-unknown}"
            return 0
            ;;
        plugin:health)
            echo "Plugin Health Report"
            echo "  Plugin name:    ${plugin_name}"
            echo "  Plugin version: ${plugin_version}"
            echo "  SDK:            v3.0"
            echo "  OEMs:           ${plugin_supported_oems}"
            echo "  Android SDKs:   ${plugin_supported_android}"
            echo "  Status:         ✅ Healthy"
            return 0
            ;;
        *)
            echo "Unknown subcommand: $subcommand"
            echo "Available: plugin:custom, plugin:health"
            return 1
            ;;
    esac
}

##############################################
# Cleanup on exit.
##############################################
plugin_cleanup() {
    log_trace "Command Extension example cleaned up"
}
