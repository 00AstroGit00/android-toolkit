#!/data/data/com.termux/files/usr/bin/bash
#
# toolkit.sh — Android Toolkit main entry point
# Version: 4.2.0
#
# A modular, non-root Android optimization and diagnostics toolkit.
# Supports ADB (USB/wireless) and Shizuku (rish) backends.
# Targeted at modern Android devices (13–16 / One UI 5–8).
#
# Usage:
#   ./toolkit.sh --help
#   ./toolkit.sh --status
#   ./toolkit.sh --backend adb --report
#   ./toolkit.sh --backend rish --apply performance
#
# Part of the Android Toolkit.

# Fail on pipe failures but NOT on individual command failures,
# since many backend operations may fail gracefully.
set -o pipefail

# ──────────────────────────────────────────────
# Determine project root (must be called from project dir or symlinked)
# ──────────────────────────────────────────────
ANDROID_TOOLKIT_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ANDROID_TOOLKIT_ROOT_DIR

# ──────────────────────────────────────────────
# Read version from VERSION file
# ──────────────────────────────────────────────
ANDROID_TOOLKIT_VERSION="$(cat "${ANDROID_TOOLKIT_ROOT_DIR}/VERSION" 2>/dev/null | head -1 | tr -d '[:space:]')"
ANDROID_TOOLKIT_VERSION="${ANDROID_TOOLKIT_VERSION:-0.0.0}"
export ANDROID_TOOLKIT_VERSION

# ──────────────────────────────────────────────
# Source library files
# ──────────────────────────────────────────────
for _lib in logging detection backup utils backend rollback plugin \
            commands capability_graph events settings json_output dependencies; do
    _lib_path="${ANDROID_TOOLKIT_ROOT_DIR}/lib/${_lib}.sh"
    if [[ -f "$_lib_path" ]]; then
        source "$_lib_path"
    else
        echo "FATAL: Library not found: $_lib_path" >&2
        exit 1
    fi
done

# ──────────────────────────────────────────────
# Source module files (lazy-loaded on demand)
# ──────────────────────────────────────────────
_load_module() {
    local name="$1"
    local path="${ANDROID_TOOLKIT_ROOT_DIR}/modules/${name}.sh"
    if [[ -f "$path" ]]; then
        source "$path"
        return 0
    fi
    log_error "Module not found: $name"
    return 1
}

# ──────────────────────────────────────────────
# CLI argument parsing (must run before init)
# ──────────────────────────────────────────────
ACTION=""
ACTION_ARGS=()
BACKEND_ARG=""
SERIAL_ARG=""
ANDROID_TOOLKIT_DRY_RUN=false
ANDROID_TOOLKIT_TIMEOUT="${ANDROID_TOOLKIT_TIMEOUT:-300}"
JSON_OUTPUT=false

