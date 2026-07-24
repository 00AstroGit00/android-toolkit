#!/data/data/com.termux/files/usr/bin/bash
#
# json_output.sh — Machine-Readable JSON Output Helpers
#
# Provides standardized JSON output functions for commands that
# support the --json flag. Each command can call into these
# helpers to produce consistent structured output.
#
# Part of the Android Toolkit.

JSON_OUTPUT=false
JSON_BUFFER=()

##############################################
# Enable JSON output mode.
##############################################
json_enable() {
    JSON_OUTPUT=true
}

##############################################
# Check if JSON mode is active.
# Returns: 0 if JSON mode on
##############################################
json_active() {
    $JSON_OUTPUT
}

##############################################
# Start a JSON output buffer.
# Arguments:
#   $1: root key name (e.g., "report", "status")
##############################################
json_start() {
    local root="${1:-result}"
    JSON_BUFFER=("{\"${root}\":{")
}

##############################################
# Add a key-value pair to the JSON buffer.
# Arguments:
#   $1: key
#   $2: value (will be JSON-escaped as string)
##############################################
json_add() {
    local key="$1" value="$2"
    local escaped
    escaped="$(echo "$value" | sed 's/"/\\"/g')"
    JSON_BUFFER+=("\"${key}\":\"${escaped}\",")
}

##############################################
# Add a numeric value to the JSON buffer.
# Arguments:
#   $1: key
#   $2: numeric value
##############################################
json_add_number() {
    local key="$1" value="$2"
    JSON_BUFFER+=("\"${key}\":${value},")
}

##############################################
# Add a boolean value to the JSON buffer.
# Arguments:
#   $1: key
#   $2: true|false
##############################################
json_add_bool() {
    local key="$1" value="$2"
    JSON_BUFFER+=("\"${key}\":${value},")
}

##############################################
# Add an array to the JSON buffer.
# Arguments:
#   $1: key
#   $2: space-separated array elements
##############################################
json_add_array() {
    local key="$1" value="$2"
    local escaped
    escaped="$(echo "$value" | sed 's/"/\\"/g')"
    local items=""
    local first=true
    local item
    for item in $escaped; do
        $first || items+=","
        first=false
        items+="\"${item}\""
    done
    JSON_BUFFER+=("\"${key}\":[${items}],")
}

##############################################
# Start a nested object.
# Arguments:
#   $1: key
##############################################
json_start_object() {
    local key="$1"
    JSON_BUFFER+=("\"${key}\":{")
}

##############################################
# End a nested object.
##############################################
json_end_object() {
    # Remove trailing comma from last entry
    _json_trim_last_comma
    JSON_BUFFER+=("},")
}

##############################################
# Finalize and output the JSON buffer.
# Removes trailing commas, closes braces, prints to stdout.
##############################################
json_finish() {
    _json_trim_last_comma
    JSON_BUFFER+=("}}")

    local line
    for line in "${JSON_BUFFER[@]}"; do
        echo -n "$line"
    done
    echo ""

    JSON_BUFFER=()
}

##############################################
# Output a simple JSON message.
# Arguments:
#   $1: key
#   $2: value
##############################################
json_simple() {
    local key="$1" value="$2"
    local escaped
    escaped="$(echo "$value" | sed 's/"/\\"/g')"
    echo "{\"${key}\":\"${escaped}\"}"
}

##############################################
# Output a JSON error.
# Arguments:
#   $1: error message
##############################################
json_error() {
    local msg="$1"
    local escaped
    escaped="$(echo "$msg" | sed 's/"/\\"/g')"
    echo "{\"error\":\"${escaped}\"}" >&2
}

##############################################
# Trim trailing comma from last buffer entry.
##############################################
_json_trim_last_comma() {
    local last_idx=$(( ${#JSON_BUFFER[@]} - 1 ))
    local last="${JSON_BUFFER[$last_idx]}"
    if [[ "$last" == *"," ]]; then
        JSON_BUFFER[$last_idx]="${last%,}"
    fi
}

##############################################
# Convert a key=value line to JSON {key: value}.
# Arguments:
#   $1: key=value string
##############################################
json_from_kv() {
    local line="$1"
    local key="${line%%=*}"
    local value="${line#*=}"
    local escaped
    escaped="$(echo "$value" | sed 's/"/\\"/g')"
    echo "\"${key}\":\"${escaped}\""
}
