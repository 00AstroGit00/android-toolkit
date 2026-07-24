#!/data/data/com.termux/files/usr/bin/bash
#
# security_review.sh — Final Security Review
#
# Audits the entire codebase for:
#   - Unsafe shell expansion
#   - Command injection risks
#   - Insecure temporary files
#   - Missing input validation
#   - Privilege assumptions
#   - Race conditions
#   - Rollback integrity
#
# Part of the Android Toolkit.

SECURITY_FINDINGS=()
SECURITY_ERRORS=0
SECURITY_WARNINGS=0
SECURITY_REPORT=""

##############################################
# Run full security audit.
# Arguments:
#   $1: output report file (optional)
##############################################
security_review_run() {
    local output_file="${1:-${ANDROID_TOOLKIT_ROOT_DIR}/exports/security-review-${ANDROID_TOOLKIT_VERSION:-0.0.0}.json}"

    log_section "Final Security Review"

    mkdir -p "$(dirname "$output_file")"

    echo ""
    _security_check_shell_expansion
    _security_check_command_injection
    _security_check_temp_files
    _security_check_input_validation
    _security_check_privilege
    _security_check_race_conditions
    _security_check_rollback_integrity

    # Summary
    echo ""
    echo "  ── Security Review Summary ──"
    echo "  Errors:   $SECURITY_ERRORS"
    echo "  Warnings: $SECURITY_WARNINGS"
    echo "  Findings: ${#SECURITY_FINDINGS[@]}"
    echo ""

    if [[ "$SECURITY_ERRORS" -gt 0 ]]; then
        log_error "Security review FAILED — ${SECURITY_ERRORS} error(s), ${SECURITY_WARNINGS} warning(s)"
    elif [[ "$SECURITY_WARNINGS" -gt 0 ]]; then
        log_warning "Security review PASSED with ${SECURITY_WARNINGS} warning(s)"
    else
        log_success "Security review PASSED"
    fi

    # Generate JSON report
    if command -v jq &>/dev/null; then
        local findings_json="[]"
        local finding
        for finding in "${SECURITY_FINDINGS[@]}"; do
            local severity file line message
            severity="$(echo "$finding" | cut -d: -f1)"
            file="$(echo "$finding" | cut -d: -f2)"
            line="$(echo "$finding" | cut -d: -f3)"
            message="$(echo "$finding" | cut -d: -f4-)"

            findings_json="$(echo "$findings_json" | jq \
                --arg sev "$severity" \
                --arg file "$file" \
                --arg line "$line" \
                --arg msg "$message" \
                '. + [{"severity": $sev, "file": $file, "line": $line, "message": $msg}]' 2>/dev/null)"
        done

        jq -n \
            --arg date "$(date -Iseconds)" \
            --arg version "${ANDROID_TOOLKIT_VERSION:-0.0.0}" \
            --argjson errors "$SECURITY_ERRORS" \
            --argjson warnings "$SECURITY_WARNINGS" \
            --argjson findings "$findings_json" \
            '{
                review: "final-security-review",
                date: $date,
                version: $version,
                errors: $errors,
                warnings: $warnings,
                findings: $findings,
                verdict: (if $errors > 0 then "FAIL" elif $warnings > 0 then "PASS_WITH_WARNINGS" else "PASS" end)
            }' > "$output_file" 2>/dev/null

        log_success "Security report: $output_file"
    fi

    return $SECURITY_ERRORS
}

