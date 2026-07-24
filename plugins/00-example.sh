#!/data/data/com.termux/files/usr/bin/bash
#
# 00-example.sh — Example plugin for the Android Toolkit plugin system
#
# This plugin demonstrates the complete Plugin SDK v2.0 API.
# Copy this file to create new plugins.
#
# Required:
#   plugin_name              — Human-readable name
#   plugin_version           — Semver version
#   plugin_supported_oems    — Space-separated OEM list or "all"
#   plugin_supported_android — Space-separated SDK list
#   plugin_run()             — Called when plugin is executed
#
# Optional:
#   plugin_register()        — Called once at load time
#   plugin_pre_run()         — Called before plugin_run()
#   plugin_post_run()        — Called after plugin_run()
#   plugin_cleanup()         — Called on exit/error
#   plugin_config()          — Return default config as KEY=VALUE lines
#   plugin_dependencies()    — Return space-separated dependency names
#
# Part of the Android Toolkit.

plugin_name="Example Plugin"
plugin_version="2.0.0"
plugin_supported_oems="all"
plugin_supported_android="33 34 35 36"

##############################################
# Register plugin capabilities.
# Called once when the plugin is loaded.
##############################################
plugin_register() {
    log_debug "Example plugin registered"
}

##############################################
# Pre-run hook.
# Called before plugin_run().
# Arguments: same as plugin_run
##############################################
plugin_pre_run() {
    log_trace "Example plugin pre-run: $*"
}

##############################################
# Main plugin execution.
# Arguments: passed from CLI after plugin name
#   toolkit.sh --plugin example --arg1 value1 --arg2 value2
##############################################
plugin_run() {
    log_section "Example Plugin"
    log_info "Plugin: $plugin_name v$plugin_version"
    log_info "Arguments: $*"
    log_info "OEM support: $plugin_supported_oems"
    log_info "Android support: $plugin_supported_android"

    # Access plugin config
    local cfg_val
    cfg_val="$(plugin_config_get "00-example" "example_setting")"
    log_info "Config example_setting: ${cfg_val:-not set}"

    log_success "Example plugin executed successfully"
}

##############################################
# Post-run hook.
# Called after plugin_run().
# Arguments:
#   $1: exit code from plugin_run
##############################################
plugin_post_run() {
    local exit_code="$1"
    log_trace "Example plugin post-run (exit code: $exit_code)"
}

##############################################
# Cleanup on exit or error.
##############################################
plugin_cleanup() {
    log_debug "Example plugin cleaned up"
}

##############################################
# Default configuration (optional).
# Returns KEY=VALUE lines.
##############################################
plugin_config() {
    cat <<'CONFIG'
# Example plugin configuration
example_setting=default_value
example_timeout=30
CONFIG
}

##############################################
# Plugin dependencies (optional).
# Returns space-separated plugin names that must be loaded first.
##############################################
plugin_dependencies() {
    echo ""
}
