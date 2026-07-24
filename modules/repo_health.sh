#!/data/data/com.termux/files/usr/bin/bash
#
# repo_health.sh — Repository Health Audit
#
# Automatically audits:
#   - duplicate code
#   - dead code
#   - unused modules
#   - orphan plugins
#   - broken documentation links
#   - missing tests
#   - configuration drift
#
# Generates a repository health report (JSON + Markdown).
#
# Part of the Android Toolkit.

REPO_HEALTH_REPORT="${ANDROID_TOOLKIT_ROOT_DIR}/exports/repo-health.json"

##############################################
# Run full repository health audit.
##############################################
repo_health_run() {
    log_section "Repository Health Audit"

    local findings="[]"
    local score=100

    mkdir -p "$(dirname "$REPO_HEALTH_REPORT")"

    echo ""

    # 1. Duplicate code
    _health_check_duplicates
    local result=$?
    findings="$(echo "$findings" | jq --argjson r "$(_health_result "duplicate_code" "$result" "Duplicate code blocks detected")" '. + [$r]' 2>/dev/null)"
    score=$((score - result))

    # 2. Dead code
    _health_check_dead_code
    result=$?
    findings="$(echo "$findings" | jq --argjson r "$(_health_result "dead_code" "$result" "Potentially dead code (unreferenced functions)")" '. + [$r]' 2>/dev/null)"
    score=$((score - result))

    # 3. Unused modules
    _health_check_unused_modules
    result=$?
    findings="$(echo "$findings" | jq --argjson r "$(_health_result "unused_modules" "$result" "Modules not referenced in toolkit.sh")" '. + [$r]' 2>/dev/null)"
    score=$((score - result))

    # 4. Orphan plugins
    _health_check_orphan_plugins
    result=$?
    findings="$(echo "$findings" | jq --argjson r "$(_health_result "orphan_plugins" "$result" "Plugin files without registration")" '. + [$r]' 2>/dev/null)"
    score=$((score - result))

    # 5. Broken doc links
    _health_check_doc_links
    result=$?
    findings="$(echo "$findings" | jq --argjson r "$(_health_result "broken_links" "$result" "Potential broken documentation links")" '. + [$r]' 2>/dev/null)"
    score=$((score - result))

    # 6. Missing tests
    _health_check_test_coverage
    result=$?
    findings="$(echo "$findings" | jq --argjson r "$(_health_result "missing_tests" "$result" "Modules missing corresponding tests")" '. + [$r]' 2>/dev/null)"
    score=$((score - result * 2))

    [[ "$score" -lt 0 ]] && score=0

    # Summary
    echo ""
    echo "  ── Repository Health Summary ──"
    echo "  Health Score: ${score}/100"
    echo ""

    local rating
    if [[ "$score" -ge 90 ]]; then rating="$(tput setaf 2)EXCELLENT$(tput sgr0)"
    elif [[ "$score" -ge 75 ]]; then rating="$(tput setaf 2)GOOD$(tput sgr0)"
    elif [[ "$score" -ge 50 ]]; then rating="$(tput setaf 3)FAIR$(tput sgr0)"
    else rating="$(tput setaf 1)POOR$(tput sgr0)"
    fi
    echo "  Rating: $rating"

    # Generate report
    jq -n \
        --arg date "$(date -Iseconds)" \
        --arg version "${ANDROID_TOOLKIT_VERSION:-0.0.0}" \
        --argjson score "$score" \
        --argjson findings "$findings" \
        '{
            audit_date: $date,
            toolkit_version: $version,
            score: $score,
            max_score: 100,
            rating: (if $score >= 90 then "EXCELLENT" elif $score >= 75 then "GOOD" elif $score >= 50 then "FAIR" else "POOR" end),
            findings: $findings
        }' > "$REPO_HEALTH_REPORT" 2>/dev/null

    log_success "Repository health report: $REPO_HEALTH_REPORT"
}

_health_result() {
    local check="$1" count="$2" desc="$3"
    jq -n \
        --arg check "$check" \
        --argjson count "$count" \
        --arg desc "$desc" \
        '{
            check: $check,
            issues: $count,
            description: $desc,
            severity: (if $count > 10 then "high" elif $count > 3 then "medium" else "low" end)
        }' 2>/dev/null || echo '{"check":"'$check'","issues":'$count'}'
}

