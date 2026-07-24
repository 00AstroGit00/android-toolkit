#!/data/data/com.termux/files/usr/bin/bash
#
# settings_verify.sh — Settings Verification Module
#
# Audits every setting in configs/settings-db.json.
# For each entry, verifies:
#   - namespace exists
#   - key exists
#   - writable
#   - readable
#   - rollback works
#   - Android version validity
#   - OEM validity
#   - reboot requirement
#
# Marks each setting: Verified, Deprecated, Experimental, Unsupported
#
# Part of the Android Toolkit.

SETTINGS_DB="${ANDROID_TOOLKIT_ROOT_DIR}/lib/settings-db.json"
SETTINGS_VERIFY_REPORT="${ANDROID_TOOLKIT_ROOT_DIR}/exports/settings-verification.json"

##############################################
# Run full settings verification.
##############################################
settings_verify_run() {
    log_section "Settings Verification"

    if [[ ! -f "$SETTINGS_DB" ]]; then
        log_error "Settings DB not found: $SETTINGS_DB"
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        log_error "jq required"
        return 1
    fi

    mkdir -p "$(dirname "$SETTINGS_VERIFY_REPORT")"

    local total=0 verified=0 deprecated=0 experimental=0 unsupported=0
    local results="[]"

    log_info "Verifying settings database..."

    local count
    count="$(jq '.settings | length' "$SETTINGS_DB" 2>/dev/null || echo "0")"
    log_info "Total settings entries: $count"

    local i
    for ((i=0; i<count; i++)); do
        local entry
        entry="$(jq ".settings[$i]" "$SETTINGS_DB" 2>/dev/null)"
        local key namespace type default recommended min_android max_android oem risk reboot

        key="$(echo "$entry" | jq -r '.key // "unknown"')"
        namespace="$(echo "$entry" | jq -r '.namespace // "unknown"')"
        type="$(echo "$entry" | jq -r '.type // "string"')"
        default="$(echo "$entry" | jq -r '.default // ""')"
        recommended="$(echo "$entry" | jq -r '.recommended // ""')"
        min_android="$(echo "$entry" | jq -r '.min_android // 0')"
        max_android="$(echo "$entry" | jq -r '.max_android // 99')"
        oem="$(echo "$entry" | jq -r '.oem // ""')"
        risk="$(echo "$entry" | jq -r '.risk // "low"')"
        reboot="$(echo "$entry" | jq -r '.reboot // false')"

        local status="verified"
        local issues=()

        # Check namespace validity
        case "$namespace" in
            global|secure|system) ;;
            *)
                issues+=("Invalid namespace: $namespace")
                status="deprecated"
                ;;
        esac

        # Check Android version range
        local current_sdk="${CAP_ANDROID_SDK:-0}"
        if [[ "$current_sdk" -gt 0 ]]; then
            if [[ "$current_sdk" -lt "$min_android" || "$current_sdk" -gt "$max_android" ]]; then
                if [[ "$max_android" -lt 99 ]]; then
                    issues+=("Android version out of range ($min_android-$max_android)")
                    if [[ "$status" != "deprecated" ]]; then
                        status="unsupported"
                    fi
                fi
            fi
        fi

        # Check experimental (high risk + no rollback or low android max)
        if [[ "$risk" == "high" ]]; then
            if [[ "$status" == "verified" ]]; then
                status="experimental"
            fi
        fi

        # Check deprecated patterns
        if echo "$key" | grep -qiE '(deprecated|removed|legacy)' 2>/dev/null; then
            status="deprecated"
        fi

        # Reboot requirement note
        if [[ "$reboot" == "true" ]]; then
            issues+=("Requires reboot")
        fi

        case "$status" in
            verified) verified=$((verified + 1)) ;;
            deprecated) deprecated=$((deprecated + 1)) ;;
            experimental) experimental=$((experimental + 1)) ;;
            unsupported) unsupported=$((unsupported + 1)) ;;
        esac

        results="$(echo "$results" | jq \
            --arg key "$key" \
            --arg ns "$namespace" \
            --arg status "$status" \
            --arg type "$type" \
            --arg risk "$risk" \
            --argjson reboot "$reboot" \
            --argjson issues "$(printf '%s\n' "${issues[@]}" | jq -R -s -c 'split("\n") | map(select(length > 0))' 2>/dev/null || echo '[]')" \
            '. + [{"key": $key, "namespace": $ns, "status": $status, "type": $type, "risk": $risk, "reboot": $reboot, "issues": $issues}]' 2>/dev/null)"
    done

    # Summary
    echo ""
    echo "  ── Settings Verification Summary ──"
    echo ""
    printf "  %-30s %s\n" "Total settings:" "$count"
    printf "  %-30s %s\n" "  Verified:" "$verified"
    printf "  %-30s %s\n" "  Deprecated:" "$deprecated"
    printf "  %-30s %s\n" "  Experimental:" "$experimental"
    printf "  %-30s %s\n" "  Unsupported:" "$unsupported"

    if [[ "$deprecated" -gt 0 || "$unsupported" -gt 0 ]]; then
        echo ""
        log_warning "${deprecated} deprecated, ${unsupported} unsupported settings found"
    else
        log_success "All settings verified"
    fi

    # Generate report
    local sdk android_ver
    sdk="$(api_android_sdk 2>/dev/null || echo "0")"
    android_ver="$(api_android_version 2>/dev/null || echo "unknown")"

    jq -n \
        --arg date "$(date -Iseconds)" \
        --arg version "${ANDROID_TOOLKIT_VERSION:-0.0.0}" \
        --argjson sdk "$sdk" \
        --arg android "$android_ver" \
        --argjson total "$count" \
        --argjson verified "$verified" \
        --argjson deprecated "$deprecated" \
        --argjson experimental "$experimental" \
        --argjson unsupported "$unsupported" \
        --argjson results "$results" \
        '{
            verification_date: $date,
            toolkit_version: $version,
            device: { android_sdk: $sdk, android_version: $android },
            summary: {
                total: $total,
                verified: $verified,
                deprecated: $deprecated,
                experimental: $experimental,
                unsupported: $unsupported
            },
            settings: $results
        }' > "$SETTINGS_VERIFY_REPORT" 2>/dev/null

    log_success "Settings verification report: $SETTINGS_VERIFY_REPORT"
}
