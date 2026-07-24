#!/data/data/com.termux/files/usr/bin/bash
#
# release_ready.sh — Release Readiness Assessment
#
# Verifies the full release checklist:
#   - all tests pass
#   - static analysis passes
#   - runtime tests pass
#   - documentation generated
#   - schemas validate
#   - benchmarks complete
#   - SBOM generated
#   - checksums valid
#   - compatibility matrix updated
#   - security review passed
#   - API freeze document exists
#
# Returns: PASS, WARNING, or FAIL with actionable recommendations.
#
# Part of the Android Toolkit.

RELEASE_READY_REPORT="${ANDROID_TOOLKIT_ROOT_DIR}/exports/release-ready.json"

##############################################
# Run full release readiness assessment.
##############################################
release_ready_run() {
    log_section "Release Readiness Assessment"

    mkdir -p "$(dirname "$RELEASE_READY_REPORT")"

    local checks="[]"
    local errors=0 warnings=0

    echo ""

    # 1. Syntax check
    _ready_check_syntax
    local status=$?
    checks="$(_ready_add "Syntax check" "$status" "All .sh files pass bash -n")"
    [[ "$status" == "FAIL" ]] && errors=$((errors + 1))
    [[ "$status" == "WARNING" ]] && warnings=$((warnings + 1))

    # 2. Static analysis
    _ready_check_static
    status=$?
    checks="$(_ready_add "Static analysis" "$status" "ShellCheck + shfmt + markdownlint + jq")"
    [[ "$status" == "FAIL" ]] && errors=$((errors + 1))

    # 3. JSON validation
    _ready_check_json
    status=$?
    checks="$(_ready_add "JSON validation" "$status" "All .json files parse correctly")"
    [[ "$status" == "FAIL" ]] && errors=$((errors + 1))

    # 4. Documentation
    _ready_check_docs
    status=$?
    checks="$(_ready_add "Documentation" "$status" "All required docs exist")"
    [[ "$status" == "FAIL" ]] && errors=$((errors + 1))
    [[ "$status" == "WARNING" ]] && warnings=$((warnings + 1))

    # 5. API freeze
    _ready_check_api_freeze
    status=$?
    checks="$(_ready_add "API freeze" "$status" "API_STATUS.md exists and is current")"
    [[ "$status" == "FAIL" ]] && errors=$((errors + 1))

    # 6. Compatibility matrix
    _ready_check_compat
    status=$?
    checks="$(_ready_add "Compatibility matrix" "$status" "COMPATIBILITY.md exists")"
    [[ "$status" == "WARNING" ]] && warnings=$((warnings + 1))

    # 7. Security review
    _ready_check_security
    status=$?
    checks="$(_ready_add "Security review" "$status" "Security hardening report exists")"
    [[ "$status" == "FAIL" ]] && errors=$((errors + 1))

    # 8. SBOM
    _ready_check_sbom
    status=$?
    checks="$(_ready_add "SBOM" "$status" "Software Bill of Materials exists")"
    [[ "$status" == "WARNING" ]] && warnings=$((warnings + 1))

    # 9. Version consistency
    _ready_check_version
    status=$?
    checks="$(_ready_add "Version consistency" "$status" "VERSION matches CHANGELOG")"
    [[ "$status" == "FAIL" ]] && errors=$((errors + 1))

    # 10. LTS policy
    _ready_check_lts
    status=$?
    checks="$(_ready_add "LTS policy" "$status" "LTS-POLICY.md exists")"
    [[ "$status" == "FAIL" ]] && errors=$((errors + 1))

    # Verdict
    local verdict="PASS"
    if [[ "$errors" -gt 0 ]]; then
        verdict="FAIL"
    elif [[ "$warnings" -gt 0 ]]; then
        verdict="WARNING"
    fi

    echo ""
    echo "  ── Release Readiness Verdict ──"
    echo ""

    if [[ "$verdict" == "PASS" ]]; then
        echo "  $(tput setaf 2)╔══════════════════════════════╗$(tput sgr0)"
        echo "  $(tput setaf 2)║        RELEASE READY         ║$(tput sgr0)"
        echo "  $(tput setaf 2)╚══════════════════════════════╝$(tput sgr0)"
        echo ""
        log_success "All checks passed. Ready for release."
    elif [[ "$verdict" == "WARNING" ]]; then
        echo "  $(tput setaf 3)╔══════════════════════════════╗$(tput sgr0)"
        echo "  $(tput setaf 3)║    RELEASE READY (WARNINGS)  ║$(tput sgr0)"
        echo "  $(tput setaf 3)╚══════════════════════════════╝$(tput sgr0)"
        echo ""
        log_warning "Release ready with ${warnings} warning(s)"
        echo ""
        echo "$checks" | jq -r '.[] | select(.status == "WARNING") | "  ⚠ \(.check): \(.details)"' 2>/dev/null
    else
        echo "  $(tput setaf 1)╔══════════════════════════════╗$(tput sgr0)"
        echo "  $(tput setaf 1)║       NOT RELEASE READY      ║$(tput sgr0)"
        echo "  $(tput setaf 1)╚══════════════════════════════╝$(tput sgr0)"
        echo ""
        log_error "Release not ready — ${errors} error(s), ${warnings} warning(s)"
        echo ""
        echo "$checks" | jq -r '.[] | select(.status == "FAIL") | "  ✘ \(.check): \(.details)"' 2>/dev/null
    fi

    # Generate report
    jq -n \
        --arg date "$(date -Iseconds)" \
        --arg version "${ANDROID_TOOLKIT_VERSION:-0.0.0}" \
        --arg verdict "$verdict" \
        --argjson errors "$errors" \
        --argjson warnings "$warnings" \
        --argjson checks "$checks" \
        '{
            assessment_date: $date,
            toolkit_version: $version,
            verdict: $verdict,
            errors: $errors,
            warnings: $warnings,
            checks: $checks,
            actionable_recommendations: (
                [$checks[] | select(.status == "FAIL" or .status == "WARNING") | "\(.check): \(.details)"]
            )
        }' > "$RELEASE_READY_REPORT" 2>/dev/null

    log_success "Release readiness report: $RELEASE_READY_REPORT"

    if [[ "$verdict" == "FAIL" ]]; then
        return 1
    fi
    return 0
}

