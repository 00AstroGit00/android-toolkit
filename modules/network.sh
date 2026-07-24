#!/data/data/com.termux/files/usr/bin/bash
#
# network.sh — Network settings optimization module
#
# Safe, reversible network tweaks:
#   - Refresh network configuration
#   - Toggle mobile data always-on
#   - Disable BLE/WiFi scanning when not needed
#   - DNS flush and private DNS configuration
#   - Network scoring and recommendations
#   - WiFi power save mode
#   - Connectivity check
#
# Part of the Android Toolkit.

##############################################
# Refresh network configuration.
# Includes DNS flush, scanning toggles, and connectivity check.
##############################################
network_refresh() {
    log_section "Network Refresh"

    # 1. Toggle mobile data always-on (can save battery)
    local mobile_data_always_on
    mobile_data_always_on="$(backend_settings_get global mobile_data_always_on 2>/dev/null)"
    if [[ -n "$mobile_data_always_on" ]]; then
        log_info "mobile_data_always_on is currently: $mobile_data_always_on"
        # Setting to 0 can save battery but may cause slower data reconnection
        if [[ "$mobile_data_always_on" != "0" ]]; then
            backend_settings_put global mobile_data_always_on 0
        fi
    else
        log_debug "mobile_data_always_on not available — skipping"
    fi

    # 2. Disable BLE scanning if available
    local ble_scan
    ble_scan="$(backend_settings_get global ble_scan_always_enabled 2>/dev/null)"
    if [[ -n "$ble_scan" ]]; then
        if [[ "$ble_scan" != "0" ]]; then
            backend_settings_put global ble_scan_always_enabled 0
        fi
    else
        log_debug "ble_scan_always_enabled not available — skipping"
    fi

    # 3. WiFi always-on scanning toggle
    local wifi_scan
    wifi_scan="$(backend_settings_get global wifi_scan_always_enabled 2>/dev/null)"
    if [[ -n "$wifi_scan" ]]; then
        if [[ "$wifi_scan" != "0" ]]; then
            backend_settings_put global wifi_scan_always_enabled 0
        fi
    fi

    # 4. WiFi power save mode (can reduce throughput but save battery)
    local wifi_ps
    wifi_ps="$(backend_settings_get global wifi_power_save 2>/dev/null)"
    if [[ -n "$wifi_ps" ]]; then
        log_info "WiFi power save: $wifi_ps"
        # Don't change by default — just report
    fi

    # 5. Network scoring (disable if not needed for diagnostics)
    local net_score
    net_score="$(backend_settings_get global network_scoring_ui_enabled 2>/dev/null)"
    if [[ -n "$net_score" ]]; then
        log_debug "network_scoring_ui_enabled: $net_score"
    fi

    # 6. Attempt DNS refresh via connectivity manager (requires elevated access)
    if [[ "$ANDROID_TOOLKIT_DRY_RUN" != "true" ]]; then
        if backend_require "adb" || backend_require "rish"; then
            log_info "Attempting DNS cache refresh..."
            # Try multiple DNS flush methods
            local dns_flushed=false

            # Method 1: cmd resolver (Android 10+)
            if backend_exec cmd resolver flushdefaultdnscache 2>/dev/null; then
                dns_flushed=true
            fi

            # Method 2: ndc resolver (older Android)
            if [[ "$dns_flushed" != "true" ]]; then
                if backend_exec ndc resolver clearnetdns 0 2>/dev/null; then
                    dns_flushed=true
                fi
            fi

            # Method 3: settings delete (some devices)
            if [[ "$dns_flushed" != "true" ]]; then
                if backend_exec settings delete global dns_resolver_samples 2>/dev/null; then
                    dns_flushed=true
                fi
            fi

            if [[ "$dns_flushed" == "true" ]]; then
                log_success "DNS cache flushed"
            else
                log_debug "DNS flush not supported on this device"
            fi
        fi
    else
        log_info "[DRY-RUN] Would flush DNS cache"
    fi

    # 7. Run a quick connectivity check
    log_info "Checking network connectivity..."
    if command -v ping &>/dev/null; then
        if ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
            log_success "Network: reachable"
        else
            log_warn "Network: unreachable (8.8.8.8 not responding)"
        fi
    else
        log_debug "ping not available — skipping connectivity check"
    fi

    log_success "Network refresh complete"
}

