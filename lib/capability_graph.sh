#!/data/data/com.termux/files/usr/bin/bash
#
# capability_graph.sh — Capability dependency graph
#
# Capabilities can express dependencies on other capabilities.
# Commands can require capabilities; the graph ensures transitive
# dependencies are resolved before use.
#
# Example dependency chains:
#   benchmark → dumpsys → settings_service
#   report → battery + display + network + samsung
#   samsung_light → is_samsung + one_ui + settings_global
#
# Part of the Android Toolkit.

declare -A CAP_GRAPH_NODES

##############################################
# Register a capability with its dependencies.
# Usage: cap_graph_register <capability> <dep1> [dep2 ...]
##############################################
cap_graph_register() {
    local cap="$1"
    shift
    CAP_GRAPH_NODES["$cap"]="$*"
}

##############################################
# Build the capability graph from known capabilities.
# Should be called after all capability modules are loaded.
##############################################
cap_graph_init() {
    # ── Platform capabilities ──
    cap_graph_register "adb" ""
    cap_graph_register "rish" ""
    cap_graph_register "root" ""

    # ── Android system services ──
    cap_graph_register "dumpsys" "adb rish"
    cap_graph_register "settings_global" "adb rish"
    cap_graph_register "settings_secure" "adb rish"
    cap_graph_register "settings_system" "adb rish"
    cap_graph_register "device_config" "adb rish"
    cap_graph_register "pm_compile" "adb rish"
    cap_graph_register "cmd_appops" "adb rish"

    # ── Feature capabilities ──
    cap_graph_register "is_samsung" ""
    cap_graph_register "is_google" ""
    cap_graph_register "is_oneplus" ""
    cap_graph_register "one_ui" "is_samsung"
    cap_graph_register "one_ui_7_plus" "one_ui"
    cap_graph_register "samsung_gos" "is_samsung settings_global"
    cap_graph_register "samsung_ram_plus" "is_samsung settings_global"
    cap_graph_register "samsung_refresh_rate" "is_samsung settings_secure"
    cap_graph_register "samsung_light_perf" "is_samsung one_ui_7_plus"

    # ── Command capabilities ──
    cap_graph_register "benchmark" "dumpsys"
    cap_graph_register "report" "dumpsys"
    cap_graph_register "audit" "dumpsys"
    cap_graph_register "compile" "pm_compile"
    cap_graph_register "network_refresh" "device_config settings_global"

    # ── Tool capabilities ──
    cap_graph_register "jq_available" ""
    cap_graph_register "curl_available" ""
    cap_graph_register "wget_available" ""
    cap_graph_register "zip_available" ""
    cap_graph_register "dialog_available" ""

    log_debug "Capability graph initialized with ${#CAP_GRAPH_NODES[@]} nodes"
}

##############################################
# Check if a capability exists and all its transitive deps are met.
# Usage: cap_graph_has <capability>
# Returns: 0 if available
##############################################
cap_graph_has() {
    local cap="$1"

    # Check if capability is probed (CAP_* global exists and is truthy)
    if ! cap_has "$cap" 2>/dev/null; then
        return 1
    fi

    # Check dependencies recursively
    local deps="${CAP_GRAPH_NODES[$cap]:-}"
    if [[ -z "$deps" ]]; then
        return 0
    fi

    local dep
    for dep in $deps; do
        if ! cap_graph_has "$dep"; then
            return 1
        fi
    done

    return 0
}

##############################################
# Check capability using the CAP_* global convention.
# Arguments:
#   $1: capability name (will be uppercased and prefixed CAP_)
# Returns: 0 if truthy
##############################################
cap_has() {
    local cap="$1"
    local var_name="CAP_$(echo "$cap" | tr '[:lower:]' '[:upper:]')"
    local val="${!var_name:-}"
    [[ "$val" == "1" || "$val" == "true" ]]
}

##############################################
# Resolve all transitive dependencies for a capability.
# Usage: cap_graph_resolve <capability>
# Outputs: space-separated list of all required capabilities
##############################################
cap_graph_resolve() {
    local cap="$1"
    local -a resolved=()
    local -a visited=()

    _cap_graph_resolve_recursive "$cap" resolved visited
    echo "${resolved[*]}"
}

_cap_graph_resolve_recursive() {
    local cap="$1"
    local -n _resolved="$2"
    local -n _visited="$3"

    # Cycle detection
    local v
    for v in "${_visited[@]}"; do
        [[ "$v" == "$cap" ]] && return
    done
    _visited+=("$cap")

    local deps="${CAP_GRAPH_NODES[$cap]:-}"
    if [[ -n "$deps" ]]; then
        local dep
        for dep in $deps; do
            _cap_graph_resolve_recursive "$dep" _resolved _visited
        done
    fi

    _resolved+=("$cap")
}

##############################################
# Check which required capabilities are missing.
# Usage: cap_graph_missing <cap1> [cap2 ...]
# Outputs: missing capabilities (one per line)
##############################################
cap_graph_missing() {
    local caps=("$@")
    local cap result=()
    for cap in "${caps[@]}"; do
        if ! cap_graph_has "$cap"; then
            result+=("$cap")
        fi
    done
    printf '%s\n' "${result[@]}"
}

##############################################
# Get missing dependencies for a capability chain.
# Usage: cap_graph_missing_deps <capability>
# Outputs: missing deps
##############################################
cap_graph_missing_deps() {
    local cap="$1"
    local all_deps
    declare -a all_deps=()
    declare -a visited=()

    _cap_graph_resolve_recursive "$cap" all_deps visited

    local dep missing=()
    for dep in "${all_deps[@]}"; do
        if ! cap_graph_has "$dep"; then
            missing+=("$dep")
        fi
    done

    printf '%s\n' "${missing[@]}"
}

##############################################
# List all registered capabilities and their status.
##############################################
cap_graph_list() {
    echo "  Capability Graph"
    echo "  ─────────────────────────────────────────────"
    local cap
    for cap in "${!CAP_GRAPH_NODES[@]}"; do
        local status deps
        if cap_graph_has "$cap"; then
            status="✓"
        else
            status="✗"
        fi
        deps="${CAP_GRAPH_NODES[$cap]}"
        if [[ -n "$deps" ]]; then
            printf "  %s %-30s → %s\n" "$status" "$cap" "$deps"
        else
            printf "  %s %-30s\n" "$status" "$cap"
        fi
    done
}