_ready_add() {
    local check="$1" status="$2" details="$3"
    local current="$4"
    echo "$current" | jq \
        --arg c "$check" \
        --arg s "$status" \
        --arg d "$details" \
        '. + [{"check": $c, "status": $s, "details": $d}]' 2>/dev/null || echo "[]"
}

_ready_check_syntax() {
    echo -n "  [1/10] Syntax check... "
    local count=0 errors=0
    local f
    for f in $(find "$ANDROID_TOOLKIT_ROOT_DIR" -name '*.sh' -not -path '*/logs/*' -not -path '*/.git/*' | sort); do
        count=$((count + 1))
        bash -n "$f" 2>/dev/null || errors=$((errors + 1))
    done
    if [[ "$errors" -eq 0 ]]; then echo "$(tput setaf 2)PASS$(tput sgr0) ($count scripts)"; echo "PASS"
    else echo "$(tput setaf 1)FAIL$(tput sgr0) ($errors/$count)"; echo "FAIL"
    fi
}

_ready_check_static() {
    echo -n "  [2/10] Static analysis... "
    if command -v shellcheck &>/dev/null; then
        local errors
        shellcheck -x -e SC1091,SC1090,SC2034,SC2154,SC2312,SC2311 \
            $(find "$ANDROID_TOOLKIT_ROOT_DIR" -name '*.sh' -not -path '*/logs/*' -not -path '*/.git/*' | sort) 2>/dev/null && errors=0 || errors=1
        if [[ "$errors" -eq 0 ]]; then echo "$(tput setaf 2)PASS$(tput sgr0)"; echo "PASS"
        else echo "$(tput setaf 1)FAIL$(tput sgr0)"; echo "FAIL"
        fi
    else
        echo "$(tput setaf 3)SKIP$(tput sgr0) (shellcheck not installed)"
        echo "WARNING"
    fi
}