usage() {
    local ver="${ANDROID_TOOLKIT_VERSION}"
    cat <<EOF
╔══════════════════════════════════════════════════════════════╗
║                   Android Toolkit  v${ver}                    ║
║  Non-root optimization & diagnostics for modern devices     ║
╚══════════════════════════════════════════════════════════════╝

USAGE
  toolkit.sh [OPTIONS] <ACTION>

OPTIONS
  -b, --backend <backend>  Backend to use: adb | rish | auto (default: auto)
  -s, --serial <serial>    ADB device serial (only when backend=adb)
  -h, --help               Show this help message
  -v, --verbose            Enable verbose/debug logging
  -n, --dry-run            Print what would change without executing
  --json                   Enable machine-readable JSON output

INFORMATION
  --version                Show version and exit
  --about                  Show detailed version information
  --changelog              Display the changelog

DIAGNOSTICS
  --status                 Show device status summary
  --report                 Generate full device report
  --doctor [filter]        Run system diagnostics
  --audit                  Run security audit (risk score 0-100)
  --benchmark              Run device benchmark
  --enhanced-benchmark [N] Run benchmark N times with median/variance
  --benchmark-history      List saved benchmark results
  --analyze                Run performance analysis with health scores
  --watch                  Real-time device monitoring

OPERATIONS
  --backup                 Create a full settings and packages backup
  --restore <file>         Restore settings from a backup file
  --apply <profile>        Apply a profile (balanced|performance|powersave|light)
  --compile                Force ART bytecode compilation
  --trim-cache             Trim system and app caches
  --refresh-network        Refresh network configuration and DNS
  --disable-package <pkg>  Disable a system package (opt-in)
  --enable-package <pkg>   Re-enable a previously disabled package

SAMSUNG
  --list-bloatware [level] List bloatware (safe|moderate|aggressive|all)
  --samsung-light          Apply Samsung light optimizations

MAINTENANCE
  --update [channel]       Check for updates (stable|beta|nightly)
  --stats                  Show local usage statistics
  --schedule [action]      Manage scheduled tasks (list|add|remove|run)
  --packages recommend     Analyze installed packages and recommend actions
  --deps-check             Check and manage dependencies
  --packages-analyze       Analyze package dependencies and removal risk
  --settings-verify        Verify settings database entries
  --security-harden [dir]  Run expanded security hardening scan
  --plugin-certify [name]  Certify plugin(s) against SDK requirements
  --validate-device [fmt]  Run cross-device validation

VALIDATION & QUALITY
  --release-ready          Full release readiness assessment
  --release-check          Pre-release validation suite
  --static-analysis        Run ShellCheck, shfmt, markdownlint, JSON checks
  --security-review        Audit codebase for security issues
  --repo-health            Repository health audit

DEVELOPER
  --dev <subcommand>       Developer toolkit (lint|format|docs|tests|release|clean)

BUILD
  --package [dir]          Build release artifacts (ZIP, tar.gz, SBOM, docs)

DEVICES
  --devices                List connected ADB devices
  --device <serial>        Select active device
  --all-devices            Run on all connected devices

VALIDATION
  --release-check          Run pre-release validation suite
  --static-analysis        Run ShellCheck, shfmt, markdownlint, JSON checks
  --security-review        Audit codebase for security issues

BUILD
  --sbom [file]            Generate Software Bill of Materials
  --performance [cmd]      Run performance benchmarks (suite|compare|baseline)

EXPORT & COMPARE
  --export report [fmt]    Export device report (md|json|csv|html|zip)
  --compare <r1.json> <r2.json>  Compare two JSON reports

PROFILES
  --profile-manager <sub>  Manage profiles (list|clone|edit|validate|compare|export|import)

DOCUMENTATION
  --docgen [dir]           Generate documentation

ADVANCED
  --rollback [target]      Rollback changes (latest|<ts>|list)
  --plugin <name> [args]   Execute a plugin
  --tui                    Launch interactive terminal UI
  --build                  Build release artifact

EXAMPLES
  toolkit.sh --version                    Show version
  toolkit.sh --status                     Quick device overview
  toolkit.sh --backend rish --report      Full report via Shizuku
  toolkit.sh --backend adb --backup       Backup settings via ADB
  toolkit.sh --dry-run --apply balanced   Preview profile changes
  toolkit.sh --json --status              Machine-readable status
  toolkit.sh --doctor                     Full diagnostics
  toolkit.sh --audit                      Security audit
  toolkit.sh --benchmark                  Device benchmark
  toolkit.sh --enhanced-benchmark 5       Run benchmark 5 times with stats
  toolkit.sh --benchmark-history          Show past benchmark results
  toolkit.sh --watch                      Real-time device monitoring
  toolkit.sh --compare r1.json r2.json    Compare two reports
  toolkit.sh --profile-manager list       List all profiles
  toolkit.sh --profile-manager validate   Validate all profiles
  toolkit.sh --docgen                     Generate documentation
  toolkit.sh --analyze                    Health analysis
  toolkit.sh --list-bloatware safe        List safe Samsung bloatware
  toolkit.sh --update stable              Update to latest stable
  toolkit.sh --deps-check                 Check dependencies
  toolkit.sh --tui                        Interactive menu
  toolkit.sh --export report json         Export report as JSON

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--verbose)
            LOG_LEVEL="debug"
            shift
            ;;
        -b|--backend)
            if [[ -z "$2" || "$2" =~ ^- ]]; then
                log_error "--backend requires an argument: adb, rish, or auto"
                exit 1
            fi
            BACKEND_ARG="$2"
            shift 2
            ;;
        -s|--serial)
            if [[ -z "$2" || "$2" =~ ^- ]]; then
                log_error "--serial requires a device serial argument"
                exit 1
            fi
            SERIAL_ARG="$2"
            shift 2
            ;;
        -n|--dry-run)
            ANDROID_TOOLKIT_DRY_RUN=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            export JSON_OUTPUT
            shift
            ;;
        --watch)
            ACTION="watch"
            shift
            ;;
        --compare)
            ACTION="compare"
            if [[ -z "$2" || "$2" =~ ^- ]]; then
                log_error "--compare requires two report file paths"
                exit 1
            fi
            ACTION_ARGS+=("$2")
            shift 2
            if [[ -z "$1" || "$1" =~ ^- ]]; then
                log_error "--compare requires two report file paths"
                exit 1
            fi
            ACTION_ARGS+=("$1")
            shift
            ;;
        --docgen)
            ACTION="docgen"
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                ACTION_ARGS+=("$2")
                shift 1
            fi
            shift
            ;;
        --profile-manager)
            ACTION="profile_manager"
            if [[ -z "$2" || "$2" =~ ^- ]]; then
                log_error "--profile-manager requires a subcommand"
                exit 1
            fi
            ACTION_ARGS+=("$2")
            shift 2
            while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do
                ACTION_ARGS+=("$1")
                shift
            done
            continue
            ;;
        --enhanced-benchmark)
            ACTION="enhanced_benchmark"
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                ACTION_ARGS+=("$2")
                shift 1
            fi
            shift
            ;;
        --benchmark-history)
            ACTION="benchmark_history"
            shift
            ;;
        --deps-check)
            ACTION="deps_check"
            shift
            ;;
        --device)
            ACTION="device_select"
            if [[ -z "$2" || "$2" =~ ^- ]]; then
                log_error "--device requires a device serial"
                exit 1
            fi
            ACTION_ARGS+=("$2")
            shift 2
            ;;
        --all-devices)
            ACTION="all_devices"
            shift
            ;;
        --devices)
            ACTION="devices_list"
            shift
            ;;
        --release-check)
            ACTION="release_check"
            shift
            ;;
        --static-analysis)
            ACTION="static_analysis"
            shift
            ;;
        --sbom)
            ACTION="sbom"
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                ACTION_ARGS+=("$2")
                shift 1
            fi
            shift
            ;;
        --performance)
            ACTION="performance"
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                ACTION_ARGS+=("$2")
                shift 1
            fi
            shift
            ;;
        --security-review)
            ACTION="security_review"
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                ACTION_ARGS+=("$2")
                shift 1
            fi
            shift
            ;;
        --packages-analyze)
            ACTION="packages_analyze"
            shift
            ;;
        --validate-device)
            ACTION="validate_device"
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                ACTION_ARGS+=("$2")
                shift 1
            fi
            shift
            ;;
        --plugin-certify)
            ACTION="plugin_certify"
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                ACTION_ARGS+=("$2")
                shift 1
            fi
            shift
            ;;
        --settings-verify)
            ACTION="settings_verify"
            shift
            ;;
        --security-harden)
            ACTION="security_harden"
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                ACTION_ARGS+=("$2")
                shift 1
            fi
            shift
            ;;
        --dev)
            ACTION="dev"
            if [[ -z "$2" || "$2" =~ ^- ]]; then
                log_error "--dev requires a subcommand (lint|format|docs|tests|release|clean)"
                exit 1
            fi
            ACTION_ARGS+=("$2")
            shift 2
            ;;
        --repo-health)
            ACTION="repo_health"
            shift
            ;;
        --package)
            ACTION="package"
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                ACTION_ARGS+=("$2")
                shift 1
            fi
            shift
            ;;
        --release-ready)
            ACTION="release_ready"
            shift
            ;;
        --status)
            ACTION="status"
            shift
            ;;
        --report)
            ACTION="report"
            shift
            ;;
        --backup)
            ACTION="backup"
            shift
            ;;
        --restore)
            ACTION="restore"
            if [[ -z "$2" || "$2" =~ ^- ]]; then
                log_error "--restore requires a backup file path"
                exit 1
            fi
            ACTION_ARGS+=("$2")
            shift 2
            ;;
        --apply)
            ACTION="apply"
            if [[ -z "$2" || "$2" =~ ^- ]]; then
                log_error "--apply requires a profile name (balanced|performance|powersave)"
                exit 1
            fi
            ACTION_ARGS+=("$2")
            shift 2
            ;;
        --compile)
            ACTION="compile"
            shift
            ;;
        --trim-cache)
            ACTION="trim_cache"
            shift
            ;;
        --refresh-network)
            ACTION="refresh_network"
            shift
            ;;
        --disable-package)
            ACTION="disable_package"
            if [[ -z "$2" || "$2" =~ ^- ]]; then
                log_error "--disable-package requires a package name"
                exit 1
            fi
            ACTION_ARGS+=("$2")
            shift 2
            ;;
        --enable-package)
            ACTION="enable_package"
            if [[ -z "$2" || "$2" =~ ^- ]]; then
                log_error "--enable-package requires a package name"
                exit 1
            fi
            ACTION_ARGS+=("$2")
            shift 2
            ;;
        --list-bloatware)
            ACTION="list_bloatware"
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                ACTION_ARGS+=("$2")
                shift 1
            fi
            shift
            ;;
        --samsung-light)
            ACTION="samsung_light"
            shift
            ;;
        --doctor)
            ACTION="doctor"
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                ACTION_ARGS+=("$2")
                shift 1
            fi
            shift
            ;;
        --rollback)
            ACTION="rollback"
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                ACTION_ARGS+=("$2")
                shift 1
            fi
            shift
            ;;
        --benchmark)
            ACTION="benchmark"
            shift
            ;;
        --plugin)
            ACTION="plugin"
            if [[ -z "$2" || "$2" =~ ^- ]]; then
                log_error "--plugin requires a plugin name"
                exit 1
            fi
            ACTION_ARGS+=("$2")
            shift 2
            # Collect remaining args for the plugin
            while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do
                ACTION_ARGS+=("$1")
                shift
            done
            continue
            ;;
        --version)
            echo "${ANDROID_TOOLKIT_VERSION}"
            exit 0
            ;;
        --about)
            ACTION="about"
            shift
            ;;
        --changelog)
            ACTION="changelog"
            shift
            ;;
        --update)
            ACTION="update"
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                ACTION_ARGS+=("$2")
                shift 1
            fi
            shift
            ;;
        --stats)
            ACTION="stats"
            shift
            ;;
        --schedule)
            ACTION="schedule"
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                ACTION_ARGS+=("$2")
                shift 1
            fi
            shift
            ;;
        --audit)
            ACTION="audit"
            shift
            ;;
        --analyze)
            ACTION="analyze"
            shift
            ;;
        --packages)
            ACTION="packages"
            if [[ -z "$2" || "$2" =~ ^- ]]; then
                log_error "--packages requires a subcommand (recommend)"
                exit 1
            fi
            ACTION_ARGS+=("$2")
            shift 2
            # Collect additional args
            while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do
                ACTION_ARGS+=("$1")
                shift
            done
            continue
            ;;
        --export)
            ACTION="export"
            if [[ -z "$2" || "$2" =~ ^- ]]; then
                log_error "--export requires a type (report)"
                exit 1
            fi
            ACTION_ARGS+=("$2")
            shift 2
            if [[ -n "$1" && ! "$1" =~ ^-- ]]; then
                ACTION_ARGS+=("$1")
                shift
            fi
            continue
            ;;
        --tui)
            ACTION="tui"
            shift
            ;;
        --build)
            ACTION="build"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            echo ""
            usage
            exit 1
            ;;
    esac
