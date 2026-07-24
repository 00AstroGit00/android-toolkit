#!/data/data/com.termux/files/usr/bin/bash
#
# pages.sh — Dashboard Page Handlers
#
# Implements render and key-handler functions
# for every dashboard page.
#
# Part of the Android Toolkit Dashboard.

# ══════════════════════════════════════════════
# DEVICES PAGE
# ══════════════════════════════════════════════

_page_render_devices() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Devices'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Connected devices and backends'
    renderer_reset

    local row=$(( top + 2 ))
    local output
    output="$(devices_list 2>&1 || echo "No devices module loaded.")"
    while IFS= read -r line; do
        renderer_cursor_goto "$row" "$left"
        renderer_fg_256 "$(theme_get fg)"
        printf '%-*s' "$width" "${line:0:width}"
        renderer_reset
        ((row++))
        (( row >= top + height - 1 )) && break
    done <<< "$output"
}

# ══════════════════════════════════════════════
# PERFORMANCE PAGE
# ══════════════════════════════════════════════

_page_render_performance() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Performance'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Profiles, benchmarks, and analysis'
    renderer_reset

    local row=$(( top + 2 ))
    local actions=(
        "1" "Apply Profile — balanced / performance / powersave / light"
        "2" "Run Benchmark — Quick device performance test"
        "3" "Enhanced Benchmark — Multi-run with statistics"
        "4" "Performance Analysis — Health scoring"
        "5" "Profile Manager — List / clone / validate"
    )
    for item in "${actions[@]}"; do
        renderer_cursor_goto "$row" "$left"
        renderer_fg_256 "$(theme_get accent)"
        renderer_bold
        printf '%s' "${item:0:1}"
        renderer_reset
        renderer_fg_256 "$(theme_get fg)"
        printf '  %s' "${item:2}"
        renderer_reset
        ((row++))
    done

    renderer_cursor_goto $(( row + 1 )) "$left"
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    printf 'Press Enter on a numbered action to execute.'
    renderer_reset
}

_page_key_performance() {
    local key="$1"
    case "$key" in
        "1")
            _page_run_profile_menu
            ;;
        "2")
            _load_module "benchmark" 2>/dev/null || true
            menu_msgbox "Benchmark" "$(benchmark_run 2>&1 | head -30)"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "3")
            _load_module "benchmark" 2>/dev/null || true
            local n
            n="$(menu_input "Runs" "Number of runs:" "5")" || return 0
            [[ -z "$n" || ! "$n" =~ ^[0-9]+$ ]] && n=5
            menu_msgbox "Enhanced Benchmark" "$(benchmark_repeated_measure "$n" 2>&1 | head -40)"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "4")
            _load_module "analyzer" 2>/dev/null || true
            menu_msgbox "Analysis" "$(analyzer_run 2>&1 | head -40)"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "5")
            _load_module "profile_manager" 2>/dev/null || true
            menu_msgbox "Profile Manager" "$(profile_manager_list 2>&1 | head -40)"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
    esac
}

_page_run_profile_menu() {
    local prof
    prof="$(menu_select "Select Profile" "Choose a profile:" \
        "balanced"    "Daily-use balanced settings" \
        "performance" "Maximum responsiveness" \
        "powersave"   "Maximum battery life" \
        "light"       "Samsung battery-optimized")" || return 0
    [[ -z "$prof" ]] && return 0
    _load_module "performance" 2>/dev/null || true
    menu_gauge "Applying Profile" "Applying '$prof'..." performance_apply_profile "$prof"
    notify_push "Profile '$prof' applied successfully" "success"
    DASHBOARD_REDRAW_NEEDED=true
}

# ══════════════════════════════════════════════
# OPTIMIZATION PAGE
# ══════════════════════════════════════════════

