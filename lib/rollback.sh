#!/data/data/com.termux/files/usr/bin/bash
#
# rollback.sh — Rollback engine for settings changes
#
# Maintains a journal of all settings changes with timestamps,
# old/new values, and status. Supports:
#   - toolkit --rollback latest        Revert the most recent changes
#   - toolkit --rollback <timestamp>   Revert to a specific point
#   - toolkit --rollback list          List all rollback snapshots
#
# Each rollback snapshot records:
#   - Timestamp
#   - Device model and Android version
#   - Profile name or action trigger
#   - Every changed key with old/new values
#   - Status of the rollback
#
# Part of the Android Toolkit.

ROLLBACK_DIR="${ANDROID_TOOLKIT_ROOT_DIR}/rollbacks"
ROLLBACK_INDEX="${ROLLBACK_DIR}/index.txt"

##############################################
# Initialize rollback directory.
##############################################
rollback_init() {
    mkdir -p "$ROLLBACK_DIR" 2>/dev/null || true
    if [[ ! -f "$ROLLBACK_INDEX" ]]; then
        touch "$ROLLBACK_INDEX" 2>/dev/null || true
    fi
}

##############################################
# Begin a new rollback journal entry.
# Returns: journal file path (stdout)
# Arguments:
#   $1: label/trigger (e.g., "apply:performance", "manual")
##############################################
rollback_begin() {
    local label="${1:-manual}"
    rollback_init

    local timestamp
    timestamp="$(date '+%Y%m%d_%H%M%S')"
    local journal_file="${ROLLBACK_DIR}/journal_${timestamp}.txt"

    {
        echo "# Android Toolkit Rollback Journal"
        echo "# Created: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "# Timestamp: $timestamp"
        echo "# Label: $label"
        echo "# Device: ${CAP_MODEL:-$(cap_get CAP_MODEL 2>/dev/null || echo 'unknown')}"
        echo "# Android: ${CAP_ANDROID_VERSION:-$(cap_get CAP_ANDROID_VERSION 2>/dev/null || echo 'unknown')}"
        echo "# Backend: ${ANDROID_TOOLKIT_BACKEND:-unknown}"
        echo "# Status: active"
        echo "#----------------------------------------"
        echo "# Format: namespace|key|old_value|new_value|status"
        echo ""
    } > "$journal_file"

    # Append to index
    echo "${timestamp}|${label}|$(date '+%Y-%m-%d %H:%M:%S')|active" >> "$ROLLBACK_INDEX"

    echo "$journal_file"
    return 0
}

##############################################
# Record a settings change in the active journal.
# Arguments:
#   $1: journal file path (from rollback_begin)
#   $2: namespace (system|secure|global)
#   $3: key
#   $4: old value
#   $5: new value
#   $6: status (applied|failed|skipped) — default: applied
##############################################
rollback_record() {
    local journal="$1" ns="$2" key="$3" old_val="$4" new_val="$5" status="${6:-applied}"

    if [[ ! -f "$journal" ]]; then
        log_debug "rollback_record: journal not found: $journal"
        return 1
    fi

    # Escape pipes in values
    old_val="${old_val//|/\\|}"
    new_val="${new_val//|/\\|}"

    echo "${ns}|${key}|${old_val}|${new_val}|${status}" >> "$journal"
}

##############################################
# Close a rollback journal (mark as completed or failed).
# Arguments:
#   $1: journal file path
#   $2: final status (completed|failed|partial)
##############################################
rollback_close() {
    local journal="$1" status="${2:-completed}"

    if [[ ! -f "$journal" ]]; then
        log_debug "rollback_close: journal not found: $journal"
        return 1
    fi

    # Update the status line in the journal
    if [[ "$(uname -s)" == "Darwin" ]]; then
        sed -i '' "s/^# Status: active$/# Status: $status/" "$journal" 2>/dev/null || true
    else
        sed -i "s/^# Status: active$/# Status: $status/" "$journal" 2>/dev/null || true
    fi

    # Update index
    local timestamp
    timestamp="$(grep '^# Timestamp:' "$journal" | head -1 | cut -d' ' -f3)"
    if [[ -n "$timestamp" ]]; then
        if [[ "$(uname -s)" == "Darwin" ]]; then
            sed -i '' "s/^${timestamp}|.*active$/${timestamp}|$(grep '^# Label:' "$journal" | head -1 | cut -d' ' -f3- | sed 's/^ *//')|$(date '+%Y-%m-%d %H:%M:%S')|${status}/" "$ROLLBACK_INDEX" 2>/dev/null || true
        else
            sed -i "s/^${timestamp}|.*active$/${timestamp}|$(grep '^# Label:' "$journal" | head -1 | cut -d' ' -f3- | sed 's/^ *//')|$(date '+%Y-%m-%d %H:%M:%S')|${status}/" "$ROLLBACK_INDEX" 2>/dev/null || true
        fi
    fi
}

