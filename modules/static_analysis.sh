#!/data/data/com.termux/files/usr/bin/bash
#
# static_analysis.sh — Static Analysis Tools Integration
#
# Runs all static analysis checks:
#   - ShellCheck
#   - shfmt (format check)
#   - markdownlint
#   - jq JSON validation
#   - JSON schema validation
#
# Part of the Android Toolkit.

STATIC_ANALYSIS_ERRORS=0
STATIC_ANALYSIS_WARNINGS=0

##############################################
# Run all static analysis checks.
# Returns: 0 if all pass
##############################################
static_analysis_run_all() {
    log_section "Static Analysis"

    static_analysis_shellcheck
    static_analysis_shfmt
    static_analysis_markdownlint
    static_analysis_json_validate
    static_analysis_json_schema

    echo ""
    if [[ "$STATIC_ANALYSIS_ERRORS" -gt 0 ]]; then
        log_error "Static analysis: ${STATIC_ANALYSIS_ERRORS} error(s), ${STATIC_ANALYSIS_WARNINGS} warning(s)"
        return 1
    elif [[ "$STATIC_ANALYSIS_WARNINGS" -gt 0 ]]; then
        log_warning "Static analysis: ${STATIC_ANALYSIS_WARNINGS} warning(s)"
        return 0
    else
        log_success "Static analysis: all checks passed"
        return 0
    fi
}

##############################################
# Run ShellCheck on all shell scripts.
##############################################
static_analysis_shellcheck() {
    echo ""
    echo -n "  [1/5] ShellCheck... "

    if ! command -v shellcheck &>/dev/null; then
        echo "$(tput setaf 3)SKIP$(tput sgr0) (not installed)"
        STATIC_ANALYSIS_WARNINGS=$((STATIC_ANALYSIS_WARNINGS + 1))
        return
    fi

    local errors=0
    local output
    output="$(shellcheck -x -e SC1091,SC1090,SC2034,SC2154,SC2312,SC2311 \
        $(find "$ANDROID_TOOLKIT_ROOT_DIR" -name '*.sh' -not -path '*/logs/*' -not -path '*/.git/*' | sort) 2>&1)" || errors=1

    if [[ "$errors" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"
    else
        local count
        count="$(echo "$output" | grep -c "^In " 2>/dev/null || echo "1")"
        echo "$(tput setaf 1)FAIL$(tput sgr0) ($count issues)"
        echo "$output" | head -20
        STATIC_ANALYSIS_ERRORS=$((STATIC_ANALYSIS_ERRORS + count))
    fi
}

##############################################
# Run shfmt formatting check.
##############################################
static_analysis_shfmt() {
    echo -n "  [2/5] shfmt formatting... "

    if ! command -v shfmt &>/dev/null; then
        echo "$(tput setaf 3)SKIP$(tput sgr0) (not installed)"
        STATIC_ANALYSIS_WARNINGS=$((STATIC_ANALYSIS_WARNINGS + 1))
        return
    fi

    local errors=0
    local output
    output="$(shfmt -d -i 4 -bn -ci \
        $(find "$ANDROID_TOOLKIT_ROOT_DIR" -name '*.sh' -not -path '*/logs/*' -not -path '*/.git/*' | sort) 2>&1)" || errors=1

    if [[ "$errors" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"
    else
        local count
        count="$(echo "$output" | grep -c "^--- " 2>/dev/null || echo "1")"
        echo "$(tput setaf 1)FAIL$(tput sgr0) ($count files need formatting)"
        STATIC_ANALYSIS_ERRORS=$((STATIC_ANALYSIS_ERRORS + count))
    fi
}

##############################################
# Run markdownlint on all markdown files.
##############################################
static_analysis_markdownlint() {
    echo -n "  [3/5] markdownlint... "

    if ! command -v markdownlint &>/dev/null; then
        echo "$(tput setaf 3)SKIP$(tput sgr0) (not installed)"
        STATIC_ANALYSIS_WARNINGS=$((STATIC_ANALYSIS_WARNINGS + 1))
        return
    fi

    local errors=0
    local output
    output="$(markdownlint "$ANDROID_TOOLKIT_ROOT_DIR"/*.md "$ANDROID_TOOLKIT_ROOT_DIR"/docs/*.md \
        "$ANDROID_TOOLKIT_ROOT_DIR"/docs/guides/*.md 2>/dev/null)" || errors=1

    if [[ "$errors" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"
    else
        local count
        count="$(echo "$output" | grep -c ":" 2>/dev/null || echo "1")"
        echo "$(tput setaf 3)$count issues$(tput sgr0) (warnings only)"
        STATIC_ANALYSIS_WARNINGS=$((STATIC_ANALYSIS_WARNINGS + count))
    fi
}

##############################################
# Validate all JSON files with jq.
##############################################
static_analysis_json_validate() {
    echo -n "  [4/5] JSON validation... "

    if ! command -v jq &>/dev/null; then
        echo "$(tput setaf 3)SKIP$(tput sgr0) (not installed)"
        STATIC_ANALYSIS_WARNINGS=$((STATIC_ANALYSIS_WARNINGS + 1))
        return
    fi

    local errors=0 count=0
    local f
    for f in $(find "$ANDROID_TOOLKIT_ROOT_DIR" -name '*.json' -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/logs/*' | sort); do
        count=$((count + 1))
        if ! jq empty "$f" 2>/dev/null; then
            log_error "  Invalid JSON: $f"
            errors=$((errors + 1))
        fi
    done

    if [[ "$errors" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0) ($count files)"
    else
        echo "$(tput setaf 1)FAIL$(tput sgr0) ($errors/$count invalid)"
        STATIC_ANALYSIS_ERRORS=$((STATIC_ANALYSIS_ERRORS + errors))
    fi
}

##############################################
# Validate JSON against schemas.
##############################################
static_analysis_json_schema() {
    echo -n "  [5/5] JSON schema validation... "

    if ! declare -f schema_validate_all &>/dev/null; then
        if [[ -f "${ANDROID_TOOLKIT_ROOT_DIR}/lib/json_schema.sh" ]]; then
            source "${ANDROID_TOOLKIT_ROOT_DIR}/lib/json_schema.sh"
        else
            echo "$(tput setaf 3)SKIP$(tput sgr0) (json_schema module not available)"
            STATIC_ANALYSIS_WARNINGS=$((STATIC_ANALYSIS_WARNINGS + 1))
            return
        fi
    fi

    if schema_validate_all 2>/dev/null; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"
    else
        echo "$(tput setaf 1)FAIL$(tput sgr0)"
        STATIC_ANALYSIS_ERRORS=$((STATIC_ANALYSIS_ERRORS + 1))
    fi
}
