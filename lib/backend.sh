#!/data/data/com.termux/files/usr/bin/bash
#
# backend.sh — ADB and Shizuku/rish backend handling
#
# This module detects and manages the execution backend:
#   - adb:   Connected via ADB (USB or wireless) from a computer or local ADB
#   - rish:  Shizuku's rish shell (elevated ADB-level privileges on-device)
#   - local: Direct Termux shell (limited, no elevated access)
#
# rish Integration Notes:
#   - rish requires Shizuku to be running (started via ADB or root)
#   - Two files are needed: rish script + rish_shizuku.dex
#   - Both should be in $PREFIX/bin/ (e.g., /data/data/com.termux/files/usr/bin/)
#   - The rish script must have PKG replaced with the actual package name
#   - RISH_PRESERVE_ENV=0 prevents Termux PATH/LD_PRELOAD leaking to remote shell
#   - When running under adb backend, rish defaults to RISH_PRESERVE_ENV=0
#
# Part of the Android Toolkit.

ANDROID_TOOLKIT_BACKEND=""
ANDROID_TOOLKIT_ADB_SERIAL=""
ANDROID_TOOLKIT_RISH_PATH=""

##############################################
# Detect which backend is available.
# Sets ANDROID_TOOLKIT_BACKEND to one of:
#   adb, rish, local
# Globals:
#   ANDROID_TOOLKIT_BACKEND
#   ANDROID_TOOLKIT_ADB_SERIAL
#   ANDROID_TOOLKIT_RISH_PATH
##############################################
backend_detect() {
    # 1. Check if ADB is available and has a device
    if command -v adb &>/dev/null; then
        local devices
        devices="$(adb devices 2>/dev/null | awk 'NR>1 && /device$/ {print $1}')"
        if [[ -n "$devices" ]]; then
            ANDROID_TOOLKIT_BACKEND="adb"
            ANDROID_TOOLKIT_ADB_SERIAL="$(echo "$devices" | head -1)"
            log_info "Backend: ADB (serial: $ANDROID_TOOLKIT_ADB_SERIAL)"
            return 0
        fi
    fi

    # 2. Check if rish (Shizuku shell) is available in PATH
    if command -v rish &>/dev/null; then
        ANDROID_TOOLKIT_RISH_PATH="$(command -v rish)"
        if _rish_validate "$ANDROID_TOOLKIT_RISH_PATH"; then
            ANDROID_TOOLKIT_BACKEND="rish"
            log_info "Backend: Shizuku/rish (path: $ANDROID_TOOLKIT_RISH_PATH)"
            return 0
        fi
    fi

    # 3. Check for rish in common Termux and Android locations
    local rish_candidates=(
        "/data/data/com.termux/files/usr/bin/rish"
        "/data/local/tmp/rish"
        "/storage/emulated/0/Android/data/moe.shizuku.privileged.api/files/rish"
        "/sdcard/Android/data/moe.shizuku.privileged.api/files/rish"
        "/data/data/moe.shizuku.privileged.api/files/rish"
    )
    for rpath in "${rish_candidates[@]}"; do
        if [[ -x "$rpath" ]]; then
            if _rish_validate "$rpath"; then
                ANDROID_TOOLKIT_BACKEND="rish"
                ANDROID_TOOLKIT_RISH_PATH="$rpath"
                log_info "Backend: Shizuku/rish (path: $ANDROID_TOOLKIT_RISH_PATH)"
                return 0
            fi
        fi
    done

    # 4. Fallback: local shell (no elevated privileges)
    ANDROID_TOOLKIT_BACKEND="local"
    log_warn "Backend: local (no ADB or rish found — limited functionality)"
    return 0
}

##############################################
# Validate that a rish binary actually works.
# Sets RISH_PRESERVE_ENV appropriately.
# Arguments:
#   $1: path to rish binary
# Returns: 0 if rish works, 1 otherwise
##############################################
_rish_validate() {
    local rpath="$1"

    # Check the rish script has the PKG variable set correctly
    if grep -q 'PKG=' "$rpath" 2>/dev/null; then
        local pkg_val
        pkg_val="$(grep 'PKG=' "$rpath" | head -1 | sed 's/.*PKG=//')"
        if [[ "$pkg_val" == "PKG" || -z "$pkg_val" ]]; then
            log_warn "rish PKG not configured in $rpath — attempting anyway"
        fi
    fi

    # Set RISH_PRESERVE_ENV=0 to prevent Termux PATH leakage
    # This is important when running under adb backend
    export RISH_PRESERVE_ENV=0

    # Verify rish actually works by running a simple command
    if "$rpath" -c 'echo rish_ok' 2>/dev/null | grep -q rish_ok; then
        return 0
    fi

    # Try with explicit RISH_PRESERVE_ENV=1 (root backend)
    if RISH_PRESERVE_ENV=1 "$rpath" -c 'echo rish_ok' 2>/dev/null | grep -q rish_ok; then
        export RISH_PRESERVE_ENV=1
        return 0
    fi

    return 1
}

