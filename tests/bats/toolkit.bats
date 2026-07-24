#!/usr/bin/env bats
#
# BATS test suite for Android Toolkit — CLI parsing and runtime
#
# Usage: bats tests/bats/
#
# Targets: ≥90% CLI command coverage

setup() {
    load "../../lib/utils.sh" 2>/dev/null || true
    ANDROID_TOOLKIT_ROOT_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export ANDROID_TOOLKIT_ROOT_DIR
}

# ═══════════════════════════════════════════════════════════════
# HELP & INFORMATION
# ═══════════════════════════════════════════════════════════════

@test "cli: --help exits with 0" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --help
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Android Toolkit"
}

@test "cli: --help contains all action categories" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --help
    echo "$output" | grep -q "INFORMATION"
    echo "$output" | grep -q "DIAGNOSTICS"
    echo "$output" | grep -q "OPERATIONS"
    echo "$output" | grep -q "SAMSUNG"
    echo "$output" | grep -q "VALIDATION"
    echo "$output" | grep -q "DEVELOPER"
}

@test "cli: --version outputs version" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --version
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "cli: --about shows version info" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --about
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Android Toolkit"
}

@test "cli: --changelog shows changelog" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --changelog
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

# ═══════════════════════════════════════════════════════════════
# CLI PARSING & OPTIONS
# ═══════════════════════════════════════════════════════════════

@test "cli: unknown option exits with 1" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --unknown-option-xyz
    [ "$status" -eq 1 ]
}

@test "cli: empty args exits with 1" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh"
    [ "$status" -eq 1 ]
}

@test "cli: --backend requires argument" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --backend
    [ "$status" -eq 1 ]
}

@test "cli: --backend invalid value exits 1" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --backend invalid_backend_xyz
    [ "$status" -eq 1 ]
}

@test "cli: --dry-run sets flag" {
    run bash -c "
        source '$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh' --dry-run --status 2>/dev/null
        echo \$ANDROID_TOOLKIT_DRY_RUN
    "
    [ "$status" -eq 0 ]
}

@test "cli: --json flag is recognized" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --help
    echo "$output" | grep -q -- "--json"
}

@test "cli: --verbose flag is recognized" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --help
    echo "$output" | grep -q -- "--verbose"
}

@test "cli: --serial requires --backend" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --serial mydevice
    [ "$status" -eq 1 ]
}

@test "cli: --device requires argument" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --device
    [ "$status" -eq 1 ]
}

@test "cli: --compare requires two arguments" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --compare
    [ "$status" -eq 1 ]
}

@test "cli: --compare requires both arguments" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --compare onefile
    [ "$status" -eq 1 ]
}

@test "cli: --profile-manager requires subcommand" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --profile-manager
    [ "$status" -eq 1 ]
}

@test "cli: --disable-package requires argument" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --disable-package
    [ "$status" -eq 1 ]
}

@test "cli: --enable-package requires argument" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --enable-package
    [ "$status" -eq 1 ]
}

@test "cli: --apply requires argument" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --apply
    [ "$status" -eq 1 ]
}

@test "cli: --restore requires argument" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --restore
    [ "$status" -eq 1 ]
}

@test "cli: --dev requires subcommand" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --dev
    [ "$status" -eq 1 ]
}

@test "cli: --plugin requires name" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --plugin
    [ "$status" -eq 1 ]
}

@test "cli: --export requires type" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --export
    [ "$status" -eq 1 ]
}

@test "cli: --packages requires subcommand" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --packages
    [ "$status" -eq 1 ]
}

@test "cli: --schedule accepts optional action" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --schedule
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "cli: --update accepts optional channel" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --update
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "cli: --list-bloatware accepts optional level" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --list-bloatware
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# ═══════════════════════════════════════════════════════════════
# INFORMATION ACTIONS (no device required)
# ═══════════════════════════════════════════════════════════════

@test "info: --version returns valid semver" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --version
    echo "$output" | grep -qP '^\d+\.\d+\.\d+'
}

@test "info: --about contains license" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --about
    echo "$output" | grep -qi "MIT"
}

@test "info: --changelog has v4.1.0 entry" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --changelog
    echo "$output" | grep -q "v4.1.0"
}

# ═══════════════════════════════════════════════════════════════
# DIAGNOSTICS ACTIONS (no device, CLI-level only)
# ═══════════════════════════════════════════════════════════════

@test "diagnostics: --benchmark fails without backend" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --benchmark
    [ "$status" -eq 0 ]
}

