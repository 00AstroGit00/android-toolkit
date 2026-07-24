#!/data/data/com.termux/files/usr/bin/bash
#
# builder.sh — Release build module
#
# Generates a production-ready release artifact:
#   - Release ZIP with all source files
#   - SHA256 checksum
#   - Manifest JSON with version metadata
#   - Documentation bundle
#   - Test results
#   - Release notes
#
# Part of the Android Toolkit.

BUILDER_OUTPUT_DIR="${ANDROID_TOOLKIT_ROOT_DIR}/dist"

##############################################
# Run tests and capture results.
# Arguments:
#   $1: output file for results
##############################################
_builder_run_tests() {
    local output_file="$1"

    log_info "Running test suite..."

    if [[ -f "${ANDROID_TOOLKIT_ROOT_DIR}/tests/run_tests.sh" ]]; then
        bash "${ANDROID_TOOLKIT_ROOT_DIR}/tests/run_tests.sh" 2>&1 | tee "$output_file" || true
    else
        echo "No test suite found" > "$output_file"
    fi
}

##############################################
# Generate release notes.
# Arguments:
#   $1: output file
#   $2: version
##############################################
_builder_release_notes() {
    local output_file="$1" version="$2"

    cat > "$output_file" << EOF
# Android Toolkit v${version}

## Overview

Android Toolkit is a modular, non-root Android optimization and diagnostics toolkit.
It supports ADB (USB/wireless) and Shizuku (rish) backends, targeting Android 13-16
and Samsung One UI 5-8.

## Features

- Device detection and capability probing
- Performance profiles (balanced, performance, powersave, light)
- Comprehensive diagnostics (doctor, benchmark, audit, analyze)
- Settings management with automatic validation and rollback
- Samsung One UI optimization (GOS, RAM Plus, refresh rate, light profile)
- Security audit with risk scoring
- Plugin system for extensibility
- OEM framework for device-specific logic
- Local telemetry (no network transmission)
- Interactive TUI (dialog/whiptail)
- Report export (Markdown, JSON, CSV, HTML, PDF, ZIP)
- Self-update mechanism (stable/beta/nightly channels)
- Task scheduling (cron/Termux:Boot)

## Installation

See README.md for installation instructions.

## Checksums

SHA256 checksums are provided in the accompanying .sha256 file.

EOF

    # Append changelog entries for this version
    if [[ -f "${ANDROID_TOOLKIT_ROOT_DIR}/CHANGELOG.md" ]]; then
        echo "" >> "$output_file"
        echo "## Changelog" >> "$output_file"
        echo "" >> "$output_file"
        grep -A 50 "^## v${version}" "${ANDROID_TOOLKIT_ROOT_DIR}/CHANGELOG.md" 2>/dev/null | \
            sed '/^## v[0-9]/q' | head -n -1 >> "$output_file" || true
    fi
}

##############################################
# Generate the manifest JSON.
# Arguments:
#   $1: output file
#   $2: version
#   $3: build date
#   $4: sha256
##############################################
_builder_manifest() {
    local output_file="$1" version="$2" build_date="$3" sha256="$4"

    if command -v jq &>/dev/null; then
        jq -n \
            --arg v "$version" \
            --arg d "$build_date" \
            --arg s "$sha256" \
            '{
                name: "android-toolkit",
                version: $v,
                build_date: $d,
                sha256: $s,
                min_android_sdk: 33,
                max_android_sdk: 36,
                license: "MIT",
                author: "Android Toolkit Contributors"
            }' > "$output_file"
    else
        cat > "$output_file" << JSONEOF
{
  "name": "android-toolkit",
  "version": "${version}",
  "build_date": "${build_date}",
  "sha256": "${sha256}",
  "min_android_sdk": 33,
  "max_android_sdk": 36,
  "license": "MIT",
  "author": "Android Toolkit Contributors"
}
JSONEOF
    fi
}

