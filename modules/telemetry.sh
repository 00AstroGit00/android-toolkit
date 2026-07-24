#!/data/data/com.termux/files/usr/bin/bash
#
# telemetry.sh — Local-only usage telemetry
#
# Collects usage statistics locally. Never transmits data.
# Statistics are stored in a JSON file under .telemetry/.
#
# Tracks:
#   - number of runs
#   - profile usage
#   - execution duration
#   - failed operations
#   - rollback count
#   - backend usage
#   - OEM usage
#
# Part of the Android Toolkit.

TELEMETRY_DIR="${ANDROID_TOOLKIT_ROOT_DIR}/.telemetry"
TELEMETRY_FILE="${TELEMETRY_DIR}/stats.json"
TELEMETRY_LOCK="${TELEMETRY_DIR}/.lock"

##############################################
# Initialize telemetry storage.
##############################################
telemetry_init() {
    mkdir -p "$TELEMETRY_DIR"

    if [[ ! -f "$TELEMETRY_FILE" ]]; then
        cat > "$TELEMETRY_FILE" <<'EOF'
{
  "first_run": "",
  "last_run": "",
  "total_runs": 0,
  "total_duration_sec": 0,
  "profiles": {},
  "backends": {},
  "oems": {},
  "actions": {},
  "failed_operations": 0,
  "rollbacks_performed": 0,
  "updates_performed": []
}
EOF
    fi
}

##############################################
# Record a run completion.
# Arguments:
#   $1: duration in seconds
#   $2: action name (e.g., "status", "apply")
#   $3: backend used (e.g., "adb", "rish")
##############################################
telemetry_record_run() {
    local duration="${1:-0}" action="${2:-unknown}" backend="${3:-unknown}"

    telemetry_init

    local now
    now="$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)"

    if command -v jq &>/dev/null; then
        local data
        data="$(cat "$TELEMETRY_FILE")"

        data="$(echo "$data" | jq \
            --arg now "$now" \
            --argjson dur "$duration" \
            --arg action "$action" \
            --arg backend "$backend" \
            --arg oem "${OEM_LOADED:-generic}" \
            '
            .last_run = $now |
            if .first_run == "" then .first_run = $now else . end |
            .total_runs += 1 |
            .total_duration_sec += $dur |
            .actions[$action] = (.actions[$action] // 0) + 1 |
            .backends[$backend] = (.backends[$backend] // 0) + 1 |
            .oems[$oem] = (.oems[$oem] // 0) + 1
        ')"

        echo "$data" > "$TELEMETRY_FILE"
    else
        log_debug "jq not available — telemetry: run recorded ($action)"
    fi
}

##############################################
# Record a failed operation.
##############################################
telemetry_record_failure() {
    telemetry_init

    if command -v jq &>/dev/null; then
        local data
        data="$(cat "$TELEMETRY_FILE")"
        data="$(echo "$data" | jq '.failed_operations += 1')"
        echo "$data" > "$TELEMETRY_FILE"
    fi
}

##############################################
# Record a rollback event.
##############################################
telemetry_record_rollback() {
    telemetry_init

    if command -v jq &>/dev/null; then
        local data
        data="$(cat "$TELEMETRY_FILE")"
        data="$(echo "$data" | jq '.rollbacks_performed += 1')"
        echo "$data" > "$TELEMETRY_FILE"
    fi
}

##############################################
# Record a profile application.
# Arguments:
#   $1: profile name
##############################################
telemetry_record_profile() {
    local profile="${1:-unknown}"

    if command -v jq &>/dev/null; then
        local data
        data="$(cat "$TELEMETRY_FILE")"
        data="$(echo "$data" | jq --arg p "$profile" '.profiles[$p] = (.profiles[$p] // 0) + 1')"
        echo "$data" > "$TELEMETRY_FILE"
    fi
}

##############################################
# Record an update event.
# Arguments:
#   $1: version change description
##############################################
telemetry_record_update() {
    local desc="${1:-unknown}"

    if command -v jq &>/dev/null; then
        local data now
        now="$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)"
        data="$(cat "$TELEMETRY_FILE")"
        data="$(echo "$data" | jq --arg d "$desc" --arg t "$now" '.updates_performed += [{"version": $d, "date": $t}]')"
        echo "$data" > "$TELEMETRY_FILE"
    fi
}

##############################################
# Display telemetry statistics.
##############################################
telemetry_show() {
    telemetry_init

    log_section "Usage Statistics"

    if ! command -v jq &>/dev/null; then
        log_warning "jq required to display statistics"
        echo ""
        echo "  Install jq to view detailed stats: pkg install jq"
        return 0
    fi

    local data
    data="$(cat "$TELEMETRY_FILE")"

    local first_run last_run total_runs total_dur failures rollbacks
    first_run="$(echo "$data" | jq -r '.first_run // "never"')"
    last_run="$(echo "$data" | jq -r '.last_run // "never"')"
    total_runs="$(echo "$data" | jq -r '.total_runs // 0')"
    total_dur="$(echo "$data" | jq -r '.total_duration_sec // 0')"
    failures="$(echo "$data" | jq -r '.failed_operations // 0')"
    rollbacks="$(echo "$data" | jq -r '.rollbacks_performed // 0')"

    echo ""
    echo "  First run:     $first_run"
    echo "  Last run:      $last_run"
    echo "  Total runs:    $total_runs"
    echo "  Total time:    ${total_dur}s ($(( total_dur / 60 ))m)"
    echo "  Failures:      $failures"
    echo "  Rollbacks:     $rollbacks"
    echo ""

    echo "  Actions:"
    echo "$data" | jq -r '.actions | to_entries[] | "    \(.key): \(.value) time(s)"' 2>/dev/null || true

    echo ""
    echo "  Backends:"
    echo "$data" | jq -r '.backends | to_entries[] | "    \(.key): \(.value) time(s)"' 2>/dev/null || true

    echo ""
    echo "  OEMs:"
    echo "$data" | jq -r '.oems | to_entries[] | "    \(.key): \(.value) time(s)"' 2>/dev/null || true

    echo ""
    echo "  Profiles applied:"
    echo "$data" | jq -r '.profiles | to_entries[] | "    \(.key): \(.value) time(s)"' 2>/dev/null || true

    echo ""
    echo "  Updates:"
    local update_count
    update_count="$(echo "$data" | jq -r '.updates_performed | length' 2>/dev/null || echo 0)"
    if [[ "$update_count" -gt 0 ]]; then
        echo "$data" | jq -r '.updates_performed[] | "    \(.date) — \(.version)"' 2>/dev/null || true
    else
        echo "    None"
    fi

    echo ""
    log_info "Telemetry is stored locally at: $TELEMETRY_FILE"
    log_info "No data is ever transmitted."
}