_page_render_optimization() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Optimization Center'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Categorized device optimizations'
    renderer_reset

    local categories=(
        "1" "Battery — Power saving, thermal management"
        "2" "Display — Resolution, refresh rate, effects"
        "3" "Performance — CPU governor, animations, freezer"
        "4" "Memory — OOM settings, swap, LMK"
        "5" "Network — TCP tweaks, DNS, WiFi optimization"
        "6" "Gaming — Latency, GPU, scheduler tweaks"
        "7" "Samsung — One UI specific optimizations"
        "8" "Cleanup — Cache trim, package cleanup"
    )
    local row=$(( top + 2 ))
    for item in "${categories[@]}"; do
        renderer_cursor_goto "$row" "$left"
        renderer_fg_256 "$(theme_get accent)"
        renderer_bold
        printf '%s' "${item:0:1}"
        renderer_reset
        renderer_fg_256 "$(theme_get fg)"
        printf '  %s' "${item:2}"
        renderer_reset
        ((row++))
    done
}

# ══════════════════════════════════════════════
# PACKAGES PAGE
# ══════════════════════════════════════════════

_page_render_packages() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Package Manager'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Browse, search, disable packages'
    renderer_reset

    local row=$(( top + 2 ))
    local output
    _load_module "packages" 2>/dev/null || true
    output="$(packages_list_third_party 2>&1 | head -$(( height - 2 )) || echo "Packages module loaded.")"
    while IFS= read -r line; do
        renderer_cursor_goto "$row" "$left"
        renderer_fg_256 "$(theme_get fg)"
        printf '%-*s' "$width" "${line:0:width}"
        renderer_reset
        ((row++))
    done <<< "$output"
}

# ══════════════════════════════════════════════
# BLOATWARE PAGE
# ══════════════════════════════════════════════

_page_render_bloatware() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Bloatware Manager'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — List and remove Samsung bloatware'
    renderer_reset

    local row=$(( top + 2 ))
    local actions=(
        "1" "List Safe Bloatware — Generally safe to disable"
        "2" "List Moderate Bloatware — May affect some features"
        "3" "List Aggressive Bloatware — High removal rate"
        "4" "List All Known Samsung Packages"
    )
    for item in "${actions[@]}"; do
        renderer_cursor_goto "$row" "$left"
        renderer_fg_256 "$(theme_get accent)"
        renderer_bold
        printf '%s' "${item:0:1}"
        renderer_reset
        renderer_fg_256 "$(theme_get fg)"
        printf '  %s' "${item:2}"
        renderer_reset
        ((row++))
    done
}

_page_key_bloatware() {
    local key="$1"
    local levels=("" "safe" "moderate" "aggressive" "all")
    local idx=$key
    [[ "$idx" -ge 1 && "$idx" -le 4 ]] || return 0
    local level="${levels[$idx]}"
    _load_module "samsung" 2>/dev/null || true
    local output
    output="$(samsung_list_bloatware "$level" 2>&1)"
    menu_textbox "Bloatware — $level" "$output"
    DASHBOARD_REDRAW_NEEDED=true
}

# ══════════════════════════════════════════════
# BATTERY PAGE
# ══════════════════════════════════════════════

_page_render_battery() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Battery'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Status, optimization, and health'
    renderer_reset

    local row=$(( top + 2 ))
    local output
    _load_module "battery" 2>/dev/null || true
    output="$(battery_status 2>&1 || backend_exec dumpsys battery 2>&1 | head -30 || echo "No battery data.")"
    while IFS= read -r line; do
        renderer_cursor_goto "$row" "$left"
        renderer_fg_256 "$(theme_get fg)"
        printf '%-*s' "$width" "${line:0:width}"
        renderer_reset
        ((row++))
    done <<< "$output"
}

# ══════════════════════════════════════════════
# DISPLAY PAGE
# ══════════════════════════════════════════════

