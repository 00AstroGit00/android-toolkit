#!/data/data/com.termux/files/usr/bin/bash
#
# commands.sh — Unified Command Registry
#
# Centralizes command definitions so that CLI help, validation, and
# dispatch are all driven from a single data structure.
#
# Each command entry:
#   name          — Primary command name (--name)
#   aliases       — Alternative invocations
#   description   — Help text
#   category      — Grouping for help output
#   backend       — Required backend (adb|rish|any|none)
#   capabilities  — Space-separated capability requirements
#   dependencies  — Space-separated external tool requirements
#   min_android   — Minimum Android SDK (default: 33)
#   oems          — Supported OEMs ("all" or space-separated list)
#   handler       — Function to call (may be in a module)
#   module        — Module to load before calling handler
#   json_output   — Whether --json output is supported
#   hidden        — If true, omit from help listing
#
# Part of the Android Toolkit.

COMMANDS_REGISTRY=()
COMMANDS_LOADED=false

##############################################
# Define a command in the registry.
# Usage: command_define <name> <key=value> [key=value ...]
##############################################
command_define() {
    local name="$1"
    shift

    # Build entry as tab-separated key=value pairs
    local entry="name=${name}"

    local pair
    for pair in "$@"; do
        entry="${entry}	${pair}"
    done

    COMMANDS_REGISTRY+=("$entry")
}

