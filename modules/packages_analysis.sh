#!/data/data/com.termux/files/usr/bin/bash
#
# packages_analysis.sh — Package Dependency Analysis Module
#
# Expands the package intelligence with:
#   - Package dependency resolution
#   - Shared UID group detection
#   - Launcher component identification
#   - Privileged app detection
#   - Vendor app detection
#   - Removable candidate analysis
#   - High-risk removal detection
#
# Never recommends removing packages with unresolved dependencies.
#
# Part of the Android Toolkit.

PACKAGES_ANALYSIS_CACHE=""

##############################################
# Analyze a single package's dependencies.
# Arguments:
#   $1: package name
# Outputs: JSON with dependency info
##############################################
packages_analyze_deps() {
    local pkg="$1"

    if ! declare -f backend_shell &>/dev/null; then
        log_error "Backend not available"
        return 1
    fi

    local deps shared_uid launcher privileged vendor

    # Get dependencies (dumpsys package)
    deps="$(backend_shell "dumpsys package $pkg 2>/dev/null" 2>/dev/null | grep -A 100 'dependencies:' | grep -m 20 'Package:' | sed 's/.*Package: \[//;s/\]//')"

    # Shared UID
    shared_uid="$(backend_shell "dumpsys package $pkg 2>/dev/null" 2>/dev/null | grep 'sharedUser=' | sed 's/.*sharedUser=//')"

    # Check if launcher
    launcher="false"
    if backend_shell "pm query-intent --resolve -a android.intent.action.MAIN -c android.intent.category.LAUNCHER 2>/dev/null" 2>/dev/null | grep -q "$pkg"; then
        launcher="true"
    fi

    # Check privileged
    privileged="false"
    if backend_shell "pm list packages --show-versions 2>/dev/null" 2>/dev/null | grep -q "$pkg"; then
        local path
        path="$(backend_shell "pm path $pkg 2>/dev/null" 2>/dev/null | sed 's/package://')"
        if [[ -n "$path" ]] && backend_shell "ls -l $path 2>/dev/null" 2>/dev/null | grep -qE 'system/priv-app|system/app'; then
            privileged="true"
        fi
    fi

    # Check vendor
    vendor="false"
    if [[ -n "$path" ]] && echo "$path" | grep -qE 'vendor/'; then
        vendor="true"
    fi

    jq -n \
        --arg pkg "$pkg" \
        --argjson deps "$(echo "$deps" | jq -R -s -c 'split("\n") | map(select(length > 0))' 2>/dev/null || echo '[]')" \
        --arg shared_uid "${shared_uid:-null}" \
        --argjson launcher "$launcher" \
        --argjson privileged "$privileged" \
        --argjson vendor "$vendor" \
        '{
            package: $pkg,
            dependencies: $deps,
            shared_uid: $shared_uid,
            is_launcher: $launcher,
            is_privileged: $privileged,
            is_vendor: $vendor
        }' 2>/dev/null || echo "{\"package\":\"$pkg\"}"
}

##############################################
# Check if removing a package is safe.
# Arguments:
#   $1: package name
# Returns: 0 if safe, 1 if risky
# Outputs: risk analysis JSON
##############################################
packages_analyze_removal_risk() {
    local pkg="$1"
    local risk_level="low"
    local reasons=()

    local analysis
    analysis="$(packages_analyze_deps "$pkg")"

    # Check if launcher
    if echo "$analysis" | jq -e '.is_launcher' &>/dev/null; then
        risk_level="high"
        reasons+=("launcher component")
    fi

    # Check if privileged
    if echo "$analysis" | jq -e '.is_privileged' &>/dev/null; then
        if [[ "$risk_level" != "high" ]]; then
            risk_level="medium"
        fi
        reasons+=("privileged app")
    fi

    # Check dependencies from other packages
    local dep_count
    dep_count="$(echo "$analysis" | jq '.dependencies | length' 2>/dev/null || echo "0")"
    if [[ "$dep_count" -gt 0 ]]; then
        if [[ "$risk_level" != "high" ]]; then
            risk_level="medium"
        fi
        reasons+=("${dep_count} dependent package(s)")
    fi

    jq -n \
        --arg pkg "$pkg" \
        --arg risk "$risk_level" \
        --argjson reasons "$(printf '%s\n' "${reasons[@]}" | jq -R -s -c 'split("\n") | map(select(length > 0))' 2>/dev/null || echo '[]')" \
        '{
            package: $pkg,
            removal_risk: $risk,
            risk_reasons: $reasons,
            safe_to_remove: (if $risk == "low" then true else false end)
        }' 2>/dev/null
}