done

# ──────────────────────────────────────────────
# Backend override logic
# ──────────────────────────────────────────────
if [[ -n "$BACKEND_ARG" ]]; then
    case "$BACKEND_ARG" in
        adb)
            if [[ -n "$SERIAL_ARG" ]]; then
                ANDROID_TOOLKIT_ADB_SERIAL="$SERIAL_ARG"
            fi
            ANDROID_TOOLKIT_BACKEND="adb"
            # Verify ADB works
            if ! command -v adb &>/dev/null; then
                log_error "ADB command not found. Install android-tools or platform-tools."
                exit 1
            fi
            if [[ -n "$SERIAL_ARG" ]]; then
                if ! adb devices | grep -q "$SERIAL_ARG"; then
                    log_error "ADB device with serial '$SERIAL_ARG' not found"
                    exit 1
                fi
            else
                if ! adb devices | grep -q 'device$'; then
                    log_error "No ADB device found. Connect a device and authorize debugging."
                    exit 1
                fi
            fi
            log_info "Using ADB backend${SERIAL_ARG:+ (serial: $SERIAL_ARG)}"
            ;;
        rish)
            ANDROID_TOOLKIT_BACKEND="rish"
            if ! command -v rish &>/dev/null; then
                # Try common rish paths
                found=false
                for rp in /data/data/com.termux/files/usr/bin/rish /data/local/tmp/rish; do
                    if [[ -x "$rp" ]]; then
                        ANDROID_TOOLKIT_RISH_PATH="$rp"
                        found=true
                        break
                    fi
                done
                if ! $found; then
                    log_error "rish not found. Install Shizuku and set up terminal access."
                    exit 1
                fi
            fi
            log_info "Using Shizuku/rish backend"
            ;;
        auto)
            backend_detect
            ;;
        *)
            log_error "Invalid backend: '$BACKEND_ARG'. Use adb, rish, or auto."
            exit 1
            ;;
    esac