_page_render_display() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Display'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Resolution, density, refresh rate'
    renderer_reset

    local row=$(( top + 2 ))
    local output
    _load_module "display" 2>/dev/null || true
    output="$(display_status 2>&1)"
    while IFS= read -r line; do
        renderer_cursor_goto "$row" "$left"
        renderer_fg_256 "$(theme_get fg)"
        printf '%-*s' "$width" "${line:0:width}"
        renderer_reset
        ((row++))
    done <<< "$output"
}

# ══════════════════════════════════════════════
# NETWORK PAGE
# ══════════════════════════════════════════════

_page_render_network() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Network'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Connectivity, DNS, WiFi status'
    renderer_reset

    local row=$(( top + 2 ))
    local output
    _load_module "network" 2>/dev/null || true
    output="$(network_status 2>&1 || echo "Network module loaded.")"
    while IFS= read -r line; do
        renderer_cursor_goto "$row" "$left"
        renderer_fg_256 "$(theme_get fg)"
        printf '%-*s' "$width" "${line:0:width}"
        renderer_reset
        ((row++))
    done <<< "$output"
}

# ══════════════════════════════════════════════
# SECURITY PAGE
# ══════════════════════════════════════════════

_page_render_security() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Security'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Audit, hardening, and privacy'
    renderer_reset

    local row=$(( top + 2 ))
    local actions=(
        "1" "Run Security Audit — Check device security posture"
        "2" "Security Hardening — Deep codebase security scan"
        "3" "Code Security Review — Audit project code"
    )
    for item in "${actions[@]}"; do
        renderer_cursor_goto "$row" "$left"
        renderer_fg_256 "$(theme_get accent)"
        renderer_bold
        printf '%s' "${item:0:1}"
        renderer_reset
        renderer_fg_256 "$(theme_get fg)"
        printf '  %s' "${item:2}"
        renderer_reset
        ((row++))
    done

    # Security patch info
    local patch selinux
    patch="$(status_get security_patch)"
    selinux="$(status_get selinux)"
    renderer_cursor_goto $(( row + 1 )) "$left"
    renderer_fg_256 "$(theme_get muted)"
    printf 'Security Patch: %s   SELinux: %s' "${patch:-?}" "${selinux:-?}"
    renderer_reset
}

_page_key_security() {
    local key="$1"
    case "$key" in
        "1")
            _load_module "audit" 2>/dev/null || true
            menu_msgbox "Security Audit" "$(audit_run 2>&1 | head -50)"
            ;;
        "2")
            _load_module "security_harden" 2>/dev/null || true
            menu_msgbox "Security Hardening" "$(security_harden_scan 2>&1 | head -50 || echo "Module loaded.")"
            ;;
        "3")
            _load_module "security_review" 2>/dev/null || true
            menu_msgbox "Security Review" "$(security_review_run 2>&1 | head -50 || echo "Module loaded.")"
            ;;
    esac
    DASHBOARD_REDRAW_NEEDED=true
}

# ══════════════════════════════════════════════
# PLUGINS PAGE
# ══════════════════════════════════════════════

_page_render_plugins() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Plugin Manager'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Installed plugins and extensions'
    renderer_reset

    local row=$(( top + 2 ))
    local output
    output="$(plugin_list 2>&1)"
    while IFS= read -r line; do
        renderer_cursor_goto "$row" "$left"
        renderer_fg_256 "$(theme_get fg)"
        printf '%-*s' "$width" "${line:0:width}"
        renderer_reset
        ((row++))
    done <<< "$output"

    local count
    count="$(plugin_list 2>&1 | wc -l)"
    [[ "$count" -gt 0 ]] && count=$(( count - 1 ))
    renderer_cursor_goto $(( row + 1 )) "$left"
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    printf '%d plugin(s) loaded. Use Settings > Plugins for details.' "$count"
    renderer_reset
}

# ══════════════════════════════════════════════
# REPORTS PAGE
# ══════════════════════════════════════════════

