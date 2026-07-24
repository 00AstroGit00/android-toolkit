#!/data/data/com.termux/files/usr/bin/bash
#
# events.sh — Internal Event Bus
#
# Lightweight event system for inter-module communication.
# Modules and plugins can subscribe to events and emit events.
#
# Events:
#   backend_selected      — Backend chosen (adb/rish/local)
#   profile_loaded        — Profile applied
#   capability_detected   — Capability probed
#   setting_applied       — Setting written
#   rollback_started      — Rollback initiated
#   rollback_completed    — Rollback finished
#   report_generated      — Report file created
#   plugin_loaded         — Plugin registered
#   benchmark_finished    — Benchmark completed
#
# Part of the Android Toolkit.

declare -A EVENTS_SUBSCRIBERS
EVENTS_EMIT_STACK=()
EVENTS_ENABLED=true

##############################################
# Subscribe to an event.
# Usage: events_subscribe <event_name> <handler_function>
# The handler receives event name and any emitted data as arguments.
# Returns: subscription ID (for unsubscribe)
##############################################
events_subscribe() {
    local event="$1" handler="$2"
    local id="${event}|${handler}"

    if [[ -z "${EVENTS_SUBSCRIBERS[$id]:-}" ]]; then
        EVENTS_SUBSCRIBERS[$id]="$handler"
    fi

    log_trace "Event subscription: ${event} → ${handler}"
    echo "$id"
}

##############################################
# Unsubscribe from an event.
# Usage: events_unsubscribe <subscription_id>
##############################################
events_unsubscribe() {
    local id="$1"
    unset "EVENTS_SUBSCRIBERS[$id]"
    log_trace "Event unsubscribed: $id"
}

##############################################
# Emit an event, calling all subscribers.
# Usage: events_emit <event_name> [data...]
##############################################
events_emit() {
    $EVENTS_ENABLED || return 0
    local event="$1"
    shift

    # Prevent infinite loops
    local stack_item="${event}|$*"
    local s
    for s in "${EVENTS_EMIT_STACK[@]}"; do
        [[ "$s" == "$stack_item" ]] && return 0
    done
    EVENTS_EMIT_STACK+=("$stack_item")

    log_trace "Event emitted: ${event} (data: $*)"

    local id handler
    for id in "${!EVENTS_SUBSCRIBERS[@]}"; do
        if [[ "$id" == "${event}|"* ]]; then
            handler="${EVENTS_SUBSCRIBERS[$id]}"
            if declare -f "$handler" &>/dev/null; then
                $handler "$event" "$@" 2>/dev/null || true
            fi
        fi
    done

    # Pop stack
    local new_stack=()
    for s in "${EVENTS_EMIT_STACK[@]}"; do
        [[ "$s" != "$stack_item" ]] && new_stack+=("$s")
    done
    EVENTS_EMIT_STACK=("${new_stack[@]}")
}

##############################################
# Enable/disable the event system.
# Usage: events_enable [true|false]
##############################################
events_enable() {
    EVENTS_ENABLED="${1:-true}"
}

##############################################
# List all active subscriptions.
##############################################
events_list_subscribers() {
    echo "  Event Subscriptions"
    echo "  ─────────────────────────────────────────────"
    if [[ ${#EVENTS_SUBSCRIBERS[@]} -eq 0 ]]; then
        echo "  No active subscriptions"
        return 0
    fi
    local id handler
    for id in "${!EVENTS_SUBSCRIBERS[@]}"; do
        local event="${id%%|*}"
        handler="${EVENTS_SUBSCRIBERS[$id]}"
        printf "  %-30s → %s\n" "$event" "$handler"
    done
}

##############################################
# Initialize default event subscriptions.
# Called automatically from modules that need events.
##############################################
events_init_defaults() {
    # Log certain events automatically
    events_subscribe "backend_selected" "_events_log_backend"
    events_subscribe "setting_applied" "_events_log_setting"
    events_subscribe "rollback_completed" "_events_log_rollback"
    events_subscribe "plugin_loaded" "_events_log_plugin"
}

# Default event handlers
_events_log_backend() {
    log_info "Backend selected: $2"
}

_events_log_setting() {
    log_debug "Setting applied: $2=$3 (namespace: $4)"
}

_events_log_rollback() {
    log_info "Rollback completed: $2"
}

_events_log_plugin() {
    log_debug "Plugin loaded: $2 v$3"
}

# Initialize default subscriptions
events_init_defaults
