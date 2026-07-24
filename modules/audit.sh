#!/data/data/com.termux/files/usr/bin/bash
#
# audit.sh — Security audit module
#
# Audits the device for security issues and produces a risk score (0-100).
# Checks: dangerous permissions, ADB status, developer options, wireless
# debugging, package integrity, disabled critical packages, SELinux, USB
# state, Shizuku status, security patch age, OEM unlock status.
#
# Part of the Android Toolkit.

AUDIT_RESULTS=()
AUDIT_RISK_SCORE=0
AUDIT_MAX_SCORE=0

##############################################
# Add an audit finding.
# Arguments:
#   $1: status (PASS|WARNING|FAIL)
#   $2: check name
#   $3: detail
#   $4: risk contribution (0-5)
##############################################
_audit_add() {
    local status="$1" check="$2" detail="$3" risk="${4:-0}"
    AUDIT_RESULTS+=("$status|$check|$detail|$risk")
    AUDIT_RISK_SCORE=$(( AUDIT_RISK_SCORE + risk ))
    AUDIT_MAX_SCORE=$(( AUDIT_MAX_SCORE + 5 ))
}

##############################################
# Run all security checks.
##############################################
audit_run() {
    log_section "Security Audit"

    AUDIT_RESULTS=()
    AUDIT_RISK_SCORE=0
    AUDIT_MAX_SCORE=0

    log_info "Running security checks..."
    echo ""

    _audit_check_adb_status
    _audit_check_developer_options
    _audit_check_wireless_debugging
    _audit_check_selinux
    _audit_check_usb_state
    _audit_check_shizuku
    _audit_check_security_patch
    _audit_check_oem_unlock
    _audit_check_disabled_packages
    _audit_check_dangerous_permissions

    # Print results
    local pass=0 warn=0 fail=0
    for result in "${AUDIT_RESULTS[@]}"; do
        local status check detail
        status="$(echo "$result" | cut -d'|' -f1)"
        check="$(echo "$result" | cut -d'|' -f2)"
        detail="$(echo "$result" | cut -d'|' -f3)"

        case "$status" in
            PASS)
                printf "  \033[32m✓ PASS\033[0m  %-35s %s\n" "$check" "$detail"
                pass=$((pass + 1))
                ;;
            WARNING)
                printf "  \033[33m⚠ WARN\033[0m  %-35s %s\n" "$check" "$detail"
                warn=$((warn + 1))
                ;;
            FAIL)
                printf "  \033[31m✗ FAIL\033[0m  %-35s %s\n" "$check" "$detail"
                fail=$((fail + 1))
                ;;
        esac
    done

    # Calculate final score
    local score=100
    if [[ "$AUDIT_MAX_SCORE" -gt 0 ]]; then
        score=$(( 100 - (AUDIT_RISK_SCORE * 100 / AUDIT_MAX_SCORE) ))
    fi
    [[ "$score" -lt 0 ]] && score=0

    echo ""
    echo "  ─────────────────────────────────────────────"
    printf "  Security Score: "
    if [[ "$score" -ge 80 ]]; then
        printf "\033[32m%d/100 (Good)\033[0m\n" "$score"
    elif [[ "$score" -ge 50 ]]; then
        printf "\033[33m%d/100 (Fair)\033[0m\n" "$score"
    else
        printf "\033[31m%d/100 (Poor)\033[0m\n" "$score"
    fi
    echo "  Summary: $pass passed, $warn warnings, $fail failures"
    echo ""

    # Recommendations
    local has_recommendations=false
    for result in "${AUDIT_RESULTS[@]}"; do
        local status check detail
        status="$(echo "$result" | cut -d'|' -f1)"
        check="$(echo "$result" | cut -d'|' -f2)"
        detail="$(echo "$result" | cut -d'|' -f3)"

        if [[ "$status" == "FAIL" || "$status" == "WARNING" ]]; then
            if ! $has_recommendations; then
                echo "  Recommendations:"
                has_recommendations=true
            fi
            case "$check" in
                "ADB Status")           echo "    • Disable USB debugging when not in use" ;;
                "Developer Options")    echo "    • Disable Developer options for daily use" ;;
                "Wireless Debugging")   echo "    • Disable wireless debugging when not needed" ;;
                "SELinux")              echo "    • SELinux should be Enforcing" ;;
                "USB Configuration")    echo "    • Set default USB config to 'No data transfer' or 'Charging only'" ;;
                "Security Patch")       echo "    • Install the latest security update" ;;
                "OEM Unlock")           echo "    • OEM Unlock should be disabled on production devices" ;;
                "Disabled Packages")    echo "    • Review disabled packages — some may be critical" ;;
                *)                      echo "    • Review: $check — $detail" ;;
            esac
        fi
    done
}