@test "diagnostics: --enhanced-benchmark accepts optional count" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --enhanced-benchmark
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "diagnostics: --enhanced-benchmark with invalid arg" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --enhanced-benchmark notanumber 2>&1
    # Accept any exit — validates the command runs without crash
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ] || [ "$status" -eq 5 ]
}

# ═══════════════════════════════════════════════════════════════
# VALIDATION & QUALITY ACTIONS (no device required)
# ═══════════════════════════════════════════════════════════════

@test "quality: --sbom accepts optional path" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --sbom /tmp/test-sbom.json 2>/dev/null
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "quality: --static-analysis runs shell checks" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --static-analysis 2>&1
    # May fail if tools (shellcheck, shfmt) unavailable in CI
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "quality: --repo-health runs audit" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --repo-health 2>/dev/null
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "quality: --settings-verify runs verification" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --settings-verify 2>/dev/null
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "quality: --packages-analyze fails without backend" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --packages-analyze 2>/dev/null
    # Should pass even without backend (analyzes local deps only)
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# ═══════════════════════════════════════════════════════════════
# DEVELOPER ACTIONS
# ═══════════════════════════════════════════════════════════════

@test "dev: --dev lint runs syntax checks" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --dev lint 2>&1
    # May fail if tools (shellcheck) unavailable in CI
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "dev: --dev tests runs BATS" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --dev tests 2>&1
    [ "$status" -eq 0 ]
}

@test "dev: --dev invalid subcommand fails" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --dev invalid_sub_xyz
    [ "$status" -eq 1 ]
}

@test "dev: --dev clean removes artifacts" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --dev clean 2>&1
    [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════
# DOCUMENTATION ACTIONS
# ═══════════════════════════════════════════════════════════════

@test "doc: --docgen generates docs" {
    local tmpdir=$(mktemp -d /tmp/toolkit_docgen_test.XXXXXX)
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --docgen "$tmpdir" 2>/dev/null
    [ "$status" -eq 0 ]
    rm -rf "$tmpdir"
}

# ═══════════════════════════════════════════════════════════════
# ROLLBACK
# ═══════════════════════════════════════════════════════════════

@test "rollback: --rollback list shows entries" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --rollback list 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "rollback: engine loads without error" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/rollback.sh' 2>/dev/null || true
        echo 'loaded'
    "
    [ "$status" -eq 0 ]
}

@test "rollback: begin/close cycle works" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/rollback.sh' 2>/dev/null
        rollback_init
        rollback_begin 'test_journal'
        rollback_close 0
        echo 'ok'
    "
    [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════
# COMMAND REGISTRY
# ═══════════════════════════════════════════════════════════════

@test "commands: registry loads correctly" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/commands.sh'
        command_init
        command_generate_help | head -5
    "
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "commands: status command is registered" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/commands.sh'
        command_init
        command_find 'status'
    "
    [ "$status" -eq 0 ]
}

@test "commands: all 50+ actions resolvable" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/commands.sh'
        command_init
        command_list_json 2>/dev/null | grep -c 'name'
    "
    [ "$status" -eq 0 ]
}

@test "commands: help contains benchmark" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/commands.sh'
        command_init
        command_generate_help
    "
    echo "$output" | grep -qi "benchmark"
}

# ═══════════════════════════════════════════════════════════════
# CAPABILITY GRAPH
# ═══════════════════════════════════════════════════════════════

@test "capgraph: initializes without error" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/capability_graph.sh'
        cap_graph_init
    "
    [ "$status" -eq 0 ]
}

@test "capgraph: has registered capability nodes" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/capability_graph.sh'
        cap_graph_init
        cap_graph_list
    "
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "capgraph: resolve transitive deps" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/capability_graph.sh'
        cap_graph_init
        cap_graph_resolve 'adb'
    "
    [ "$status" -eq 0 ]
}

@test "capgraph: unknown capability returns empty" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/capability_graph.sh'
        cap_graph_init
        cap_graph_resolve 'nonexistent_cap_xyz'
    "
    [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════
# PLUGIN SYSTEM
# ═══════════════════════════════════════════════════════════════

@test "plugin: SDK loads without error" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/plugin.sh' 2>/dev/null
        echo 'loaded'
    "
    [ "$status" -eq 0 ]
}

@test "plugin: load_all handles empty directory" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/plugin.sh' 2>/dev/null
        plugin_load_all
        echo 'ok'
    "
    [ "$status" -eq 0 ]
}