_page_render_reports() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Reports Center'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — View and export device reports'
    renderer_reset

    local row=$(( top + 2 ))
    local reports=(
        "1" "Health Report — Quick device health overview"
        "2" "Full Device Report — Comprehensive report"
        "3" "Security Report — Security audit results"
        "4" "Benchmark Report — Performance benchmark data"
        "5" "Compatibility Report — Device compatibility matrix"
    )
    for item in "${reports[@]}"; do
        renderer_cursor_goto "$row" "$left"
        renderer_fg_256 "$(theme_get accent)"
        renderer_bold
        printf '%s' "${item:0:1}"
        renderer_reset
        renderer_fg_256 "$(theme_get fg)"
        printf '  %s' "${item:2}"
        renderer_reset
        ((row++))
    done
}

_page_key_reports() {
    local key="$1"
    _load_module "reporting" 2>/dev/null || true
    local output=""
    case "$key" in
        "1") _load_module "doctor" 2>/dev/null; output="$(doctor_run 2>&1)" ;;
        "2") output="$(reporting_full_report 2>&1)" ;;
        "3") _load_module "audit" 2>/dev/null; output="$(audit_run 2>&1)" ;;
        "4") _load_module "benchmark" 2>/dev/null; output="$(benchmark_run 2>&1)" ;;
        "5") _load_module "compat_matrix" 2>/dev/null; output="$(compat_matrix_generate 2>&1)" ;;
    esac
    [[ -n "$output" ]] && menu_textbox "Report" "$output"
    DASHBOARD_REDRAW_NEEDED=true
}

# ══════════════════════════════════════════════
# BENCHMARKS PAGE
# ══════════════════════════════════════════════

_page_render_benchmarks() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Benchmark Center'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Performance testing and history'
    renderer_reset

    local row=$(( top + 2 ))
    local actions=(
        "1" "Run Quick Benchmark — Standard performance test"
        "2" "Enhanced Benchmark — Multi-run with median/variance"
        "3" "Benchmark History — Past results"
        "4" "Compare with Previous — See improvement/regression"
    )
    for item in "${actions[@]}"; do
        renderer_cursor_goto "$row" "$left"
        renderer_fg_256 "$(theme_get accent)"
        renderer_bold
        printf '%s' "${item:0:1}"
        renderer_reset
        renderer_fg_256 "$(theme_get fg)"
        printf '  %s' "${item:2}"
        renderer_reset
        ((row++))
    done
}

_page_key_benchmarks() {
    local key="$1"
    _load_module "benchmark" 2>/dev/null || true
    case "$key" in
        "1") menu_msgbox "Benchmark" "$(benchmark_run 2>&1 | head -50)" ;;
        "2")
            local n
            n="$(menu_input "Runs" "Number of runs:" "5")" || return 0
            [[ -z "$n" || ! "$n" =~ ^[0-9]+$ ]] && n=5
            menu_msgbox "Enhanced Benchmark" "$(benchmark_repeated_measure "$n" 2>&1 | head -50)"
            ;;
        "3") menu_msgbox "History" "$(benchmark_list_history 2>&1 | head -50)" ;;
        "4") menu_msgbox "Comparison" "$(benchmark_compare_previous 2>&1 | head -50)" ;;
    esac
    DASHBOARD_REDRAW_NEEDED=true
}

# ══════════════════════════════════════════════
# VALIDATION PAGE
# ══════════════════════════════════════════════

_page_render_validation() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Validation'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Release readiness and quality checks'
    renderer_reset

    local row=$(( top + 2 ))
    local actions=(
        "1" "Release Readiness — Full release assessment"
        "2" "Pre-release Check — Validation suite"
        "3" "Static Analysis — ShellCheck, shfmt, lint"
        "4" "Repository Health — Git repo audit"
        "5" "Validate Device — Cross-device validation"
    )
    for item in "${actions[@]}"; do
        renderer_cursor_goto "$row" "$left"
        renderer_fg_256 "$(theme_get accent)"
        renderer_bold
        printf '%s' "${item:0:1}"
        renderer_reset
        renderer_fg_256 "$(theme_get fg)"
        printf '  %s' "${item:2}"
        renderer_reset
        ((row++))
    done
}

