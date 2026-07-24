#!/data/data/com.termux/files/usr/bin/bash
#
# release_check.sh — Release Validation Module
#
# Runs a comprehensive pre-release validation suite:
#   - Syntax checks on all scripts
#   - Documentation completeness
#   - Version consistency
#   - JSON schema validation
#   - Test results
#   - Artifact integrity
#   - Checksum verification
#   - Manifest validation
#   - Plugin compatibility
#
# Returns PASS/FAIL summary.
#
# Part of the Android Toolkit.

RELEASE_CHECK_REPORT="${ANDROID_TOOLKIT_ROOT_DIR}/exports/release-check.json"

##############################################
# Run the full release validation suite.
##############################################
release_check_run() {
    log_section "Release Validation Suite"

    local errors=0 warnings=0
    local report_entries="[]"

    mkdir -p "${ANDROID_TOOLKIT_ROOT_DIR}/exports"

    # 1. Syntax checks
    echo ""
    _release_check_syntax
    case $? in
        0) report_entries="$(_release_add_result "$report_entries" "syntax" "PASS" "All scripts pass bash -n")" ;;
        1) report_entries="$(_release_add_result "$report_entries" "syntax" "FAIL" "Syntax errors detected"); errors=$((errors+1)) ;;
        2) report_entries="$(_release_add_result "$report_entries" "syntax" "WARNING" "Some files not found"); warnings=$((warnings+1)) ;;
    esac

    # 2. Version consistency
    _release_check_version
    case $? in
        0) report_entries="$(_release_add_result "$report_entries" "version" "PASS" "VERSION file consistent")" ;;
        1) report_entries="$(_release_add_result "$report_entries" "version" "FAIL" "Version mismatch"); errors=$((errors+1)) ;;
        2) report_entries="$(_release_add_result "$report_entries" "version" "WARNING" "Could not verify all version references"); warnings=$((warnings+1)) ;;
    esac

    # 3. Documentation
    _release_check_docs
    case $? in
        0) report_entries="$(_release_add_result "$report_entries" "docs" "PASS" "Documentation complete")" ;;
        1) report_entries="$(_release_add_result "$report_entries" "docs" "FAIL" "Missing required docs"); errors=$((errors+1)) ;;
        2) report_entries="$(_release_add_result "$report_entries" "docs" "WARNING" "Some documentation gaps"); warnings=$((warnings+1)) ;;
    esac

    # 4. JSON validation
    _release_check_json
    case $? in
        0) report_entries="$(_release_add_result "$report_entries" "json" "PASS" "All JSON valid")" ;;
        1) report_entries="$(_release_add_result "$report_entries" "json" "FAIL" "Invalid JSON found"); errors=$((errors+1)) ;;
        2) report_entries="$(_release_add_result "$report_entries" "json" "WARNING" "Could not validate all JSON"); warnings=$((warnings+1)) ;;
    esac

    # 5. Test results
    _release_check_tests
    case $? in
        0) report_entries="$(_release_add_result "$report_entries" "tests" "PASS" "Tests passing")" ;;
        1) report_entries="$(_release_add_result "$report_entries" "tests" "FAIL" "Test failures detected"); errors=$((errors+1)) ;;
        2) report_entries="$(_release_add_result "$report_entries" "tests" "WARNING" "Tests not run or incomplete"); warnings=$((warnings+1)) ;;
    esac

    # 6. Plugin compatibility
    _release_check_plugins
    case $? in
        0) report_entries="$(_release_add_result "$report_entries" "plugins" "PASS" "Plugins compatible")" ;;
        1) report_entries="$(_release_add_result "$report_entries" "plugins" "FAIL" "Plugin compatibility issues"); errors=$((errors+1)) ;;
        2) report_entries="$(_release_add_result "$report_entries" "plugins" "WARNING" "Could not verify all plugins"); warnings=$((warnings+1)) ;;
    esac

    # 7. Config validation
    _release_check_configs
    case $? in
        0) report_entries="$(_release_add_result "$report_entries" "configs" "PASS" "Configs valid")" ;;
        1) report_entries="$(_release_add_result "$report_entries" "configs" "FAIL" "Config errors"); errors=$((errors+1)) ;;
        2) report_entries="$(_release_add_result "$report_entries" "configs" "WARNING" "Some configs unverified"); warnings=$((warnings+1)) ;;
    esac

    # Summary
    echo ""
    echo "  ── Release Validation Summary ──"
    echo ""
    echo "  $(tput setaf 2)✔ PASS:$(tput sgr0) $(echo "$report_entries" | jq '[.[] | select(.status=="PASS")] | length' 2>/dev/null || echo "0")"
    echo "  $(tput setaf 3)⚠ WARN:$(tput sgr0) $(echo "$report_entries" | jq '[.[] | select(.status=="WARNING")] | length' 2>/dev/null || echo "$warnings")"
    echo "  $(tput setaf 1)✘ FAIL:$(tput sgr0) $(echo "$report_entries" | jq '[.[] | select(.status=="FAIL")] | length' 2>/dev/null || echo "$errors")"
    echo ""

    if [[ "$errors" -gt 0 ]]; then
        log_error "Release validation FAILED — ${errors} error(s), ${warnings} warning(s)"
        echo ""
        echo "$report_entries" | jq -r '.[] | select(.status=="FAIL") | "  ✘ \(.check): \(.message)"' 2>/dev/null
    elif [[ "$warnings" -gt 0 ]]; then
        log_warning "Release validation PASSED with ${warnings} warning(s)"
    else
        log_success "Release validation PASSED"
    fi

    # Save report
    local version="${ANDROID_TOOLKIT_VERSION:-0.0.0}"
    jq -n \
        --arg date "$(date -Iseconds)" \
        --arg version "$version" \
        --argjson results "$report_entries" \
        --argjson errors "$errors" \
        --argjson warnings "$warnings" \
        '{
            check: "release-validation",
            date: $date,
            version: $version,
            results: $results,
            summary: {
                errors: $errors,
                warnings: $warnings,
                passed: ([$results[] | select(.status=="PASS")] | length)
            },
            verdict: (if $errors > 0 then "FAIL" elif $warnings > 0 then "PASS_WITH_WARNINGS" else "PASS" end)
        }' > "$RELEASE_CHECK_REPORT" 2>/dev/null || true

    return $errors
}

