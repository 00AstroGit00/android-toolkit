#!/data/data/com.termux/files/usr/bin/bash
#
# updater.sh — Self-update module
#
# Checks GitHub releases for new versions and applies updates.
# Supports stable, beta, and nightly channels.
# Never overwrites without confirmation and backs up the current installation.
#
# Part of the Android Toolkit.

UPDATER_DATA_DIR="${ANDROID_TOOLKIT_ROOT_DIR}/.updater"
UPDATER_CHANNELS="stable beta nightly"

##############################################
# Read metadata from the VERSION file.
##############################################
_updater_current_version() {
    echo "${ANDROID_TOOLKIT_VERSION:-0.0.0}"
}

##############################################
# Fetch available version for a channel.
# Arguments:
#   $1: channel (stable|beta|nightly)
# Outputs: version string or "0.0.0" on failure
##############################################
_updater_fetch_remote_version() {
    local channel="${1:-stable}"
    local version_file_url

    case "$channel" in
        stable)  version_file_url="https://raw.githubusercontent.com/android-toolkit/toolkit/main/VERSION" ;;
        beta)    version_file_url="https://raw.githubusercontent.com/android-toolkit/toolkit/beta/VERSION" ;;
        nightly) version_file_url="https://raw.githubusercontent.com/android-toolkit/toolkit/nightly/VERSION" ;;
        *)       log_error "Unknown channel: $channel"; return 1 ;;
    esac

    if command -v curl &>/dev/null; then
        curl -fsSL "$version_file_url" 2>/dev/null | head -1 | tr -d '[:space:]'
    elif command -v wget &>/dev/null; then
        wget -qO- "$version_file_url" 2>/dev/null | head -1 | tr -d '[:space:]'
    else
        log_warning "Neither curl nor wget available — cannot check for updates"
        echo "0.0.0"
    fi
}

##############################################
# Compare two semantic versions.
# Returns: 0 if $1 < $2, 1 otherwise
##############################################
_updater_version_lt() {
    local v1="$1" v2="$2"
    if [[ "$v1" == "$v2" ]]; then
        return 1
    fi
    local IFS=.
    local i a1 a2 a3 b1 b2 b3
    read -r a1 a2 a3 <<< "$v1"
    read -r b1 b2 b3 <<< "$v2"
    a1="${a1:-0}" a2="${a2:-0}" a3="${a3:-0}"
    b1="${b1:-0}" b2="${b2:-0}" b3="${b3:-0}"
    if (( a1 < b1 )); then return 0; fi
    if (( a1 > b1 )); then return 1; fi
    if (( a2 < b2 )); then return 0; fi
    if (( a2 > b2 )); then return 1; fi
    if (( a3 < b3 )); then return 0; fi
    return 1
}

##############################################
# Check for available updates.
# Arguments:
#   $1: channel (default: stable)
# Outputs: remote version if update available, "" otherwise
##############################################
updater_check() {
    local channel="${1:-stable}"
    local current remote

    current="$(_updater_current_version)"
    remote="$(_updater_fetch_remote_version "$channel")"

    if [[ -z "$remote" || "$remote" == "0.0.0" ]]; then
        log_warning "Could not determine remote version for channel '$channel'"
        return 1
    fi

    if _updater_version_lt "$current" "$remote"; then
        echo "$remote"
        return 0
    fi
    return 1
}

##############################################
# Download a release archive.
# Arguments:
#   $1: version
#   $2: channel
# Outputs: path to downloaded file
##############################################
_updater_download() {
    local version="$1" channel="${2:-stable}"
    local url download_dir download_file

    mkdir -p "$UPDATER_DATA_DIR"

    case "$channel" in
        stable)  url="https://github.com/android-toolkit/toolkit/archive/refs/tags/v${version}.zip" ;;
        beta)    url="https://github.com/android-toolkit/toolkit/archive/refs/heads/beta.zip" ;;
        nightly) url="https://github.com/android-toolkit/toolkit/archive/refs/heads/main.zip" ;;
    esac

    download_file="${UPDATER_DATA_DIR}/update-${version}.zip"

    log_info "Downloading v${version} from $channel channel..."
    if command -v curl &>/dev/null; then
        if ! curl -fSL -o "$download_file" "$url" 2>/dev/null; then
            log_error "Download failed"
            return 1
        fi
    elif command -v wget &>/dev/null; then
        if ! wget -q -O "$download_file" "$url" 2>/dev/null; then
            log_error "Download failed"
            return 1
        fi
    else
        log_error "Neither curl nor wget available"
        return 1
    fi

    echo "$download_file"
}

##############################################
# Verify the downloaded archive checksum.
# Arguments:
#   $1: archive path
#   $2: version
# Returns: 0 if valid
##############################################
_updater_verify() {
    local archive="$1" version="$2"
    local sha_url sha_file

    sha_url="https://github.com/android-toolkit/toolkit/releases/download/v${version}/android-toolkit-v${version}.zip.sha256"
    sha_file="${UPDATER_DATA_DIR}/update-${version}.sha256"

    if command -v curl &>/dev/null; then
        curl -fSL -o "$sha_file" "$sha_url" 2>/dev/null || {
            log_warning "No SHA256 file available — skipping checksum verification"
            return 0
        }
    elif command -v wget &>/dev/null; then
        wget -q -O "$sha_file" "$sha_url" 2>/dev/null || {
            log_warning "No SHA256 file available — skipping checksum verification"
            return 0
        }
    else
        log_warning "Cannot verify checksum — no curl or wget"
        return 0
    fi

    if command -v sha256sum &>/dev/null; then
        if (cd "$UPDATER_DATA_DIR" && sha256sum -c "$sha_file" 2>/dev/null); then
            log_success "Checksum verified"
            return 0
        else
            log_error "Checksum mismatch — downloaded file may be corrupted"
            return 1
        fi
    fi
    return 0
}