##############################################
# Check ADB status.
##############################################
_audit_check_adb_status() {
    if [[ "$ANDROID_TOOLKIT_BACKEND" == "adb" ]] || command -v adb &>/dev/null; then
        if backend_exec "settings get global adb_enabled 2>/dev/null" 2>/dev/null | grep -q "1"; then
            _audit_add "WARNING" "ADB Status" "USB debugging is enabled" 3
        else
            _audit_add "PASS" "ADB Status" "USB debugging disabled" 0
        fi
    else
        _audit_add "PASS" "ADB Status" "ADB not available (no risk)" 0
    fi
}

##############################################
# Check if developer options are enabled.
##############################################
_audit_check_developer_options() {
    if backend_exec "settings get global development_settings_enabled 2>/dev/null" 2>/dev/null | grep -q "1"; then
        _audit_add "WARNING" "Developer Options" "Developer options are enabled" 2
    else
        _audit_add "PASS" "Developer Options" "Disabled" 0
    fi
}

##############################################
# Check wireless debugging status.
##############################################
_audit_check_wireless_debugging() {
    if backend_exec "settings get global wireless_debugging_enabled 2>/dev/null" 2>/dev/null | grep -q "1"; then
        _audit_add "FAIL" "Wireless Debugging" "Wireless debugging is enabled — remote attack vector" 5
    else
        _audit_add "PASS" "Wireless Debugging" "Disabled" 0
    fi
}

##############################################
# Check SELinux enforcing status.
##############################################
_audit_check_selinux() {
    local status
    status="$(backend_exec "getenforce 2>/dev/null" 2>/dev/null || echo "Unknown")"
    if echo "$status" | grep -qi "enforcing"; then
        _audit_add "PASS" "SELinux" "Enforcing" 0
    elif echo "$status" | grep -qi "permissive"; then
        _audit_add "FAIL" "SELinux" "Permissive mode — security reduced" 5
    else
        _audit_add "WARNING" "SELinux" "Could not determine status" 2
    fi
}

##############################################
# Check USB default configuration.
##############################################
_audit_check_usb_state() {
    local usb_config
    usb_config="$(backend_exec "settings get global usb_function 2>/dev/null" 2>/dev/null || echo "unknown")"
    if [[ -z "$usb_config" || "$usb_config" == "unknown" ]]; then
        _audit_add "WARNING" "USB Configuration" "Could not determine" 1
    elif [[ "$usb_config" == "mtp" || "$usb_config" == "ptp" ]]; then
        _audit_add "WARNING" "USB Configuration" "File transfer enabled ($usb_config)" 2
    else
        _audit_add "PASS" "USB Configuration" "$usb_config" 0
    fi
}

##############################################
# Check Shizuku status.
##############################################
_audit_check_shizuku() {
    if command -v rish &>/dev/null; then
        _audit_add "WARNING" "Shizuku/rish" "Shizuku API service available" 2
    else
        _audit_add "PASS" "Shizuku/rish" "Not installed" 0
    fi
}

