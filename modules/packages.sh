#!/data/data/com.termux/files/usr/bin/bash
#
# packages.sh — Package management module
#
# Enable, disable, and inspect packages.
# All destructive actions are opt-in and require confirmation.
# Backups are created before disabling packages.
#
# Part of the Android Toolkit.

# List of packages that should never be disabled (safety list)
PACKAGES_PROTECTED=(
    "com.android.phone"
    "com.android.systemui"
    "com.android.settings"
    "com.android.launcher"
    "com.android.inputmethod.latin"
    "com.google.android.inputmethod.latin"
    "com.android.permissioncontroller"
    "com.android.packageinstaller"
    "com.android.documentsui"
    "com.android.providers.settings"
    "com.android.providers.media"
    "com.android.providers.downloads"
    "com.android.vending"
    "com.google.android.gms"
    "com.google.android.gsf"
    "com.sec.android.app.launcher"
    "com.sec.android.app.camera"
    "com.samsung.android.phone"
    "com.samsung.android.systemui"
)

##############################################
# Disable a package (user 0).
# Creates a package backup before disabling.
# Arguments:
#   $1: package name
##############################################
packages_disable() {
    local pkg="$1"

    if ! utils_validate_package "$pkg"; then
        return 1
    fi

    log_section "Disable Package: $pkg"

    # Check if package is protected
    local protected=false
    for protected_pkg in "${PACKAGES_PROTECTED[@]}"; do
        if [[ "$pkg" == "$protected_pkg" ]]; then
            protected=true
            break
        fi
    done

    if $protected; then
        log_error "Package '$pkg' is protected — disabling it may break system functionality."
        log_error "Remove it from the protected list in packages.sh to proceed."
        return 1
    fi

    # Check if package exists
    if ! backend_package_installed "$pkg"; then
        log_error "Package '$pkg' is not installed on this device"
        return 1
    fi

    # Check if already disabled
    local disabled_list
    disabled_list="$(backend_exec pm list packages --disabled 2>/dev/null)"
    if echo "$disabled_list" | grep -q "$pkg"; then
        log_info "Package '$pkg' is already disabled"
        return 0
    fi

    if [[ "$ANDROID_TOOLKIT_DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would disable package: $pkg"
        return 0
    fi

    # Create package state backup before disabling
    backup_create_packages "before_disable_${pkg}" > /dev/null

    # Require confirmation
    if utils_is_interactive; then
        log_warn "You are about to disable: $pkg"
        if ! utils_confirm "This can be reversed later with --enable-package."; then
            log_info "Cancelled"
            return 0
        fi
    fi

    # Disable the package
    if backend_exec pm disable-user --user 0 "$pkg" 2>/dev/null; then
        log_success "Package disabled: $pkg"
    else
        log_error "Failed to disable package '$pkg'. It may be a critical system app."
        return 1
    fi
}

##############################################
# Enable a previously disabled package.
# Arguments:
#   $1: package name
##############################################
packages_enable() {
    local pkg="$1"

    if ! utils_validate_package "$pkg"; then
        return 1
    fi

    log_section "Enable Package: $pkg"

    # Check if package exists
    if ! backend_package_installed "$pkg"; then
        log_error "Package '$pkg' is not installed on this device"
        return 1
    fi

    # Check if already enabled
    local enabled_list
    enabled_list="$(backend_exec pm list packages --enabled 2>/dev/null)"
    if echo "$enabled_list" | grep -q "$pkg"; then
        log_info "Package '$pkg' is already enabled"
        return 0
    fi

    if [[ "$ANDROID_TOOLKIT_DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would enable package: $pkg"
        return 0
    fi

    # Enable the package
    if backend_exec pm enable "$pkg" 2>/dev/null; then
        log_success "Package enabled: $pkg"
    else
        log_error "Failed to enable package '$pkg'"
        return 1
    fi
}

##############################################
# List disabled packages.
##############################################
packages_list_disabled() {
    log_section "Disabled Packages"

    local disabled
    disabled="$(backend_exec pm list packages --disabled 2>/dev/null | sed 's/^package://')"

    if [[ -z "$disabled" ]]; then
        log_info "No disabled packages found"
        return 0
    fi

    local count=0
    while IFS= read -r pkg; do
        if [[ -n "$pkg" ]]; then
            echo "  $pkg"
            count=$((count + 1))
        fi
    done <<< "$disabled"

    log_info "Total disabled: $count"
}

##############################################
# List third-party packages.
##############################################
packages_list_third_party() {
    log_section "Third-Party Packages"

    local packages
    packages="$(backend_list_third_party_packages)"

    if [[ -z "$packages" ]]; then
        log_info "No third-party packages found"
        return 0
    fi

    local count=0
    while IFS= read -r pkg; do
        if [[ -n "$pkg" ]]; then
            echo "  $pkg"
            count=$((count + 1))
        fi
    done <<< "$packages"

    log_info "Total third-party: $count"
}

##############################################
# Analyze installed packages and recommend actions.
# Scans installed packages, classifies them, and provides
# recommendations for bloatware removal.
##############################################
packages_recommend() {
    log_section "Package Recommendations"

    # Get all installed packages
    local all_packages
    all_packages="$(backend_exec "pm list packages 2>/dev/null" 2>/dev/null || echo "")"
    all_packages="$(echo "$all_packages" | sed 's/^package://')"

    if [[ -z "$all_packages" ]]; then
        log_warning "Could not retrieve package list"
        return 1
    fi

    # Known bloatware patterns by category
    local samsung_bloat=(
        "com.samsung.android.bixby.wakeup"
        "com.samsung.android.bixby.agent"
        "com.samsung.android.app.spage"
        "com.samsung.android.visionintelligence"
        "com.samsung.android.bixbyvision.framework"
        "com.facebook.katana"
        "com.facebook.appmanager"
        "com.facebook.system"
        "com.microsoft.skydrive"
        "com.microsoft.office.excel"
        "com.microsoft.office.word"
        "com.microsoft.office.powerpoint"
        "com.microsoft.office.outlook"
        "com.microsoft.office.officehubrow"
        "com.linkedin.android"
        "com.ebay.mobile"
        "com.amazon.mShop.android.shopping"
        "com.amazon.kindle"
        "com.spotify.music"
        "com.netflix.mediaclient"
        "com.google.android.apps.maps"
        "com.google.android.apps.photos"
        "com.google.android.apps.messaging"
        "com.google.android.apps.docs"
        "com.google.android.apps.drive"
        "com.google.android.apps.youtube.music"
        "com.android.chrome"
        "com.google.android.gm"
        "com.samsung.android.calendar"
        "com.samsung.android.contacts"
        "com.samsung.android.messaging"
    )

    local carrier_bloat_patterns=(
        "com.att"
        "com.tmobile"
        "com.sprint"
        "com.verizon"
        "com.vzw"
        "com.cricket"
        "com.metropcs"
        "com.uscc"
        "com.boost"
    )

    local google_duplicates=(
        "com.google.android.apps.maps"
        "com.google.android.apps.photos"
        "com.google.android.apps.messaging"
        "com.google.android.apps.docs"
        "com.google.android.apps.drive"
    )

    local classified_samsung=()
    local classified_carrier=()
    local classified_google=()
    local classified_thirdparty=()
    local classified_system=()

    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue

        local is_samsung=false
        local is_carrier=false
        local is_google=false

        # Check Samsung bloat
        for bp in "${samsung_bloat[@]}"; do
            if [[ "$pkg" == "$bp" ]]; then
                classified_samsung+=("$pkg")
                is_samsung=true
                break
            fi
        done

        # Check carrier bloat
        if ! $is_samsung; then
            for cp in "${carrier_bloat_patterns[@]}"; do
                if [[ "$pkg" == "$cp"* ]]; then
                    classified_carrier+=("$pkg")
                    is_carrier=true
                    break
                fi
            done
        fi

        # Check Google duplicates
        if ! $is_samsung && ! $is_carrier; then
            for gp in "${google_duplicates[@]}"; do
                if [[ "$pkg" == "$gp" ]]; then
                    classified_google+=("$pkg")
                    is_google=true
                    break
                fi
            done
        fi

        # Classify remaining
        if ! $is_samsung && ! $is_carrier && ! $is_google; then
            # Check if it's a known system package
            if [[ "$pkg" == "com.android."* || "$pkg" == "com.google.android."* || "$pkg" == "com.samsung."* ]]; then
                classified_system+=("$pkg")
            else
                classified_thirdparty+=("$pkg")
            fi
        fi
    done <<< "$all_packages"

    echo ""
    echo "  Package Classification Summary"
    echo "  ─────────────────────────────────────────────"
    printf "  %-20s %4d packages\n" "Samsung" "${#classified_samsung[@]}"
    printf "  %-20s %4d packages\n" "Carrier" "${#classified_carrier[@]}"
    printf "  %-20s %4d packages\n" "Google Duplicates" "${#classified_google[@]}"
    printf "  %-20s %4d packages\n" "System" "${#classified_system[@]}"
    printf "  %-20s %4d packages\n" "Third Party" "${#classified_thirdparty[@]}"

    # Recommendations
    echo ""
    echo "  Recommendations"
    echo "  ─────────────────────────────────────────────"

    if [[ "${#classified_samsung[@]}" -gt 0 ]]; then
        echo ""
        echo "  Samsung bloatware candidates:"
        for pkg in "${classified_samsung[@]}"; do
            echo "    • $pkg"
        done
        echo "    Use: toolkit.sh --disable-package <pkg> to disable individually"
    fi

    if [[ "${#classified_carrier[@]}" -gt 0 ]]; then
        echo ""
        echo "  Carrier bloatware candidates:"
        for pkg in "${classified_carrier[@]}"; do
            echo "    • $pkg"
        done
    fi

    if [[ "${#classified_google[@]}" -gt 0 ]]; then
        echo ""
        echo "  Google duplicate apps (replaceable with lighter alternatives):"
        for pkg in "${classified_google[@]}"; do
            echo "    • $pkg"
        done
    fi

    echo ""
    log_info "No packages are disabled automatically. Review and use --disable-package."
}