##############################################
# Backup current installation.
# Arguments:
#   $1: version (for directory naming)
# Outputs: path to backup directory
##############################################
_updater_backup_current() {
    local version="${1:-pre-update}"
    local backup_dir="${ANDROID_TOOLKIT_ROOT_DIR}/backups/updater-backup-${version}-$(date +%Y%m%d%H%M%S)"

    mkdir -p "$backup_dir"
    log_info "Backing up current installation to $backup_dir"

    cp -r "$ANDROID_TOOLKIT_ROOT_DIR"/* "$backup_dir/" 2>/dev/null || {
        log_error "Backup failed"
        return 1
    }

    echo "$backup_dir"
}

##############################################
# Apply an update from a downloaded archive.
# Arguments:
#   $1: archive path
#   $2: version
# Returns: 0 on success, triggers rollback on failure
##############################################
_updater_apply() {
    local archive="$1" version="$2"
    local temp_dir

    temp_dir="$(mktemp -d "${UPDATER_DATA_DIR}/extract.XXXXXX")"

    log_info "Extracting update..."
    if ! unzip -qo "$archive" -d "$temp_dir" 2>/dev/null; then
        log_error "Extraction failed"
        rm -rf "$temp_dir"
        return 1
    fi

    # Find the root directory inside the zip (GitHub wraps in a folder)
    local inner_dir
    inner_dir="$(find "$temp_dir" -maxdepth 1 -type d | tail -1)"

    if [[ -z "$inner_dir" || "$inner_dir" == "$temp_dir" ]]; then
        # Flat structure
        inner_dir="$temp_dir"
    fi

    log_info "Applying update..."
    # Copy each file, preserving structure
    for item in "$inner_dir"/*; do
        local base
        base="$(basename "$item")"
        # Skip .git if present
        [[ "$base" == ".git" ]] && continue
        cp -r "$item" "${ANDROID_TOOLKIT_ROOT_DIR}/" 2>/dev/null || {
            log_error "Failed to apply update (file: $base)"
            rm -rf "$temp_dir"
            return 1
        }
    done

    rm -rf "$temp_dir"

    # Make scripts executable
    chmod +x "${ANDROID_TOOLKIT_ROOT_DIR}/toolkit.sh" 2>/dev/null || true

    log_success "Update applied successfully"
    return 0
}

##############################################
# Main update entry point.
# Arguments:
#   $1: channel (stable|beta|nightly), default: stable
##############################################
updater_run() {
    local channel="${1:-stable}"
    local current backup_dir archive remote_version

    current="$(_updater_current_version)"

    log_section "Update Check"
    log_info "Current version: v${current}"
    log_info "Channel: $channel"

    remote_version="$(updater_check "$channel")" || {
        if [[ -z "$remote_version" ]]; then
            log_success "Already up-to-date (v${current})"
        else
            log_warning "Update check failed"
        fi
        return 0
    }

    log_info "New version available: v${remote_version}"

    # Confirmation
    if ! utils_confirm "Update to v${remote_version} (channel: ${channel})?"; then
        log_info "Update cancelled"
        return 0
    fi

    # Backup
    backup_dir="$(_updater_backup_current "$current")" || {
        log_error "Backup failed — aborting update"
        return 1
    }
    log_info "Backup saved to: $backup_dir"

    # Download
    archive="$(_updater_download "$remote_version" "$channel")" || return 1

    # Verify
    _updater_verify "$archive" "$remote_version" || {
        log_error "Verification failed"
        rm -f "$archive" 2>/dev/null
        return 1
    }

    # Apply
    if _updater_apply "$archive" "$remote_version"; then
        rm -f "$archive" 2>/dev/null
        log_success "Updated from v${current} to v${remote_version}"
        echo ""
        echo "═══════════════════════════════════════════"
        echo " Update complete. Restart the toolkit to"
        echo " use the new version."
        echo "═══════════════════════════════════════════"

        # Log telemetry
        _load_module "telemetry" 2>/dev/null && telemetry_record "update" "$current -> $remote_version" || true
    else
        log_error "Update failed — initiating rollback"
        log_info "Restoring from backup: $backup_dir"
        cp -r "$backup_dir"/* "${ANDROID_TOOLKIT_ROOT_DIR}/" 2>/dev/null || {
            log_error "Rollback failed — manual restore required from: $backup_dir"
        }
        rm -f "$archive" 2>/dev/null
        return 1
    fi
}

##############################################
# Check version (non-interactive, for scripts).
# Arguments:
#   $1: channel
# Returns: 0 if update available, prints version
##############################################
updater_check_only() {
    local channel="${1:-stable}"
    updater_check "$channel" || return 1
}