_page_key_validation() {
    local key="$1"
    case "$key" in
        "1") _load_module "release_ready" 2>/dev/null; menu_msgbox "Release Readiness" "$(release_ready_run 2>&1 | head -50 || echo "Module loaded.")" ;;
        "2") _load_module "release_check" 2>/dev/null; menu_msgbox "Pre-release Check" "$(release_check_run 2>&1 | head -50 || echo "Module loaded.")" ;;
        "3") _load_module "static_analysis" 2>/dev/null; menu_msgbox "Static Analysis" "$(static_analysis_run 2>&1 | head -50 || echo "Module loaded.")" ;;
        "4") _load_module "repo_health" 2>/dev/null; menu_msgbox "Repo Health" "$(repo_health_run 2>&1 | head -50 || echo "Module loaded.")" ;;
        "5") _load_module "validate_device" 2>/dev/null; menu_msgbox "Device Validation" "$(validate_device_run 2>&1 | head -50 || echo "Module loaded.")" ;;
    esac
    DASHBOARD_REDRAW_NEEDED=true
}

# ══════════════════════════════════════════════
# COMPATIBILITY PAGE
# ══════════════════════════════════════════════

_page_render_compatibility() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Compatibility'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Device and module compatibility matrix'
    renderer_reset

    local row=$(( top + 2 ))
    local output
    _load_module "compat_matrix" 2>/dev/null || true
    output="$(compat_matrix_generate 2>&1 | head -$(( height - 2 )) || echo "Compatibility module loaded.")"
    while IFS= read -r line; do
        renderer_cursor_goto "$row" "$left"
        renderer_fg_256 "$(theme_get fg)"
        printf '%-*s' "$width" "${line:0:width}"
        renderer_reset
        ((row++))
    done <<< "$output"
}

# ══════════════════════════════════════════════
# LOGS PAGE
# ══════════════════════════════════════════════

_page_render_logs() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Logs'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Toolkit activity log'
    renderer_reset

    local row=$(( top + 2 ))
    local logfile="${LOG_FILE:-${ANDROID_TOOLKIT_ROOT_DIR}/logs/toolkit_latest.log}"
    if [[ -f "$logfile" ]]; then
        local output
        output="$(tail -$(( height - 2 )) "$logfile" 2>/dev/null)"
        while IFS= read -r line; do
            renderer_cursor_goto "$row" "$left"
            renderer_fg_256 "$(theme_get fg)"
            printf '%-*s' "$width" "${line:0:width}"
            renderer_reset
            ((row++))
        done <<< "$output"
    else
        renderer_cursor_goto "$row" "$left"
        renderer_fg_256 "$(theme_get muted)"
        printf 'No log file found.'
        renderer_reset
    fi
}

# ══════════════════════════════════════════════
# SETTINGS PAGE
# ══════════════════════════════════════════════

_page_render_settings() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Settings'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Configuration and preferences'
    renderer_reset

    local row=$(( top + 2 ))
    local actions=(
        "1" "View Configuration — Current settings"
        "2" "Change Theme — dark / light / nord / dracula / catppuccin / classic"
        "3" "Check Dependencies — Verify toolkit dependencies"
        "4" "Benchmark History — Past benchmark results"
        "5" "Usage Statistics — Local toolkit usage"
    )
    for item in "${actions[@]}"; do
        renderer_cursor_goto "$row" "$left"
        renderer_fg_256 "$(theme_get accent)"
        renderer_bold
        printf '%s' "${item:0:1}"
        renderer_reset
        renderer_fg_256 "$(theme_get fg)"
        printf '  %s' "${item:2}"
        renderer_reset
        ((row++))
    done
}