##############################################
# Confirms a specific backend is available.
# Arguments:
#   $1: backend name (adb, rish, local)
# Returns: 0 if available, 1 otherwise
##############################################
backend_require() {
    local required="$1"
    if [[ "$ANDROID_TOOLKIT_BACKEND" == "$required" ]]; then
        return 0
    fi
    # If backend hasn't been detected yet, try detection
    if [[ -z "$ANDROID_TOOLKIT_BACKEND" ]]; then
        backend_detect
        if [[ "$ANDROID_TOOLKIT_BACKEND" == "$required" ]]; then
            return 0
        fi
    fi
    log_error "Backend '$required' is required but not available (current: '${ANDROID_TOOLKIT_BACKEND:-none}')"
    return 1
}

##############################################
# Build the shell command string for the active backend.
# Arguments:
#   $@: command and arguments
# Returns: the full command string (stdout)
##############################################
_backend_build_cmd() {
    if [[ -z "$ANDROID_TOOLKIT_BACKEND" ]]; then
        backend_detect
    fi

    case "$ANDROID_TOOLKIT_BACKEND" in
        adb)
            if [[ -n "$ANDROID_TOOLKIT_ADB_SERIAL" ]]; then
                echo "adb -s $ANDROID_TOOLKIT_ADB_SERIAL shell $*"
            else
                echo "adb shell $*"
            fi
            ;;
        rish)
            if [[ -n "$ANDROID_TOOLKIT_RISH_PATH" ]]; then
                echo "RISH_PRESERVE_ENV=${RISH_PRESERVE_ENV:-0} $ANDROID_TOOLKIT_RISH_PATH -c '$*'"
            else
                echo "RISH_PRESERVE_ENV=${RISH_PRESERVE_ENV:-0} rish -c '$*'"
            fi
            ;;
        local)
            echo "$*"
            ;;
        *)
            return 1
            ;;
    esac
}

##############################################
# Run a shell command using the detected backend.
# For ADB, prepends "adb shell".
# For rish, uses "rish -c" with RISH_PRESERVE_ENV.
# For local, runs directly.
# In dry-run mode, prints what would be executed.
# Arguments:
#   $@: command and arguments to execute
# Returns: exit code of the command
##############################################
backend_exec() {
    if [[ -z "$ANDROID_TOOLKIT_BACKEND" ]]; then
        backend_detect
    fi

    if [[ "$ANDROID_TOOLKIT_DRY_RUN" == "true" ]]; then
        local cmd_str
        cmd_str="$(_backend_build_cmd "$@")" || {
            log_warn "Dry-run: could not build command string"
            return 0
        }
        log_info "[DRY-RUN] $cmd_str"
        return 0
    fi

    case "$ANDROID_TOOLKIT_BACKEND" in
        adb)
            if [[ -n "$ANDROID_TOOLKIT_ADB_SERIAL" ]]; then
                adb -s "$ANDROID_TOOLKIT_ADB_SERIAL" shell "$@"
            else
                adb shell "$@"
            fi
            ;;
        rish)
            # rish passes arguments as a single string to the remote shell
            local rish_env="${RISH_PRESERVE_ENV:-0}"
            if [[ -n "$ANDROID_TOOLKIT_RISH_PATH" ]]; then
                RISH_PRESERVE_ENV="$rish_env" "$ANDROID_TOOLKIT_RISH_PATH" -c "$*"
            else
                RISH_PRESERVE_ENV="$rish_env" rish -c "$*"
            fi
            ;;
        local)
            eval "$@"
            ;;
        *)
            log_error "No valid backend to execute command"
            return 1
            ;;
    esac
}

##############################################
# Run a command with "cmd" prefix (for service commands).
# This handles the common pattern: cmd <service> <command>
# Arguments:
#   $@: cmd service and arguments
##############################################
backend_cmd() {
    backend_exec cmd "$@"
}

##############################################
# Read a system property via getprop.
# Arguments:
#   $1: property name
# Returns: property value (stdout)
##############################################
backend_getprop() {
    backend_exec getprop "$1" 2>/dev/null | tr -d '\r\n'
}

##############################################
# Read a settings value.
# Arguments:
#   $1: namespace (system, secure, global)
#   $2: key name
# Returns: setting value (stdout), or empty if unset
##############################################
backend_settings_get() {
    local ns="$1" key="$2"
    backend_exec settings get "$ns" "$key" 2>/dev/null | tr -d '\r\n'
}