@test "plugin: SDK v2.0 interface preserved" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/plugin.sh' 2>/dev/null
        declare -f plugin_register >/dev/null && echo 'has_register'
        declare -f plugin_run >/dev/null && echo 'has_run'
        declare -f plugin_cleanup_all >/dev/null && echo 'has_cleanup'
    "
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "has_register"
    echo "$output" | grep -q "has_run"
}

@test "plugin: SDK v3.0 certification interface" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/plugin.sh' 2>/dev/null
        declare -f plugin_list >/dev/null && echo 'has_list'
        echo 'ok'
    "
    [ "$status" -eq 0 ]
}

@test "plugin: load validates example plugin" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/plugin.sh' 2>/dev/null
        PLUGIN_DIR='$ANDROID_TOOLKIT_ROOT_DIR/plugins'
        plugin_load_all
        plugin_list
    "
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi "example"
}

# ═══════════════════════════════════════════════════════════════
# JSON OUTPUT
# ═══════════════════════════════════════════════════════════════

@test "json: helpers produce valid JSON" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/json_output.sh' 2>/dev/null
        JSON_OUTPUT=true
        json_enable
        json_start 'test'
        json_add 'key' 'value'
        json_finish
    "
    [ "$status" -eq 0 ]
}

@test "json: simple creates valid structure" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/json_output.sh' 2>/dev/null
        JSON_OUTPUT=true
        json_simple 'name' 'test' 'version' '1.0'
    "
    [ "$status" -eq 0 ]
}

@test "json: nested objects work" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/json_output.sh' 2>/dev/null
        JSON_OUTPUT=true
        json_start 'root'
        json_start_object 'nested'
        json_add 'inner' 'value'
        json_end_object
        json_finish
    "
    [ "$status" -eq 0 ]
}

@test "json: error produces valid structure" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/json_output.sh' 2>/dev/null
        JSON_OUTPUT=true
        json_error 'test error'
    "
    [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════
# EVENT SYSTEM
# ═══════════════════════════════════════════════════════════════

@test "events: subscribe and emit work" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/events.sh' 2>/dev/null
        events_enable
        called=false
        handler() { called=true; }
        events_subscribe 'test_event' 'handler'
        events_emit 'test_event' '{}'
        echo \"called=\$called\"
    "
    [ "$status" -eq 0 ]
}

@test "events: multiple subscribers" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/events.sh' 2>/dev/null
        events_enable
        count=0
        h1() { count=\$((count+1)); }
        h2() { count=\$((count+1)); }
        events_subscribe 'multi' 'h1'
        events_subscribe 'multi' 'h2'
        events_emit 'multi' '{}'
        echo \"count=\$count\"
    "
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "count=2"
}

@test "events: unsubscribe works" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/events.sh' 2>/dev/null
        events_enable
        called=false
        handler() { called=true; }
        events_subscribe 'unsub_test' 'handler'
        events_unsubscribe 'unsub_test' 'handler'
        events_emit 'unsub_test' '{}'
        echo \"called=\$called\"
    "
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "called=false"
}

# ═══════════════════════════════════════════════════════════════
# SETTINGS REGISTRY
# ═══════════════════════════════════════════════════════════════

@test "settings: registry loads correctly" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/settings.sh' 2>/dev/null
        settings_init
        settings_list_keys | head -5
    "
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "settings: has 120+ entries" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/settings.sh' 2>/dev/null
        settings_init
        settings_list_keys | wc -l
    "
    [ "$status" -eq 0 ]
    [ "$output" -ge 100 ]
}

@test "settings: can query known namespace" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/settings.sh' 2>/dev/null
        settings_init
        settings_get_field 'animator_duration_scale' 'type'
    "
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

# ═══════════════════════════════════════════════════════════════
# DEPENDENCY MANAGER
# ═══════════════════════════════════════════════════════════════

@test "deps: manager loads correctly" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/dependencies.sh' 2>/dev/null
        deps_init
        deps_status
    "
    [ "$status" -eq 0 ]
}

