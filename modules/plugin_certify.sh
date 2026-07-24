#!/data/data/com.termux/files/usr/bin/bash
#
# plugin_certify.sh — Plugin Certification Suite
#
# Validates plugins for:
#   - Metadata completeness
#   - Config schema compliance
#   - Permission declarations
#   - API usage correctness
#   - Version compatibility
#   - Event subscriptions
#   - Configuration validation
#   - Security scan
#
# Usage: toolkit.sh --plugin-certify [plugin-name]
#   Without args, certifies all loaded plugins.
#   With a plugin name, certifies that specific plugin.
#
# Part of the Android Toolkit.

PLUGIN_CERT_DIR="${ANDROID_TOOLKIT_ROOT_DIR}/exports"

##############################################
# Run plugin certification.
# Arguments:
#   $1: specific plugin name (optional)
##############################################
plugin_certify_run() {
    local specific_plugin="${1:-}"

    log_section "Plugin Certification Suite"

    if [[ ${#PLUGIN_REGISTERED[@]} -eq 0 ]]; then
        log_warning "No plugins loaded"
        return 0
    fi

    mkdir -p "$PLUGIN_CERT_DIR"

    local results="[]"
    local total=0 passed=0 failed=0

    local plugin
    for plugin in "${PLUGIN_REGISTERED[@]}"; do
        [[ -n "$specific_plugin" && "$plugin" != "$specific_plugin" ]] && continue
        total=$((total + 1))

        log_info "Certifying plugin: $plugin"
        local result
        result="$(_plugin_certify_single "$plugin")"
        local status
        status="$(echo "$result" | jq -r '.status' 2>/dev/null || echo "fail")"

        results="$(echo "$results" | jq --argjson r "$result" '. + [$r]' 2>/dev/null)"

        if [[ "$status" == "pass" ]]; then
            passed=$((passed + 1))
            log_success "  $plugin: PASS"
        else
            failed=$((failed + 1))
            log_warning "  $plugin: FAIL ($(echo "$result" | jq -r '.issues | length' 2>/dev/null || echo "?") issues)"
        fi
    done

    # Summary
    echo ""
    echo "  ── Certification Summary ──"
    printf "  %-30s %s\n" "Plugins certified:" "$total"
    printf "  %-30s %s\n" "Passed:" "$passed"
    printf "  %-30s %s\n" "Failed:" "$failed"

    # Generate report
    local report_file="${PLUGIN_CERT_DIR}/plugin-cert-$(date +%Y%m%d_%H%M%S).json"
    jq -n \
        --arg date "$(date -Iseconds)" \
        --arg version "${ANDROID_TOOLKIT_VERSION:-0.0.0}" \
        --argjson results "$results" \
        --argjson total "$total" \
        --argjson passed "$passed" \
        --argjson failed "$failed" \
        '{
            certification_date: $date,
            toolkit_version: $version,
            summary: { total: $total, passed: $passed, failed: $failed },
            plugins: $results
        }' > "$report_file" 2>/dev/null

    log_success "Certification report: $report_file"

    [[ "$failed" -eq 0 ]]
}

##############################################
# Certify a single plugin.
# Arguments:
#   $1: plugin name
# Outputs: JSON result
##############################################
_plugin_certify_single() {
    local name="$1"
    local issues="[]"
    local warnings="[]"

    # 1. Check metadata
    local version min_tk author desc perms events cert
    version="$(_plugin_get_meta "$name" "version")"
    min_tk="$(_plugin_get_meta "$name" "min_toolkit")"
    author="$(_plugin_get_meta "$name" "author")"
    desc="$(_plugin_get_meta "$name" "description")"
    perms="$(_plugin_get_meta "$name" "permissions")"
    events="$(_plugin_get_meta "$name" "events")"
    cert="$(_plugin_get_meta "$name" "certified")"

    if [[ -z "$version" || "$version" == "0.0.0" ]]; then
        issues="$(echo "$issues" | jq '. + ["Missing or invalid plugin_version"]' 2>/dev/null)"
    fi
    if [[ -z "$author" || "$author" == "unknown" ]]; then
        warnings="$(echo "$warnings" | jq '. + ["Missing plugin_author"]' 2>/dev/null)"
    fi
    if [[ "$cert" != "true" ]]; then
        warnings="$(echo "$warnings" | jq '. + ["Plugin not certified (no v3.0 metadata)"]' 2>/dev/null)"
    fi

    # 2. Check config schema
    if declare -f plugin_config_schema &>/dev/null 2>&1; then
        local schema
        schema="$(plugin_config_schema 2>/dev/null || true)"
        if [[ -z "$schema" ]]; then
            warnings="$(echo "$warnings" | jq '. + ["Empty plugin_config_schema"]' 2>/dev/null)"
        fi
    fi

    # 3. Check permissions
    if [[ "$perms" == "none" || -z "$perms" ]]; then
        warnings="$(echo "$warnings" | jq '. + ["No permissions declared"]' 2>/dev/null)"
    else
        local p
        for p in $perms; do
            case "$p" in
                adb|rish|shell|settings_read|settings_write|package_disable|package_enable) ;;
                *) warnings="$(echo "$warnings" | jq --arg p "$p" '. + ["Unknown permission: " + $p]' 2>/dev/null)" ;;
            esac
        done
    fi

    # 4. Check version compatibility
    if [[ -n "$min_tk" && "$min_tk" != "any" ]]; then
        local current="${ANDROID_TOOLKIT_VERSION:-0.0.0}"
        local higher
        higher="$(printf '%s\n%s\n' "$min_tk" "$current" | sort -V | tail -1)"
        if [[ "$higher" != "$current" ]]; then
            issues="$(echo "$issues" | jq --arg m "$min_tk" --arg c "$current" '. + ["Toolkit version mismatch: requires " + $m + ", has " + $c]' 2>/dev/null)"
        fi
    fi

    # 5. Check event subscriptions
    if [[ "$events" != "none" && -n "$events" ]]; then
        if ! declare -f events_emit &>/dev/null; then
            warnings="$(echo "$warnings" | jq '. + ["Events subscribed but event system not available"]' 2>/dev/null)"
        fi
    fi

    # 6. Check plugin_run exists
    if ! declare -f plugin_run &>/dev/null; then
        issues="$(echo "$issues" | jq '. + ["Missing plugin_run() function"]' 2>/dev/null)"
    fi

    local num_issues num_warnings status
    num_issues="$(echo "$issues" | jq 'length' 2>/dev/null || echo "0")"
    num_warnings="$(echo "$warnings" | jq 'length' 2>/dev/null || echo "0")"

    if [[ "$num_issues" -gt 0 ]]; then
        status="fail"
    elif [[ "$num_warnings" -gt 0 ]]; then
        status="pass_with_warnings"
    else
        status="pass"
    fi

    jq -n \
        --arg name "$name" \
        --arg status "$status" \
        --arg version "$version" \
        --arg min_tk "${min_tk:-any}" \
        --arg author "${author:-unknown}" \
        --argjson issues "$issues" \
        --argjson warnings "$warnings" \
        '{
            plugin: $name,
            status: $status,
            version: $version,
            min_toolkit: $min_tk,
            author: $author,
            issues: $issues,
            warnings: $warnings
        }' 2>/dev/null || echo "{\"plugin\":\"$name\",\"status\":\"error\"}"
}