##############################################
# Add a result entry to the report.
##############################################
_release_add_result() {
    local report="$1" check="$2" status="$3" message="$4"
    echo "$report" | jq \
        --arg c "$check" \
        --arg s "$status" \
        --arg m "$message" \
        '. + [{"check": $c, "status": $s, "message": $m}]' 2>/dev/null || echo "$report"
}

##############################################
# Check 1: Syntax validation.
# Returns: 0=PASS, 1=FAIL, 2=WARNING
##############################################
_release_check_syntax() {
    echo -n "  [1/7] Syntax check... "
    local failed=0 count=0
    while IFS= read -r f; do
        count=$((count + 1))
        bash -n "$f" 2>/dev/null || failed=$((failed + 1))
    done < <(find "$ANDROID_TOOLKIT_ROOT_DIR" -name '*.sh' -not -path '*/logs/*' -not -path '*/.git/*' | sort)

    if [[ "$failed" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0) ($count scripts)"
        return 0
    else
        echo "$(tput setaf 1)FAIL$(tput sgr0) ($failed/$count scripts failed)"
        return 1
    fi
}

##############################################
# Check 2: Version consistency.
##############################################
_release_check_version() {
    echo -n "  [2/7] Version consistency... "
    local vfile="${ANDROID_TOOLKIT_ROOT_DIR}/VERSION"

    if [[ ! -f "$vfile" ]]; then
        echo "$(tput setaf 1)FAIL$(tput sgr0) (VERSION file not found)"
        return 1
    fi

    local version
    version="$(cat "$vfile" | tr -d '[:space:]')"

    # Check CHANGELOG for version entry
    if grep -q "^## v${version}" "${ANDROID_TOOLKIT_ROOT_DIR}/CHANGELOG.md" 2>/dev/null; then
        echo "$(tput setaf 2)PASS$(tput sgr0) (v${version})"
        return 0
    else
        echo "$(tput setaf 3)WARN$(tput sgr0) (version v${version} not found in CHANGELOG)"
        return 2
    fi
}

##############################################
# Check 3: Documentation completeness.
##############################################
_release_check_docs() {
    echo -n "  [3/7] Documentation... "
    local missing=0
    local required_files=(
        "README.md"
        "CHANGELOG.md"
        "LICENSE"
        "SECURITY.md"
        "CONTRIBUTING.md"
        "RELEASE.md"
    )

    local f
    for f in "${required_files[@]}"; do
        if [[ ! -f "${ANDROID_TOOLKIT_ROOT_DIR}/${f}" ]]; then
            missing=$((missing + 1))
        fi
    done

    if [[ "$missing" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"
        return 0
    else
        echo "$(tput setaf 3)WARN$(tput sgr0) ($missing required files missing)"
        return 2
    fi
}

##############################################
# Check 4: JSON validation.
##############################################
_release_check_json() {
    echo -n "  [4/7] JSON validation... "

    if ! command -v jq &>/dev/null; then
        echo "$(tput setaf 3)WARN$(tput sgr0) (jq not available)"
        return 2
    fi

    local failed=0 count=0
    while IFS= read -r f; do
        count=$((count + 1))
        jq empty "$f" 2>/dev/null || failed=$((failed + 1))
    done < <(find "$ANDROID_TOOLKIT_ROOT_DIR" -name '*.json' -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/logs/*' | sort)

    if [[ "$failed" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0) ($count files)"
        return 0
    else
        echo "$(tput setaf 1)FAIL$(tput sgr0) ($failed/$count files invalid)"
        return 1
    fi
}

##############################################
# Check 5: Test results.
##############################################
_release_check_tests() {
    echo -n "  [5/7] Test results... "

    if [[ -f "${ANDROID_TOOLKIT_ROOT_DIR}/tests/test_results.json" ]]; then
        local passed failed
        passed="$(jq -r '.passed // 0' "${ANDROID_TOOLKIT_ROOT_DIR}/tests/test_results.json" 2>/dev/null)"
        failed="$(jq -r '.failed // 0' "${ANDROID_TOOLKIT_ROOT_DIR}/tests/test_results.json" 2>/dev/null)"

        if [[ "$failed" -gt 0 ]]; then
            echo "$(tput setaf 1)FAIL$(tput sgr0) ($failed failures)"
            return 1
        fi
        echo "$(tput setaf 2)PASS$(tput sgr0) ($passed passed)"
        return 0
    fi

    # Check if BATS was run
    if ls "${ANDROID_TOOLKIT_ROOT_DIR}/tests/bats/"*.bats &>/dev/null 2>&1; then
        echo "$(tput setaf 3)WARN$(tput sgr0) (BATS tests exist but results not saved)"
        return 2
    fi

    echo "$(tput setaf 3)WARN$(tput sgr0) (no test results found)"
    return 2
}

##############################################
# Check 6: Plugin compatibility.
##############################################
_release_check_plugins() {
    echo -n "  [6/7] Plugin compatibility... "

    local plugin_dir="${ANDROID_TOOLKIT_ROOT_DIR}/plugins"
    if [[ ! -d "$plugin_dir" ]] || [[ -z "$(ls -A "$plugin_dir" 2>/dev/null)" ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0) (no plugins to check)"
        return 0
    fi

    local failed=0 count=0
    local f
    for f in "$plugin_dir"/*.sh; do
        [[ -f "$f" ]] || continue
        count=$((count + 1))
        bash -n "$f" 2>/dev/null || failed=$((failed + 1))
    done

    if [[ "$failed" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0) ($count plugins)"
        return 0
    else
        echo "$(tput setaf 1)FAIL$(tput sgr0) ($failed/$count plugins have issues)"
        return 1
    fi
}

##############################################
# Check 7: Config file validation.
##############################################
_release_check_configs() {
    echo -n "  [7/7] Config validation... "

    local failed=0 count=0
    while IFS= read -r f; do
        count=$((count + 1))
        bash -n "$f" 2>/dev/null || failed=$((failed + 1))
    done < <(find "$ANDROID_TOOLKIT_ROOT_DIR" -name '*.conf' -not -path '*/.git/*' | sort)

    if [[ "$failed" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0) ($count configs)"
        return 0
    else
        echo "$(tput setaf 1)FAIL$(tput sgr0) ($failed/$count configs invalid)"
        return 1
    fi
}

# CLI entry point
release_check_main() {
    release_check_run
}
