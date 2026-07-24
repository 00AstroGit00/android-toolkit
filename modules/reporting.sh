#!/data/data/com.termux/files/usr/bin/bash
#
# reporting.sh — Device status and report generation
#
# Generates comprehensive device reports and quick status summaries.
#
# Part of the Android Toolkit.

##############################################
# Show concise device status overview.
##############################################
reporting_status() {
    log_section "Device Status"
    echo ""

    # Summary line
    echo "  $(detect_device_summary)"
    echo ""

    # Backend
    utils_print_kv "Backend" "${ANDROID_TOOLKIT_BACKEND:-not detected}"
    if [[ -n "$ANDROID_TOOLKIT_ADB_SERIAL" ]]; then
        utils_print_kv "  Serial" "$ANDROID_TOOLKIT_ADB_SERIAL"
    fi

    # Build
    utils_print_kv "Build" "$(echo "${DEVICE_BUILD_FINGERPRINT:-unknown}" | cut -d'/' -f1-3 2>/dev/null || echo 'unknown')"

    # Battery quick status
    local battery_info
    battery_info="$(backend_exec dumpsys battery 2>/dev/null | grep '^[[:space:]]*level:\|^[[:space:]]*scale:' || true)"
    if [[ -n "$battery_info" ]]; then
        local level scale
        level="$(echo "$battery_info" | grep 'level:' | head -1 | awk '{print $2}')"
        scale="$(echo "$battery_info" | grep 'scale:' | head -1 | awk '{print $2}')"
        if [[ -n "$level" && -n "$scale" ]] && [[ "$scale" =~ ^[0-9]+$ ]] && [[ "$scale" -gt 0 ]]; then
            utils_print_kv "Battery" "$(( level * 100 / scale ))%"
        fi
    fi

    # Display
    local wm_size wm_density
    wm_size="$(backend_exec wm size 2>/dev/null | grep -i 'physical' | awk '{print $3}')"
    wm_density="$(backend_exec wm density 2>/dev/null | grep -i 'physical' | awk '{print $3}')"
    utils_print_kv "Display" "${wm_size:-unknown} @ ${wm_density:-?}dpi"

    # Storage
    local storage
    storage="$(backend_exec df -h /data 2>/dev/null | awk 'NR==2 {print $3"/"$2" ("$5")"}')"
    utils_print_kv "Storage" "${storage:-unknown}"

    # Security
    local patch_level
    patch_level="$(backend_getprop ro.build.version.security_patch 2>/dev/null)"
    utils_print_kv "Security Patch" "${patch_level:-unknown}"

    echo ""
    log_info "Use --report for detailed information."
}

##############################################
# Generate a comprehensive device report.
##############################################
reporting_full_report() {
    log_section "Comprehensive Device Report"
    echo ""
    echo "  Generated: $(utils_timestamp)"
    echo ""

    # ── Device Info ──
    echo "  ── Device Information ──"
    utils_print_kv "Manufacturer" "${DEVICE_MANUFACTURER:-unknown}"
    utils_print_kv "Model" "${DEVICE_MODEL:-unknown}"
    utils_print_kv "Android Version" "${DEVICE_ANDROID_VERSION:-unknown}"
    utils_print_kv "SDK Level" "${DEVICE_SDK_VERSION:-unknown}"
    utils_print_kv "One UI Version" "${DEVICE_ONE_UI_VERSION:-not available}"
    utils_print_kv "ABI" "${DEVICE_ABI:-unknown}"
    utils_print_kv "Security Patch" "$(backend_getprop ro.build.version.security_patch 2>/dev/null || echo 'unknown')"
    utils_print_kv "Build Fingerprint" "$(echo "${DEVICE_BUILD_FINGERPRINT:-unknown}" | cut -c1-80)"
    echo ""

    # ── Backend Info ──
    echo "  ── Backend ──"
    utils_print_kv "Active Backend" "${ANDROID_TOOLKIT_BACKEND:-not detected}"
    if [[ -n "$ANDROID_TOOLKIT_ADB_SERIAL" ]]; then
        utils_print_kv "ADB Serial" "$ANDROID_TOOLKIT_ADB_SERIAL"
    fi
    echo ""

    # ── Battery Report ──
    echo "  ── Battery ──"
    battery_status
    echo ""

    # ── Display Report ──
    echo "  ── Display ──"
    display_status
    echo ""

    # ── Network Report ──
    echo "  ── Network ──"
    network_status
    echo ""

    # ── Packages Summary ──
    echo "  ── Packages ──"
    local total_pkgs third_party_pkgs disabled_pkgs
    total_pkgs="$(backend_list_all_packages 2>/dev/null | wc -l)"
    third_party_pkgs="$(backend_list_third_party_packages 2>/dev/null | wc -l)"
    disabled_pkgs="$(backend_exec pm list packages --disabled 2>/dev/null | wc -l)"
    utils_print_kv "Total Packages" "$total_pkgs"
    utils_print_kv "Third-Party" "$third_party_pkgs"
    utils_print_kv "Disabled" "$disabled_pkgs"
    echo ""

    # ── System Properties (key ones) ──
    echo "  ── Key System Properties ──"
    for prop in \
        "dalvik.vm.heapsize" \
        "dalvik.vm.heapgrowthlimit" \
        "ro.sf.lcd_density" \
        "debug.force_rtl" \
        "persist.sys.timezone" \
        "gsm.network.type" \
    ; do
        local val
        val="$(backend_getprop "$prop" 2>/dev/null || true)"
        if [[ -n "$val" ]]; then
            utils_print_kv "$prop" "$val"
        fi
    done
    echo ""

    # ── Samsung-specific Report ──
    if detect_is_samsung; then
        echo "  ── Samsung / One UI ──"
        _load_module "samsung"
        samsung_info
        echo ""

        # Show bloatware count if configured
        local show_bloat
        show_bloat="$(grep -o 'ANDROID_TOOLKIT_SHOW_BLOATWARE=.*' "${ANDROID_TOOLKIT_ROOT_DIR}/configs/default.conf" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || true)"
        if [[ "$show_bloat" == "true" ]]; then
            echo "  ── Samsung Bloatware Summary ──"
            samsung_list_bloatware "all" 2>/dev/null | tail -5
            echo ""
        fi
    fi

    # ── Logging Info ──
    if [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]]; then
        utils_print_kv "Log File" "$LOG_FILE"
    fi
    echo ""
    log_success "Report complete"
}
