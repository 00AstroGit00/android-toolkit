#!/data/data/com.termux/files/usr/bin/bash
#
# security_harden.sh — Security Hardening Module (Expanded)
#
# Automatically detects:
#   - unsafe eval
#   - unsafe source
#   - temporary file races
#   - world-writable files
#   - unsafe PATH usage
#   - missing quoting
#   - command injection
#   - weak permissions
#
# Produces:
#   - security score (0-100)
#   - recommended fixes
#   - CWE mapping where applicable
#
# Part of the Android Toolkit.

SECURITY_HARDEN_REPORT="${ANDROID_TOOLKIT_ROOT_DIR}/exports/security-hardening.json"

# CWE mappings
declare -A CWE_MAP
CWE_MAP["unsafe_eval"]="CWE-95"
CWE_MAP["unsafe_source"]="CWE-829"
CWE_MAP["temp_file_race"]="CWE-377"
CWE_MAP["world_writable"]="CWE-732"
CWE_MAP["unsafe_path"]="CWE-426"
CWE_MAP["missing_quoting"]="CWE-88"
CWE_MAP["command_injection"]="CWE-78"
CWE_MAP["weak_permissions"]="CWE-276"
CWE_MAP["insecure_temp"]="CWE-379"

##############################################
# Run expanded security hardening audit.
# Arguments:
#   $1: specific file or directory to scan (optional)
##############################################
security_harden_run() {
    local scan_target="${1:-$ANDROID_TOOLKIT_ROOT_DIR}"

    log_section "Security Hardening Scan"

    mkdir -p "$(dirname "$SECURITY_HARDEN_REPORT")"

    local findings="[]"
    local score=100

    echo ""

    # 1. Unsafe eval
    _harden_check_eval "$scan_target"
    local result=$?
    findings="$(echo "$findings" | jq --argjson r "$(_harden_result_json "unsafe_eval" "$result" "Unsafe eval detected")" '. + [$r]' 2>/dev/null)"
    [[ "$result" -gt 0 ]] && score=$((score - result))

    # 2. Unsafe source
    _harden_check_source "$scan_target"
    result=$?
    findings="$(echo "$findings" | jq --argjson r "$(_harden_result_json "unsafe_source" "$result" "Unsafe source/include detected")" '. + [$r]' 2>/dev/null)"
    [[ "$result" -gt 0 ]] && score=$((score - result))

    # 3. Temp file races
    _harden_check_temp "$scan_target"
    result=$?
    findings="$(echo "$findings" | jq --argjson r "$(_harden_result_json "temp_file_race" "$result" "Insecure temporary file usage")" '. + [$r]' 2>/dev/null)"
    [[ "$result" -gt 0 ]] && score=$((score - result))

    # 4. World-writable files
    _harden_check_permissions "$scan_target"
    result=$?
    findings="$(echo "$findings" | jq --argjson r "$(_harden_result_json "world_writable" "$result" "World-writable files found")" '. + [$r]' 2>/dev/null)"
    [[ "$result" -gt 0 ]] && score=$((score - result * 2))

    # 5. Unsafe PATH
    _harden_check_path "$scan_target"
    result=$?
    findings="$(echo "$findings" | jq --argjson r "$(_harden_result_json "unsafe_path" "$result" "Unsafe PATH usage")" '. + [$r]' 2>/dev/null)"
    [[ "$result" -gt 0 ]] && score=$((score - result))

    # 6. Missing quoting
    _harden_check_quoting "$scan_target"
    result=$?
    findings="$(echo "$findings" | jq --argjson r "$(_harden_result_json "missing_quoting" "$result" "Missing variable quoting")" '. + [$r]' 2>/dev/null)"
    [[ "$result" -gt 0 ]] && score=$((score - result))

    # 7. Command injection
    _harden_check_injection "$scan_target"
    result=$?
    findings="$(echo "$findings" | jq --argjson r "$(_harden_result_json "command_injection" "$result" "Command injection risk")" '. + [$r]' 2>/dev/null)"
    [[ "$result" -gt 0 ]] && score=$((score - result * 2))

    # 8. Weak permissions on key files
    _harden_check_weak_perms "$scan_target"
    result=$?
    findings="$(echo "$findings" | jq --argjson r "$(_harden_result_json "weak_permissions" "$result" "Weak file permissions")" '. + [$r]' 2>/dev/null)"
    [[ "$result" -gt 0 ]] && score=$((score - result))

    # Clamp score
    [[ "$score" -lt 0 ]] && score=0

    # Summary
    echo ""
    echo "  ── Security Hardening Summary ──"
    echo "  Security Score: ${score}/100"
    echo ""

    local severity
    if [[ "$score" -ge 90 ]]; then
        severity="$(tput setaf 2)EXCELLENT$(tput sgr0)"
    elif [[ "$score" -ge 75 ]]; then
        severity="$(tput setaf 2)GOOD$(tput sgr0)"
    elif [[ "$score" -ge 50 ]]; then
        severity="$(tput setaf 3)FAIR$(tput sgr0)"
    else
        severity="$(tput setaf 1)POOR$(tput sgr0)"
    fi
    echo "  Rating: $severity"
    echo ""

    # Generate report
    jq -n \
        --arg date "$(date -Iseconds)" \
        --arg version "${ANDROID_TOOLKIT_VERSION:-0.0.0}" \
        --argjson score "$score" \
        --argjson findings "$findings" \
        '{
            scan_date: $date,
            toolkit_version: $version,
            score: $score,
            max_score: 100,
            rating: (if $score >= 90 then "EXCELLENT" elif $score >= 75 then "GOOD" elif $score >= 50 then "FAIR" else "POOR" end),
            findings: $findings
        }' > "$SECURITY_HARDEN_REPORT" 2>/dev/null

    log_success "Security hardening report: $SECURITY_HARDEN_REPORT"
    log_info "Security score: ${score}/100"

    [[ "$score" -ge 75 ]]
}

