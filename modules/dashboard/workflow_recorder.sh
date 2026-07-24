#!/data/data/com.termux/files/usr/bin/bash
#
# workflow_recorder.sh — Workflow Recorder
#
# Records user actions and allows replay, edit, save,
# share, and conversion into reusable workflows.
#
# Part of the Android Toolkit Dashboard.

declare -ga WORKFLOW_RECORDER_LOG=()
WORKFLOW_RECORDER_ACTIVE=false
WORKFLOW_RECORDER_NAME=""
WORKFLOW_RECORDER_DIR="${ANDROID_TOOLKIT_ROOT_DIR}/workflows"

##############################################
# Initialize workflow recorder.
workflow_recorder_init() {
    mkdir -p "$WORKFLOW_RECORDER_DIR" 2>/dev/null || true
}

##############################################
# Start recording a workflow.
workflow_recorder_start() {
    local name="${1:-workflow_$(date +%Y%m%d_%H%M%S)}"
    WORKFLOW_RECORDER_LOG=()
    WORKFLOW_RECORDER_ACTIVE=true
    WORKFLOW_RECORDER_NAME="$name"
    workflow_recorder_log "system" "Recording started" "workflow_recorder_start"
    notify_push "Recording: $name" "info"
    timeline_record "optimization" "Workflow recording started" "$name" "info"
}

##############################################
# Log an action during recording.
workflow_recorder_log() {
    local category="$1" action="$2" detail="${3:-}" timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    if [[ "$WORKFLOW_RECORDER_ACTIVE" == "true" ]]; then
        WORKFLOW_RECORDER_LOG+=("${timestamp}|${category}|${action}|${detail}")
    fi
}

##############################################
# Stop recording.
workflow_recorder_stop() {
    WORKFLOW_RECORDER_ACTIVE=false
    notify_push "Recording stopped: ${#WORKFLOW_RECORDER_LOG[@]} steps" "success"
}

##############################################
# Save recorded workflow.
workflow_recorder_save() {
    local name="${1:-$WORKFLOW_RECORDER_NAME}"
    local file="${WORKFLOW_RECORDER_DIR}/${name}.wf"
    {
        echo "# Workflow: $name"
        echo "# Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "# Steps: ${#WORKFLOW_RECORDER_LOG[@]}"
        echo "---"
        local entry
        for entry in "${WORKFLOW_RECORDER_LOG[@]}"; do
            echo "$entry"
        done
    } > "$file"
    echo "$file"
}

##############################################
# Load a saved workflow.
workflow_recorder_load() {
    local name="$1"
    local file="${WORKFLOW_RECORDER_DIR}/${name}.wf"
    WORKFLOW_RECORDER_LOG=()
    if [[ -f "$file" ]]; then
        while IFS= read -r line; do
            [[ "$line" == "#"* || "$line" == "---" || -z "$line" ]] && continue
            WORKFLOW_RECORDER_LOG+=("$line")
        done < "$file"
        WORKFLOW_RECORDER_NAME="$name"
        return 0
    fi
    return 1
}

##############################################
# Replay a recorded workflow.
workflow_recorder_replay() {
    local count=0
    local entry
    for entry in "${WORKFLOW_RECORDER_LOG[@]}"; do
        local cat="${entry#*|}"
        cat="${cat%%|*}"
        local action="${entry#*|*|}"
        action="${action%%|*}"
        notify_push "Replaying: $action" "info"
        event_bus_emit "automation" "workflow_replay" "$action" "info"
        sleep 0.5
        ((count++))
    done
    echo "$count steps replayed"
}