##############################################
# Check 1: Unsafe shell expansion
##############################################
_security_check_shell_expansion() {
    echo -n "  [1/7] Unsafe shell expansion... "
    local errors=0
    local findings=""

    # Check for unquoted variables in risky contexts
    local files
    files="$(find "$ANDROID_TOOLKIT_ROOT_DIR" -name '*.sh' -not -path '*/logs/*' -not -path '*/.git/*' 2>/dev/null)"

    local file
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        local line_num=0
        while IFS= read -r line; do
            line_num=$((line_num + 1))
            # Check eval with user-controlled variables
            if echo "$line" | grep -qP 'eval\s+\$' 2>/dev/null; then
                local rel_path="${file#$ANDROID_TOOLKIT_ROOT_DIR/}"
                findings="${findings}ERROR:$rel_path:$line_num:eval with potentially unquoted variable"
                errors=$((errors + 1))
            fi
        done < "$file"
    done <<< "$files"

    if [[ "$errors" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"
    else
        echo "$(tput setaf 1)$errors issue(s)$(tput sgr0)"
        SECURITY_ERRORS=$((SECURITY_ERRORS + errors))
        _security_add_findings "$findings"
    fi
}

##############################################
# Check 2: Command injection risks
##############################################
_security_check_command_injection() {
    echo -n "  [2/7] Command injection risks... "
    local errors=0
    local findings=""

    local files
    files="$(find "$ANDROID_TOOLKIT_ROOT_DIR" -name '*.sh' -not -path '*/logs/*' -not -path '*/.git/*' 2>/dev/null)"

    local file
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        local line_num=0
        while IFS= read -r line; do
            line_num=$((line_num + 1))
            # Check backtick execution with variable interpolation
            if echo "$line" | grep -qP '`.*\$' 2>/dev/null; then
                local rel_path="${file#$ANDROID_TOOLKIT_ROOT_DIR/}"
                # Only flag if it's not a known safe pattern
                if ! echo "$line" | grep -qP '(date|basename|dirname|echo|printf)' 2>/dev/null; then
                    findings="${findings}WARNING:$rel_path:$line_num:backtick execution with variable interpolation"
                    errors=$((errors + 1))
                fi
            fi
            # Check eval with variable interpolation
            if echo "$line" | grep -qP 'eval\s+"?\$' 2>/dev/null; then
                local rel_path="${file#$ANDROID_TOOLKIT_ROOT_DIR/}"
                findings="${findings}WARNING:$rel_path:$line_num:eval with variable interpolation"
                errors=$((errors + 1))
            fi
        done < "$file"
    done <<< "$files"

    if [[ "$errors" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"
    else
        echo "$(tput setaf 3)$errors issue(s)$(tput sgr0)"
        SECURITY_WARNINGS=$((SECURITY_WARNINGS + errors))
        _security_add_findings "$findings"
    fi
}

##############################################
# Check 3: Insecure temporary files
##############################################
_security_check_temp_files() {
    echo -n "  [3/7] Insecure temporary files... "
    local errors=0
    local findings=""

    local files
    files="$(find "$ANDROID_TOOLKIT_ROOT_DIR" -name '*.sh' -not -path '*/logs/*' -not -path '*/.git/*' 2>/dev/null)"

    local file
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        local line_num=0
        while IFS= read -r line; do
            line_num=$((line_num + 1))
            # Check for mktemp without XXXX pattern
            if echo "$line" | grep -qP 'mktemp\s+.*(?!XXXXXX)' 2>/dev/null; then
                if ! echo "$line" | grep -qP 'XXXX' 2>/dev/null; then
                    local rel_path="${file#$ANDROID_TOOLKIT_ROOT_DIR/}"
                    findings="${findings}WARNING:$rel_path:$line_num:mktemp without XXXXXX pattern"
                    errors=$((errors + 1))
                fi
            fi
            # Check for predictable temp file paths
            if echo "$line" | grep -qP '/tmp/[a-zA-Z]+\.[a-zA-Z]+' 2>/dev/null; then
                local rel_path="${file#$ANDROID_TOOLKIT_ROOT_DIR/}"
                findings="${findings}WARNING:$rel_path:$line_num:predictable temp file path"
                errors=$((errors + 1))
            fi
        done < "$file"
    done <<< "$files"

    if [[ "$errors" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"
    else
        echo "$(tput setaf 3)$errors issue(s)$(tput sgr0)"
        SECURITY_WARNINGS=$((SECURITY_WARNINGS + errors))
        _security_add_findings "$findings"
    fi
}

##############################################
# Check 4: Missing input validation
##############################################
_security_check_input_validation() {
    echo -n "  [4/7] Missing input validation... "
    local errors=0
    local findings=""

    local files
    files="$(find "$ANDROID_TOOLKIT_ROOT_DIR" -name '*.sh' -not -path '*/logs/*' -not -path '*/.git/*' 2>/dev/null)"

    local file
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        local line_num=0
        while IFS= read -r line; do
            line_num=$((line_num + 1))
            # Check for adb -s with variable directly
            if echo "$line" | grep -qP 'adb\s+-s\s+\$' 2>/dev/null; then
                local rel_path="${file#$ANDROID_TOOLKIT_ROOT_DIR/}"
                findings="${findings}WARNING:$rel_path:$line_num:adb -s with variable (ensure serial is validated)"
                errors=$((errors + 1))
            fi
            # Check for settings put with variable
            if echo "$line" | grep -qP '(settings put|device_config put)\s+(global|secure|system)\s+\$\S+' 2>/dev/null; then
                local rel_path="${file#$ANDROID_TOOLKIT_ROOT_DIR/}"
                findings="${findings}INFO:$rel_path:$line_num:settings put with variable (validate key before use)"
                errors=$((errors + 1))
            fi
        done < "$file"
    done <<< "$files"

    if [[ "$errors" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"
    else
        echo "$(tput setaf 3)$errors issue(s)$(tput sgr0)"
        SECURITY_WARNINGS=$((SECURITY_WARNINGS + errors))
        _security_add_findings "$findings"
    fi
}

##############################################
# Check 5: Privilege assumptions
##############################################
_security_check_privilege() {
    echo -n "  [5/7] Privilege assumptions... "
    local errors=0
    local findings=""

    local files
    files="$(find "$ANDROID_TOOLKIT_ROOT_DIR" -name '*.sh' -not -path '*/logs/*' -not -path '*/.git/*' 2>/dev/null)"

    local file
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        local line_num=0
        while IFS= read -r line; do
            line_num=$((line_num + 1))
            # Check for sudo usage
            if echo "$line" | grep -qP '\bsudo\b' 2>/dev/null; then
                local rel_path="${file#$ANDROID_TOOLKIT_ROOT_DIR/}"
                findings="${findings}INFO:$rel_path:$line_num:sudo usage (toolkit should not require root)"
                errors=$((errors + 1))
            fi
            # Check for fixed paths that assume root
            if echo "$line" | grep -qP '/data/local/tmp/[^)]+' 2>/dev/null; then
                local rel_path="${file#$ANDROID_TOOLKIT_ROOT_DIR/}"
                # This is a known Shizuku path, just note it
                findings="${findings}INFO:$rel_path:$line_num:assumes /data/local/tmp accessibility"
                errors=$((errors + 1))
            fi
        done < "$file"
    done <<< "$files"

    if [[ "$errors" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"
    else
        echo "$(tput setaf 3)$errors note(s)$(tput sgr0)"
        SECURITY_WARNINGS=$((SECURITY_WARNINGS + errors))
        _security_add_findings "$findings"
    fi
}

##############################################
# Check 6: Race conditions
##############################################
_security_check_race_conditions() {
    echo -n "  [6/7] Race conditions... "
    local errors=0
    local findings=""

    local files
    files="$(find "$ANDROID_TOOLKIT_ROOT_DIR" -name '*.sh' -not -path '*/logs/*' -not -path '*/.git/*' 2>/dev/null)"

    local file
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        local line_num=0
        while IFS= read -r line; do
            line_num=$((line_num + 1))
            # Check for TOCTOU: test -f followed by source/read
            if echo "$line" | grep -qP '\[\[ -f .* \]\].*\n.*(source|cat|\. )' 2>/dev/null; then
                local rel_path="${file#$ANDROID_TOOLKIT_ROOT_DIR/}"
                findings="${findings}INFO:$rel_path:$line_num:possible TOCTOU (file check then use)"
                errors=$((errors + 1))
            fi
        done < "$file"
    done <<< "$files"

    if [[ "$errors" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"
    else
        echo "$(tput setaf 3)$errors note(s)$(tput sgr0)"
        SECURITY_WARNINGS=$((SECURITY_WARNINGS + errors))
        _security_add_findings "$findings"
    fi
}

##############################################
# Check 7: Rollback integrity
##############################################
_security_check_rollback_integrity() {
    echo -n "  [7/7] Rollback integrity... "
    local errors=0
    local findings=""

    local rollback_file="${ANDROID_TOOLKIT_ROOT_DIR}/lib/rollback.sh"

    if [[ -f "$rollback_file" ]]; then
        # Check that rollback uses atomic operations
        if grep -q 'mv .*\.tmp' "$rollback_file" 2>/dev/null; then
            : # Good — uses atomic moves
        else
            findings="${findings}WARNING:$rollback_file:0:rollback may not use atomic file operations"
            errors=$((errors + 1))
        fi

        # Check that rollback records old values
        if grep -q 'rollback_record' "$rollback_file" 2>/dev/null; then
            : # Good — records rollback data
        else
            findings="${findings}ERROR:$rollback_file:0:rollback missing record function"
            errors=$((errors + 1))
        fi
    fi

    if [[ "$errors" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"
    else
        echo "$(tput setaf 3)$errors issue(s)$(tput sgr0)"
        SECURITY_WARNINGS=$((SECURITY_WARNINGS + errors))
        _security_add_findings "$findings"
    fi
}

##############################################
# Add findings from multiline string.
##############################################
_security_add_findings() {
    local findings="$1"
    while IFS= read -r finding; do
        [[ -z "$finding" ]] && continue
        SECURITY_FINDINGS+=("$finding")
    done <<< "$findings"
}
