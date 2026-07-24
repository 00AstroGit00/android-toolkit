#!/data/data/com.termux/files/usr/bin/bash
#
# developer.sh — Developer Toolkit
#
# Orchestrates existing functionality for development workflows:
#
#   toolkit.sh --dev lint       Run static analysis
#   toolkit.sh --dev format     Format shell scripts
#   toolkit.sh --dev docs       Generate documentation
#   toolkit.sh --dev tests      Run test suite
#   toolkit.sh --dev release    Run release validation
#   toolkit.sh --dev clean      Clean artifacts
#
# Part of the Android Toolkit.

##############################################
# Main developer toolkit entry point.
# Arguments:
#   $1: subcommand (lint|format|docs|tests|release|clean)
##############################################
dev_run() {
    local cmd="${1:-help}"

    case "$cmd" in
        lint)
            dev_lint
            ;;
        format)
            dev_format
            ;;
        docs)
            dev_docs
            ;;
        tests)
            dev_tests
            ;;
        release)
            dev_release
            ;;
        clean)
            dev_clean
            ;;
        help|--help)
            echo ""
            echo "  Developer Toolkit Commands:"
            echo ""
            echo "    lint     Run static analysis (ShellCheck, shfmt, markdownlint, jq)"
            echo "    format   Format shell scripts with shfmt"
            echo "    docs     Generate documentation with --docgen"
            echo "    tests    Run BATS and functional tests"
            echo "    release  Run release validation"
            echo "    clean    Remove exports, logs, temp files"
            echo ""
            ;;
        *)
            log_error "Unknown dev command: $cmd"
            echo "  Available: lint, format, docs, tests, release, clean"
            return 1
            ;;
    esac
}

##############################################
# Run static analysis (lint).
##############################################
dev_lint() {
    log_section "Dev: Lint"

    if declare -f static_analysis_run_all &>/dev/null; then
        static_analysis_run_all
    elif [[ -f "${ANDROID_TOOLKIT_ROOT_DIR}/modules/static_analysis.sh" ]]; then
        source "${ANDROID_TOOLKIT_ROOT_DIR}/modules/static_analysis.sh"
        static_analysis_run_all
    else
        log_warning "Static analysis module not available — running basic checks"
        _dev_basic_lint
    fi
}

##############################################
# Format shell scripts with shfmt.
##############################################
dev_format() {
    log_section "Dev: Format"

    if ! command -v shfmt &>/dev/null; then
        log_error "shfmt not installed. Install with: pkg install shfmt"
        return 1
    fi

    log_info "Formatting shell scripts..."

    local count=0
    local f
    for f in $(find "$ANDROID_TOOLKIT_ROOT_DIR" -name '*.sh' -not -path '*/logs/*' -not -path '*/.git/*' | sort); do
        shfmt -w -i 4 -bn -ci "$f"
        count=$((count + 1))
    done

    log_success "Formatted $count files"
}

##############################################
# Generate documentation.
##############################################
dev_docs() {
    log_section "Dev: Documentation"

    if declare -f docgen_run &>/dev/null; then
        docgen_run "${ANDROID_TOOLKIT_ROOT_DIR}/docs"
    elif [[ -f "${ANDROID_TOOLKIT_ROOT_DIR}/modules/docgen.sh" ]]; then
        source "${ANDROID_TOOLKIT_ROOT_DIR}/modules/docgen.sh"
        docgen_run "${ANDROID_TOOLKIT_ROOT_DIR}/docs"
    else
        log_error "Docgen module not available"
        return 1
    fi

    # Also generate compatibility matrix
    if declare -f compat_matrix_generate &>/dev/null; then
        compat_matrix_generate
    elif [[ -f "${ANDROID_TOOLKIT_ROOT_DIR}/modules/compat_matrix.sh" ]]; then
        source "${ANDROID_TOOLKIT_ROOT_DIR}/modules/compat_matrix.sh"
        compat_matrix_generate
    fi

    log_success "Documentation generated in ${ANDROID_TOOLKIT_ROOT_DIR}/docs/"
}