##############################################
# List saved workflows.
workflow_recorder_list() {
    local result=()
    if [[ -d "$WORKFLOW_RECORDER_DIR" ]]; then
        local f
        for f in "$WORKFLOW_RECORDER_DIR"/*.wf; do
            [[ -f "$f" ]] && result+=("$(basename "$f" .wf)" "$f")
        done
    fi
    if [[ "${#result[@]}" -eq 0 ]]; then
        echo "No saved workflows"
    else
        local i=0
        while (( i < ${#result[@]} )); do
            echo "${result[$i]} ($(wc -l < "${result[$((i+1))]}") lines)"
            ((i += 2))
        done
    fi
}

##############################################
# Render workflow recorder page.
_page_render_workflow_recorder() {
    local top="$1" left="$2" width="$3" height="$4"
    workflow_recorder_init

    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Workflow Recorder'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Record, replay, and share workflows'
    renderer_reset

    local row=$(( top + 2 ))
    local col="$left"

    # Recording status
    if [[ "$WORKFLOW_RECORDER_ACTIVE" == "true" ]]; then
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get error)"
        renderer_bold
        printf ' ● RECORDING: %s  (%d steps)' "$WORKFLOW_RECORDER_NAME" "${#WORKFLOW_RECORDER_LOG[@]}"
        renderer_reset
    else
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get muted)"
        printf ' Not recording. Press [r] to start.'
        renderer_reset
    fi
    ((row++))

    # Actions
    local actions=()
    if [[ "$WORKFLOW_RECORDER_ACTIVE" == "true" ]]; then
        actions+=("s" "Stop & Save" "c" "Cancel")
    else
        actions+=("r" "Start Recording" "l" "Load" "p" "Play" "d" "Delete")
    fi
    renderer_cursor_goto "$row" "$col"
    local i=0
    while (( i < ${#actions[@]} )); do
        renderer_fg_256 "$(theme_get info)"
        renderer_bold
        printf ' [%s]' "${actions[$i]}"
        renderer_reset
        renderer_fg_256 "$(theme_get fg)"
        printf ' %s ' "${actions[$((i+1))]}"
        renderer_reset
        ((i += 2))
    done
    ((row += 2))

    # Steps log
    if [[ "${#WORKFLOW_RECORDER_LOG[@]}" -gt 0 ]]; then
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get muted)"
        renderer_dim
        printf 'Recorded Steps:'
        renderer_reset
        ((row++))

        local max_steps=$(( height - (row - top) - 1 ))
        local start=$(( ${#WORKFLOW_RECORDER_LOG[@]} - max_steps ))
        [[ "$start" -lt 0 ]] && start=0

        local idx
        for (( idx = start; idx < ${#WORKFLOW_RECORDER_LOG[@]}; idx++ )); do
            [[ "$row" -ge $(( top + height - 1 )) ]] && break
            local entry="${WORKFLOW_RECORDER_LOG[$idx]}"
            local ts="${entry%%|*}"
            local rest="${entry#*|}"
            local cat="${rest%%|*}"
            rest="${rest#*|}"
            local action="${rest%%|*}"

            renderer_cursor_goto "$row" "$col"
            renderer_fg_256 "$(theme_get muted)"
            printf '  [%s] %s' "$cat" "$action"
            renderer_reset
            ((row++))
        done
    fi

    # Saved workflows list
    if [[ "$WORKFLOW_RECORDER_ACTIVE" != "true" ]]; then
        ((row++))
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get muted)"
        renderer_dim
        printf 'Saved workflows:'
        renderer_reset
        ((row++))
        local saved
        saved="$(workflow_recorder_list)"
        while IFS= read -r line; do
            [[ "$row" -ge $(( top + height - 1 )) ]] && break
            renderer_cursor_goto "$row" "$col"
            renderer_fg_256 "$(theme_get fg)"
            printf '  • %s' "$line"
            renderer_reset
            ((row++))
        done <<< "$saved"
    fi
}

_page_key_workflow_recorder() {
    local key="$1"
    case "$key" in
        "r"|"R")
            local name
            name="$(menu_input "Record Workflow" "Workflow name:")" || return 0
            workflow_recorder_start "${name:-workflow_$(date +%Y%m%d_%H%M%S)}"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "s"|"S")
            if [[ "$WORKFLOW_RECORDER_ACTIVE" == "true" ]]; then
                workflow_recorder_stop
                local file
                file="$(workflow_recorder_save)"
                menu_textbox "Workflow Saved" "Saved to: $file"
            fi
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "c"|"C")
            if [[ "$WORKFLOW_RECORDER_ACTIVE" == "true" ]]; then
                WORKFLOW_RECORDER_ACTIVE=false
                WORKFLOW_RECORDER_LOG=()
                notify_push "Recording cancelled" "info"
            fi
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "l"|"L")
            local list
            list="$(workflow_recorder_list)"
            if [[ "$list" == "No saved workflows" ]]; then
                notify_push "No workflows to load" "warning"
                DASHBOARD_REDRAW_NEEDED=true
                return 0
            fi
            local name
            name="$(menu_input "Load Workflow" "Workflow name:")" || return 0
            if workflow_recorder_load "$name"; then
                notify_push "Loaded: $name (${#WORKFLOW_RECORDER_LOG[@]} steps)" "success"
            else
                notify_push "Workflow not found: $name" "error"
            fi
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "p"|"P")
            if [[ "${#WORKFLOW_RECORDER_LOG[@]}" -eq 0 ]]; then
                notify_push "No workflow loaded" "warning"
                DASHBOARD_REDRAW_NEEDED=true
                return 0
            fi
            if menu_yesno "Replay" "Replay ${#WORKFLOW_RECORDER_LOG[@]} steps?"; then
                local result
                result="$(workflow_recorder_replay)"
                notify_push "$result" "success"
            fi
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "d"|"D")
            local name
            name="$(menu_input "Delete Workflow" "Workflow name:")" || return 0
            local file="${WORKFLOW_RECORDER_DIR}/${name}.wf"
            if [[ -f "$file" ]]; then
                rm -f "$file"
                notify_push "Deleted: $name" "info"
            else
                notify_push "Not found: $name" "error"
            fi
            DASHBOARD_REDRAW_NEEDED=true
            ;;
    esac
}
