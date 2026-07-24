#!/data/data/com.termux/files/usr/bin/bash
#
# validate_device.sh — Cross-Device Validation Framework
#
# Validates toolkit compatibility across devices:
#   - Detects connected device
#   - Checks feature support against OEM profiles
#   - Runs basic command validation
#   - Generates Markdown/JSON/HTML reports
#
# Usage: toolkit.sh --validate-device [--format json|md|html]
#
# Part of the Android Toolkit.

VALIDATION_OEM_FILE="${ANDROID_TOOLKIT_ROOT_DIR}/validation/oem-profiles.json"
VALIDATION_REPORT_DIR="${ANDROID_TOOLKIT_ROOT_DIR}/exports"

##############################################
# Run cross-device validation.
# Arguments:
#   $1: output format (text|json|md|html) — default: text
##############################################
validate_device_run() {
    local format="${1:-text}"

    log_section "Cross-Device Validation"

    if [[ ! -f "$VALIDATION_OEM_FILE" ]]; then
        log_error "OEM profiles not found: $VALIDATION_OEM_FILE"
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        log_error "jq required for validation"
        return 1
    fi

    mkdir -p "$VALIDATION_REPORT_DIR"

    # Detect device
    local manufacturer model android_version sdk oem_entry
    manufacturer="$(api_device_manufacturer 2>/dev/null || echo "unknown")"
    model="$(api_device_model 2>/dev/null || echo "unknown")"
    android_version="$(api_android_version 2>/dev/null || echo "unknown")"
    sdk="$(api_android_sdk 2>/dev/null || echo "0")"

    log_info "Device: ${manufacturer} ${model} (Android ${android_version}, SDK ${sdk})"

    # Look up OEM profile
    oem_entry="$(jq --arg oem "$manufacturer" '.oems[$oem] // empty' "$VALIDATION_OEM_FILE" 2>/dev/null)"

    if [[ -z "$oem_entry" ]]; then
        log_warning "No OEM profile found for: $manufacturer"
        oem_entry='{"name":"Unknown","features":{},"validation":{"verified":false,"notes":"Unrecognized OEM"}}'
    fi

    # Validate features
    local results_json
    results_json="$(_validate_check_features "$manufacturer" "$oem_entry" "$sdk")"

    # Build validation report
    local output_text output_json
    output_json="$(jq -n \
        --arg manufacturer "$manufacturer" \
        --arg model "$model" \
        --arg android "$android_version" \
        --argjson sdk "$sdk" \
        --argjson oem "$oem_entry" \
        --argjson results "$results_json" \
        --arg date "$(date -Iseconds)" \
        --arg version "${ANDROID_TOOLKIT_VERSION:-0.0.0}" \
        '{
            validation_date: $date,
            toolkit_version: $version,
            device: {
                manufacturer: $manufacturer,
                model: $model,
                android_version: $android,
                sdk: $sdk
            },
            oem_profile: $oem,
            results: $results,
            summary: {
                supported: ([$results[] | select(.status == "supported")] | length),
                partial: ([$results[] | select(.status == "partial")] | length),
                unsupported: ([$results[] | select(.status == "unsupported")] | length),
                total: ($results | length)
            }
        }' 2>/dev/null)"

    # Save JSON report
    local json_file="${VALIDATION_REPORT_DIR}/validation-$(date +%Y%m%d_%H%M%S).json"
    echo "$output_json" > "$json_file"
    log_success "Validation report (JSON): $json_file"

    # Format output
    case "$format" in
        json)
            echo "$output_json"
            ;;
        md|markdown)
            _validate_format_md "$output_json"
            local md_file="${VALIDATION_REPORT_DIR}/validation-$(date +%Y%m%d_%H%M%S).md"
            _validate_format_md "$output_json" > "$md_file"
            log_success "Validation report (Markdown): $md_file"
            ;;
        html)
            _validate_format_html "$output_json"
            local html_file="${VALIDATION_REPORT_DIR}/validation-$(date +%Y%m%d_%H%M%S).html"
            _validate_format_html "$output_json" > "$html_file"
            log_success "Validation report (HTML): $html_file"
            ;;
        text|*)
            _validate_format_text "$output_json"
            ;;
    esac
}

