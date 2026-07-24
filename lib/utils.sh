#!/data/data/com.termux/files/usr/bin/bash
#
# utils.sh — Utility functions used across the toolkit
#
# Part of the Android Toolkit.

##############################################
# Check if a required command is available.
# Arguments:
#   $1: command name
#   $2: optional package hint for installation
# Returns: 0 if found, 1 if missing
##############################################
utils_require_cmd() {
    local cmd="$1" hint="${2:-}"
    if ! command -v "$cmd" &>/dev/null; then
        if [[ -n "$hint" ]]; then
            log_error "Required command '$cmd' not found. Install: $hint"
        else
            log_error "Required command '$cmd' not found in PATH"
        fi
        return 1
    fi
    return 0
}

##############################################
# Confirm a potentially destructive action with the user.
# Arguments:
#   $1: prompt message
#   $2: default answer (yes/no) — defaults to no
# Returns: 0 if confirmed, 1 if declined
##############################################
utils_confirm() {
    local prompt="$1" default="${2:-no}"
    local yn=""
    local default_char=""
    local other_char=""

    case "$default" in
        yes|y|Y)
            default_char="Y"
            other_char="n"
            default="yes"
            ;;
        *)
            default_char="N"
            other_char="y"
            default="no"
            ;;
    esac

    echo ""
    echo "  ⚠  $prompt"
    printf "  Confirm? [%s/%s] (default: %s) " "$default_char" "$other_char" "$default"
    read -r yn
    echo ""

    case "$yn" in
        y|Y|yes|YES) return 0 ;;
        n|N|no|NO) return 1 ;;
        *) [[ "$default" == "yes" ]] && return 0 || return 1 ;;
    esac
}

##############################################
# Validate that a string is a non-empty package name.
# Arguments:
#   $1: package name candidate
# Returns: 0 if valid
##############################################
utils_validate_package() {
    local pkg="$1"
    if [[ -z "$pkg" ]]; then
        log_error "Package name cannot be empty"
        return 1
    fi
    if ! echo "$pkg" | grep -qE '^[a-zA-Z0-9][a-zA-Z0-9._-]+[a-zA-Z0-9]$'; then
        log_error "Invalid package name: '$pkg'"
        return 1
    fi
    return 0
}

##############################################
# Validate a numeric value within a range.
# Arguments:
#   $1: value
#   $2: min
#   $3: max
#   $4: label for error message
# Returns: 0 if valid
##############################################
utils_validate_range() {
    local val="$1" min="$2" max="$3" label="$4"
    if ! [[ "$val" =~ ^[0-9]+$ ]]; then
        log_error "$label must be a number, got '$val'"
        return 1
    fi
    if [[ "$val" -lt "$min" || "$val" -gt "$max" ]]; then
        log_error "$label must be between $min and $max, got $val"
        return 1
    fi
    return 0
}

##############################################
# Print a formatted key-value pair.
# Arguments:
#   $1: key
#   $2: value
#   $3: indent level (default: 1)
##############################################
utils_print_kv() {
    local key="$1" val="$2" indent="${3:-1}"
    local pad=""
    for ((i=0; i<indent; i++)); do pad+="  "; done
    printf "  %s%-20s %s\n" "$pad" "$key:" "$val"
}

##############################################
# Detect if we are running interactively.
# Returns: 0 if interactive
##############################################
utils_is_interactive() {
    [[ -t 0 && -t 1 ]]
}

##############################################
# Print a formatted table row.
# Arguments:
#   $1: column 1
#   $2: column 2
#   $3: column 3 (optional)
##############################################
utils_print_row() {
    printf "  %-30s %-30s %s\n" "$1" "$2" "${3:-}"
}

##############################################
# Get current timestamp in ISO format.
##############################################
utils_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

##############################################
# Run a command with a timeout.
# Arguments:
#   $1: timeout in seconds
#   $@: command to run
# Returns: exit code of the command (124 if timed out)
##############################################
utils_timeout() {
    local timeout="$1"
    shift
    if command -v timeout &>/dev/null; then
        log_debug "Running with ${timeout}s timeout: $*"
        timeout "$timeout" "$@"
        local rc=$?
        if [[ "$rc" -eq 124 ]]; then
            log_warn "Command timed out after ${timeout}s: $*"
        fi
        return "$rc"
    else
        # Fallback: run without timeout
        log_debug "timeout command not available, running without timeout: $*"
        "$@"
    fi
}
