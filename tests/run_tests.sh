#!/data/data/com.termux/files/usr/bin/bash
#
# run_tests.sh — Android Toolkit test runner
#
# Runs ShellCheck on all scripts and executes functional tests.
# Usage:
#   ./tests/run_tests.sh                  # Run all tests
#   ./tests/run_tests.sh --shellcheck     # Only ShellCheck
#   ./tests/run_tests.sh --functional     # Only functional tests
#   ./tests/run_tests.sh --list           # List test files
#
# Part of the Android Toolkit.

set -euo pipefail

ANDROID_TOOLKIT_ROOT_DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
export ANDROID_TOOLKIT_ROOT_DIR

PASS=0
FAIL=0
SKIP=0

print_result() {
    local status="$1" name="$2" detail="${3:-}"
    if [[ "$status" == "PASS" ]]; then
        echo "  ✅ PASS | $name${detail:+ — $detail}"
        PASS=$((PASS + 1))
    elif [[ "$status" == "SKIP" ]]; then
        echo "  ⏭️  SKIP | $name${detail:+ — $detail}"
        SKIP=$((SKIP + 1))
    else
        echo "  ❌ FAIL | $name${detail:+ — $detail}"
        FAIL=$((FAIL + 1))
    fi
}

check_shellcheck_installed() {
    command -v shellcheck &>/dev/null
}

##############################################
# Find all shell scripts in the project.
##############################################
find_scripts() {
    find "$ANDROID_TOOLKIT_ROOT_DIR" -name '*.sh' -not -path '*/logs/*' -not -path '*/tests/*' | sort
}

##############################################
# Run ShellCheck on all scripts.
##############################################
test_shellcheck() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo " ShellCheck — Static analysis"
    echo "═══════════════════════════════════════════"

    if ! check_shellcheck_installed; then
        echo "  ShellCheck not installed — skipping"
        SKIP=$((SKIP + 1))
        return
    fi

    local scripts
    scripts="$(find_scripts)"

    if [[ -z "$scripts" ]]; then
        print_result "FAIL" "ShellCheck" "No scripts found"
        return
    fi

    local any_fail=false
    while IFS= read -r script; do
        local rel_path="${script#$ANDROID_TOOLKIT_ROOT_DIR/}"
        if shellcheck -x -e SC1091,SC1090,SC2034,SC2154,SC2312,SC2311 "$script" 2>&1; then
            print_result "PASS" "ShellCheck" "$rel_path"
        else
            print_result "FAIL" "ShellCheck" "$rel_path"
            any_fail=true
        fi
    done <<< "$scripts"

    if $any_fail; then
        echo ""
        echo "  ── Some scripts have ShellCheck warnings/errors."
        echo "  ── See details above. Use shellcheck -x to re-run individually."
    fi
}

##############################################
# Check bash syntax (bash -n) on all scripts.
##############################################
test_bash_syntax() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo " Bash syntax check (bash -n)"
    echo "═══════════════════════════════════════════"

    local scripts
    scripts="$(find_scripts)"

    if [[ -z "$scripts" ]]; then
        print_result "FAIL" "bash -n" "No scripts found"
        return
    fi

    while IFS= read -r script; do
        local rel_path="${script#$ANDROID_TOOLKIT_ROOT_DIR/}"
        if bash -n "$script" 2>/dev/null; then
            print_result "PASS" "bash -n" "$rel_path"
        else
            print_result "FAIL" "bash -n" "$rel_path"
        fi
    done <<< "$scripts"
}

##############################################
# Test that all required module/library files exist.
##############################################
test_file_integrity() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo " File integrity check"
    echo "═══════════════════════════════════════════"

    local missing=false

    # Required libraries
    for lib in logging detection backup utils backend rollback plugin config; do
        if [[ ! -f "$ANDROID_TOOLKIT_ROOT_DIR/lib/${lib}.sh" ]]; then
            print_result "FAIL" "Missing lib" "${lib}.sh"
            missing=true
        else
            print_result "PASS" "Library exists" "${lib}.sh"
        fi
    done

    # Required modules
    local modules=(
        reporting battery display network samsung performance maintenance
        packages capabilities doctor benchmark telemetry updater scheduler
        audit analyzer export tui builder
    )
    for mod in "${modules[@]}"; do
        if [[ ! -f "$ANDROID_TOOLKIT_ROOT_DIR/modules/${mod}.sh" ]]; then
            print_result "FAIL" "Missing module" "${mod}.sh"
            missing=true
        else
            print_result "PASS" "Module exists" "${mod}.sh"
        fi
    done

    # OEM modules
    if [[ ! -f "$ANDROID_TOOLKIT_ROOT_DIR/modules/oem.sh" ]]; then
        print_result "FAIL" "Missing module" "oem.sh"
        missing=true
    else
        print_result "PASS" "Module exists" "oem.sh"
    fi

    for oem in Samsung Google OnePlus Nothing Xiaomi Motorola Oppo Vivo; do
        if [[ ! -f "$ANDROID_TOOLKIT_ROOT_DIR/modules/oem/${oem}.sh" ]]; then
            print_result "SKIP" "OEM module" "${oem}.sh — not present"
        else
            print_result "PASS" "OEM module exists" "${oem}.sh"
        fi
    done

    # Required configs
    local conf_files=(
        configs/default.conf
        configs/settings-db.json
        profiles/balanced.conf
        profiles/performance.conf
        profiles/powersave.conf
        profiles/light.conf
    )

    for cfg_rel in "${conf_files[@]}"; do
        local cfg_path="$ANDROID_TOOLKIT_ROOT_DIR/$cfg_rel"
        if [[ ! -f "$cfg_path" ]]; then
            print_result "FAIL" "Missing file" "$cfg_rel"
            missing=true
        else
            print_result "PASS" "File exists" "$cfg_rel"
        fi
    done

    # Check toolkit.sh itself
    if [[ ! -f "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" ]]; then
        print_result "FAIL" "Missing entrypoint" "toolkit.sh"
        missing=true
    else
        print_result "PASS" "Entrypoint exists" "toolkit.sh"
    fi

    if $missing; then
        echo ""
        echo "  ── Some required files are missing. Check the FAIL entries above."
    fi
}

