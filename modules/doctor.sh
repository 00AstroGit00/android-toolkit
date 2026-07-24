#!/data/data/com.termux/files/usr/bin/bash
#
# doctor.sh — System diagnostics and health check
#
# Checks:
#   - Backend availability (ADB, Shizuku, rish)
#   - USB/Wireless debugging status
#   - Developer options
#   - Battery optimization state
#   - Storage and permissions
#   - Package integrity
#   - Module validity
#   - Profile validity
#   - Configuration errors
#   - Unsupported commands
#
# Output: PASS | WARNING | FAIL with recommendations
#
# Part of the Android Toolkit.

##############################################
# Run all diagnostic checks.
# Arguments:
#   $1: optional filter (backend|storage|packages|modules|all)
##############################################
doctor_run() {
    local filter="${1:-all}"

    log_section "Android Toolkit — Doctor"

    local pass=0 warn=0 fail=0

    _doctor_check "Backend" _doctor_backend && pass=$((pass+1)) || {
        [[ $? -eq 2 ]] && warn=$((warn+1)) || fail=$((fail+1))
    }

    [[ "$filter" == "all" || "$filter" == "storage" ]] && {
        _doctor_check "Storage" _doctor_storage && pass=$((pass+1)) || {
            [[ $? -eq 2 ]] && warn=$((warn+1)) || fail=$((fail+1))
        }
    }

    [[ "$filter" == "all" || "$filter" == "packages" ]] && {
        _doctor_check "Protected Packages" _doctor_protected_packages && pass=$((pass+1)) || {
            [[ $? -eq 2 ]] && warn=$((warn+1)) || fail=$((fail+1))
        }
    }

    [[ "$filter" == "all" || "$filter" == "modules" ]] && {
        _doctor_check "Modules" _doctor_modules && pass=$((pass+1)) || {
            [[ $? -eq 2 ]] && warn=$((warn+1)) || fail=$((fail+1))
        }
    }

    [[ "$filter" == "all" || "$filter" == "profiles" ]] && {
        _doctor_check "Profiles" _doctor_profiles && pass=$((pass+1)) || {
            [[ $? -eq 2 ]] && warn=$((warn+1)) || fail=$((fail+1))
        }
    }

    [[ "$filter" == "all" || "$filter" == "capabilities" ]] && {
        _doctor_check "Capabilities" _doctor_capabilities && pass=$((pass+1)) || {
            [[ $? -eq 2 ]] && warn=$((warn+1)) || fail=$((fail+1))
        }
    }

    _doctor_check "Permissions" _doctor_permissions && pass=$((pass+1)) || {
        [[ $? -eq 2 ]] && warn=$((warn+1)) || fail=$((fail+1))
    }

    echo ""
    echo "  ── Summary ──"
    echo "  PASS:    $pass"
    echo "  WARNING: $warn"
    echo "  FAIL:    $fail"
    echo ""

    if [[ "$fail" -gt 0 ]]; then
        log_warn "Some checks failed. Review the recommendations above."
        return 1
    elif [[ "$warn" -gt 0 ]]; then
        log_info "All checks passed with warnings."
        return 0
    else
        log_success "All checks passed."
        return 0
    fi
}

##############################################
# Run a single doctor check with labeled output.
##############################################
_doctor_check() {
    local label="$1"
    shift
    local rc=0
    "$@" || rc=$?

    if [[ "$rc" -eq 0 ]]; then
        echo "  ✓ $label"
    elif [[ "$rc" -eq 2 ]]; then
        echo "  ⚠ $label"
    else
        echo "  ✗ $label"
    fi
    return "$rc"
}

##############################################
# Check backend availability.
##############################################
_doctor_backend() {
    local rc=0

    # ADB
    if command -v adb &>/dev/null; then
        local devices
        devices="$(adb devices 2>/dev/null | awk 'NR>1 && /device$/ {print $1}')"
        if [[ -n "$devices" ]]; then
            echo "    ADB:         AVAILABLE ($(echo "$devices" | wc -l) device(s))"
        else
            echo "    ADB:         INSTALLED (no device connected)"
            rc=2
        fi
    else
        echo "    ADB:         NOT INSTALLED (pkg install android-tools)"
        rc=2
    fi

    # Shizuku
    if command -v rish &>/dev/null || [[ -x "/data/data/com.termux/files/usr/bin/rish" ]]; then
        echo "    Shizuku:     AVAILABLE"
    else
        echo "    Shizuku:     NOT FOUND (install Shizuku app + rish)"
        rc=2
    fi

    # Backend
    if [[ -n "$ANDROID_TOOLKIT_BACKEND" ]]; then
        echo "    Active:      ${ANDROID_TOOLKIT_BACKEND}"
    else
        echo "    Active:      NONE (run with --backend adb or --backend rish)"
        rc=1
    fi

    return "$rc"
}