##############################################
# Check feature support against OEM profile.
# Arguments:
#   $1: manufacturer
#   $2: OEM profile JSON
#   $3: SDK version
# Outputs: JSON array of results
##############################################
_validate_check_features() {
    local manufacturer="$1" oem_entry="$2" sdk="$3"

    local results="[]"
    local features
    features="$(echo "$oem_entry" | jq -r '.features | to_entries[] | @base64' 2>/dev/null || true)"

    local entry
    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        local name status workaround reason android_min
        name="$(echo "$entry" | base64 -d 2>/dev/null | jq -r '.key' || echo "unknown")"
        status="$(echo "$entry" | base64 -d 2>/dev/null | jq -r '.value.supported // "unknown"' || echo "unknown")"
        workaround="$(echo "$entry" | base64 -d 2>/dev/null | jq -r '.value.workaround // ""' || echo "")"
        reason="$(echo "$entry" | base64 -d 2>/dev/null | jq -r '.value.reason // ""' || echo "")"
        android_min="$(echo "$entry" | base64 -d 2>/dev/null | jq -r '.value.android_min // 0' || echo "0")"

        # Check if this Android version is supported
        local version_status="$status"
        if [[ "$android_min" -gt 0 && "$sdk" -lt "$android_min" ]]; then
            version_status="unsupported"
            reason="Requires Android SDK $android_min+ (current: $sdk)"
        fi

        results="$(echo "$results" | jq \
            --arg name "$name" \
            --arg status "$version_status" \
            --arg workaround "$workaround" \
            --arg reason "$reason" \
            '. + [{"feature": $name, "status": $status, "workaround": $workaround, "reason": $reason}]' 2>/dev/null)"
    done <<< "$features"

    echo "$results"
}

##############################################
# Format validation output as plain text.
##############################################
_validate_format_text() {
    local json="$1"
    echo ""
    echo "  Device: $(echo "$json" | jq -r '.device.manufacturer') $(echo "$json" | jq -r '.device.model')"
    echo "  Android: $(echo "$json" | jq -r '.device.android_version') (SDK $(echo "$json" | jq -r '.device.sdk'))"
    echo "  OEM Profile: $(echo "$json" | jq -r '.oem_profile.name // "Unknown"')"
    echo ""

    local supported partial unsupported total
    supported="$(echo "$json" | jq -r '.summary.supported')"
    partial="$(echo "$json" | jq -r '.summary.partial')"
    unsupported="$(echo "$json" | jq -r '.summary.unsupported')"

    echo "  Supported:   $supported"
    echo "  Partial:     $partial"
    echo "  Unsupported: $unsupported"
    echo ""

    echo "  Features:"
    local features
    features="$(echo "$json" | jq -r '.results[] | "\(.status):\(.feature)"' 2>/dev/null)"
    local line
    while IFS= read -r line; do
        local s f
        s="$(echo "$line" | cut -d: -f1)"
        f="$(echo "$line" | cut -d: -f2-)"
        case "$s" in
            supported)   echo "    $(tput setaf 2)✓$(tput sgr0) $f" ;;
            partial)     echo "    $(tput setaf 3)◐$(tput sgr0) $f" ;;
            unsupported) echo "    $(tput setaf 1)✗$(tput sgr0) $f" ;;
            *)           echo "    $(tput setaf 8)?$(tput sgr0) $f" ;;
        esac
    done <<< "$features"
}

