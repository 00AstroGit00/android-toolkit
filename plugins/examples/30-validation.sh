#!/data/data/com.termux/files/usr/bin/bash
#
# 30-validation.sh — Example: Validation Plugin
#
# Demonstrates how to validate prerequisites, configuration,
# and device compatibility before executing.
#
# Plugin SDK v3.0 feature.
#
# Usage:
#   toolkit.sh --plugin validate-example
#
# This plugin demonstrates:
#   - Prerequisite validation in plugin_register()
#   - Config schema definition
#   - Dependency declaration
#   - Safe abort on incompatible device
#
# Part of the Android Toolkit — Plugin Examples.
# Licensed under MIT.

plugin_name="Validation Example"
plugin_version="1.0.0"
plugin_supported_oems="samsung google"   # Only runs on Samsung or Google Pixel
plugin_supported_android="34 35 36"       # Requires Android 14+

##############################################
# Register and validate.
##############################################
plugin_register() {
    log_debug "Validation example registered"
}

##############################################
# Declare dependencies (optional).
# Other plugins that must be loaded first.
##############################################
plugin_dependencies() {
    echo ""
}

##############################################
# Default configuration schema (optional).
# Defines expected config keys and their types.
# Format: {"key": "type"}
##############################################
plugin_config_schema() {
    cat <<SCHEMA
{
    "validate_example.timeout": "integer",
    "validate_example.verbose": "boolean"
}
SCHEMA
}

##############################################
# Default configuration (optional).
# Returns KEY=VALUE lines for initial setup.
##############################################
plugin_config() {
    cat <<CONFIG
validate_example.timeout=30
validate_example.verbose=false
CONFIG
}

##############################################
# Pre-run validation hook.
# Called before plugin_run().
# Return non-zero to abort execution.
##############################################
plugin_pre_run() {
    # Check a required config value
    local timeout
    timeout="$(plugin_config_get "validate-example" "validate_example.timeout" 2>/dev/null || echo "30")"
    if [[ "$timeout" -lt 1 ]]; then
        log_error "Validation example: timeout must be ≥ 1"
        return 1
    fi

    log_info "Validation example: pre-run checks passed"
    return 0
}

##############################################
# Main execution.
##############################################
plugin_run() {
    echo "══════════════════════════════════════════"
    echo "  Validation Example Plugin"
    echo "══════════════════════════════════════════"
    echo ""

    echo "  Plugin:          ${plugin_name} v${plugin_version}"
    echo "  Supported OEMs:  ${plugin_supported_oems}"
    echo "  Supported SDKs:  ${plugin_supported_android}"

    # Validate device compatibility at runtime
    local current_oem current_sdk
    current_oem="$(api_device_oem 2>/dev/null || echo "unknown")"
    current_sdk="$(api_android_sdk 2>/dev/null || echo "0")"

    echo "  Current OEM:     ${current_oem}"
    echo "  Current SDK:     ${current_sdk}"

    # Check OEM match
    local oem_ok=false
    for o in $plugin_supported_oems; do
        if [[ "$current_oem" == "$o" ]]; then
            oem_ok=true
            break
        fi
    done

    if ! $oem_ok; then
        echo "  ⚠️  Warning: This plugin is optimized for Samsung/Google devices."
        echo "  Some features may not work on ${current_oem}."
    fi

    echo ""
    echo "  ✅ Validation complete"
    echo "══════════════════════════════════════════"

    return 0
}

##############################################
# Post-run hook.
##############################################
plugin_post_run() {
    local exit_code="$1"
    log_trace "Validation example completed with exit code ${exit_code}"
}

##############################################
# Cleanup.
##############################################
plugin_cleanup() {
    log_trace "Validation example cleaned up"
}
