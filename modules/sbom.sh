#!/data/data/com.termux/files/usr/bin/bash
#
# sbom.sh — Software Bill of Materials Generator
#
# Generates SBOM (Software Bill of Materials) for releases.
# Includes:
#   - All shell scripts
#   - Config files
#   - Libraries
#   - Modules
#   - Plugins
#   - Dependencies (tools)
#   - Checksums
#
# Output: SPDX-compatible JSON
#
# Part of the Android Toolkit.

SBOM_OUTPUT="${ANDROID_TOOLKIT_ROOT_DIR}/exports"

##############################################
# Generate a complete SBOM for the toolkit.
# Arguments:
#   $1: output file (optional, default: exports/sbom-<version>.json)
##############################################
sbom_generate() {
    local output_file="${1:-${SBOM_OUTPUT}/sbom-${ANDROID_TOOLKIT_VERSION:-0.0.0}.json}"

    log_section "Software Bill of Materials"
    log_info "Generating SBOM..."

    mkdir -p "$SBOM_OUTPUT"

    local date_created
    date_created="$(date -Iseconds)"

    # Collect all files
    local files_array="[]"
    local file
    for file in $(find "$ANDROID_TOOLKIT_ROOT_DIR" -type f \
        -not -path '*/.git/*' \
        -not -path '*/logs/*' \
        -not -path '*/node_modules/*' \
        -not -path '*/dist/*' \
        -not -path '*/.benchmarks/*' \
        -not -path '*/.telemetry/*' \
        \( -name '*.sh' -o -name '*.conf' -o -name '*.json' -o -name '*.md' -o -name '*.txt' -o -name '*.yml' -o -name '*.yaml' -o -name '*.toml' \) | sort); do
        local rel_path sha256
        rel_path="${file#$ANDROID_TOOLKIT_ROOT_DIR/}"
        sha256="$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1 || echo "unknown")"

        files_array="$(echo "$files_array" | jq \
            --arg path "$rel_path" \
            --arg sha "$sha256" \
            '. + [{"path": $path, "checksum": $sha, "algorithm": "SHA256"}]' 2>/dev/null)"
    done

    # Detect external dependencies
    local deps_array="[]"
    local tools=("bash" "adb" "jq" "shellcheck" "shfmt" "timeout" "curl" "git" "zip" "sha256sum")
    local tool
    for tool in "${tools[@]}"; do
        local version=""
        case "$tool" in
            bash) version="$(bash --version 2>/dev/null | head -1 | grep -oP 'version \K[^ ]+' || true)" ;;
            adb) version="$(adb --version 2>/dev/null | head -1 | grep -oP 'version \K[^ ]+' || true)" ;;
            jq) version="$(jq --version 2>/dev/null || true)" ;;
            git) version="$(git --version 2>/dev/null | grep -oP 'version \K[^ ]+' || true)" ;;
            zip) version="$(zip --version 2>/dev/null | head -1 | grep -oP 'Zip \K[^ ]+' || true)" ;;
            sha256sum) version="$(sha256sum --version 2>/dev/null | head -1 || true)" ;;
        esac

        local installed=false
        command -v "$tool" &>/dev/null && installed=true

        deps_array="$(echo "$deps_array" | jq \
            --arg name "$tool" \
            --arg ver "$version" \
            --argjson installed "$installed" \
            '. + [{"name": $name, "version": $ver, "installed": $installed}]' 2>/dev/null)"
    done

    # Count packages by type
    local sh_count json_count conf_count md_count
    sh_count="$(echo "$files_array" | jq '[.[] | select(.path | endswith(".sh"))] | length' 2>/dev/null || echo "0")"
    json_count="$(echo "$files_array" | jq '[.[] | select(.path | endswith(".json"))] | length' 2>/dev/null || echo "0")"
    conf_count="$(echo "$files_array" | jq '[.[] | select(.path | endswith(".conf"))] | length' 2>/dev/null || echo "0")"
    md_count="$(echo "$files_array" | jq '[.[] | select(.path | endswith(".md"))] | length' 2>/dev/null || echo "0")"

    # Build final SBOM
    jq -n \
        --arg version "${ANDROID_TOOLKIT_VERSION:-0.0.0}" \
        --arg date "$date_created" \
        --argjson files "$files_array" \
        --argjson deps "$deps_array" \
        --argjson sh_count "$sh_count" \
        --argjson json_count "$json_count" \
        --argjson conf_count "$conf_count" \
        --argjson md_count "$md_count" \
        '{
            "$schema": "https://raw.githubusercontent.com/spdx/spdx-spec/v2.3/schemas/spdx-schema.json",
            "spdxVersion": "SPDX-2.3",
            "dataLicense": "CC0-1.0",
            "name": "android-toolkit",
            "version": $version,
            "created": $date,
            "creator": "Tool: android-toolkit-sbom-generator",
            "packages": [
                {
                    "name": "android-toolkit",
                    "version": $version,
                    "files": $files,
                    "summary": "Android optimization and diagnostics toolkit"
                }
            ],
            "externalDependencies": $deps,
            "summary": {
                "total_files": ($files | length),
                "shell_scripts": $sh_count,
                "json_files": $json_count,
                "config_files": $conf_count,
                "docs": $md_count,
                "external_tools": ($deps | length)
            }
        }' > "$output_file" 2>/dev/null

    if [[ -f "$output_file" ]]; then
        log_success "SBOM generated: $output_file"
        local size
        size="$(wc -c < "$output_file")"
        log_info "  Size: ${size} bytes"
    else
        log_error "SBOM generation failed"
        return 1
    fi
}