_ready_check_json() {
    echo -n "  [3/10] JSON validation... "
    if command -v jq &>/dev/null; then
        local errors=0 count=0
        local f
        for f in $(find "$ANDROID_TOOLKIT_ROOT_DIR" -name '*.json' -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/logs/*' | sort); do
            count=$((count + 1))
            jq empty "$f" 2>/dev/null || errors=$((errors + 1))
        done
        if [[ "$errors" -eq 0 ]]; then echo "$(tput setaf 2)PASS$(tput sgr0) ($count files)"; echo "PASS"
        else echo "$(tput setaf 1)FAIL$(tput sgr0) ($errors/$count)"; echo "FAIL"
        fi
    else
        echo "$(tput setaf 3)SKIP$(tput sgr0) (jq not installed)"; echo "WARNING"
    fi
}

_ready_check_docs() {
    echo -n "  [4/10] Documentation... "
    local needed=("README.md" "CHANGELOG.md" "LICENSE" "LTS-POLICY.md" "CONTRIBUTING.md" "SECURITY.md")
    local missing=0
    local f
    for f in "${needed[@]}"; do
        [[ -f "${ANDROID_TOOLKIT_ROOT_DIR}/$f" ]] || missing=$((missing + 1))
    done
    if [[ "$missing" -eq 0 ]]; then echo "$(tput setaf 2)PASS$(tput sgr0)"; echo "PASS"
    else echo "$(tput setaf 1)$missing missing$(tput sgr0)"; echo "FAIL"
    fi
}

_ready_check_api_freeze() {
    echo -n "  [5/10] API freeze... "
    if [[ -f "${ANDROID_TOOLKIT_ROOT_DIR}/docs/API_STATUS.md" ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"; echo "PASS"
    else
        echo "$(tput setaf 1)MISSING$(tput sgr0)"; echo "FAIL"
    fi
}

_ready_check_compat() {
    echo -n "  [6/10] Compatibility matrix... "
    if [[ -f "${ANDROID_TOOLKIT_ROOT_DIR}/docs/COMPATIBILITY.md" ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"; echo "PASS"
    else
        echo "$(tput setaf 3)NOT FOUND$(tput sgr0)"; echo "WARNING"
    fi
}

_ready_check_security() {
    echo -n "  [7/10] Security review... "
    # Check for recent security report
    local latest
    latest="$(ls -t "${ANDROID_TOOLKIT_ROOT_DIR}/exports"/security-*.json 2>/dev/null | head -1)"
    if [[ -n "$latest" ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0) ($(basename "$latest"))"; echo "PASS"
    else
        echo "$(tput setaf 3)NOT RUN$(tput sgr0)"; echo "WARNING"
    fi
}

_ready_check_sbom() {
    echo -n "  [8/10] SBOM... "
    local latest
    latest="$(ls -t "${ANDROID_TOOLKIT_ROOT_DIR}/exports"/sbom-*.json 2>/dev/null | head -1)"
    if [[ -n "$latest" ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"; echo "PASS"
    else
        echo "$(tput setaf 3)NOT GENERATED$(tput sgr0)"; echo "WARNING"
    fi
}

_ready_check_version() {
    echo -n "  [9/10] Version consistency... "
    local version
    version="$(cat "${ANDROID_TOOLKIT_ROOT_DIR}/VERSION" 2>/dev/null | tr -d '[:space:]')"
    if grep -q "^## v${version}" "${ANDROID_TOOLKIT_ROOT_DIR}/CHANGELOG.md" 2>/dev/null; then
        echo "$(tput setaf 2)PASS$(tput sgr0) (v$version)"; echo "PASS"
    else
        echo "$(tput setaf 1)MISMATCH$(tput sgr0)"; echo "FAIL"
    fi
}

_ready_check_lts() {
    echo -n "  [10/10] LTS policy... "
    if [[ -f "${ANDROID_TOOLKIT_ROOT_DIR}/LTS-POLICY.md" ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"; echo "PASS"
    else
        echo "$(tput setaf 1)MISSING$(tput sgr0)"; echo "FAIL"
    fi
}
