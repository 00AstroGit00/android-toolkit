#!/data/data/com.termux/files/usr/bin/bash
#
# maintenance.sh — System maintenance module
#
# Provides:
#   - ART bytecode compilation (pm bg-dexopt-job / pm compile)
#   - Per-app compile mode selection
#   - Cache trimming (app caches)
#   - System cache management
#   - Filesystem optimization (fstrim)
#   - Background dexopt job control
#
# ART Compilation Modes (from AOSP):
#   - verify:            Only verification, no compilation
#   - speed-profile:     AOT compile methods found in profile (recommended)
#   - speed:             Full AOT compile (fastest, most storage)
#   - quicken:           Partial compile for better startup (legacy)
#   - everything:        Compile everything AOT
#   - extract:           Extract DEX files, no compilation
#
# Part of the Android Toolkit.

##############################################
# Force background ART (Android Runtime) optimization.
# This recompiles app bytecode for faster startup.
# Safe to run; effects are noticeable after reboot.
# Arguments:
#   $1: optional compile mode (default: speed-profile)
##############################################
maintenance_compile() {
    local mode="${1:-speed-profile}"
    log_section "ART Optimization"

    # Requires ADB or rish
    if ! backend_require "adb" && ! backend_require "rish"; then
        log_error "ART compilation requires ADB or rish backend"
        return 1
    fi

    # Validate compile mode
    case "$mode" in
        speed|speed-profile|verify|quicken|everything|extract)
            ;;
        *)
            log_error "Invalid compile mode: '$mode'"
            log_info "Valid modes: speed, speed-profile, verify, quicken, everything, extract"
            return 1
            ;;
    esac

    if [[ "$ANDROID_TOOLKIT_DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would run: cmd package bg-dexopt-job (mode: $mode)"
        log_info "[DRY-RUN] Would compile all apps with '$mode' filter"
        log_info "[DRY-RUN] Compiler filter details:"
        case "$mode" in
            speed)
                log_info "[DRY-RUN]   speed: Full AOT compilation — fastest runtime, most storage"
                ;;
            speed-profile)
                log_info "[DRY-RUN]   speed-profile: Profile-guided AOT — good balance"
                ;;
            verify)
                log_info "[DRY-RUN]   verify: Verification only — minimal storage, slower startup"
                ;;
        esac
        return 0
    fi

    local timeout="${ANDROID_TOOLKIT_TIMEOUT:-300}"

    log_info "Starting background dexopt job (timeout: ${timeout}s, mode: ${mode})..."
    log_info "This may take several minutes depending on the number of apps."
    log_warn "Device may feel warm during compilation — this is normal."

    # First attempt: pm bg-dexopt-job (preferred, respects device idle state)
    if utils_timeout "$timeout" backend_exec cmd package bg-dexopt-job 2>/dev/null; then
        log_success "Background dexopt job completed successfully"
        return 0
    fi

    # Fallback: pm compile for all apps with the specified mode
    log_info "Background job not triggered; trying direct compilation..."
    log_info "Compiling all apps with '$mode' filter..."

    maintenance_compile_all "$mode"
}

##############################################
# Compile all packages with a specific filter.
# Arguments:
#   $1: compile mode (speed|speed-profile|verify|quicken|everything|extract)
##############################################
maintenance_compile_all() {
    local mode="${1:-speed-profile}"

    local pkg_list
    pkg_list="$(backend_list_all_packages)"
    local count=0
    local errors=0
    local total
    total="$(echo "$pkg_list" | grep -c . || echo 0)"

    while IFS= read -r pkg; do
        if [[ -z "$pkg" ]]; then
            continue
        fi
        # Apply per-package timeout (shorter per package)
        if utils_timeout 30 backend_exec cmd package compile -m "$mode" -f "$pkg" 2>/dev/null; then
            count=$((count + 1))
        else
            errors=$((errors + 1))
        fi
        if [[ $((count % 20)) -eq 0 && "$count" -gt 0 ]]; then
            log_info "  Compiled $count of $total packages..."
        fi
    done <<< "$pkg_list"

    log_success "Compilation requested for $count packages (errors: $errors)"
    log_info "Full optimization completes after a charge cycle with device idle."
}