_page_key_settings() {
    local key="$1"
    case "$key" in
        "1")
            menu_textbox "Configuration" "$(config_list 2>&1)"
            ;;
        "2")
            local theme
            theme="$(menu_select "Select Theme" "Choose a color scheme:" \
                "dark"       "Dark theme (default)" \
                "light"      "Light theme" \
                "classic"    "Classic navy theme" \
                "nord"       "Nord polar theme" \
                "dracula"    "Dracula theme" \
                "catppuccin" "Catppuccin theme")" || return 0
            [[ -z "$theme" ]] && return 0
            theme_load "$theme"
            THEME_NAME="$theme"
            notify_push "Theme changed to $theme" "success"
            ;;
        "3")
            menu_msgbox "Dependencies" "$(deps_check 2>&1 || echo "Dependencies: OK")"
            ;;
        "4")
            _load_module "benchmark" 2>/dev/null || true
            menu_msgbox "Benchmark History" "$(benchmark_list_history 2>&1 | head -50)"
            ;;
        "5")
            menu_msgbox "Usage Statistics" "$(usage_stats 2>&1 || echo "Stats module: not available")"
            ;;
    esac
    DASHBOARD_REDRAW_NEEDED=true
}

# ══════════════════════════════════════════════
# HELP PAGE
# ══════════════════════════════════════════════

_page_render_help() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Help & Keyboard Shortcuts'
    renderer_reset

    local row=$(( top + 2 ))
    local help_lines=(
        "Navigation:"
        "  ↑ / ↓      Navigate sidebar or list items"
        "  ← / ESC    Go back to previous page"
        "  → / Enter  Select current item"
        "  Tab        Cycle to next page"
        "  Q / Ctrl+C  Quit dashboard"
        ""
        "Actions:"
        "  F1         Show this help screen"
        "  F5 / Ctrl+R  Refresh all data"
        "  Ctrl+L     Redraw screen"
        ""
        "Dashboard Pages:"
        "  Dashboard    — Live device overview with widgets"
        "  Devices      — Connected device management"
        "  Performance  — Profiles, benchmarks, analysis"
        "  Optimization — Battery, display, memory, network"
        "  Packages     — Package browser and management"
        "  Bloatware    — Samsung bloatware removal"
        "  Battery      — Battery status and optimization"
        "  Display      — Resolution, density settings"
        "  Network      — Connectivity and DNS"
        "  Security     — Audit, hardening, review"
        "  Plugins      — Plugin manager"
        "  Reports      — View and export reports"
        "  Benchmarks   — Performance testing"
        "  Validation   — Release readiness checks"
        "  Compatibility— Device compatibility matrix"
        "  Logs         — Toolkit activity logs"
        "  Settings     — Configuration and themes"
        ""
        "Phase 3 — Enterprise Console:"
        "  Multi-Device  — Workspace with broadcast & group ops"
        "  Compare       — Side-by-side device comparison"
        "  AI Assistant  — Rules-based device expert"
        "  Terminal      — Managed console with safe mode"
        "  Automation    — Workflows, builder, scheduler"
        "  Diagnostics   — Health checks & scoring"
        "  Perf Monitor  — Live CPU/mem/temp graphs"
        "  Plugin Center — Plugin dev & validation"
        "  Docs          — Searchable documentation browser"
        "  Audit Trail   — Action history & export"
        "  Sessions      — Save/restore dashboard state"
        "  Enterprise    — Central settings hub"
        "  Security Ctr  — Scoring & hardening center"
        ""
        "Phase 4 — Autonomous Operations & Intelligence:"
        "  Digital Twin  — Virtual device representation"
        "  Timeline      — Complete historical event log"
        "  Health Intel  — Weighted multi-category scoring"
        "  Predictive    — Trend analysis & forecasting"
        "  Recommendations— Evidence-based ranked suggestions"
        "  Fleet         — Enterprise multi-device management"
        "  Policies      — Configurable compliance policies"
        "  Report Studio — Executive reports (MD/HTML/JSON)"
        "  System Map    — Live dependency visualization"
        "  Recorder      — Record/replay user workflows"
        "  Recovery      — Rollback points & restoration"
        "  Knowledge     — Searchable integrated docs"
        "  Profiler      — Toolkit execution timing analysis"
        "  Plugin Sandbox— Plugin monitoring & isolation"
        "  Profiles      — Role-based dashboard layouts"
        "  Offline       — Graceful offline operation"
        "  Event Bus     — Centralized inter-module events"
        ""
        "For more details:"
        "  https://github.com/00AstroGit00/android-toolkit"
    )

    for line in "${help_lines[@]}"; do
        renderer_cursor_goto "$row" "$left"
        if [[ "$line" == "" ]]; then
            # empty line
            :
        elif [[ "$line" =~ ^[[:space:]]*[A-Z] ]]; then
            renderer_bold
            renderer_fg_256 "$(theme_get accent)"
            printf '%-*s' "$width" "${line:0:width}"
            renderer_reset
        else
            renderer_fg_256 "$(theme_get fg)"
            printf '%-*s' "$width" "${line:0:width}"
            renderer_reset
        fi
        ((row++))
        (( row > top + height - 1 )) && break
    done
}