##############################################
# Test config parsing by sourcing config files.
##############################################
test_config_parsing() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo " Config parsing test"
    echo "═══════════════════════════════════════════"

    for cfg in "$ANDROID_TOOLKIT_ROOT_DIR/configs"/*.conf "$ANDROID_TOOLKIT_ROOT_DIR/profiles"/*.conf; do
        [[ -f "$cfg" ]] || continue
        local name
        name="$(basename "$cfg")"
        local dir_name
        dir_name="$(basename "$(dirname "$cfg")")"
        if bash -n "$cfg" 2>/dev/null; then
            print_result "PASS" "Config syntax" "$dir_name/$name"
        else
            print_result "FAIL" "Config syntax" "$dir_name/$name"
        fi
    done
}

##############################################
# Validate settings-db.json structure.
##############################################
test_settings_db_structure() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo " Settings DB structure validation"
    echo "═══════════════════════════════════════════"

    local db_file="$ANDROID_TOOLKIT_ROOT_DIR/configs/settings-db.json"
    if [[ ! -f "$db_file" ]]; then
        print_result "SKIP" "Settings DB" "settings-db.json not found"
        return
    fi

    # Validate JSON syntax
    if command -v jq &>/dev/null; then
        if jq empty "$db_file" 2>/dev/null; then
            print_result "PASS" "Settings DB" "Valid JSON"
        else
            print_result "FAIL" "Settings DB" "Invalid JSON"
            return
        fi
    else
        # Fallback: basic structure check
        if grep -q '"settings"' "$db_file" && grep -q '"namespace"' "$db_file"; then
            print_result "PASS" "Settings DB" "Basic structure OK (jq not available)"
        else
            print_result "FAIL" "Settings DB" "Missing expected fields"
        fi
    fi

    # Check that each entry has required fields
    local entries
    entries="$(grep -c 'min_android' "$db_file" 2>/dev/null || echo 0)"
    if [[ "$entries" -ge 30 ]]; then
        print_result "PASS" "Settings DB" "Found $entries entries with required fields"
    else
        print_result "WARNING" "Settings DB" "Only $entries entries — expected 30+"
    fi
}

##############################################
# Main test dispatcher.
##############################################
main() {
    echo "═══════════════════════════════════════════"
    echo " Android Toolkit — Test Runner"
    echo " Root: $ANDROID_TOOLKIT_ROOT_DIR"
    echo " Date: $(date)"
    echo "═══════════════════════════════════════════"

    local run_all=true
    local run_shellcheck=false
    local run_functional=false
    local list_only=false

    for arg in "$@"; do
        case "$arg" in
            --shellcheck) run_shellcheck=true; run_all=false ;;
            --functional) run_functional=true; run_all=false ;;
            --list) list_only=true ;;
        esac
    done

    if $list_only; then
        echo ""
        echo "Available test suites:"
        echo "  test_shellcheck        — ShellCheck static analysis"
        echo "  test_bash_syntax       — bash -n syntax check"
        echo "  test_file_integrity    — File existence checks"
        echo "  test_config_parsing    — Config file syntax"
        echo "  test_settings_db_structure — Settings DB structure validation"
        exit 0
    fi

    if $run_all || $run_shellcheck; then
        test_shellcheck
        test_bash_syntax
    fi

    if $run_all || $run_functional; then
        test_file_integrity
        test_config_parsing
        test_settings_db_structure
    fi

    # Summary
    echo ""
    echo "═══════════════════════════════════════════"
    echo " Results:  ✅ $PASS passed  ❌ $FAIL failed  ⏭️  $SKIP skipped"
    echo "═══════════════════════════════════════════"

    # Exit code
    if [[ "$FAIL" -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

main "$@"
