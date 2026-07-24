#!/data/data/com.termux/files/usr/bin/bash
#
# logging.sh — Advanced logging with levels, colors, and structured output
#
# Features:
#   Levels: TRACE DEBUG INFO WARN ERROR FATAL
#   Colored console output (auto-detects terminal capability)
#   Plain log files (no ANSI codes)
#   JSON log format option
#   Log rotation (deletes files older than retention days)
#   ISO 8601 timestamps
#   Execution duration tracking
#   Module name and command name annotation
#
# Part of the Android Toolkit.

# ──────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────
LOG_DIR="${ANDROID_TOOLKIT_ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/logs"
LOG_FILE=""
LOG_LEVEL="${ANDROID_TOOLKIT_LOG_LEVEL:-info}"   # trace, debug, info, warn, error, fatal
LOG_FORMAT="${ANDROID_TOOLKIT_LOG_FORMAT:-plain}" # plain or json
LOG_RETENTION_DAYS="${ANDROID_TOOLKIT_LOG_RETENTION_DAYS:-30}"
LOG_MODULE=""
LOG_COMMAND=""
LOG_START_TIME=""

# Colors (only used if terminal supports them)
LOG_COLORS=true
_log_has_color() {
    [[ -t 1 && -n "$TERM" && "$TERM" != "dumb" ]]
}

# Level definitions
LOG_LEVEL_NUMBERS=(
    ["trace"]=0
    ["debug"]=10
    ["info"]=20
    ["warn"]=30
    ["error"]=40
    ["fatal"]=50
)

# Level colors
_LOG_COLOR_RESET="\033[0m"
_LOG_COLOR_TRACE="\033[90m"    # Bright black (gray)
_LOG_COLOR_DEBUG="\033[36m"    # Cyan
_LOG_COLOR_INFO="\033[32m"     # Green
_LOG_COLOR_WARN="\033[33m"     # Yellow
_LOG_COLOR_ERROR="\033[31m"    # Red
_LOG_COLOR_FATAL="\033[41;97m" # White on red

##############################################
# Initialize logging subsystem.
# Creates the log directory, rotates old logs, records start time.
# Arguments:
#   $1: optional log filename stem (default: toolkit)
#   $2: optional module name
##############################################
log_init() {
    local stem="${1:-toolkit}"
    LOG_MODULE="${2:-}"

    mkdir -p "$LOG_DIR" 2>/dev/null || true

    # Rotate old logs
    _log_rotate

    # Create log file
    LOG_FILE="${LOG_DIR}/${stem}_$(date '+%Y%m%d_%H%M%S').log"
    touch "$LOG_FILE" 2>/dev/null || LOG_FILE=""

    # Record start time for duration tracking
    LOG_START_TIME="$(_log_now_ms)"

    # Log session start
    _log_write_file "SESSION" "Log session started (pid: $$)"
}

##############################################
# Delete log files older than retention period.
##############################################
_log_rotate() {
    local retention_seconds=$(( LOG_RETENTION_DAYS * 86400 ))
    local now
    now="$(date +%s)"

    if [[ ! -d "$LOG_DIR" ]]; then
        return 0
    fi

    while IFS= read -r -d '' logfile; do
        local file_time
        file_time="$(stat -c '%Y' "$logfile" 2>/dev/null || echo 0)"
        if [[ "$file_time" -gt 0 && $(( now - file_time )) -gt "$retention_seconds" ]]; then
            rm -f "$logfile" 2>/dev/null || true
        fi
    done < <(find "$LOG_DIR" -name '*.log' -type f -print0 2>/dev/null)
}

##############################################
# Get current timestamp in milliseconds.
##############################################
_log_now_ms() {
    date +%s%3N 2>/dev/null || date +%s000
}

##############################################
# Format a timestamp.
# Arguments:
#   $1: format string (default: ISO 8601)
##############################################
_log_timestamp() {
    local fmt="${1:-%Y-%m-%dT%H:%M:%S%z}"
    date "+$fmt" 2>/dev/null
}

##############################################
# Get the numeric level for comparison.
# Arguments:
#   $1: level name
# Outputs: numeric level
##############################################
_log_level_num() {
    local level="${1:-INFO}"
    local num="${LOG_LEVEL_NUMBERS[${level,,}]}"
    echo "${num:-20}"  # default to INFO level number
}

##############################################
# Check if a message level should be logged.
# Arguments:
#   $1: message level
# Returns: 0 if should log
##############################################
_log_should_log() {
    local msg_level="$1"
    local config_num msg_num
    config_num="$(_log_level_num "$LOG_LEVEL")"
    msg_num="$(_log_level_num "$msg_level")"
    [[ "$msg_num" -ge "$config_num" ]]
}

##############################################
# Get the ANSI color code for a level.
# Arguments:
#   $1: level name
##############################################
_log_color() {
    local level="$1"
    case "${level}" in
        TRACE)  echo -e "$_LOG_COLOR_TRACE" ;;
        DEBUG)  echo -e "$_LOG_COLOR_DEBUG" ;;
        INFO)   echo -e "$_LOG_COLOR_INFO" ;;
        WARN)   echo -e "$_LOG_COLOR_WARN" ;;
        ERROR)  echo -e "$_LOG_COLOR_ERROR" ;;
        FATAL)  echo -e "$_LOG_COLOR_FATAL" ;;
        *)      echo -e "$_LOG_COLOR_RESET" ;;
    esac
}