##############################################
# Compile a specific package.
# Arguments:
#   $1: package name
#   $2: optional compile mode (default: speed-profile)
##############################################
maintenance_compile_package() {
    local pkg="$1"
    local mode="${2:-speed-profile}"

    if [[ -z "$pkg" ]]; then
        log_error "Package name required"
        return 1
    fi

    log_section "Compile Package: $pkg"

    if ! backend_package_installed "$pkg"; then
        log_error "Package '$pkg' is not installed"
        return 1
    fi

    if [[ "$ANDROID_TOOLKIT_DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would compile '$pkg' with mode '$mode'"
        return 0
    fi

    log_info "Compiling '$pkg' with '$mode' filter..."
    if backend_exec cmd package compile -m "$mode" -f "$pkg" 2>/dev/null; then
        log_success "Package '$pkg' compiled successfully"
    else
        log_error "Failed to compile package '$pkg'"
        return 1
    fi
}

##############################################
# Reset compilation for a specific package.
# Arguments:
#   $1: package name
##############################################
maintenance_compile_reset() {
    local pkg="$1"

    if [[ -z "$pkg" ]]; then
        log_error "Package name required"
        return 1
    fi

    log_section "Reset Compilation: $pkg"

    if [[ "$ANDROID_TOOLKIT_DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would reset compilation for '$pkg'"
        return 0
    fi

    if backend_exec cmd package compile --reset "$pkg" 2>/dev/null; then
        log_success "Compilation reset for '$pkg'"
    else
        log_warn "Could not reset compilation for '$pkg'"
    fi
}

##############################################
# Cancel running background dexopt job.
##############################################
maintenance_compile_cancel() {
    log_section "Cancel Background Dexopt"

    if [[ "$ANDROID_TOOLKIT_DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would cancel background dexopt job"
        return 0
    fi

    if backend_exec pm bg-dexopt-job --cancel 2>/dev/null; then
        log_success "Background dexopt job cancelled"
    else
        log_warn "Could not cancel background dexopt job (may not be running)"
    fi
}

##############################################
# Trim cached data.
# Clears app caches and trims system file caches.
##############################################
maintenance_trim_cache() {
    log_section "Cache Maintenance"

    if ! backend_require "adb" && ! backend_require "rish"; then
        log_error "Cache maintenance requires ADB or rish backend"
        return 1
    fi

    if [[ "$ANDROID_TOOLKIT_DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would clear caches for all packages"
        log_info "[DRY-RUN] Would run: pm trim-caches 999G"
        log_info "[DRY-RUN] Would run: fstrim /data"
        return 0
    fi

    local timeout="${ANDROID_TOOLKIT_TIMEOUT:-300}"

    # 1. Bulk cache trim using pm trim-caches (preferred, faster)
    log_info "Trimming all caches (timeout: ${timeout}s)..."
    if utils_timeout "$timeout" backend_exec pm trim-caches 999G 2>/dev/null; then
        log_success "Cache trim completed via pm trim-caches"
    else
        # Fallback: per-package cache clear
        log_info "pm trim-caches not available; clearing per-package..."
        maintenance_clear_caches_individual
    fi

    # 2. Trim the filesystem (fstrim) if available
    log_info "Running filesystem trim (fstrim)..."
    if backend_exec fstrim /data 2>/dev/null; then
        log_success "Filesystem trimmed (/data)"
    else
        log_debug "fstrim not available — skipping"
    fi

    log_success "Cache maintenance complete"
}

##############################################
# Clear caches per-package (fallback method).
##############################################
maintenance_clear_caches_individual() {
    local pkg_list
    pkg_list="$(backend_list_all_packages)"
    local cleared=0
    local errors=0

    while IFS= read -r pkg; do
        if [[ -z "$pkg" ]]; then
            continue
        fi
        if utils_timeout 30 backend_exec pm clear --cache-only "$pkg" 2>/dev/null; then
            cleared=$((cleared + 1))
        else
            errors=$((errors + 1))
        fi
    done <<< "$pkg_list"

    log_info "Caches cleared for $cleared packages"
    if [[ "$errors" -gt 0 ]]; then
        log_debug "Could not clear cache for $errors packages (may be running)"
    fi
}

##############################################
# Run a quick system health check.
##############################################
maintenance_health_check() {
    log_section "System Health Check"

    # Check storage
    local storage_info
    storage_info="$(backend_exec df -h /data 2>/dev/null || true)"
    if [[ -n "$storage_info" ]]; then
        local avail
        avail="$(echo "$storage_info" | awk 'NR==2 {print $4}')"
        utils_print_kv "Available Storage" "${avail:-unknown}"
    fi

    # Check uptime
    local uptime
    uptime="$(backend_exec cat /proc/uptime 2>/dev/null | awk '{print $1}' || true)"
    if [[ -n "$uptime" ]]; then
        local days hours mins
        days="$(echo "scale=0; $uptime / 86400" | bc 2>/dev/null || echo 0)"
        hours="$(echo "scale=0; ($uptime % 86400) / 3600" | bc 2>/dev/null || echo 0)"
        mins="$(echo "scale=0; ($uptime % 3600) / 60" | bc 2>/dev/null || echo 0)"
        utils_print_kv "Uptime" "${days}d ${hours}h ${mins}m"
    fi

    # Check running services
    local service_count
    service_count="$(backend_exec dumpsys activity services 2>/dev/null | grep -c 'ServiceRecord' || true)"
    utils_print_kv "Running Services" "${service_count:-unknown}"

    # Check ART compilation status
    local compile_stats
    compile_stats="$(backend_exec cmd package dump-profiles 2>/dev/null | head -5 || true)"
    if [[ -n "$compile_stats" ]]; then
        utils_print_kv "ART Profiles" "available"
    fi

    log_success "Health check complete"
}
