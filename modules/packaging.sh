#!/data/data/com.termux/files/usr/bin/bash
#
# packaging.sh — Release Packaging Module
#
# Produces release artifacts:
#   - source ZIP and tar.gz
#   - SHA256 and SHA512 checksums
#   - SBOM
#   - manifest
#   - release notes
#   - documentation bundle
#   - sample reports and plugins
#   - test report
#
# Everything packaged under dist/
#
# Part of the Android Toolkit.

PACKAGING_DIST="${ANDROID_TOOLKIT_ROOT_DIR}/dist"

##############################################
# Build all release artifacts.
# Arguments:
#   $1: output directory (default: dist/)
##############################################
packaging_build() {
    local dist_dir="${1:-$PACKAGING_DIST}"
    local version="${ANDROID_TOOLKIT_VERSION:-0.0.0}"

    log_section "Release Packaging"
    log_info "Building v${version}..."

    rm -rf "$dist_dir"
    mkdir -p "$dist_dir"
    mkdir -p "${dist_dir}/docs"

    # 1. Source archive (ZIP)
    _package_zip "$dist_dir" "$version"

    # 2. Source archive (tar.gz)
    _package_targz "$dist_dir" "$version"

    # 3. Checksums
    _package_checksums "$dist_dir" "$version"

    # 4. SBOM
    _package_sbom "$dist_dir" "$version"

    # 5. Manifest
    _package_manifest "$dist_dir" "$version"

    # 6. Release notes
    _package_release_notes "$dist_dir" "$version"

    # 7. Documentation bundle
    _package_docs "$dist_dir"

    # 8. Sample reports
    _package_samples "$dist_dir"

    # 9. Test report
    _package_test_report "$dist_dir"

    # Summary
    echo ""
    echo "  ── Release Artifacts ──"
    ls -lh "$dist_dir" | sed 's/^/    /'

    local total_size
    total_size="$(du -sh "$dist_dir" | cut -f1)"
    log_success "Release package built: ${dist_dir} (${total_size})"
}

##############################################
# Create source ZIP archive.
##############################################
_package_zip() {
    local dist="$1" version="$2"
    local zip_file="${dist}/android-toolkit-v${version}.zip"

    log_info "  Creating ZIP archive..."

    cd "$ANDROID_TOOLKIT_ROOT_DIR" || return 1

    # Use git ls-files if available, otherwise find
    if git rev-parse --git-dir &>/dev/null 2>&1; then
        git ls-files --recurse-submodules | zip -q "$zip_file" -@ 2>/dev/null
    else
        find . -type f \
            -not -path './.git/*' \
            -not -path './logs/*' \
            -not -path './dist/*' \
            -not -path './node_modules/*' \
            -not -path './.benchmarks/*' \
            -not -path './.telemetry/*' \
            | zip -q "$zip_file" -@ 2>/dev/null
    fi

    log_success "  ZIP: $zip_file ($(du -h "$zip_file" | cut -f1))"
}

##############################################
# Create tar.gz source archive.
##############################################
_package_targz() {
    local dist="$1" version="$2"
    local tar_file="${dist}/android-toolkit-v${version}.tar.gz"

    log_info "  Creating tar.gz archive..."

    cd "$ANDROID_TOOLKIT_ROOT_DIR" || return 1

    if git rev-parse --git-dir &>/dev/null 2>&1; then
        git ls-files --recurse-submodules | tar czf "$tar_file" -T - 2>/dev/null
    else
        find . -type f \
            -not -path './.git/*' \
            -not -path './logs/*' \
            -not -path './dist/*' \
            -not -path './node_modules/*' \
            -not -path './.benchmarks/*' \
            -not -path './.telemetry/*' \
            | tar czf "$tar_file" -T - 2>/dev/null
    fi

    log_success "  tar.gz: $tar_file ($(du -h "$tar_file" | cut -f1))"
}

##############################################
# Generate checksums.
##############################################
_package_checksums() {
    local dist="$1" version="$2"

    log_info "  Generating checksums..."

    local f_sha256="${dist}/android-toolkit-v${version}.sha256"
    local f_sha512="${dist}/android-toolkit-v${version}.sha512"

    cd "$dist" || return 1

    sha256sum *.zip *.tar.gz 2>/dev/null > "$f_sha256"
    sha512sum *.zip *.tar.gz 2>/dev/null > "$f_sha512"

    log_success "  SHA256: $f_sha256"
    log_success "  SHA512: $f_sha512"
}

##############################################
# Generate SBOM.
##############################################
_package_sbom() {
    local dist="$1" version="$2"

    log_info "  Generating SBOM..."

    if declare -f sbom_generate &>/dev/null; then
        sbom_generate "${dist}/sbom-v${version}.json"
    else
        log_warning "  SBOM module not available"
    fi
}

##############################################
# Generate manifest.
##############################################
_package_manifest() {
    local dist="$1" version="$2"

    log_info "  Generating manifest..."

    local zip_file="${dist}/android-toolkit-v${version}.zip"
    local tar_file="${dist}/android-toolkit-v${version}.tar.gz"

    jq -n \
        --arg version "$version" \
        --arg date "$(date -Iseconds)" \
        --arg zip "$(basename "$zip_file")" \
        --arg targz "$(basename "$tar_file")" \
        --arg zip_size "$(du -h "$zip_file" 2>/dev/null | cut -f1)" \
        --arg targz_size "$(du -h "$tar_file" 2>/dev/null | cut -f1)" \
        --arg zip_sha "$(sha256sum "$zip_file" 2>/dev/null | cut -d' ' -f1)" \
        --arg targz_sha "$(sha256sum "$tar_file" 2>/dev/null | cut -d' ' -f1)" \
        '{
            name: "android-toolkit",
            version: $version,
            release_date: $date,
            artifacts: {
                zip: { file: $zip, size: $zip_size, sha256: $zip_sha },
                targz: { file: $targz, size: $targz_size, sha256: $targz_sha }
            },
            requirements: {
                bash: "5.0+",
                android: "13+",
                backends: ["adb", "rish"]
            }
        }' > "${dist}/manifest-v${version}.json" 2>/dev/null

    log_success "  Manifest: ${dist}/manifest-v${version}.json"
}