##############################################
# Analyze all installed packages and classify them.
##############################################
packages_full_analysis() {
    log_section "Package Dependency Analysis"

    if ! declare -f backend_shell &>/dev/null; then
        log_error "Backend not available"
        return 1
    fi

    log_info "Fetching package list..."
    local packages
    packages="$(backend_shell "pm list packages 2>/dev/null" 2>/dev/null | sed 's/package://')"

    if [[ -z "$packages" ]]; then
        log_warning "No packages found"
        return 1
    fi

    local total=0 privileged_count=0 vendor_count=0 launcher_count=0 \
          removable_low=0 removable_medium=0 removable_high=0
    local pkg

    echo ""
    for pkg in $packages; do
        total=$((total + 1))
        local analysis risk
        analysis="$(packages_analyze_deps "$pkg" 2>/dev/null || true)"
        risk="$(packages_analyze_removal_risk "$pkg" 2>/dev/null || true)"

        if echo "$analysis" | jq -e '.is_privileged' &>/dev/null; then
            privileged_count=$((privileged_count + 1))
        fi
        if echo "$analysis" | jq -e '.is_vendor' &>/dev/null; then
            vendor_count=$((vendor_count + 1))
        fi
        if echo "$analysis" | jq -e '.is_launcher' &>/dev/null; then
            launcher_count=$((launcher_count + 1))
        fi

        local risk_level
        risk_level="$(echo "$risk" | jq -r '.removal_risk' 2>/dev/null || echo "unknown")"
        case "$risk_level" in
            low) removable_low=$((removable_low + 1)) ;;
            medium) removable_medium=$((removable_medium + 1)) ;;
            high) removable_high=$((removable_high + 1)) ;;
        esac
    done

    # Summary
    echo "  ── Package Analysis Summary ──"
    printf "  %-30s %s\n" "Total packages:" "$total"
    printf "  %-30s %s\n" "Privileged apps:" "$privileged_count"
    printf "  %-30s %s\n" "Vendor apps:" "$vendor_count"
    printf "  %-30s %s\n" "Launcher components:" "$launcher_count"
    echo ""
    printf "  %-30s %s\n" "Safe to remove (low risk):" "$removable_low"
    printf "  %-30s %s\n" "Caution (medium risk):" "$removable_medium"
    printf "  %-30s %s\n" "Do not remove (high risk):" "$removable_high"

    # Generate JSON report
    if command -v jq &>/dev/null; then
        local report_file="${ANDROID_TOOLKIT_ROOT_DIR}/exports/package_analysis_$(date +%Y%m%d_%H%M%S).json"
        mkdir -p "${ANDROID_TOOLKIT_ROOT_DIR}/exports"

        jq -n \
            --argjson total "$total" \
            --argjson privileged "$privileged_count" \
            --argjson vendor "$vendor_count" \
            --argjson launcher "$launcher_count" \
            --argjson removable_low "$removable_low" \
            --argjson removable_medium "$removable_medium" \
            --argjson removable_high "$removable_high" \
            '{
                summary: {
                    total_packages: $total,
                    privileged_apps: $privileged,
                    vendor_apps: $vendor,
                    launcher_components: $launcher,
                    safe_to_remove: $removable_low,
                    caution: $removable_medium,
                    do_not_remove: $removable_high
                }
            }' > "$report_file"
        log_success "Analysis saved: $report_file"
    fi
}