##############################################
# Format validation output as Markdown.
##############################################
_validate_format_md() {
    local json="$1"
    {
        echo "# Device Validation Report"
        echo ""
        echo "**Device:** $(echo "$json" | jq -r '.device.manufacturer') $(echo "$json" | jq -r '.device.model')"
        echo ""
        echo "**Android:** $(echo "$json" | jq -r '.device.android_version') (SDK $(echo "$json" | jq -r '.device.sdk'))"
        echo ""
        echo "**OEM Profile:** $(echo "$json" | jq -r '.oem_profile.name // "Unknown"')"
        echo ""
        echo "**Date:** $(echo "$json" | jq -r '.validation_date')"
        echo ""

        local supported partial unsupported total
        supported="$(echo "$json" | jq -r '.summary.supported')"
        partial="$(echo "$json" | jq -r '.summary.partial')"
        unsupported="$(echo "$json" | jq -r '.summary.unsupported')"

        echo "## Summary"
        echo ""
        echo "| Status | Count |"
        echo "|--------|-------|"
        echo "| ✅ Supported | $supported |"
        echo "| ◐ Partial | $partial |"
        echo "| ❌ Unsupported | $unsupported |"
        echo ""

        echo "## Feature Details"
        echo ""
        echo "| Feature | Status | Workaround / Reason |"
        echo "|---------|--------|---------------------|"

        local features
        features="$(echo "$json" | jq -r '.results[] | "\(.status)|\(.feature)|\(.workaround)//\(.reason)"' 2>/dev/null)"
        local line
        while IFS= read -r line; do
            local s f w r
            s="$(echo "$line" | cut -d'|' -f1)"
            f="$(echo "$line" | cut -d'|' -f2)"
            w="$(echo "$line" | cut -d'|' -f3)"

            local icon=""
            case "$s" in
                supported) icon="✅" ;;
                partial) icon="◐" ;;
                unsupported) icon="❌" ;;
            esac

            w="${w//\/\// — }"
            echo "| $icon $s | $f | $w |"
        done <<< "$features"
    }
}

##############################################
# Format validation output as HTML.
##############################################
_validate_format_html() {
    local json="$1"
    local manufacturer android_model android_ver oem_name date_str
    manufacturer="$(echo "$json" | jq -r '.device.manufacturer')"
    android_model="$(echo "$json" | jq -r '.device.model')"
    android_ver="$(echo "$json" | jq -r '.device.android_version')"
    oem_name="$(echo "$json" | jq -r '.oem_profile.name // "Unknown"')"
    date_str="$(echo "$json" | jq -r '.validation_date')"

    local supported partial unsupported
    supported="$(echo "$json" | jq -r '.summary.supported')"
    partial="$(echo "$json" | jq -r '.summary.partial')"
    unsupported="$(echo "$json" | jq -r '.summary.unsupported')"

    cat << HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Device Validation Report</title>
<style>
body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; max-width: 800px; margin: 40px auto; padding: 0 20px; color: #333; }
h1 { color: #1a73e8; }
table { border-collapse: collapse; width: 100%; margin: 16px 0; }
th, td { border: 1px solid #ddd; padding: 10px; text-align: left; }
th { background: #f5f5f5; }
.status-supported { color: #0a0; }
.status-partial { color: #a80; }
.status-unsupported { color: #c00; }
.summary { display: flex; gap: 20px; margin: 20px 0; }
.summary-card { border: 1px solid #ddd; border-radius: 8px; padding: 16px; flex: 1; text-align: center; }
.summary-card h3 { margin: 0 0 8px; }
.meta { color: #666; font-size: 0.9em; }
</style>
</head>
<body>
<h1>Device Validation Report</h1>
<p class="meta">${date_str} | Toolkit v$(echo "$json" | jq -r '.toolkit_version')</p>
<table>
<tr><th>Device</th><td>${manufacturer} ${android_model}</td></tr>
<tr><th>Android</th><td>${android_ver}</td></tr>
<tr><th>OEM Profile</th><td>${oem_name}</td></tr>
</table>
<div class="summary">
  <div class="summary-card"><h3 class="status-supported">✅ ${supported}</h3><p>Supported</p></div>
  <div class="summary-card"><h3 class="status-partial">◐ ${partial}</h3><p>Partial</p></div>
  <div class="summary-card"><h3 class="status-unsupported">❌ ${unsupported}</h3><p>Unsupported</p></div>
</div>
<h2>Features</h2>
<table>
<tr><th>Feature</th><th>Status</th><th>Notes</th></tr>
HTML
    local features
    features="$(echo "$json" | jq -r '.results[] | "\(.status)|\(.feature)|\(.workaround)//\(.reason)"' 2>/dev/null)"
    local line
    while IFS= read -r line; do
        local s f n
        s="$(echo "$line" | cut -d'|' -f1)"
        f="$(echo "$line" | cut -d'|' -f2)"
        n="$(echo "$line" | cut -d'|' -f3)"
        n="${n//\/\// — }"
        echo "<tr><td>$f</td><td class=\"status-$s\">$s</td><td>$n</td></tr>"
    done <<< "$features"
    cat << HTML
</table>
</body>
</html>
HTML
}