##############################################
# Helper: create a finding result JSON.
##############################################
_harden_result_json() {
    local check="$1" count="$2" desc="$3"
    local cwe="${CWE_MAP[$check]:-CWE-unknown}"
    jq -n \
        --arg check "$check" \
        --argjson count "$count" \
        --arg desc "$desc" \
        --arg cwe "$cwe" \
        '{
            check: $check,
            issues: $count,
            description: $desc,
            cwe: $cwe,
            severity: (if $count > 10 then "high" elif $count > 3 then "medium" else "low" end)
        }' 2>/dev/null || echo '{"check":"'$check'","issues":'$count'}'
}

##############################################
# Check 1: Unsafe eval usage.
##############################################
_harden_check_eval() {
    local dir="$1"
    echo -n "  [1/8] Unsafe eval... "
    local count=0
    local f
    for f in $(find "$dir" -name '*.sh' -not -path '*/logs/*' -not -path '*/.git/*' 2>/dev/null); do
        if grep -nP 'eval\s+\$' "$f" 2>/dev/null | grep -qvP 'eval\s+\$\{?[A-Z_]+' 2>/dev/null; then
            count=$((count + 1))
        fi
    done
    if [[ "$count" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"
    else
        echo "$(tput setaf 1)$count issue(s)$(tput sgr0)"
    fi
    echo "$count"
}

##############################################
# Check 2: Unsafe source/include.
##############################################
_harden_check_source() {
    local dir="$1"
    echo -n "  [2/8] Unsafe source/include... "
    local count=0
    local f
    for f in $(find "$dir" -name '*.sh' -not -path '*/logs/*' -not -path '*/.git/*' 2>/dev/null); do
        if grep -nP 'source\s+\$' "$f" 2>/dev/null | grep -qvP 'source\s+\$\{?ANDROID_TOOLKIT' 2>/dev/null; then
            count=$((count + 1))
        fi
    done
    if [[ "$count" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"
    else
        echo "$(tput setaf 1)$count issue(s)$(tput sgr0)"
    fi
    echo "$count"
}

##############################################
# Check 3: Insecure temporary file usage.
##############################################
_harden_check_temp() {
    local dir="$1"
    echo -n "  [3/8] Temp file security... "
    local count=0
    local f
    for f in $(find "$dir" -name '*.sh' -not -path '*/logs/*' -not -path '*/.git/*' 2>/dev/null); do
        if grep -nP 'mktemp\s+' "$f" 2>/dev/null | grep -vP 'XXXX' 2>/dev/null | grep -qP '.'; then
            count=$((count + 1))
        fi
        # Check for direct /tmp/ usage
        if grep -nP '>/tmp/' "$f" 2>/dev/null | grep -qP '.'; then
            count=$((count + 1))
        fi
    done
    if [[ "$count" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"
    else
        echo "$(tput setaf 3)$count note(s)$(tput sgr0)"
    fi
    echo "$count"
}

##############################################
# Check 4: World-writable files.
##############################################
_harden_check_permissions() {
    local dir="$1"
    echo -n "  [4/8] World-writable files... "
    local count=0
    local f
    for f in $(find "$dir" -type f -perm -o=w -not -path '*/logs/*' -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null); do
        count=$((count + 1))
    done
    if [[ "$count" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"
    else
        echo "$(tput setaf 1)$count file(s)$(tput sgr0)"
    fi
    echo "$count"
}

##############################################
# Check 5: Unsafe PATH usage.
##############################################
_harden_check_path() {
    local dir="$1"
    echo -n "  [5/8] PATH safety... "
    local count=0
    local f
    for f in $(find "$dir" -name '*.sh' -not -path '*/logs/*' -not -path '*/.git/*' 2>/dev/null); do
        if grep -nP 'PATH=.*:' "$f" 2>/dev/null | grep -qvP '(export PATH|\$PATH|/bin|/usr/bin)' 2>/dev/null; then
            count=$((count + 1))
        fi
    done
    if [[ "$count" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"
    else
        echo "$(tput setaf 3)$count note(s)$(tput sgr0)"
    fi
    echo "$count"
}

##############################################
# Check 6: Missing variable quoting.
##############################################
_harden_check_quoting() {
    local dir="$1"
    echo -n "  [6/8] Variable quoting... "
    local count=0
    local f
    for f in $(find "$dir" -name '*.sh' -not -path '*/logs/*' -not -path '*/.git/*' 2>/dev/null); do
        # Check for unquoted variables in test brackets
        while IFS= read -r line; do
            if echo "$line" | grep -qP '\[\[.*[^"'"'"'\$].*\$[A-Z_]+.*\]\]' 2>/dev/null; then
                count=$((count + 1))
            fi
        done < "$f"
    done
    if [[ "$count" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"
    else
        echo "$(tput setaf 3)$count note(s)$(tput sgr0)"
    fi
    echo "$count"
}

##############################################
# Check 7: Command injection.
##############################################
_harden_check_injection() {
    local dir="$1"
    echo -n "  [7/8] Command injection... "
    local count=0
    local f
    for f in $(find "$dir" -name '*.sh' -not -path '*/logs/*' -not -path '*/.git/*' 2>/dev/null); do
        # Check for adb shell with unquoted variables
        while IFS= read -r line; do
            if echo "$line" | grep -qP 'adb\s+shell\s+.*\$' 2>/dev/null; then
                if ! echo "$line" | grep -qP '\".*\$.*\"' 2>/dev/null; then
                    count=$((count + 1))
                fi
            fi
        done < "$f"
    done
    if [[ "$count" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"
    else
        echo "$(tput setaf 1)$count issue(s)$(tput sgr0)"
    fi
    echo "$count"
}

##############################################
# Check 8: Weak permissions on key files.
##############################################
_harden_check_weak_perms() {
    local dir="$1"
    echo -n "  [8/8] Key file permissions... "
    local count=0
    local key_files=("toolkit.sh" "VERSION" "lib/settings-db.json")
    local f
    for f in "${key_files[@]}"; do
        local full="$dir/$f"
        if [[ -f "$full" ]]; then
            local perms
            perms="$(stat -c "%a" "$full" 2>/dev/null || stat -f "%Lp" "$full" 2>/dev/null || echo "644")"
            if [[ "$perms" != "644" && "$perms" != "600" && "$perms" != "640" ]]; then
                count=$((count + 1))
            fi
        fi
    done
    if [[ "$count" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"
    else
        echo "$(tput setaf 1)$count issue(s)$(tput sgr0)"
    fi
    echo "$count"
}