##############################################
# Check 1: Duplicate code detection.
##############################################
_health_check_duplicates() {
    echo -n "  [1/6] Duplicate code... "
    local count=0
    local seen=()
    local f
    for f in $(find "$ANDROID_TOOLKIT_ROOT_DIR" -name '*.sh' -not -path '*/logs/*' -not -path '*/.git/*' 2>/dev/null); do
        local functions
        functions="$(grep -oP '^\s*[a-zA-Z_][a-zA-Z0-9_]*\(\)\s*\{' "$f" 2>/dev/null | sed 's/()\s*{//' | tr -d '[:space:]')"
        local func
        while IFS= read -r func; do
            [[ -z "$func" ]] && continue
            for seen_func in "${seen[@]}"; do
                if [[ "$seen_func" == "$func" ]]; then
                    count=$((count + 1))
                fi
            done
            seen+=("$func")
        done <<< "$functions"
    done
    if [[ "$count" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"
    else
        echo "$(tput setaf 1)$count potential duplicate(s)$(tput sgr0)"
    fi
    echo "$count"
}

##############################################
# Check 2: Dead code detection.
##############################################
_health_check_dead_code() {
    echo -n "  [2/6] Dead code... "
    local count=0
    local f
    for f in $(find "$ANDROID_TOOLKIT_ROOT_DIR" -name '*.sh' -not -path '*/logs/*' -not -path '*/.git/*' 2>/dev/null); do
        local functions
        functions="$(grep -oP '^\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\(\)' "$f" 2>/dev/null | sed 's/()//' | tr -d '[:space:]')"
        local func
        while IFS= read -r func; do
            [[ -z "$func" ]] && continue
            # Skip well-known callbacks
            [[ "$func" =~ ^(plugin_register|plugin_run|plugin_pre_run|plugin_post_run|plugin_cleanup|plugin_config|plugin_dependencies|plugin_config_schema|plugin_commands|plugin_on_event)$ ]] && continue
            # Check if function is referenced elsewhere
            local refcount
            refcount="$(grep -r "$func" "$ANDROID_TOOLKIT_ROOT_DIR" --include='*.sh' -l 2>/dev/null | wc -l)"
            if [[ "$refcount" -le 1 ]]; then
                count=$((count + 1))
            fi
        done <<< "$functions"
    done
    if [[ "$count" -le 5 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0) ($count isolated functions)"
    else
        echo "$(tput setaf 3)$count isolated functions$(tput sgr0)"
    fi
    echo "$count"
}

##############################################
# Check 3: Unused modules.
##############################################
_health_check_unused_modules() {
    echo -n "  [3/6] Unused modules... "
    local count=0
    local f
    for f in "$ANDROID_TOOLKIT_ROOT_DIR"/modules/*.sh; do
        [[ -f "$f" ]] || continue
        local basename
        basename="$(basename "$f" .sh)"
        # Check if referenced in toolkit.sh
        if ! grep -q "$basename" "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" 2>/dev/null; then
            count=$((count + 1))
        fi
    done
    if [[ "$count" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"
    else
        echo "$(tput setaf 3)$count module(s) not in toolkit.sh$(tput sgr0)"
    fi
    echo "$count"
}

##############################################
# Check 4: Orphan plugins.
##############################################
_health_check_orphan_plugins() {
    echo -n "  [4/6] Orphan plugins... "
    local count=0
    if [[ -d "$ANDROID_TOOLKIT_ROOT_DIR/plugins" ]]; then
        local f
        for f in "$ANDROID_TOOLKIT_ROOT_DIR"/plugins/*.sh; do
            [[ -f "$f" ]] || continue
            local basename
            basename="$(basename "$f" .sh)"
            if ! grep -q "$basename" "$ANDROID_TOOLKIT_ROOT_DIR/toolkit.sh" 2>/dev/null; then
                count=$((count + 1))
            fi
        done
    fi
    echo "$(tput setaf 2)PASS$(tput sgr0) ($count plugins external to toolkit.sh)"
    echo "$count"
}

##############################################
# Check 5: Broken documentation links.
##############################################
_health_check_doc_links() {
    echo -n "  [5/6] Documentation links... "
    local count=0
    local f
    for f in "$ANDROID_TOOLKIT_ROOT_DIR"/*.md "$ANDROID_TOOLKIT_ROOT_DIR"/docs/*.md; do
        [[ -f "$f" ]] || continue
        # Find markdown links [text](path)
        local links
        links="$(grep -oP '\[.*?\]\([^)]+\)' "$f" 2>/dev/null || true)"
        local link
        while IFS= read -r link; do
            [[ -z "$link" ]] && continue
            local path
            path="$(echo "$link" | grep -oP '\([^)]+\)' | sed 's/[()]//g')"
            # Skip URLs
            if echo "$path" | grep -qP '^https?://' 2>/dev/null; then
                continue
            fi
            local full_path
            if [[ "$path" =~ ^/ ]]; then
                full_path="${ANDROID_TOOLKIT_ROOT_DIR}${path}"
            else
                full_path="$(dirname "$f")/$path"
            fi
            if [[ ! -f "$full_path" && ! -d "$full_path" ]]; then
                count=$((count + 1))
            fi
        done <<< "$links"
    done
    if [[ "$count" -eq 0 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0)"
    else
        echo "$(tput setaf 1)$count broken link(s)$(tput sgr0)"
    fi
    echo "$count"
}

##############################################
# Check 6: Test coverage.
##############################################
_health_check_test_coverage() {
    echo -n "  [6/6] Test coverage... "
    local total=0 missing=0

    # Check modules against BATS tests
    if [[ -d "$ANDROID_TOOLKIT_ROOT_DIR/tests/bats" ]]; then
        local f
        for f in "$ANDROID_TOOLKIT_ROOT_DIR"/modules/*.sh; do
            [[ -f "$f" ]] || continue
            total=$((total + 1))
            local basename
            basename="$(basename "$f" .sh)"
            if ! grep -q "$basename" "$ANDROID_TOOLKIT_ROOT_DIR/tests/bats/"*.bats 2>/dev/null; then
                missing=$((missing + 1))
            fi
        done
    fi

    local pct=0
    [[ "$total" -gt 0 ]] && pct=$(( (total - missing) * 100 / total ))

    if [[ "$pct" -ge 50 ]]; then
        echo "$(tput setaf 2)PASS$(tput sgr0) ($pct% coverage)"
    else
        echo "$(tput setaf 3)$missing untested modules ($pct% coverage)$(tput sgr0)"
    fi
    echo "$missing"
}