##############################################
# Initialize the command registry with all toolkit commands.
##############################################
command_init() {
    $COMMANDS_LOADED && return 0
    COMMANDS_LOADED=true

    # ── Information ──
    command_define "version" \
        "aliases=" \
        "description=Show version and exit" \
        "category=Information" \
        "backend=none" \
        "capabilities=" \
        "dependencies=" \
        "min_android=0" \
        "oems=all" \
        "handler=toolkit_cmd_version" \
        "module=" \
        "json_output=false" \
        "hidden=false"

    command_define "about" \
        "aliases=" \
        "description=Show detailed version information" \
        "category=Information" \
        "backend=none" \
        "capabilities=" \
        "dependencies=" \
        "min_android=0" \
        "oems=all" \
        "handler=toolkit_cmd_about" \
        "module=" \
        "json_output=false" \
        "hidden=false"

    command_define "changelog" \
        "aliases=" \
        "description=Display the changelog" \
        "category=Information" \
        "backend=none" \
        "capabilities=" \
        "dependencies=" \
        "min_android=0" \
        "oems=all" \
        "handler=toolkit_cmd_changelog" \
        "module=" \
        "json_output=false" \
        "hidden=false"

    # ── Diagnostics ──
    command_define "status" \
        "aliases=" \
        "description=Show device status summary" \
        "category=Diagnostics" \
        "backend=any" \
        "capabilities=" \
        "dependencies=" \
        "min_android=33" \
        "oems=all" \
        "handler=reporting_status" \
        "module=reporting" \
        "json_output=true" \
        "hidden=false"

    command_define "report" \
        "aliases=" \
        "description=Generate full device report" \
        "category=Diagnostics" \
        "backend=any" \
        "capabilities=dumpsys" \
        "dependencies=" \
        "min_android=33" \
        "oems=all" \
        "handler=toolkit_cmd_report" \
        "module=reporting" \
        "json_output=true" \
        "hidden=false"

    command_define "doctor" \
        "aliases=" \
        "description=Run system diagnostics" \
        "category=Diagnostics" \
        "backend=any" \
        "capabilities=" \
        "dependencies=" \
        "min_android=33" \
        "oems=all" \
        "handler=doctor_run" \
        "module=doctor" \
        "json_output=true" \
        "hidden=false"

    command_define "audit" \
        "aliases=security-check" \
        "description=Run security audit (risk score 0-100)" \
        "category=Diagnostics" \
        "backend=any" \
        "capabilities=dumpsys" \
        "dependencies=" \
        "min_android=33" \
        "oems=all" \
        "handler=audit_run" \
        "module=audit" \
        "json_output=true" \
        "hidden=false"

    command_define "benchmark" \
        "aliases=perf" \
        "description=Run device benchmark" \
        "category=Diagnostics" \
        "backend=any" \
        "capabilities=dumpsys" \
        "dependencies=" \
        "min_android=33" \
        "oems=all" \
        "handler=benchmark_run" \
        "module=benchmark" \
        "json_output=true" \
        "hidden=false"

    command_define "analyze" \
        "aliases=health" \
        "description=Run performance analysis with health scores" \
        "category=Diagnostics" \
        "backend=any" \
        "capabilities=dumpsys" \
        "dependencies=" \
        "min_android=33" \
        "oems=all" \
        "handler=analyzer_run" \
        "module=analyzer" \
        "json_output=true" \
        "hidden=false"

    # ── Operations ──
    command_define "backup" \
        "aliases=snapshot" \
        "description=Create a full settings and packages backup" \
        "category=Operations" \
        "backend=any" \
        "capabilities=" \
        "dependencies=" \
        "min_android=33" \
        "oems=all" \
        "handler=toolkit_cmd_backup" \
        "module=" \
        "json_output=false" \
        "hidden=false"

    command_define "restore" \
        "aliases=" \
        "description=Restore settings from a backup file" \
        "category=Operations" \
        "backend=any" \
        "capabilities=" \
        "dependencies=" \
        "min_android=33" \
        "oems=all" \
        "handler=backup_restore" \
        "module=" \
        "json_output=false" \
        "hidden=false"

    command_define "apply" \
        "aliases=profile" \
        "description=Apply a profile (balanced|performance|powersave|light)" \
        "category=Operations" \
        "backend=any" \
        "capabilities=" \
        "dependencies=" \
        "min_android=33" \
        "oems=all" \
        "handler=performance_apply_profile" \
        "module=performance" \
        "json_output=true" \
        "hidden=false"

    command_define "compile" \
        "aliases=dexopt" \
        "description=Force ART bytecode compilation" \
        "category=Operations" \
        "backend=any" \
        "capabilities=pm_compile" \
        "dependencies=" \
        "min_android=33" \
        "oems=all" \
        "handler=maintenance_compile" \
        "module=maintenance" \
        "json_output=false" \
        "hidden=false"

    command_define "trim-cache" \
        "aliases=clean" \
        "description=Trim system and app caches" \
        "category=Operations" \
        "backend=any" \
        "capabilities=" \
        "dependencies=" \
        "min_android=33" \
        "oems=all" \
        "handler=maintenance_trim_cache" \
        "module=maintenance" \
        "json_output=false" \
        "hidden=false"

    command_define "refresh-network" \
        "aliases=network" \
        "description=Refresh network configuration and DNS" \
        "category=Operations" \
        "backend=any" \
        "capabilities=device_config" \
        "dependencies=" \
        "min_android=33" \
        "oems=all" \
        "handler=network_refresh" \
        "module=network" \
        "json_output=false" \
        "hidden=false"

    command_define "disable-package" \
        "aliases=disable" \
        "description=Disable a system package (opt-in)" \
        "category=Operations" \
        "backend=any" \
        "capabilities=" \
        "dependencies=" \
        "min_android=33" \
        "oems=all" \
        "handler=packages_disable" \
        "module=packages" \
        "json_output=false" \
        "hidden=false"

    command_define "enable-package" \
        "aliases=enable" \
        "description=Re-enable a previously disabled package" \
        "category=Operations" \
        "backend=any" \
        "capabilities=" \
        "dependencies=" \
        "min_android=33" \
        "oems=all" \
        "handler=packages_enable" \
        "module=packages" \
        "json_output=false" \
        "hidden=false"

    # ── Samsung ──
    command_define "list-bloatware" \
        "aliases=bloatware" \
        "description=List bloatware by safety level (safe|moderate|aggressive|all)" \
        "category=Samsung" \
        "backend=none" \
        "capabilities=is_samsung" \
        "dependencies=" \
        "min_android=33" \
        "oems=samsung" \
        "handler=samsung_list_bloatware" \
        "module=samsung" \
        "json_output=false" \
        "hidden=false"

    command_define "samsung-light" \
        "aliases=light-profile" \
        "description=Apply Samsung light optimizations" \
        "category=Samsung" \
        "backend=any" \
        "capabilities=is_samsung one_ui" \
        "dependencies=" \
        "min_android=33" \
        "oems=samsung" \
        "handler=toolkit_cmd_samsung_light" \
        "module=samsung" \
        "json_output=false" \
        "hidden=false"

    # ── Maintenance ──
    command_define "update" \
        "aliases=upgrade" \
        "description=Check for updates (stable|beta|nightly)" \
        "category=Maintenance" \
        "backend=none" \
        "capabilities=" \
        "dependencies=curl|wget" \
        "min_android=0" \
        "oems=all" \
        "handler=updater_run" \
        "module=updater" \
        "json_output=false" \
        "hidden=false"

    command_define "stats" \
        "aliases=telemetry" \
        "description=Show local usage statistics" \
        "category=Maintenance" \
        "backend=none" \
        "capabilities=" \
        "dependencies=" \
        "min_android=0" \
        "oems=all" \
        "handler=telemetry_show" \
        "module=telemetry" \
        "json_output=true" \
        "hidden=false"

    command_define "schedule" \
        "aliases=cron" \
        "description=Manage scheduled tasks (list|enable|disable|run)" \
        "category=Maintenance" \
        "backend=none" \
        "capabilities=" \
        "dependencies=" \
        "min_android=0" \
        "oems=all" \
        "handler=scheduler_run" \
        "module=scheduler" \
        "json_output=false" \
        "hidden=false"

    command_define "packages-recommend" \
        "aliases=pkg-recommend" \
        "description=Analyze installed packages and recommend actions" \
        "category=Maintenance" \
        "backend=any" \
        "capabilities=" \
        "dependencies=" \
        "min_android=33" \
        "oems=all" \
        "handler=packages_recommend" \
        "module=packages" \
        "json_output=true" \
        "hidden=false"

    # ── Advanced ──
    command_define "rollback" \
        "aliases=undo" \
        "description=Rollback changes (latest|<ts>|list)" \
        "category=Advanced" \
        "backend=none" \
        "capabilities=" \
        "dependencies=" \
        "min_android=0" \
        "oems=all" \
        "handler=rollback_perform" \
        "module=" \
        "json_output=true" \
        "hidden=false"

    command_define "plugin" \
        "aliases=plugins" \
        "description=Execute or list plugins" \
        "category=Advanced" \
        "backend=none" \
        "capabilities=" \
        "dependencies=" \
        "min_android=0" \
        "oems=all" \
        "handler=plugin_run" \
        "module=" \
        "json_output=false" \
        "hidden=false"

    command_define "tui" \
        "aliases=menu" \
        "description=Launch interactive terminal UI" \
        "category=Advanced" \
        "backend=none" \
        "capabilities=" \
        "dependencies=dialog|whiptail" \
        "min_android=0" \
        "oems=all" \
        "handler=tui_main" \
        "module=tui" \
        "json_output=false" \
        "hidden=false"

    command_define "export-report" \
        "aliases=export" \
        "description=Export device report (md|json|csv|html|pdf|zip)" \
        "category=Advanced" \
        "backend=none" \
        "capabilities=" \
        "dependencies=" \
        "min_android=0" \
        "oems=all" \
        "handler=export_report" \
        "module=export" \
        "json_output=false" \
        "hidden=false"

    command_define "watch" \
        "aliases=monitor" \
        "description=Monitor device metrics in real time" \
        "category=Advanced" \
        "backend=any" \
        "capabilities=" \
        "dependencies=" \
        "min_android=33" \
        "oems=all" \
        "handler=watch_run" \
        "module=watch" \
        "json_output=false" \
        "hidden=false"

    command_define "compare-reports" \
        "aliases=compare" \
        "description=Compare two reports and show differences" \
        "category=Advanced" \
        "backend=none" \
        "capabilities=" \
        "dependencies=" \
        "min_android=0" \
        "oems=all" \
        "handler=compare_run" \
        "module=compare" \
        "json_output=true" \
        "hidden=false"

    command_define "build" \
        "aliases=dist" \
        "description=Build release artifact" \
        "category=Advanced" \
        "backend=none" \
        "capabilities=" \
        "dependencies=zip|sha256sum" \
        "min_android=0" \
        "oems=all" \
        "handler=builder_run" \
        "module=builder" \
        "json_output=false" \
        "hidden=false"

    command_define "profile-manager" \
        "aliases=profiles" \
        "description=Manage profiles (list|clone|edit|validate|compare|export|import)" \
        "category=Advanced" \
        "backend=none" \
        "capabilities=" \
        "dependencies=" \
        "min_android=0" \
        "oems=all" \
        "handler=profile_manager_run" \
        "module=profile_manager" \
        "json_output=true" \
        "hidden=false"

    # ── Hidden / Internal ──
    command_define "help" \
        "aliases=" \
        "description=Show this help message" \
        "category=Hidden" \
        "backend=none" \
        "capabilities=" \
        "dependencies=" \
        "min_android=0" \
        "oems=all" \
        "handler=usage" \
        "module=" \
        "json_output=false" \
        "hidden=true"

    log_debug "Command registry initialized with ${#COMMANDS_REGISTRY[@]} commands"
}