##############################################
# Generate release notes.
##############################################
_package_release_notes() {
    local dist="$1" version="$2"

    log_info "  Generating release notes..."

    {
        echo "# Android Toolkit v${version}"
        echo ""
        echo "Release date: $(date -Iseconds)"
        echo ""
        echo "## What's New"
        echo ""

        # Extract changelog for this version
        if [[ -f "${ANDROID_TOOLKIT_ROOT_DIR}/CHANGELOG.md" ]]; then
            sed -n "/^## v${version}/,/^## v[0-9]/p" "${ANDROID_TOOLKIT_ROOT_DIR}/CHANGELOG.md" | head -n -1
        fi

        echo ""
        echo "## Installation"
        echo ""
        echo '```bash'
        echo "# Extract the archive"
        echo "unzip android-toolkit-v${version}.zip"
        echo "cd android-toolkit-v${version}"
        echo ""
        echo "# Run the toolkit"
        echo "bash toolkit.sh --help"
        echo '```'
        echo ""
        echo "## Checksums"
        echo ""
        echo '```'
        cat "${dist}"/*.sha256 2>/dev/null
        echo '```'
        echo ""
        echo "## Documentation"
        echo ""
        echo "See the docs/ directory for complete documentation."
    } > "${dist}/RELEASE_NOTES-v${version}.md"

    log_success "  Release notes: ${dist}/RELEASE_NOTES-v${version}.md"
}

##############################################
# Bundle documentation.
##############################################
_package_docs() {
    local dist="$1"

    log_info "  Bundling documentation..."

    local doc_dir="${dist}/docs"
    mkdir -p "$doc_dir"

    # Copy markdown docs
    cp "${ANDROID_TOOLKIT_ROOT_DIR}"/*.md "$doc_dir/" 2>/dev/null || true

    # Copy docs/ directory
    if [[ -d "${ANDROID_TOOLKIT_ROOT_DIR}/docs" ]]; then
        cp -r "${ANDROID_TOOLKIT_ROOT_DIR}/docs/"* "$doc_dir/" 2>/dev/null || true
    fi

    # Generate if not exists
    if declare -f docgen_run &>/dev/null; then
        docgen_run "$doc_dir" 2>/dev/null || true
    fi

    log_success "  Documentation: $doc_dir ($(find "$doc_dir" -type f | wc -l) files)"
}

##############################################
# Package sample reports and plugins.
##############################################
_package_samples() {
    local dist="$1"

    log_info "  Packaging samples..."

    local sample_dir="${dist}/samples"
    mkdir -p "$sample_dir"

    # Sample exports
    if [[ -d "${ANDROID_TOOLKIT_ROOT_DIR}/exports" ]]; then
        local count=0
        local f
        for f in "${ANDROID_TOOLKIT_ROOT_DIR}/exports"/*.json; do
            [[ -f "$f" ]] || continue
            cp "$f" "${sample_dir}/" 2>/dev/null || true
            count=$((count + 1))
        done
        [[ "$count" -gt 0 ]] && log_debug "  Copied $count export(s)"
    fi

    # Sample plugins
    if [[ -d "${ANDROID_TOOLKIT_ROOT_DIR}/plugins" ]]; then
        mkdir -p "${sample_dir}/plugins"
        cp "${ANDROID_TOOLKIT_ROOT_DIR}/plugins/"*.sh "${sample_dir}/plugins/" 2>/dev/null || true
    fi

    log_success "  Samples: $sample_dir"
}

##############################################
# Package test report.
##############################################
_package_test_report() {
    local dist="$1"

    log_info "  Packaging test report..."

    local test_dir="${dist}/tests"
    mkdir -p "$test_dir"

    # Copy test results if they exist
    if [[ -f "${ANDROID_TOOLKIT_ROOT_DIR}/tests/test_results.json" ]]; then
        cp "${ANDROID_TOOLKIT_ROOT_DIR}/tests/test_results.json" "$test_dir/"
    fi

    # Run basic syntax check for test report
    {
        echo "# Test Report"
        echo ""
        echo "Generated: $(date -Iseconds)"
        echo ""
        echo "## Syntax Check"
        echo ""

        local errors=0 count=0
        local f
        for f in $(find "$ANDROID_TOOLKIT_ROOT_DIR" -name '*.sh' -not -path '*/logs/*' -not -path '*/.git/*' | sort); do
            count=$((count + 1))
            bash -n "$f" 2>/dev/null || errors=$((errors + 1))
        done

        echo "- Files checked: $count"
        echo "- Syntax errors: $errors"
        echo ""
        if [[ "$errors" -eq 0 ]]; then
            echo "**Result: PASS**"
        else
            echo "**Result: FAIL**"
        fi

        echo ""
        echo "## JSON Validation"
        echo ""
        if command -v jq &>/dev/null; then
            local jerrors=0 jcount=0
            for f in $(find "$ANDROID_TOOLKIT_ROOT_DIR" -name '*.json' -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/logs/*' | sort); do
                jcount=$((jcount + 1))
                jq empty "$f" 2>/dev/null || jerrors=$((jerrors + 1))
            done
            echo "- Files checked: $jcount"
            echo "- JSON errors: $jerrors"
        else
            echo "jq not available"
        fi
    } > "$test_dir/test-report.md"

    log_success "  Test report: $test_dir"
}
