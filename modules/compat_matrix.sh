#!/data/data/com.termux/files/usr/bin/bash
#
# compat_matrix.sh — Compatibility Matrix Generator
#
# Automatically generates:
#   docs/COMPATIBILITY.md
#
# Columns:
#   OEM, Android version, Supported commands,
#   Unsupported commands, Known limitations,
#   Performance notes, Security notes
#
# Part of the Android Toolkit.

COMPAT_OEM_FILE="${ANDROID_TOOLKIT_ROOT_DIR}/validation/oem-profiles.json"
COMPAT_OUTPUT="${ANDROID_TOOLKIT_ROOT_DIR}/docs/COMPATIBILITY.md"

##############################################
# Generate the full compatibility matrix.
##############################################
compat_matrix_generate() {
    log_section "Compatibility Matrix Generator"

    if [[ ! -f "$COMPAT_OEM_FILE" ]]; then
        log_error "OEM profiles not found: $COMPAT_OEM_FILE"
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        log_error "jq required"
        return 1
    fi

    mkdir -p "$(dirname "$COMPAT_OUTPUT")"

    log_info "Generating compatibility matrix..."

    {
        echo "# Compatibility Matrix"
        echo ""
        echo "Auto-generated from OEM validation profiles."
        echo "Last updated: $(date -Iseconds)"
        echo ""
        echo "## Supported Devices"
        echo ""
        echo "| OEM | UI Version | Android | Command Support | Tested Backends | Status |"
        echo "|-----|------------|---------|----------------|-----------------|--------|"

        local oems
        oems="$(jq -r '.oems | keys[]' "$COMPAT_OEM_FILE" 2>/dev/null | sort)"

        local oem
        while IFS= read -r oem; do
            [[ -z "$oem" ]] && continue
            local name
            name="$(jq -r ".oems[\"$oem\"].name" "$COMPAT_OEM_FILE" 2>/dev/null)"
            local uis android_versions backends verified
            uis="$(jq -r ".oems[\"$oem\"].uis | join(\", \")" "$COMPAT_OEM_FILE" 2>/dev/null)"
            android_versions="$(jq -r ".oems[\"$oem\"].android_versions | join(\", \")" "$COMPAT_OEM_FILE" 2>/dev/null)"
            backends="$(jq -r ".oems[\"$oem\"].validation.backends_tested | join(\", \")" "$COMPAT_OEM_FILE" 2>/dev/null)"
            verified="$(jq -r ".oems[\"$oem\"].validation.verified // false" "$COMPAT_OEM_FILE" 2>/dev/null)"

            local status_icon="$(tput setaf 3)◐$(tput sgr0)"
            local status_text="Partial"
            if [[ "$verified" == "true" ]]; then
                status_icon="$(tput setaf 2)✓$(tput sgr0)"
                status_text="Verified"
            fi

            # Count features
            local total supported partial unsupported
            total="$(jq ".oems[\"$oem\"].features | length" "$COMPAT_OEM_FILE" 2>/dev/null)"
            supported="$(jq ".oems[\"$oem\"].features | map(select(.supported == true)) | length" "$COMPAT_OEM_FILE" 2>/dev/null)"
            partial="$(jq ".oems[\"$oem\"].features | map(select(.supported == \"partial\")) | length" "$COMPAT_OEM_FILE" 2>/dev/null)"

            echo "| $name | $uis | $android_versions | ${supported}+${partial}/${total} features | $backends | $status_icon $status_text |"
        done <<< "$oems"

        echo ""
        echo "## Feature Support Details"
        echo ""

        while IFS= read -r oem; do
            [[ -z "$oem" ]] && continue
            local name
            name="$(jq -r ".oems[\"$oem\"].name" "$COMPAT_OEM_FILE" 2>/dev/null)"

            echo "### $name"
            echo ""
            echo "| Feature | Status | Workaround / Reason |"
            echo "|---------|--------|---------------------|"

            local features
            features="$(jq -r ".oems[\"$oem\"].features | to_entries[] | \"\(.key)|\(.value.supported)|\(.value.workaround // .value.reason // \"\")\"" "$COMPAT_OEM_FILE" 2>/dev/null)"

            local line
            while IFS= read -r line; do
                local feature status notes
                feature="$(echo "$line" | cut -d'|' -f1)"
                status="$(echo "$line" | cut -d'|' -f2)"
                notes="$(echo "$line" | cut -d'|' -f3-)"

                local icon
                case "$status" in
                    true) icon="✅" ;;
                    "partial") icon="◐" ;;
                    false) icon="❌" ;;
                esac

                echo "| $feature | $icon $status | $notes |"
            done <<< "$features"
            echo ""
        done <<< "$oems"

        echo "## Global Command Support"
        echo ""
        echo "All standard commands (status, report, backup, restore, doctor,"
        echo "audit, benchmark, analyze, rollback, plugin, export) work across"
        echo "all supported OEMs where the required backend (ADB/rish) is"
        echo "available."
        echo ""
        echo "OEM-specific commands are documented per-OEM above."
        echo ""
        echo "## Notes"
        echo ""
        echo "- Validation status reflects tested configurations."
        echo -e "- Untested Android/OEM combinations may still work."
        echo "- Some features require Shizuku (rish) backend."
        echo "- Settings may be read-only on certain OEM firmware versions."
    } > "$COMPAT_OUTPUT"

    log_success "Compatibility matrix: $COMPAT_OUTPUT"
}

# Alias
compat_matrix_update() {
    compat_matrix_generate
}