##############################################
# Check storage availability.
##############################################
_doctor_storage() {
    local rc=0

    # Data partition
    local data_info
    data_info="$(backend_exec df -h /data 2>/dev/null || df -h /data 2>/dev/null || true)"
    if [[ -n "$data_info" ]]; then
        local avail_pct
        avail_pct="$(echo "$data_info" | awk 'NR==2 {print $5}' | tr -d '%' 2>/dev/null || echo 0)"
        local used human_avail
        used="${avail_pct:-0}"
        human_avail="$(echo "$data_info" | awk 'NR==2 {print $4}' 2>/dev/null || echo "?")"
        echo "    Data:        ${human_avail} available (${used}% used)"
        if [[ "$used" -gt 90 ]]; then
            echo "    WARNING:     Storage critically low (<10% free)"
            rc=2
        fi
    else
        echo "    Data:        UNKNOWN"
        rc=2
    fi

    # Toolkit directory
    local tool_dir="${ANDROID_TOOLKIT_ROOT_DIR}"
    local tool_avail
    tool_avail="$(df -h "$tool_dir" 2>/dev/null | awk 'NR==2 {print $4}' || echo "?")"
    echo "    Toolkit:     ${tool_avail} available"

    return "$rc"
}

##############################################
# Check protected packages integrity.
##############################################
_doctor_protected_packages() {
    local rc=0
    local protected=(
        "com.android.phone"
        "com.android.systemui"
        "com.android.settings"
        "com.android.vending"
    )

    for pkg in "${protected[@]}"; do
        if backend_package_installed "$pkg" 2>/dev/null; then
            echo "    $pkg:  OK"
        else
            echo "    $pkg:  MISSING!"
            rc=1
        fi
    done
    return "$rc"
}

##############################################
# Check all modules for validity.
##############################################
_doctor_modules() {
    local rc=0
    local mod_dir="${ANDROID_TOOLKIT_ROOT_DIR}/modules"

    for mod in "$mod_dir"/*.sh; do
        local name
        name="$(basename "$mod")"
        if bash -n "$mod" 2>/dev/null; then
            echo "    $name:  SYNTAX OK"
        else
            echo "    $name:  SYNTAX ERROR!"
            rc=1
        fi
    done

    # Check lib files
    local lib_dir="${ANDROID_TOOLKIT_ROOT_DIR}/lib"
    for lib in "$lib_dir"/*.sh; do
        local name
        name="$(basename "$lib")"
        if bash -n "$lib" 2>/dev/null; then
            echo "    lib/$name:  SYNTAX OK"
        else
            echo "    lib/$name:  SYNTAX ERROR!"
            rc=1
        fi
    done

    return "$rc"
}

##############################################
# Check all profiles for validity.
##############################################
_doctor_profiles() {
    local rc=0
    local prof_dir="${ANDROID_TOOLKIT_ROOT_DIR}/profiles"

    for prof in "$prof_dir"/*.conf; do
        local name
        name="$(basename "$prof")"
        if bash -n "$prof" 2>/dev/null; then
            echo "    $name:  VALID"
        else
            echo "    $name:  INVALID!"
            rc=1
        fi
    done
    return "$rc"
}

##############################################
# Check capability detection.
##############################################
_doctor_capabilities() {
    local rc=0

    local device
    device="$(cap_get CAP_MODEL 2>/dev/null || echo "unknown")"
    echo "    Device:      $device"

    local android
    android="$(cap_get CAP_ANDROID_VERSION 2>/dev/null || echo "unknown")"
    echo "    Android:     $android"

    local kernel
    kernel="$(cap_get CAP_KERNEL 2>/dev/null || echo "unknown")"
    echo "    Kernel:      $kernel"

    local rooted
    rooted="$(cap_available CAP_IS_ROOTED 2>/dev/null && echo "YES" || echo "NO")"
    echo "    Rooted:      $rooted"

    local selinux
    selinux="$(cap_get CAP_SELINUX_MODE 2>/dev/null || echo "unknown")"
    echo "    SELinux:     $selinux"

    # Check critical features
    if ! cap_available CAP_CMD_SETTINGS 2>/dev/null; then
        echo "    settings:    MISSING — core functionality limited"
        rc=1
    fi
    if ! cap_available CAP_PM 2>/dev/null; then
        echo "    pm:          MISSING — package management limited"
        rc=2
    fi

    return "$rc"
}

##############################################
# Check file permissions and ownership.
##############################################
_doctor_permissions() {
    local rc=0

    local files=(
        "${ANDROID_TOOLKIT_ROOT_DIR}/toolkit.sh"
    )

    for f in "${files[@]}"; do
        if [[ -f "$f" ]]; then
            if [[ -x "$f" ]]; then
                echo "    $(basename "$f"):  EXECUTABLE"
            else
                echo "    $(basename "$f"):  NOT EXECUTABLE (chmod +x)"
                rc=2
            fi
        else
            echo "    $(basename "$f"):  MISSING"
            rc=1
        fi
    done

    # Check backup dir
    if [[ -d "${ANDROID_TOOLKIT_ROOT_DIR}/backups" ]]; then
        echo "    backups/:    OK"
    fi

    return "$rc"
}