##############################################
# Format a log line for the console.
# Arguments:
#   $1: level
#   $2: message
# Outputs: formatted string
##############################################
_log_format_console() {
    local level="$1" msg="$2"
    local ts color reset

    ts="$(_log_timestamp)"
    color=""
    reset=""

    if _log_has_color && $LOG_COLORS; then
        color="$(_log_color "$level")"
        reset="$_LOG_COLOR_RESET"
    fi

    local module_tag=""
    if [[ -n "$LOG_MODULE" ]]; then
        module_tag=" [${LOG_MODULE}]"
    fi

    echo -e "${color}[${ts}] [${level}]${module_tag} ${msg}${reset}"
}

##############################################
# Format a log line in JSON.
# Arguments:
#   $1: level
#   $2: message
# Outputs: JSON string
##############################################
_log_format_json() {
    local level="$1" msg="$2"
    local ts

    ts="$(_log_timestamp)"

    # Escape quotes in message
    msg="$(echo "$msg" | sed 's/"/\\"/g')"

    cat <<EOF
{"timestamp":"${ts}","level":"${level}","module":"${LOG_MODULE:-""}","command":"${LOG_COMMAND:-""}","message":"${msg}"}
EOF
}

##############################################
# Write a log line to the log file.
# Arguments:
#   $1: level
#   $2: message
##############################################
_log_write_file() {
    local level="$1" msg="$2"

    if [[ -z "$LOG_FILE" || ! -w "$LOG_FILE" ]]; then
        return 0
    fi

    local ts
    ts="$(_log_timestamp)"
    local log_line="[${ts}] [${level}] ${msg}"

    echo "$log_line" >> "$LOG_FILE"
}

##############################################
# Core log function.
# Arguments:
#   $1: level (TRACE|DEBUG|INFO|WARN|ERROR|FATAL)
#   $2: message
##############################################
_log_message() {
    local level="$1" msg="$2"

    _log_should_log "$level" || return 0

    # Console output
    if [[ "$LOG_FORMAT" == "json" ]]; then
        _log_format_json "$level" "$msg"
    else
        _log_format_console "$level" "$msg"
    fi

    # File output (always plain)
    _log_write_file "$level" "$msg"
}

# ──────────────────────────────────────────────
# Public API
# ──────────────────────────────────────────────

log_trace() {
    _log_message "TRACE" "$*"
    return 0
}

log_debug() {
    _log_message "DEBUG" "$*"
    return 0
}

log_info() {
    _log_message "INFO" "$*"
    return 0
}

log_warning() {
    _log_message "WARN" "$*"
    return 0
}

log_warn() {
    _log_message "WARN" "$*"
    return 0
}

log_error() {
    _log_message "ERROR" "$*"
    return 0
}

log_fatal() {
    _log_message "FATAL" "$*"
    exit 1
}

##############################################
# Print a section header.
# Arguments:
#   $1: header text
##############################################
log_section() {
    local text="$1"
    local sep="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "$sep"
    echo "  ${text}"
    echo "$sep"

    # Also write to log file
    _log_write_file "INFO" "=== ${text} ==="
}

##############################################
# Print a success message.
# Arguments:
#   $1: message
##############################################
log_success() {
    local msg="$*"
    local prefix=""
    _log_has_color && prefix="\033[32m✓\033[0m" || prefix="✓"
    echo -e "  ${prefix} ${msg}"
    _log_write_file "INFO" "SUCCESS: ${msg}"
}

##############################################
# Print a failure message.
# Arguments:
#   $1: message
##############################################
log_failure() {
    local msg="$*"
    local prefix=""
    _log_has_color && prefix="\033[31m✗\033[0m" || prefix="✗"
    echo -e "  ${prefix} ${msg}" >&2
    _log_write_file "ERROR" "FAILURE: ${msg}"
}

##############################################
# Print the log file location.
##############################################
log_show_file() {
    if [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]]; then
        log_info "Log file: $LOG_FILE"
    fi
}

##############################################
# Set the active module name for logging.
# Arguments:
#   $1: module name
##############################################
log_set_module() {
    LOG_MODULE="$1"
}

##############################################
# Set the active command name for logging.
# Arguments:
#   $1: command name
##############################################
log_set_command() {
    LOG_COMMAND="$1"
}

##############################################
# Get the elapsed time since log_init in seconds.
# Outputs: seconds (decimal)
##############################################
log_elapsed() {
    if [[ -z "$LOG_START_TIME" ]]; then
        echo "0"
        return 0
    fi
    local now
    now="$(_log_now_ms)"
    local elapsed_ms=$(( now - LOG_START_TIME ))
    echo "$(( elapsed_ms / 1000 )).$(( elapsed_ms % 1000 ))"
}

##############################################
# Log execution completion with duration.
# Arguments:
#   $1: status (success|failure)
#   $2: optional action description
##############################################
log_complete() {
    local status="${1:-success}" desc="${2:-completed}"
    local elapsed
    elapsed="$(log_elapsed)"
    _log_write_file "INFO" "Session ${status} (duration: ${elapsed}s): ${desc}"
    [[ "$status" == "success" ]] && log_info "Done (${elapsed}s)" || log_error "Failed after ${elapsed}s"
}
