#!/data/data/com.termux/files/usr/bin/bash
#
# backup.sh — Backup and restore functionality
#
# Saves and restores device settings with timestamps.
# Backups are stored as text files in the backups/ directory.
# Supports:
#   - Full settings snapshot (system, secure, global)
#   - Package state snapshot (enabled/disabled packages)
#   - Selective restore from a backup
#
# Part of the Android Toolkit.

BACKUP_DIR="${ANDROID_TOOLKIT_ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/backups"

##############################################
# Initialize backup directory.
##############################################
backup_init() {
    mkdir -p "$BACKUP_DIR" 2>/dev/null || true
}

##############################################
# Generate a backup filename with timestamp.
# Arguments:
#   $1: backup type (snapshot, packages, settings, profile)
# Returns: filename (stdout)
##############################################
backup_filename() {
    local type="$1"
    local timestamp
    timestamp="$(date '+%Y%m%d_%H%M%S')"
    echo "${BACKUP_DIR}/${type}_${timestamp}.txt"
}

##############################################
# Create a full settings snapshot.
# Saves system, secure, and global settings namespaces.
# Arguments:
#   $1: optional label/description
# Returns: path to backup file (stdout)
##############################################
backup_create_snapshot() {
    local label="${1:-manual_snapshot}"
    local file
    file="$(backup_filename "snapshot")"

    log_section "Creating Settings Backup"

    {
        echo "# Android Toolkit Snapshot"
        echo "# Created: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "# Label: $label"
        echo "# Device: $(detect_device_summary 2>/dev/null || echo 'unknown')"
        echo "# Backend: ${ANDROID_TOOLKIT_BACKEND:-unknown}"
        echo "#----------------------------------------"
        echo ""
        echo "=== SYSTEM SETTINGS ==="
        backend_exec settings list system 2>/dev/null || echo "# (unavailable)"
        echo ""
        echo "=== SECURE SETTINGS ==="
        backend_exec settings list secure 2>/dev/null || echo "# (unavailable)"
        echo ""
        echo "=== GLOBAL SETTINGS ==="
        backend_exec settings list global 2>/dev/null || echo "# (unavailable)"
    } > "$file"

    if [[ -f "$file" ]]; then
        local size
        size="$(wc -l < "$file")"
        log_success "Backup created: $file ($size lines)"
    else
        log_error "Failed to create backup at $file"
        return 1
    fi

    echo "$file"
}

##############################################
# Create a snapshot of enabled/disabled package state.
# Arguments:
#   $1: optional label
# Returns: path to backup file (stdout)
##############################################
backup_create_packages() {
    local label="${1:-package_state}"
    local file
    file="$(backup_filename "packages")"

    log_section "Creating Package State Backup"

    {
        echo "# Android Toolkit Package State"
        echo "# Created: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "# Label: $label"
        echo "#----------------------------------------"
        echo ""
        echo "=== ENABLED PACKAGES ==="
        backend_exec pm list packages --enabled 2>/dev/null || echo "# (unavailable)"
        echo ""
        echo "=== DISABLED PACKAGES ==="
        backend_exec pm list packages --disabled 2>/dev/null || echo "# (unavailable)"
        echo ""
        echo "=== THIRD-PARTY PACKAGES ==="
        backend_exec pm list packages -3 2>/dev/null || echo "# (unavailable)"
    } > "$file"

    if [[ -f "$file" ]]; then
        log_success "Package backup created: $file"
    else
        log_error "Failed to create package backup"
        return 1
    fi

    echo "$file"
}

##############################################
# List all available backups.
##############################################
backup_list() {
    backup_init
    log_section "Available Backups"

    local count=0
    while IFS= read -r -d '' file; do
        local basename size date
        basename="$(basename "$file")"
        size="$(wc -l < "$file")"
        # Use stat with portable format (prefer -c '%y' on Linux, fallback to -f on BSD/macOS)
        date="$(stat -c '%y' "$file" 2>/dev/null | cut -d. -f1)"
        if [[ -z "$date" ]]; then
            date="$(stat -f '%Sm' "$file" 2>/dev/null)" || date=""
        fi
        printf "  %-40s  %s  (%d lines)\n" "$basename" "$date" "$size"
        count=$((count + 1))
    done < <(find "$BACKUP_DIR" -maxdepth 1 -name '*.txt' -print0 2>/dev/null | sort -z)

    if [[ "$count" -eq 0 ]]; then
        log_info "No backups found in $BACKUP_DIR"
    fi
}

##############################################
# Restore settings from a backup file.
# Arguments:
#   $1: path to backup file
##############################################
backup_restore() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        log_error "Backup file not found: $file"
        return 1
    fi

    log_section "Restoring from Backup"
    log_info "File: $file"

    if [[ "$ANDROID_TOOLKIT_DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would restore settings from this backup file"
        return 0
    fi

    local section=""
    local restored=0
    local skipped=0

    while IFS= read -r line; do
        # Skip comments and blank lines
        case "$line" in
            ''|\#*) continue ;;
            "=== SYSTEM SETTINGS ===") section="system" ; continue ;;
            "=== SECURE SETTINGS ===") section="secure" ; continue ;;
            "=== GLOBAL SETTINGS ===") section="global" ; continue ;;
        esac

        # Parse "key=value" format
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local val="${BASH_REMATCH[2]}"

            # Skip read-only keys that could cause issues
            case "$key" in
                adb_enabled|development_settings_enabled|package_verifier_enable)
                    skipped=$((skipped + 1))
                    continue
                    ;;
            esac

            backend_settings_put "$section" "$key" "$val"
            restored=$((restored + 1))
        fi
    done < "$file"

    log_info "Restored $restored settings (skipped $skipped protected keys)"
    log_success "Restore complete"
}

##############################################
# Verify backup directory exists and is writable.
# Returns: 0 if ready
##############################################
backup_ready() {
    backup_init
    if [[ -d "$BACKUP_DIR" && -w "$BACKUP_DIR" ]]; then
        return 0
    fi
    log_error "Backup directory not writable: $BACKUP_DIR"
    return 1
}