else
    # Auto-detect if not specified
    backend_detect
fi

# ──────────────────────────────────────────────
# Initialize subsystems
# ──────────────────────────────────────────────
log_init "toolkit"
backup_init
detect_device_info

# Load capabilities (if capabilities module exists)
_load_module "capabilities" 2>/dev/null || true

# Load OEM framework
source "${ANDROID_TOOLKIT_ROOT_DIR}/modules/oem.sh" 2>/dev/null || true
oem_load 2>/dev/null || true

# Load plugins
plugin_load_all 2>/dev/null || true

# Initialize event system
if declare -f events_enable &>/dev/null; then
    events_enable 2>/dev/null || true
fi

# Initialize command registry
if declare -f command_init &>/dev/null; then
    command_init 2>/dev/null || true
fi

# Initialize capability graph
if declare -f cap_graph_init &>/dev/null; then
    cap_graph_init 2>/dev/null || true
fi

# Emit events for started/backend loaded
if declare -f events_emit &>/dev/null; then
    events_emit "toolkit_started" "{\"version\":\"${ANDROID_TOOLKIT_VERSION}\",\"backend\":\"${ANDROID_TOOLKIT_BACKEND:-auto}\"}" 2>/dev/null || true
fi

# ──────────────────────────────────────────────
# Action dispatch
# ──────────────────────────────────────────────
_main() {
    case "$ACTION" in
        status)
            _load_module "reporting"
            reporting_status
            ;;
        report)
            # Load ALL dependent modules for the full report
            _load_module "reporting"
            _load_module "battery"    # provides battery_status()
            _load_module "display"    # provides display_status()
            _load_module "network"    # provides network_status()
            _load_module "samsung"    # provides samsung_info()
            reporting_full_report
            log_show_file
            ;;
        backup)
            local snapshot_file pkg_file
            snapshot_file="$(backup_create_snapshot)"
            pkg_file="$(backup_create_packages)"
            log_success "Backup complete"
            log_info "  Settings: $snapshot_file"
            log_info "  Packages: $pkg_file"
            log_show_file
            ;;
        restore)
            backup_restore "${ACTION_ARGS[0]}"
            ;;
        apply)
            _load_module "performance"
            performance_apply_profile "${ACTION_ARGS[0]}"
            ;;
        compile)
            _load_module "maintenance"
            maintenance_compile
            ;;
        trim_cache)
            _load_module "maintenance"
            maintenance_trim_cache
            ;;
        refresh_network)
            _load_module "network"
            network_refresh
            ;;
        disable_package)
            _load_module "packages"
            packages_disable "${ACTION_ARGS[0]}"
            ;;
        enable_package)
            _load_module "packages"
            packages_enable "${ACTION_ARGS[0]}"
            ;;
        list_bloatware)
            _load_module "samsung"
            samsung_list_bloatware "${ACTION_ARGS[0]:-all}"
            ;;
        samsung_light)
            _load_module "samsung"
            _load_module "performance"
            # Create a pre-apply backup
            backup_create_snapshot "before_samsung_light" > /dev/null
            samsung_apply_light_optimizations
            ;;
        doctor)
            _load_module "doctor"
            doctor_run "${ACTION_ARGS[0]:-}"
            ;;
        rollback)
            rollback_perform "${ACTION_ARGS[0]:-latest}"
            ;;
        benchmark)
            _load_module "benchmark"
            benchmark_run
            ;;
        enhanced_benchmark)
            _load_module "benchmark"
            benchmark_run_enhanced "${ACTION_ARGS[0]:-3}"
            ;;
        benchmark_history)
            _load_module "benchmark"
            benchmark_list_history
            ;;
        watch)
            _load_module "watch"
            watch_run "${ACTION_ARGS[0]:-}"
            ;;
        compare)
            _load_module "compare"
            compare_run "${ACTION_ARGS[0]}" "${ACTION_ARGS[1]}"
            ;;
        docgen)
            _load_module "docgen"
            docgen_run "${ACTION_ARGS[0]:-}"
            ;;
        profile_manager)
            _load_module "profile_manager"
            profile_manager_run "${ACTION_ARGS[@]}"
            ;;
        deps_check)
            if declare -f deps_status &>/dev/null; then
                deps_status
                echo ""
                if ! deps_has all; then
                    echo "  Some dependencies are missing."
                    echo "  Run '--deps-check install' to install missing ones."
                fi
            else
                log_error "Dependency module not available"
                exit 1
            fi
            ;;
        device_select)
            _load_module "devices"
            devices_set_active "${ACTION_ARGS[0]}"
            ;;
        all_devices)
            _load_module "devices"
            devices_handle_all_flag
            ;;
        devices_list)
            _load_module "devices"
            devices_list
            ;;
        release_check)
            _load_module "release_check"
            release_check_run
            ;;
        static_analysis)
            _load_module "static_analysis"
            static_analysis_run_all
            ;;
        sbom)
            _load_module "sbom"
            sbom_generate "${ACTION_ARGS[0]:-}"
            ;;
        performance)
            _load_module "performance_test"
            perf_run "${ACTION_ARGS[0]:-suite}"
            ;;
        security_review)
            _load_module "security_review"
            security_review_run "${ACTION_ARGS[0]:-}"
            ;;
        packages_analyze)
            _load_module "packages_analysis"
            packages_full_analysis
            ;;
        validate_device)
            _load_module "validate_device"
            validate_device_run "${ACTION_ARGS[0]:-text}"
            ;;
        plugin_certify)
            _load_module "plugin_certify"
            plugin_certify_run "${ACTION_ARGS[0]:-}"
            ;;
        settings_verify)
            _load_module "settings_verify"
            settings_verify_run
            ;;
        security_harden)
            _load_module "security_harden"
            security_harden_run "${ACTION_ARGS[0]:-}"
            ;;
        dev)
            _load_module "developer"
            dev_run "${ACTION_ARGS[0]:-help}"
            ;;
        repo_health)
            _load_module "repo_health"
            repo_health_run
            ;;
        release_ready)
            _load_module "release_ready"
            release_ready_run
            ;;
        package)
            _load_module "packaging"
            packaging_build "${ACTION_ARGS[0]:-}"
            ;;
        plugin)
            plugin_run "${ACTION_ARGS[@]}"
            ;;
        about)
            echo "Android Toolkit v${ANDROID_TOOLKIT_VERSION}"
            echo "Root: ${ANDROID_TOOLKIT_ROOT_DIR}"
            echo "License: MIT"
            echo "Author: Android Toolkit Contributors"
            echo "Homepage: https://github.com/android-toolkit/toolkit"
            echo "Documentation: See README.md, DEVELOPER.md, PLUGIN_API.md"
            ;;
        changelog)
            if [[ -f "${ANDROID_TOOLKIT_ROOT_DIR}/CHANGELOG.md" ]]; then
                cat "${ANDROID_TOOLKIT_ROOT_DIR}/CHANGELOG.md"
            else
                log_error "CHANGELOG.md not found"
                exit 1
            fi
            ;;
        update)
            _load_module "updater" 2>/dev/null || {
                log_error "Update module not available"
                exit 1
            }
            updater_run "${ACTION_ARGS[0]:-stable}"
            ;;
        stats)
            _load_module "telemetry" 2>/dev/null || {
                log_warning "Telemetry module not loaded — no stats collected yet"
                echo "No statistics available. Stats collection will begin on next run."
            }
            telemetry_show
            ;;
        schedule)
            _load_module "scheduler" 2>/dev/null || {
                log_error "Scheduler module not available"
                exit 1
            }
            scheduler_run "${ACTION_ARGS[@]}"
            ;;
        audit)
            _load_module "audit" 2>/dev/null || {
                log_error "Security audit module not available"
                exit 1
            }
            audit_run
            ;;
        analyze)
            _load_module "analyzer" 2>/dev/null || {
                log_error "Performance analyzer module not available"
                exit 1
            }
            analyzer_run
            ;;
        packages)
            _load_module "packages"
            if [[ "${ACTION_ARGS[0]}" == "recommend" ]]; then
                packages_recommend
            else
                log_error "Unknown packages subcommand: ${ACTION_ARGS[0]:-}. Use 'recommend'."
                exit 1
            fi
            ;;
        export)
            if [[ "${ACTION_ARGS[0]}" == "report" ]]; then
                _load_module "export" 2>/dev/null || {
                    log_error "Export module not available"
                    exit 1
                }
                export_report "${ACTION_ARGS[1]:-md}"
            else
                log_error "Unknown export type: ${ACTION_ARGS[0]:-}. Use 'report'."
                exit 1
            fi
            ;;
        tui)
            local _loader="${ANDROID_TOOLKIT_ROOT_DIR}/modules/dashboard/loader.sh"
            if [[ -f "$_loader" ]]; then
                source "$_loader"
                dashboard_launch
            else
                # Fallback to legacy TUI
                _load_module "tui" 2>/dev/null || {
                    log_error "Dashboard module not available"
                    exit 1
                }
                tui_main
            fi
            ;;
        build)
            _load_module "builder" 2>/dev/null || {
                log_error "Build module not available"
                exit 1
            }
            builder_run
            ;;
        "")
            # Launch interactive dashboard by default
            local _loader="${ANDROID_TOOLKIT_ROOT_DIR}/modules/dashboard/loader.sh"
            if [[ -f "$_loader" ]]; then
                source "$_loader"
                dashboard_launch
            else
                log_error "No action specified. Use --help to see available actions."
                exit 1
            fi
            ;;
        *)
            log_error "Unimplemented action: $ACTION"
            exit 1
            ;;
    esac
}

_main