##############################################
# Load the settings database and look up a key.
# Arguments:
#   $1: namespace (global, secure, system)
#   $2: key name
# Returns: JSON entry as string (stdout), or empty if not found
##############################################
backend_settings_db_lookup() {
    local ns="$1" key="$2"
    local db_path="${ANDROID_TOOLKIT_ROOT_DIR}/configs/settings-db.json"

    if [[ ! -f "$db_path" ]]; then
        return 1
    fi

    # Simple grep-based lookup (no jq dependency needed)
    local entry
    entry="$(grep -A 10 "\"${key}\":" "$db_path" 2>/dev/null | grep -v "^--$" || true)"
    if [[ -n "$entry" ]]; then
        echo "$entry"
        return 0
    fi
    return 1
}

##############################################
# Perform a validated settings write with verification.
# Reads current value, stores rollback, writes, verifies,
# and auto-restores if verification fails.
# Arguments:
#   $1: namespace (system, secure, global)
#   $2: key name
#   $3: value
#   $4: optional rollback journal path
# Returns: 0 on success, 1 on failure
##############################################
backend_settings_put() {
    local ns="$1" key="$2" value="$3"
    local journal="${4:-}"

    # ── Step 1: Probe namespace exists ──
    if ! backend_settings_exists "$key" 2>/dev/null; then
        # Check database for reference
        local db_entry
        db_entry="$(backend_settings_db_lookup "$ns" "$key")"
        if [[ -z "$db_entry" ]]; then
            log_warn "Setting $ns/$key not found in settings database — may not exist on this device"
        fi
    fi

    # ── Step 2: Read current value ──
    local current
    current="$(backend_settings_get "$ns" "$key")"

    # ── Step 3: Check if already set ──
    if [[ "$current" == "$value" ]]; then
        log_debug "Setting $ns/$key already set to '$value' — skipping"
        return 0
    fi

    # ── Step 4: Record rollback ──
    if [[ -n "$journal" && -f "$journal" ]]; then
        rollback_record "$journal" "$ns" "$key" "${current:-unset}" "$value"
    fi

    # ── Step 5: Dry-run check ──
    if [[ "$ANDROID_TOOLKIT_DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would set $ns/$key = '$value' (currently: '${current:-unset}')"
        return 0
    fi

    # ── Step 6: Apply change ──
    log_info "Setting $ns/$key = '$value' (was: '${current:-unset}')"
    if ! backend_exec settings put "$ns" "$key" "$value" 2>/dev/null; then
        log_error "Failed to set $ns/$key = '$value'"
        return 1
    fi

    # ── Step 7: Verify ──
    local verify_val
    verify_val="$(backend_settings_get "$ns" "$key")"
    if [[ "$verify_val" != "$value" ]]; then
        log_warn "Verification FAILED for $ns/$key: expected '$value', got '$verify_val'"
        log_warn "Auto-restoring to previous value: '${current:-unset}'"
        backend_exec settings put "$ns" "$key" "$current" 2>/dev/null || true
        return 1
    fi

    log_debug "Verification OK: $ns/$key = $value"
    return 0
}

##############################################
# Check if a setting key exists in any namespace.
# Arguments:
#   $1: key name to search for
# Returns: 0 if found, 1 otherwise
##############################################
backend_settings_exists() {
    local key="$1"
    local found
    found="$(backend_exec settings list global 2>/dev/null | grep -F "$key" || true)"
    if [[ -n "$found" ]]; then
        return 0
    fi
    found="$(backend_exec settings list secure 2>/dev/null | grep -F "$key" || true)"
    if [[ -n "$found" ]]; then
        return 0
    fi
    found="$(backend_exec settings list system 2>/dev/null | grep -F "$key" || true)"
    if [[ -n "$found" ]]; then
        return 0
    fi
    return 1
}

##############################################
# Check if a package is installed.
# Arguments:
#   $1: package name
# Returns: 0 if installed, 1 otherwise
##############################################
backend_package_installed() {
    local pkg="$1"
    backend_exec pm list packages "$pkg" 2>/dev/null | grep -q "$pkg"
}

##############################################
# List third-party (user-installed) packages.
# Returns: list of package names (stdout)
##############################################
backend_list_third_party_packages() {
    backend_exec pm list packages -3 2>/dev/null | sed 's/^package://'
}

##############################################
# List all packages (including system).
# Returns: list of package names (stdout)
##############################################
backend_list_all_packages() {
    backend_exec pm list packages 2>/dev/null | sed 's/^package://'
}

##############################################
# List disabled packages.
# Returns: list of package names (stdout)
##############################################
backend_list_disabled_packages() {
    backend_exec pm list packages --disabled 2>/dev/null | sed 's/^package://'
}

# NOTE: backend_detect() is called explicitly from toolkit.sh after
# argument parsing, not on module load, to avoid premature detection.