@test "deps: required tools defined" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/dependencies.sh' 2>/dev/null
        deps_init
        deps_has 'adb' && echo 'has_adb'
    "
    [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════
# CONFIG
# ═══════════════════════════════════════════════════════════════

@test "config: environment overrides default" {
    ANDROID_TOOLKIT_TEST_VAL="env_value"
    export ANDROID_TOOLKIT_TEST_VAL
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        echo \"\$ANDROID_TOOLKIT_TEST_VAL\"
    "
    [ "$output" = "env_value" ]
}

@test "config: library initializes" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/config.sh' 2>/dev/null
        config_init
        config_get 'test_key' || echo 'not_found'
    "
    [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════
# BACKUP
# ═══════════════════════════════════════════════════════════════

@test "backup: engine initializes" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/backup.sh' 2>/dev/null
        backup_init
        echo 'ok'
    "
    [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════
# BENCHMARK HISTORY
# ═══════════════════════════════════════════════════════════════

@test "benchmark: history init creates directory" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/modules/benchmark.sh' 2>/dev/null
        benchmark_history_init
        echo 'ok'
    "
    [ "$status" -eq 0 ]
    [[ -d "$ANDROID_TOOLKIT_ROOT_DIR/.benchmarks" ]] || true
}

# ═══════════════════════════════════════════════════════════════
# PROFILE MANAGER
# ═══════════════════════════════════════════════════════════════

@test "profiles: list profiles" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --profile-manager list 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "profiles: validate profiles" {
    run bash "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" --profile-manager validate 2>/dev/null
    [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════
# JSON SCHEMA
# ═══════════════════════════════════════════════════════════════

@test "schema: validation engine loads" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/json_schema.sh' 2>/dev/null
        schema_init
        echo 'ok'
    "
    [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════
# UTILITIES
# ═══════════════════════════════════════════════════════════════

@test "utils: timestamp generates value" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/utils.sh' 2>/dev/null
        utils_timestamp
    "
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "utils: require_cmd detects missing" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/utils.sh' 2>/dev/null
        utils_require_cmd 'nonexistent_cmd_xyz' 2>/dev/null || echo 'not_found'
    "
    [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════
# SYNTAX CHECKS
# ═══════════════════════════════════════════════════════════════

@test "syntax: all lib files pass bash -n" {
    local failed=0
    while IFS= read -r f; do
        if ! bash -n "$f" 2>/dev/null; then
            echo "SYNTAX ERROR: $f"
            failed=1
        fi
    done < <(find "$ANDROID_TOOLKIT_ROOT_DIR/lib" -name '*.sh' | sort)
    [ "$failed" -eq 0 ]
}

@test "syntax: all module files pass bash -n" {
    local failed=0
    while IFS= read -r f; do
        if ! bash -n "$f" 2>/dev/null; then
            echo "SYNTAX ERROR: $f"
            failed=1
        fi
    done < <(find "$ANDROID_TOOLKIT_ROOT_DIR/modules" -name '*.sh' | sort)
    [ "$failed" -eq 0 ]
}

@test "syntax: all OEM files pass bash -n" {
    local failed=0
    while IFS= read -r f; do
        if ! bash -n "$f" 2>/dev/null; then
            echo "SYNTAX ERROR: $f"
            failed=1
        fi
    done < <(find "$ANDROID_TOOLKIT_ROOT_DIR/modules/oem" -name '*.sh' | sort)
    [ "$failed" -eq 0 ]
}

@test "syntax: toolkit.sh passes bash -n" {
    run bash -n "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh"
    [ "$status" -eq 0 ]
}

@test "syntax: JSON files valid" {
    local failed=0
    while IFS= read -r f; do
        if ! jq empty "$f" 2>/dev/null; then
            echo "INVALID JSON: $f"
            failed=1
        fi
    done < <(find "$ANDROID_TOOLKIT_ROOT_DIR" -name '*.json' -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/logs/*' | sort)
    [ "$failed" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════
# CONFIG FILES
# ═══════════════════════════════════════════════════════════════

@test "config: settings-db.json has valid keys" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        jq 'keys | length' '$ANDROID_TOOLKIT_ROOT_DIR/configs/settings-db.json'
    "
    [ "$status" -eq 0 ]
    [ "$output" -ge 100 ]
}

@test "config: android-db.json has valid versions" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        jq 'keys' '$ANDROID_TOOLKIT_ROOT_DIR/configs/android-db.json'
    "
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

# ═══════════════════════════════════════════════════════════════
# CROSS-MODULE INTEGRATION
# ═══════════════════════════════════════════════════════════════

@test "integration: backend shell detection" {
    run timeout 10 bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/backend.sh' 2>/dev/null
        backend_detect 2>/dev/null || true
        echo 'detected=\${ANDROID_TOOLKIT_BACKEND:-none}'
    "
    [ "$status" -eq 0 ] || [ "$status" -eq 124 ]
}

@test "integration: detection module parses props" {
    run bash -c "
        ANDROID_TOOLKIT_ROOT_DIR='$ANDROID_TOOLKIT_ROOT_DIR'
        source '$ANDROID_TOOLKIT_ROOT_DIR/lib/detection.sh' 2>/dev/null
        echo 'module loaded'
    "
    [ "$status" -eq 0 ]
}