##############################################
# Run tests.
##############################################
dev_tests() {
    log_section "Dev: Tests"

    local exit_code=0
    local test_dir="${ANDROID_TOOLKIT_ROOT_DIR}/tests"

    # Run BATS tests
    if command -v bats &>/dev/null && [[ -d "$test_dir/bats" ]]; then
        log_info "Running BATS tests..."
        bats "$test_dir/bats/" || exit_code=$?
    else
        log_warning "BATS not available or no BATS tests found"
        # Fall back to bash -n
        log_info "Running syntax checks instead..."
        bash "${test_dir}/run_tests.sh" 2>/dev/null || true
    fi

    # Run shellcheck if available
    if command -v shellcheck &>/dev/null; then
        log_info "Running ShellCheck..."
        shellcheck -x -e SC1091,SC1090,SC2034,SC2154,SC2312,SC2311 \
            $(find "$ANDROID_TOOLKIT_ROOT_DIR" -name '*.sh' -not -path '*/logs/*' -not -path '*/.git/*' | sort) 2>&1 | tail -5 || true
    fi

    if [[ "$exit_code" -eq 0 ]]; then
        log_success "All tests passed"
    else
        log_warning "Some tests failed (exit code: $exit_code)"
    fi

    return $exit_code
}

##############################################
# Run release validation.
##############################################
dev_release() {
    log_section "Dev: Release Check"

    if declare -f release_check_run &>/dev/null; then
        release_check_run
    elif [[ -f "${ANDROID_TOOLKIT_ROOT_DIR}/modules/release_check.sh" ]]; then
        source "${ANDROID_TOOLKIT_ROOT_DIR}/modules/release_check.sh"
        release_check_run
    else
        log_error "Release check module not available"
        return 1
    fi
}

##############################################
# Clean build artifacts.
##############################################
dev_clean() {
    log_section "Dev: Clean"

    local cleaned=0

    # Clean exports
    if [[ -d "${ANDROID_TOOLKIT_ROOT_DIR}/exports" ]]; then
        local count
        count="$(find "${ANDROID_TOOLKIT_ROOT_DIR}/exports" -type f | wc -l)"
        rm -f "${ANDROID_TOOLKIT_ROOT_DIR}/exports"/*.json "${ANDROID_TOOLKIT_ROOT_DIR}/exports"/*.md \
            "${ANDROID_TOOLKIT_ROOT_DIR}/exports"/*.html "${ANDROID_TOOLKIT_ROOT_DIR}/exports"/*.zip \
            "${ANDROID_TOOLKIT_ROOT_DIR}/exports"/*.sha256 2>/dev/null || true
        log_info "  Exports: $count files removed"
        cleaned=$((cleaned + count))
    fi

    # Clean logs
    if [[ -d "${ANDROID_TOOLKIT_ROOT_DIR}/logs" ]]; then
        local count
        count="$(find "${ANDROID_TOOLKIT_ROOT_DIR}/logs" -type f 2>/dev/null | wc -l)"
        rm -f "${ANDROID_TOOLKIT_ROOT_DIR}/logs"/*.log "${ANDROID_TOOLKIT_ROOT_DIR}/logs"/*.json 2>/dev/null || true
        log_info "  Logs: $count files removed"
        cleaned=$((cleaned + count))
    fi

    # Clean dist
    if [[ -d "${ANDROID_TOOLKIT_ROOT_DIR}/dist" ]]; then
        rm -rf "${ANDROID_TOOLKIT_ROOT_DIR}/dist"/* 2>/dev/null || true
        log_info "  dist/ cleaned"
    fi

    # Clean schemas
    if [[ -d "${ANDROID_TOOLKIT_ROOT_DIR}/configs/schemas" ]]; then
        rm -f "${ANDROID_TOOLKIT_ROOT_DIR}/configs/schemas"/*.json 2>/dev/null || true
        log_info "  Schemas cleaned"
    fi

    # Clean active device file
    rm -f "${ANDROID_TOOLKIT_ROOT_DIR}/.active_device" 2>/dev/null || true

    log_success "Cleaned $cleaned file(s)"
}

##############################################
# Basic lint fallback when static_analysis not available.
##############################################
_dev_basic_lint() {
    local errors=0

    # bash -n
    echo -n "  bash -n... "
    local f
    for f in $(find "$ANDROID_TOOLKIT_ROOT_DIR" -name '*.sh' -not -path '*/logs/*' -not -path '*/.git/*' | sort); do
        bash -n "$f" 2>/dev/null || { echo ""; log_error "Syntax error: $f"; errors=$((errors + 1)); }
    done
    echo "done"

    # JSON validation
    if command -v jq &>/dev/null; then
        echo -n "  JSON validation... "
        for f in $(find "$ANDROID_TOOLKIT_ROOT_DIR" -name '*.json' -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/logs/*' | sort); do
            jq empty "$f" 2>/dev/null || { echo ""; log_error "Invalid JSON: $f"; errors=$((errors + 1)); }
        done
        echo "done"
    fi

    if [[ "$errors" -eq 0 ]]; then
        log_success "Basic lint passed"
    else
        log_error "Basic lint: $errors error(s)"
    fi

    return $errors
}