##############################################
# Configure private DNS.
# Arguments:
#   $1: mode (off|auto|hostname)
#   $2: optional hostname (e.g., dns.adguard.com)
##############################################
network_set_private_dns() {
    local mode="$1" hostname="$2"

    log_section "Private DNS Configuration"

    case "$mode" in
        off)
            log_info "Disabling private DNS"
            backend_settings_put global private_dns_mode off
            ;;
        auto)
            log_info "Setting private DNS to automatic"
            backend_settings_put global private_dns_mode automatic
            ;;
        hostname)
            if [[ -z "$hostname" ]]; then
                log_error "Hostname required for private DNS (e.g., dns.adguard.com)"
                return 1
            fi
            log_info "Setting private DNS to: $hostname"
            backend_settings_put global private_dns_mode hostname
            backend_settings_put global private_dns_specifier "$hostname"
            ;;
        *)
            log_error "Invalid DNS mode: '$mode' (use: off, auto, hostname)"
            return 1
            ;;
    esac

    log_success "Private DNS configured"
}

##############################################
# Configure WiFi power save mode.
# Arguments:
#   $1: enabled (true/false)
##############################################
network_set_wifi_power_save() {
    local enable="$1"

    if [[ "$enable" == "true" ]]; then
        log_info "Enabling WiFi power save (may reduce throughput)"
        backend_settings_put global wifi_power_save 1
    else
        log_info "Disabling WiFi power save (maximum throughput)"
        backend_settings_put global wifi_power_save 0
    fi
}

##############################################
# Report current network state.
##############################################
network_status() {
    log_section "Network Status"

    # Mobile data always-on
    local mobile_data
    mobile_data="$(backend_settings_get global mobile_data_always_on 2>/dev/null)"
    utils_print_kv "Mobile Data Always-On" "${mobile_data:-unset}"

    # BLE scanning
    local ble
    ble="$(backend_settings_get global ble_scan_always_enabled 2>/dev/null)"
    utils_print_kv "BLE Always Scanning" "${ble:-unset}"

    # WiFi scanning
    local wifi_scan
    wifi_scan="$(backend_settings_get global wifi_scan_always_enabled 2>/dev/null)"
    utils_print_kv "WiFi Always Scanning" "${wifi_scan:-unset}"

    # WiFi power save
    local wifi_ps
    wifi_ps="$(backend_settings_get global wifi_power_save 2>/dev/null)"
    utils_print_kv "WiFi Power Save" "${wifi_ps:-unset}"

    # Private DNS
    local dns_mode
    dns_mode="$(backend_settings_get global private_dns_mode 2>/dev/null)"
    if [[ -n "$dns_mode" ]]; then
        utils_print_kv "Private DNS Mode" "$dns_mode"
        if [[ "$dns_mode" == "hostname" ]]; then
            local dns_spec
            dns_spec="$(backend_settings_get global private_dns_specifier 2>/dev/null)"
            utils_print_kv "Private DNS Host" "${dns_spec:-unset}"
        fi
    fi

    # Airplane mode
    local airplane
    airplane="$(backend_settings_get global airplane_mode_on 2>/dev/null)"
    utils_print_kv "Airplane Mode" "${airplane:-unset}"

    # Network scoring
    local net_score
    net_score="$(backend_settings_get global network_scoring_ui_enabled 2>/dev/null)"
    if [[ -n "$net_score" ]]; then
        utils_print_kv "Network Scoring" "$net_score"
    fi

    # Connectivity check
    if command -v ping &>/dev/null; then
        if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
            log_success "Internet: connected"
        else
            log_warn "Internet: not reachable"
        fi
    fi
}