##############################################
# Get a field from a command entry.
# Arguments:
#   $1: command entry (tab-separated key=value)
#   $2: field name
# Outputs: field value or empty string
##############################################
command_get_field() {
    local entry="$1" field="$2"
    local pair value

    # Check name first (tab-separated)
    value=$(echo "$entry" | tr '\t' '\n' | grep "^${field}=" | head -1 | cut -d= -f2-)
    echo "$value"
}

##############################################
# Find a command entry by name.
# Arguments:
#   $1: command name
# Outputs: full entry (tab-separated)
##############################################
command_find() {
    local name="$1"
    local entry
    for entry in "${COMMANDS_REGISTRY[@]}"; do
        local entry_name
        entry_name="$(command_get_field "$entry" "name")"
        if [[ "$entry_name" == "$name" ]]; then
            echo "$entry"
            return 0
        fi
        # Check aliases
        local aliases
        aliases="$(command_get_field "$entry" "aliases")"
        if echo "$aliases" | grep -qw "$name" 2>/dev/null; then
            echo "$entry"
            return 0
        fi
    done
    return 1
}

##############################################
# Generate CLI help text from the registry.
##############################################
command_generate_help() {
    local version="${ANDROID_TOOLKIT_VERSION:-0.0.0}"

    cat <<EOF
╔══════════════════════════════════════════════════════════════╗
║                   Android Toolkit  v${version}                    ║
║  Non-root optimization & diagnostics for modern devices     ║
╚══════════════════════════════════════════════════════════════╝

USAGE
  toolkit.sh [OPTIONS] <ACTION> [ARGS]

OPTIONS
  -b, --backend <type>  Backend: adb | rish | auto (default)
  -s, --serial <id>     ADB device serial
  -v, --verbose         Enable verbose logging
  -n, --dry-run         Preview changes without executing
  -h, --help            Show this help message
  --json                Output in JSON format (where supported)

EOF

    # Group commands by category
    local categories
    categories="$(for entry in "${COMMANDS_REGISTRY[@]}"; do
        command_get_field "$entry" "category"
    done | sort -u | grep -v '^Hidden$')"

    local cat
    for cat in $categories; do
        echo ""
        echo "  ${cat}:"
        local entry
        for entry in "${COMMANDS_REGISTRY[@]}"; do
            local category hidden name desc aliases
            category="$(command_get_field "$entry" "category")"
            hidden="$(command_get_field "$entry" "hidden")"
            [[ "$category" != "$cat" ]] && continue
            [[ "$hidden" == "true" ]] && continue
            name="$(command_get_field "$entry" "name")"
            desc="$(command_get_field "$entry" "description")"
            aliases="$(command_get_field "$entry" "aliases")"

            local alias_text=""
            [[ -n "$aliases" ]] && alias_text=" (alias: --${aliases//|/, --})"

            printf "    --%-25s %s\n" "$name" "$desc"
        done
    done

    echo ""
    echo "EXAMPLES"
    echo "  toolkit.sh --status              Quick device overview"
    echo "  toolkit.sh --backend rish --report  Full report via Shizuku"
    echo "  toolkit.sh --apply balanced      Apply balanced profile"
    echo "  toolkit.sh --audit               Security audit"
    echo "  toolkit.sh --watch               Live monitoring"
    echo "  toolkit.sh --export report json  Export as JSON"
    echo "  toolkit.sh --tui                 Interactive menu"
    echo ""
}