##############################################
# List all available rollback snapshots.
##############################################
rollback_list() {
    rollback_init
    log_section "Rollback Snapshots"

    if [[ ! -s "$ROLLBACK_INDEX" ]]; then
        log_info "No rollback snapshots found"
        return 0
    fi

    printf "  %-20s %-30s %-20s %s\n" "Timestamp" "Label" "Date" "Status"
    printf "  %-20s %-30s %-20s %s\n" "────" "─────" "────" "──────"

    while IFS='|' read -r ts label date status; do
        [[ -z "$ts" ]] && continue
        printf "  %-20s %-30s %-20s %s\n" "$ts" "${label:0:28}" "$date" "$status"
    done < "$ROLLBACK_INDEX"
}

##############################################
# Rollback (restore) changes from a journal.
# Arguments:
#   $1: timestamp or "latest" to rollback the most recent
##############################################
rollback_perform() {
    local target="$1"

    rollback_init

    # Find journal file
    local journal_file=""

    if [[ "$target" == "latest" ]]; then
        journal_file="$(ls -t "${ROLLBACK_DIR}"/journal_*.txt 2>/dev/null | head -1)"
    elif [[ "$target" == "list" ]]; then
        rollback_list
        return 0
    else
        journal_file="${ROLLBACK_DIR}/journal_${target}.txt"
    fi

    if [[ -z "$journal_file" || ! -f "$journal_file" ]]; then
        log_error "Rollback not found: $target"
        log_info "Use '--rollback list' to see available snapshots"
        return 1
    fi

    log_section "Rollback: $(basename "$journal_file" .txt)"

    if [[ "$ANDROID_TOOLKIT_DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would rollback changes from: $(basename "$journal_file")"
        return 0
    fi

    # Validate backend
    if [[ "$ANDROID_TOOLKIT_BACKEND" == "local" ]]; then
        log_error "Rollback requires ADB or rish backend"
        return 1
    fi

    # Read and parse journal
    local ns key old_val new_val entry_status
    local restored=0 failed=0 skipped=0

    while IFS='|' read -r ns key old_val new_val entry_status; do
        # Skip comments, headers, and blank lines
        case "$ns" in
            ''|\#*) continue ;;
            "namespace") continue ;;
        esac

        # Skip failed/skipped entries
        if [[ "$entry_status" == "failed" || "$entry_status" == "skipped" ]]; then
            skipped=$((skipped + 1))
            continue
        fi

        # Only restore if key has a previous value
        if [[ -z "$old_val" || "$old_val" == "(unset)" ]]; then
            log_debug "No previous value for $ns/$key — cannot restore, was never set"
            skipped=$((skipped + 1))
            continue
        fi

        # Read current value
        local current_val
        current_val="$(backend_settings_get "$ns" "$key" 2>/dev/null)"

        if [[ "$current_val" == "$old_val" ]]; then
            log_debug "$ns/$key already at rollback value: $old_val"
            skipped=$((skipped + 1))
            continue
        fi

        # Perform the restore
        log_info "Restoring $ns/$key to: $old_val (was: $current_val)"
        if backend_exec settings put "$ns" "$key" "$old_val" 2>/dev/null; then
            # Verify
            local verify_val
            verify_val="$(backend_settings_get "$ns" "$key" 2>/dev/null)"
            if [[ "$verify_val" == "$old_val" ]]; then
                restored=$((restored + 1))
            else
                log_warn "Verification failed for $ns/$key: expected '$old_val', got '$verify_val'"
                failed=$((failed + 1))
            fi
        else
            log_error "Failed to restore $ns/$key"
            failed=$((failed + 1))
        fi
    done < "$journal_file"

    # Update journal status
    local final_status="completed"
    [[ "$failed" -gt 0 && "$restored" -gt 0 ]] && final_status="partial"
    [[ "$failed" -gt 0 && "$restored" -eq 0 ]] && final_status="failed"
    rollback_close "$journal_file" "$final_status"

    echo ""
    log_success "Rollback complete: $restored restored, $failed failed, $skipped skipped"
}

##############################################
# Get the active rollback journal path.
# Arguments:
#   $1: journal path or empty for latest
##############################################
rollback_get_active_journal() {
    local journal="${1:-}"
    if [[ -z "$journal" ]]; then
        journal="$(ls -t "${ROLLBACK_DIR}"/journal_*.txt 2>/dev/null | head -1)"
    fi
    if [[ -f "$journal" ]]; then
        echo "$journal"
    fi
    return 0
}