# ══════════════════════════════════════════════
# ABOUT PAGE
# ══════════════════════════════════════════════

_page_render_about() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'About Android Toolkit'
    renderer_reset

    local row=$(( top + 2 ))
    local lines=(
        "Android Toolkit v$(status_get version)"
        ""
        "A modular, non-root Android optimization and"
        "diagnostics toolkit for modern devices."
        ""
        "Supports Android 13–16 and Samsung One UI 5–8."
        "Works with ADB (USB/wireless) or Shizuku/rish."
        ""
        "License: MIT"
        "Repository: github.com/00AstroGit00/android-toolkit"
        ""
        "Features:"
        "  • 40+ diagnostic and optimization modules"
        "  • Plugin SDK for community extensions"
        "  • Multi-backend (ADB, Shizuku, rish)"
        "  • Interactive Dashboard (this!)"
        "  • Export to Markdown, JSON, CSV, HTML"
        "  • Scheduled automation"
        "  • Rollback support"
        ""
        "Press Q or Ctrl+C to quit."
    )
    for line in "${lines[@]}"; do
        renderer_cursor_goto "$row" "$left"
        if [[ "$line" == "" ]]; then
            :
        elif [[ "$line" =~ ^[A-Z] ]]; then
            renderer_bold
            renderer_fg_256 "$(theme_get fg)"
            printf '%-*s' "$width" "${line:0:width}"
            renderer_reset
        elif [[ "$line" =~ ^[[:space:]]*• ]]; then
            renderer_fg_256 "$(theme_get success)"
            printf '%-*s' "$width" "${line:0:width}"
            renderer_reset
        else
            renderer_fg_256 "$(theme_get fg)"
            printf '%-*s' "$width" "${line:0:width}"
            renderer_reset
        fi
        ((row++))
    done
}

# ══════════════════════════════════════════════
# REGISTER ALL PAGES
# ══════════════════════════════════════════════