##############################################
# Check if a command can run given the current state.
# Arguments:
#   $1: command entry
# Returns: 0 if runnable, 1 if not (prints warnings)
##############################################
command_can_run() {
    local entry="$1"

    # Check backend requirement
    local required_backend min_android required_caps required_deps oems
    required_backend="$(command_get_field "$entry" "backend")"
    min_android="$(command_get_field "$entry" "min_android")"
    required_caps="$(command_get_field "$entry" "capabilities")"
    required_deps="$(command_get_field "$entry" "dependencies")"
    oems="$(command_get_field "$entry" "oems")"

    # Backend check
    if [[ "$required_backend" == "adb" && "$ANDROID_TOOLKIT_BACKEND" != "adb" ]]; then
        log_warning "Command requires ADB backend"
        return 1
    fi
    if [[ "$required_backend" == "rish" && "$ANDROID_TOOLKIT_BACKEND" != "rish" ]]; then
        log_warning "Command requires Shizuku/rish backend"
        return 1
    fi

    # Android version check
    if [[ "$min_android" -gt 0 ]]; then
        local sdk="${CAP_ANDROID_SDK:-0}"
        if [[ "$sdk" -gt 0 && "$sdk" -lt "$min_android" ]]; then
            log_warning "Command requires Android SDK $min_android+ (current: $sdk)"
            return 1
        fi
    fi

    # OEM check
    if [[ "$oems" != "all" ]]; then
        local current_oem="${OEM_LOADED:-generic}"
        if ! echo "$oems" | grep -qw "$current_oem" 2>/dev/null; then
            log_warning "Command not supported on $current_oem"
            return 1
        fi
    fi

    # Capability checks
    if [[ -n "$required_caps" ]]; then
        local cap
        for cap in $required_caps; do
            if ! cap_has "$cap" 2>/dev/null; then
                log_warning "Missing capability: $cap"
                return 1
            fi
        done
    fi

    return 0
}

##############################################
# Output command list as JSON.
##############################################
command_list_json() {
    local first=true
    echo '{"commands":['
    local entry
    for entry in "${COMMANDS_REGISTRY[@]}"; do
        $first || echo ","
        first=false
        local name desc category backend hidden json_out
        name="$(command_get_field "$entry" "name")"
        desc="$(command_get_field "$entry" "description")"
        category="$(command_get_field "$entry" "category")"
        backend="$(command_get_field "$entry" "backend")"
        hidden="$(command_get_field "$entry" "hidden")"
        json_out="$(command_get_field "$entry" "json_output")"
        printf '{"name":"%s","description":"%s","category":"%s","backend":"%s","hidden":%s,"json_output":%s}' \
            "$name" "$desc" "$category" "$backend" "$hidden" "$json_out"
    done
    echo ']}'
}

# Auto-initialize when loaded
command_init
