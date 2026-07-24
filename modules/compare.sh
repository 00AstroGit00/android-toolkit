#!/data/data/com.termux/files/usr/bin/bash
#
# compare.sh — Report Comparison Module
#
# Compares two reports (from --report or --export report json) and
# highlights differences in configuration, packages, performance,
# battery, and settings.
#
# Usage: toolkit.sh --compare <report1.json> <report2.json>
#
# Part of the Android Toolkit.

COMPARE_RESULTS=()

##############################################
# Compare two JSON reports.
# Arguments:
#   $1: path to first report
#   $2: path to second report
##############################################
compare_run() {
    local report1="${1:-}" report2="${2:-}"

    if [[ -z "$report1" || -z "$report2" ]]; then
        log_error "Usage: --compare <report1.json> <report2.json>"
        return 1
    fi

    if [[ ! -f "$report1" ]]; then
        log_error "Report not found: $report1"
        return 1
    fi
    if [[ ! -f "$report2" ]]; then
        log_error "Report not found: $report2"
        return 1
    fi

    log_section "Report Comparison"
    log_info "Report 1: $report1"
    log_info "Report 2: $report2"

    local has_jq=false
    command -v jq &>/dev/null && has_jq=true

    if $has_jq; then
        _compare_device "$report1" "$report2"
        _compare_settings "$report1" "$report2"
        _compare_scores "$report1" "$report2"
        _compare_versions "$report1" "$report2"
    else
        _compare_basic "$report1" "$report2"
    fi

    # Summary
    echo ""
    echo "  Differences found: ${#COMPARE_RESULTS[@]}"
    if [[ "${#COMPARE_RESULTS[@]}" -eq 0 ]]; then
        log_success "Reports are identical"
    fi

    # Generate diff report
    _compare_generate_report "$report1" "$report2"
}

##############################################
# Compare device info fields.
##############################################
_compare_device() {
    local r1="$1" r2="$2"
    local fields=("manufacturer" "model" "android_version" "android_sdk" "kernel" "one_ui_version" "abi")

    echo ""
    echo "  Device Information:"
    local field
    for field in "${fields[@]}"; do
        local v1 v2
        v1="$(jq -r ".report.device.${field} // \"N/A\"" "$r1" 2>/dev/null)"
        v2="$(jq -r ".report.device.${field} // \"N/A\"" "$r2" 2>/dev/null)"
        if [[ "$v1" != "$v2" ]]; then
            printf "    \033[33m⚠ %-20s changed: %s → %s\033[0m\n" "$field" "$v1" "$v2"
            COMPARE_RESULTS+=("device:${field}:${v1}:${v2}")
        else
            printf "    \033[32m✓ %-20s %s\033[0m\n" "$field" "$v1"
        fi
    done
}

##############################################

# Compare settings from two JSON reports.
##############################################
_compare_settings() {
    local r1="$1" r2="$2"

    echo ""
    echo "  Settings:"
    local changed=false
    local keys
    keys="$(jq -r '.report.settings // {} | keys[]' "$r1" 2>/dev/null || true)"

    if [[ -z "$keys" ]]; then
        echo "    No settings data available"
        return
    fi

    local key
    for key in $keys; do
        local v1 v2
        v1="$(jq -r ".report.settings[\"${key}\"] // \"N/A\"" "$r1" 2>/dev/null)"
        v2="$(jq -r ".report.settings[\"${key}\"] // \"N/A\"" "$r2" 2>/dev/null)"
        if [[ "$v1" != "$v2" ]]; then
            printf "    \033[33m⚠ %-35s %s → %s\033[0m\n" "$key" "$v1" "$v2"
            COMPARE_RESULTS+=("setting:${key}:${v1}:${v2}")
            changed=true
        fi
    done

    if ! $changed; then
        echo "    No setting differences"
    fi
}