##############################################
# Register all dashboard page handlers.
dashboard_register_all_pages() {
    dashboard_register_page "dashboard"     "_page_render_dashboard"
    dashboard_register_page "devices"       "_page_render_devices"
    dashboard_register_page "performance"   "_page_render_performance"   "_page_key_performance"
    dashboard_register_page "optimization"  "_page_render_optimization"
    dashboard_register_page "packages"      "_page_render_packages"
    dashboard_register_page "bloatware"     "_page_render_bloatware"     "_page_key_bloatware"
    dashboard_register_page "battery"       "_page_render_battery"
    dashboard_register_page "display"       "_page_render_display"
    dashboard_register_page "network"       "_page_render_network"
    dashboard_register_page "security"      "_page_render_security"      "_page_key_security"
    dashboard_register_page "plugins"       "_page_render_plugins"
    dashboard_register_page "reports"       "_page_render_reports"       "_page_key_reports"
    dashboard_register_page "benchmarks"    "_page_render_benchmarks"    "_page_key_benchmarks"
    dashboard_register_page "validation"    "_page_render_validation"    "_page_key_validation"
    dashboard_register_page "compatibility" "_page_render_compatibility"
    dashboard_register_page "logs"          "_page_render_logs"
    dashboard_register_page "settings"      "_page_render_settings"      "_page_key_settings"
    dashboard_register_page "help"          "_page_render_help"
    dashboard_register_page "about"         "_page_render_about"

    # ── Phase 3 — Enterprise Console ──
    dashboard_register_page "multi_device"      "_page_render_multi_device"        "_page_key_multi_device"
    dashboard_register_page "device_compare"    "_page_render_device_compare"
    dashboard_register_page "ai_assistant"      "_page_render_ai_assistant"        "_page_key_ai_assistant"
    dashboard_register_page "terminal"          "_page_render_terminal"            "_page_key_terminal"
    dashboard_register_page "automation"        "_page_render_automation"          "_page_key_automation"
    dashboard_register_page "diagnostics"       "_page_render_diagnostics"         "_page_key_diagnostics"
    dashboard_register_page "perf_monitor"      "_page_render_perf_monitor"        "_page_key_perf_monitor"
    dashboard_register_page "plugin_center"     "_page_render_plugin_center"       "_page_key_plugin_center"
    dashboard_register_page "doc_browser"       "_page_render_doc_browser"         "_page_key_doc_browser"
    dashboard_register_page "audit_trail"       "_page_render_audit_trail"         "_page_key_audit_trail"
    dashboard_register_page "session_manager"   "_page_render_session_manager"     "_page_key_session_manager"
    dashboard_register_page "enterprise_settings" "_page_render_enterprise_settings" "_page_key_enterprise_settings"
    dashboard_register_page "security_center"   "_page_render_security_center"     "_page_key_security_center"

    # ── Phase 4 — Autonomous Operations & Intelligence ──
    dashboard_register_page "event_bus"          "_page_render_event_bus"           "_page_key_event_bus"
    dashboard_register_page "digital_twin"       "_page_render_digital_twin"        "_page_key_digital_twin"
    dashboard_register_page "timeline"           "_page_render_timeline"            "_page_key_timeline"
    dashboard_register_page "health_intel"       "_page_render_health_intel"        "_page_key_health_intel"
    dashboard_register_page "predictive"         "_page_render_predictive"          "_page_key_predictive"
    dashboard_register_page "recommendations"    "_page_render_recommendations"     "_page_key_recommendations"
    dashboard_register_page "fleet"              "_page_render_fleet"               "_page_key_fleet"
    dashboard_register_page "policies"           "_page_render_policies"            "_page_key_policies"
    dashboard_register_page "report_studio"      "_page_render_report_studio"       "_page_key_report_studio"
    dashboard_register_page "system_map"         "_page_render_system_map"          "_page_key_system_map"
    dashboard_register_page "workflow_recorder"  "_page_render_workflow_recorder"   "_page_key_workflow_recorder"
    dashboard_register_page "recovery_center"    "_page_render_recovery_center"     "_page_key_recovery_center"
    dashboard_register_page "knowledge_base"     "_page_render_knowledge_base"      "_page_key_knowledge_base"
    dashboard_register_page "perf_profiler"      "_page_render_perf_profiler"       "_page_key_perf_profiler"
    dashboard_register_page "plugin_sandbox"     "_page_render_plugin_sandbox"      "_page_key_plugin_sandbox"
    dashboard_register_page "profiles"           "_page_render_profiles"            "_page_key_profiles"
    dashboard_register_page "offline_mode"       "_page_render_offline_mode"        "_page_key_offline_mode"
}
