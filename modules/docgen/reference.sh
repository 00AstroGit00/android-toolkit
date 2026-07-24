#!/data/data/com.termux/files/usr/bin/bash
#
# docgen.sh — Documentation Generator Module
#
# Generates:
#   - Command reference (Markdown + HTML)
#   - Plugin API reference
#   - Settings reference
#   - Changelog snippets
#   - Man page
#
# Usage: toolkit.sh --docgen [output-dir]
#   If output-dir is omitted, docs are written to docs/
#
# Part of the Android Toolkit.

DOCGEN_OUTPUT="${1:-${ANDROID_TOOLKIT_ROOT_DIR}/docs}"

##############################################
# Main entry point.
##############################################

# docgen/reference.sh — CLI reference, settings reference, changelog
# Part of the Android Toolkit.

docgen_run() {
    local output_dir="${DOCGEN_OUTPUT}"

    log_section "Documentation Generator"
    log_info "Output directory: $output_dir"

    mkdir -p "$output_dir"
    mkdir -p "${output_dir}/guides"

    docgen_command_reference "$output_dir"
    docgen_plugin_api "$output_dir"
    docgen_settings_reference "$output_dir"
    docgen_changelog_snippet "$output_dir"
    docgen_man_page "$output_dir"
    docgen_architecture "$output_dir"
    docgen_migration_guide "$output_dir"
    docgen_troubleshooting_guide "$output_dir"
    docgen_faq "$output_dir"
    docgen_module_guide "$output_dir"

    log_success "Documentation generated in: $output_dir"
    echo ""
    echo "  Files:"
    ls -lh "$output_dir"/*.md "$output_dir"/*.1 2>/dev/null | sed 's/^/    /'
    ls -lh "${output_dir}/guides/"*.md 2>/dev/null | sed 's/^/    /'
}

##############################################
# Generate command reference from command registry.
# Arguments:
#   $1: output directory
##############################################
docgen_command_reference() {
    local output_dir="$1"
    local file="${output_dir}/commands.md"

    log_info "Generating command reference..."

    {
        echo "# Command Reference"
        echo ""
        echo "Auto-generated from the Unified Command Registry."
        echo ""
        echo "## Categories"
        echo ""
    } > "$file"

    if ! declare -f command_define &>/dev/null; then
        echo "> Command registry not loaded. Run this from within the toolkit." >> "$file"
        log_warning "Command registry not available — commands.md will be incomplete"
        return
    fi

    # Group by category
    local -A categories
    local cmd
    for cmd in "${!COMMAND_NAMES[@]}"; do
        local cat
        cat="$(command_get_meta "$cmd" "category" 2>/dev/null || echo "other")"
        categories["$cat"]+=" $cmd"
    done

    for cat in "${!categories[@]}"; do
        echo "" >> "$file"
        echo "### ${cat^}" >> "$file"
        echo "" >> "$file"
        echo "| Command | Aliases | Description | Backend | Min Android |" >> "$file"
        echo "|---------|---------|-------------|---------|-------------|" >> "$file"

        local cmd
        for cmd in ${categories[$cat]}; do
            local aliases desc backend min_android
            aliases="$(command_get_meta "$cmd" "alias" 2>/dev/null || echo "-")"
            desc="$(command_get_meta "$cmd" "description" 2>/dev/null || echo "")"
            backend="$(command_get_meta "$cmd" "backend" 2>/dev/null || echo "any")"
            min_android="$(command_get_meta "$cmd" "min_android" 2>/dev/null || echo "-")"
            echo "| \`$cmd\` | $aliases | $desc | $backend | $min_android |" >> "$file"
        done
    done

    # Help text dump
    echo "" >> "$file"
    echo "## Full Help Text" >> "$file"
    echo "" >> "$file"
    echo '```' >> "$file"
    command_generate_help 2>/dev/null >> "$file" || echo "Help generation unavailable" >> "$file"
    echo '```' >> "$file"

    log_success "  commands.md"
}

##############################################
# Generate plugin API reference.
# Arguments:
#   $1: output directory
##############################################
docgen_settings_reference() {
    local output_dir="$1"
    local file="${output_dir}/settings.md"

    log_info "Generating settings reference..."

    {
        echo "# Settings Reference"
        echo ""
        echo "Auto-generated from the Settings Registry."
        echo ""
    } > "$file"

    if [[ ! -f "${ANDROID_TOOLKIT_ROOT_DIR}/lib/settings-db.json" ]]; then
        echo "> Settings database not found at lib/settings-db.json" >> "$file"
        log_warning "settings-db.json not found"
        return
    fi

    if ! command -v jq &>/dev/null; then
        echo "> jq required for full settings reference. Install jq and re-run." >> "$file"
        return
    fi

    # Extract namespaces
    local namespaces
    namespaces="$(jq -r '.settings | group_by(.namespace) | .[] | .[0].namespace' \
        "${ANDROID_TOOLKIT_ROOT_DIR}/lib/settings-db.json" 2>/dev/null)"

    for ns in $namespaces; do
        echo "" >> "$file"
        echo "## Namespace: $ns" >> "$file"
        echo "" >> "$file"
        echo "| Key | Type | Default | Recommended | Risk | Reboot |" >> "$file"
        echo "|-----|------|---------|-------------|------|--------|" >> "$file"

        local entries
        entries="$(jq -r --arg ns "$ns" \
            '.settings[] | select(.namespace == $ns) | "\(.key)|\(.type // "string")|\(.default // "-")|\(.recommended // "-")|\(.risk // "low")|\(.reboot // false)"' \
            "${ANDROID_TOOLKIT_ROOT_DIR}/lib/settings-db.json" 2>/dev/null)"

        local line
        while IFS='|' read -r key type default recommended risk reboot; do
            echo "| $key | $type | $default | $recommended | $risk | $reboot |" >> "$file"
        done <<< "$entries"
    done

    log_success "  settings.md"
}

##############################################
# Generate changelog snippet.
# Arguments:
#   $1: output directory
##############################################
docgen_changelog_snippet() {
    local output_dir="$1"
    local file="${output_dir}/CHANGELOG.md"

    if [[ -f "${ANDROID_TOOLKIT_ROOT_DIR}/CHANGELOG.md" ]]; then
        cp "${ANDROID_TOOLKIT_ROOT_DIR}/CHANGELOG.md" "$file"
        log_success "  CHANGELOG.md (copied)"
    else
        log_info "No CHANGELOG.md found — skipping"
    fi
}

##############################################
# Generate man page.
# Arguments:
#   $1: output directory
##############################################