##############################################
# Compare numeric scores.
##############################################
_compare_scores() {
    local r1="$1" r2="$2"

    echo ""
    echo "  Scores:"
    local changed=false
    local score_keys
    score_keys="$(jq -r '.report.scores // {} | keys[]' "$r1" 2>/dev/null || true)"

    if [[ -z "$score_keys" ]]; then
        echo "    No score data available"
        return
    fi

    local key
    for key in $score_keys; do
        local v1 v2
        v1="$(jq -r ".report.scores[\"${key}\"] // 0" "$r1" 2>/dev/null)"
        v2="$(jq -r ".report.scores[\"${key}\"] // 0" "$r2" 2>/dev/null)"
        if [[ "$v1" != "$v2" ]]; then
            local diff=$(( v2 - v1 ))
            if [[ "$diff" -gt 0 ]]; then
                printf "    \033[32m✓ %-20s %s → %s (+%d)\033[0m\n" "$key" "$v1" "$v2" "$diff"
            elif [[ "$diff" -lt 0 ]]; then
                printf "    \033[31m✗ %-20s %s → %s (%d)\033[0m\n" "$key" "$v1" "$v2" "$diff"
            fi
            COMPARE_RESULTS+=("score:${key}:${v1}:${v2}")
            changed=true
        else
            printf "    \033[32m✓ %-20s %s\033[0m\n" "$key" "$v1"
        fi
    done

    if ! $changed; then
        echo "    Scores unchanged"
    fi
}

##############################################
# Compare toolkit versions.
##############################################
_compare_versions() {
    local r1="$1" r2="$2"
    local v1 v2
    v1="$(jq -r '.report.toolkit_version // "N/A"' "$r1" 2>/dev/null)"
    v2="$(jq -r '.report.toolkit_version // "N/A"' "$r2" 2>/dev/null)"

    if [[ "$v1" != "$v2" ]]; then
        echo ""
        echo "  Toolkit Version: $v1 → $v2"
        COMPARE_RESULTS+=("version:toolkit:${v1}:${v2}")
    fi
}

##############################################
# Basic comparison without jq.
##############################################
_compare_basic() {
    local r1="$1" r2="$2"
    echo ""
    log_warning "jq not available — basic comparison only"

    local size1 size2
    size1="$(wc -c < "$r1" 2>/dev/null || echo 0)"
    size2="$(wc -c < "$r2" 2>/dev/null || echo 0)"

    if [[ "$size1" == "$size2" ]]; then
        if cmp -s "$r1" "$r2"; then
            log_success "Reports are identical"
            return 0
        fi
    fi

    log_info "Report sizes differ: ${size1} vs ${size2} bytes"
    COMPARE_RESULTS+=("size:differ:${size1}:${size2}")
}

##############################################
# Generate Markdown and JSON diff reports.
# Arguments:
#   $1: report1 path
#   $2: report2 path
##############################################
_compare_generate_report() {
    local r1="$1" r2="$2"
    local timestamp
    timestamp="$(date '+%Y%m%d_%H%M%S')"
    local diff_dir="${ANDROID_TOOLKIT_ROOT_DIR}/exports"
    mkdir -p "$diff_dir"

    local md_file="${diff_dir}/diff_${timestamp}.md"
    local json_file="${diff_dir}/diff_${timestamp}.json"

    # Markdown diff
    {
        echo "# Report Comparison"
        echo ""
        echo "**Report 1:** $r1"
        echo "**Report 2:** $r2"
        echo "**Date:** $(date -Iseconds)"
        echo ""
        echo "## Changes"
        echo ""
        echo "| Type | Item | Old | New |"
        echo "|------|------|-----|-----|"
        local result
        for result in "${COMPARE_RESULTS[@]}"; do
            local type item old new
            type="$(echo "$result" | cut -d: -f1)"
            item="$(echo "$result" | cut -d: -f2)"
            old="$(echo "$result" | cut -d: -f3)"
            new="$(echo "$result" | cut -d: -f4-)"
            echo "| $type | $item | $old | $new |"
        done
    } > "$md_file"

    # JSON diff
    if command -v jq &>/dev/null; then
        local json_entries="[]"
        local result
        for result in "${COMPARE_RESULTS[@]}"; do
            local type item old new
            type="$(echo "$result" | cut -d: -f1)"
            item="$(echo "$result" | cut -d: -f2)"
            old="$(echo "$result" | cut -d: -f3)"
            new="$(echo "$result" | cut -d: -f4-)"
            json_entries="$(echo "$json_entries" | jq \
                --arg t "$type" --arg i "$item" --arg o "$old" --arg n "$new" \
                '. + [{"type":$t, "item":$i, "old":$o, "new":$n}]' 2>/dev/null)"
        done
        echo "$json_entries" > "$json_file"
    fi

    log_success "Diff report (Markdown): $md_file"
    if [[ -f "$json_file" ]]; then
        log_success "Diff report (JSON): $json_file"
    fi
}

##############################################
# Alias for backwards compatibility.
##############################################
compare_reports() {
    compare_run "$@"
}