##############################################
# Main build entry point.
##############################################
builder_run() {
    local version="${ANDROID_TOOLKIT_VERSION:-0.0.0}"
    local build_date
    build_date="$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S%z')"
    local artifact_name="android-toolkit-v${version}"
    local dist_dir="${BUILDER_OUTPUT_DIR}/${artifact_name}"
    local zip_file="${BUILDER_OUTPUT_DIR}/${artifact_name}.zip"
    local sha256_file="${zip_file}.sha256"
    local manifest_file="${BUILDER_OUTPUT_DIR}/manifest.json"
    local release_notes="${BUILDER_OUTPUT_DIR}/release-notes.md"
    local test_results="${BUILDER_OUTPUT_DIR}/test-results.txt"

    log_section "Release Build v${version}"

    # Create dist directories
    mkdir -p "$dist_dir"
    mkdir -p "${dist_dir}/lib"
    mkdir -p "${dist_dir}/modules"
    mkdir -p "${dist_dir}/modules/oem"
    mkdir -p "${dist_dir}/plugins"
    mkdir -p "${dist_dir}/profiles"
    mkdir -p "${dist_dir}/configs"
    mkdir -p "${dist_dir}/tests"

    log_info "Build directory: $dist_dir"
    log_info "Version: $version"
    log_info "Date: $build_date"

    # 1. Run tests
    echo ""
    log_info "Step 1/5: Running tests..."
    _builder_run_tests "$test_results"

    # 2. Copy source files
    echo ""
    log_info "Step 2/5: Copying sources..."

    # Core
    cp "${ANDROID_TOOLKIT_ROOT_DIR}/toolkit.sh" "$dist_dir/"
    cp "${ANDROID_TOOLKIT_ROOT_DIR}/VERSION" "$dist_dir/"
    cp "${ANDROID_TOOLKIT_ROOT_DIR}/LICENSE" "$dist_dir/"
    cp "${ANDROID_TOOLKIT_ROOT_DIR}/README.md" "$dist_dir/"
    cp "${ANDROID_TOOLKIT_ROOT_DIR}/CHANGELOG.md" "$dist_dir/"
    cp "${ANDROID_TOOLKIT_ROOT_DIR}/CONTRIBUTING.md" "$dist_dir/"
    cp "${ANDROID_TOOLKIT_ROOT_DIR}/SECURITY.md" "$dist_dir/"
    cp "${ANDROID_TOOLKIT_ROOT_DIR}/DEVELOPER.md" "$dist_dir/"
    cp "${ANDROID_TOOLKIT_ROOT_DIR}/PLUGIN_API.md" "$dist_dir/"
    cp "${ANDROID_TOOLKIT_ROOT_DIR}/RELEASE.md" "$dist_dir/"

    # Libraries
    for lib in logging detection backup utils backend rollback plugin config; do
        [[ -f "${ANDROID_TOOLKIT_ROOT_DIR}/lib/${lib}.sh" ]] && \
            cp "${ANDROID_TOOLKIT_ROOT_DIR}/lib/${lib}.sh" "${dist_dir}/lib/"
    done

    # Modules
    for mod in reporting battery display network samsung performance maintenance packages capabilities doctor benchmark telemetry updater scheduler audit analyzer export tui builder oem; do
        [[ -f "${ANDROID_TOOLKIT_ROOT_DIR}/modules/${mod}.sh" ]] && \
            cp "${ANDROID_TOOLKIT_ROOT_DIR}/modules/${mod}.sh" "${dist_dir}/modules/"
    done

    # OEM modules
    for oem in Samsung Google OnePlus Nothing Xiaomi Motorola Oppo Vivo; do
        [[ -f "${ANDROID_TOOLKIT_ROOT_DIR}/modules/oem/${oem}.sh" ]] && \
            cp "${ANDROID_TOOLKIT_ROOT_DIR}/modules/oem/${oem}.sh" "${dist_dir}/modules/oem/"
    done

    # Plugins
    for plugin in "${ANDROID_TOOLKIT_ROOT_DIR}/plugins"/*.sh; do
        [[ -f "$plugin" ]] && cp "$plugin" "${dist_dir}/plugins/"
    done

    # Profiles
    for prof in "${ANDROID_TOOLKIT_ROOT_DIR}/profiles"/*.conf; do
        [[ -f "$prof" ]] && cp "$prof" "${dist_dir}/profiles/"
    done

    # Configs
    cp "${ANDROID_TOOLKIT_ROOT_DIR}/configs/default.conf" "${dist_dir}/configs/"
    cp "${ANDROID_TOOLKIT_ROOT_DIR}/configs/settings-db.json" "${dist_dir}/configs/"

    # Tests
    cp "${ANDROID_TOOLKIT_ROOT_DIR}/tests/run_tests.sh" "${dist_dir}/tests/"

    # 3. Create ZIP archive
    echo ""
    log_info "Step 3/5: Creating ZIP archive..."
    if command -v zip &>/dev/null; then
        (
            cd "$BUILDER_OUTPUT_DIR" || exit 1
            rm -f "$zip_file" 2>/dev/null
            zip -qr "$zip_file" "$artifact_name"
        )
        log_success "ZIP: $zip_file"
    else
        log_warning "zip not available — skipping archive creation"
        log_info "Raw build directory: $dist_dir"
    fi

    # 4. Generate checksum
    echo ""
    log_info "Step 4/5: Generating checksums..."
    if [[ -f "$zip_file" ]] && command -v sha256sum &>/dev/null; then
        (cd "$BUILDER_OUTPUT_DIR" && sha256sum "$(basename "$zip_file")" > "$(basename "$sha256_file")")
        local checksum
        checksum="$(cat "$sha256_file" | awk '{print $1}')"
        log_success "SHA256: $sha256_file"

        # Generate manifest
        _builder_manifest "$manifest_file" "$version" "$build_date" "$checksum"
        log_success "Manifest: $manifest_file"
    else
        log_warning "SHA256 or ZIP not available — skipping manifest"
        _builder_manifest "$manifest_file" "$version" "$build_date" "unavailable"
    fi

    # 5. Generate release notes
    echo ""
    log_info "Step 5/5: Generating release notes..."
    _builder_release_notes "$release_notes" "$version"
    log_success "Release notes: $release_notes"

    # Summary
    echo ""
    echo "═══════════════════════════════════════════"
    echo " Build Complete — v${version}"
    echo "═══════════════════════════════════════════"
    echo ""
    echo "  Output directory: $BUILDER_OUTPUT_DIR"
    echo "  Artifact:         $zip_file"
    echo "  SHA256:           $sha256_file"
    echo "  Manifest:         $manifest_file"
    echo "  Release notes:    $release_notes"
    echo "  Test results:     $test_results"
    echo ""
    echo "  Release artifact size:"
    if [[ -f "$zip_file" ]]; then
        ls -lh "$zip_file" | awk '{print "    " $5}'
    fi
    echo ""
    log_info "Distribution ready in: $BUILDER_OUTPUT_DIR"
}