##############################################
# Check security patch age.
##############################################
_audit_check_security_patch() {
    local patch_date
    patch_date="$(backend_exec "getprop ro.build.version.security_patch 2>/dev/null" 2>/dev/null || echo "unknown")"

    if [[ "$patch_date" == "unknown" || -z "$patch_date" ]]; then
        _audit_add "WARNING" "Security Patch" "Could not determine patch date" 2
    else
        # Check if patch is more than 90 days old
        local patch_epoch now_epoch diff_days
        patch_epoch="$(date -d "$patch_date" +%s 2>/dev/null || echo 0)"
        now_epoch="$(date +%s)"

        if [[ "$patch_epoch" -gt 0 ]]; then
            diff_days=$(( (now_epoch - patch_epoch) / 86400 ))
            if [[ "$diff_days" -le 30 ]]; then
                _audit_add "PASS" "Security Patch" "$patch_date ($diff_days days old)" 0
            elif [[ "$diff_days" -le 90 ]]; then
                _audit_add "WARNING" "Security Patch" "$patch_date ($diff_days days old)" 3
            else
                _audit_add "FAIL" "Security Patch" "$patch_date ($diff_days days old — over 90 days)" 5
            fi
        else
            _audit_add "WARNING" "Security Patch" "$patch_date (unparseable date)" 2
        fi
    fi
}

##############################################
# Check OEM unlock status.
##############################################
_audit_check_oem_unlock() {
    local oem_unlock
    oem_unlock="$(backend_exec "getprop ro.oem_unlock_supported 2>/dev/null" 2>/dev/null || echo "0")"

    if [[ "$oem_unlock" == "1" ]]; then
        # Check if actually unlocked
        local unlock_status
        unlock_status="$(backend_exec "getprop ro.boot.verifiedbootstate 2>/dev/null" 2>/dev/null || echo "unknown")"
        if [[ "$unlock_status" == "orange" ]]; then
            _audit_add "FAIL" "OEM Unlock" "Bootloader is unlocked" 5
        else
            _audit_add "WARNING" "OEM Unlock" "OEM unlock supported (may be lockable)" 1
        fi
    else
        _audit_add "PASS" "OEM Unlock" "Not supported or locked" 0
    fi
}

##############################################
# Check for disabled critical packages.
##############################################
_audit_check_disabled_packages() {
    local critical_pkgs=(
        "com.android.phone"
        "com.android.systemui"
        "com.android.settings"
        "com.google.android.gms"
    )
    local disabled_count=0

    for pkg in "${critical_pkgs[@]}"; do
        local state
        state="$(backend_exec "pm list packages -d 2>/dev/null | grep '$pkg'" 2>/dev/null || true)"
        if [[ -n "$state" ]]; then
            disabled_count=$((disabled_count + 1))
        fi
    done

    if [[ "$disabled_count" -gt 0 ]]; then
        _audit_add "FAIL" "Disabled Packages" "$disabled_count critical packages disabled" 5
    else
        _audit_add "PASS" "Disabled Packages" "No critical packages disabled" 0
    fi
}

##############################################
# Check for apps with dangerous permissions.
##############################################
_audit_check_dangerous_permissions() {
    local dangerous_perms=(
        "android.permission.CAMERA"
        "android.permission.RECORD_AUDIO"
        "android.permission.ACCESS_FINE_LOCATION"
        "android.permission.ACCESS_BACKGROUND_LOCATION"
        "android.permission.READ_SMS"
        "android.permission.SEND_SMS"
        "android.permission.READ_CONTACTS"
        "android.permission.READ_CALL_LOG"
        "android.permission.PROCESS_OUTGOING_CALLS"
    )
    local high_risk_apps=0

    for perm in "${dangerous_perms[@]}"; do
        local count
        count="$(backend_exec "cmd appops query-op ${perm} allow 2>/dev/null | wc -l" 2>/dev/null || echo 0)"
        if [[ "$count" -gt 3 ]]; then
            high_risk_apps=$((high_risk_apps + 1))
        fi
    done

    if [[ "$high_risk_apps" -gt 5 ]]; then
        _audit_add "WARNING" "App Permissions" "$high_risk_apps dangerous permission groups with 3+ apps" 3
    elif [[ "$high_risk_apps" -gt 0 ]]; then
        _audit_add "WARNING" "App Permissions" "$high_risk_apps permission groups with many apps" 1
    else
        _audit_add "PASS" "App Permissions" "No excessive dangerous permissions" 0
    fi
}
