#!/data/data/com.termux/files/usr/bin/bash
#
# audit_trail.sh — Audit Trail
#
# Records all significant dashboard actions with:
#   - Action log with timestamps
#   - Category filtering
#   - Export capabilities
#   - Search and filtering
#
# Part of the Android Toolkit Dashboard.

declare -a AUDIT_LOG=()
AUDIT_LOG_MAX=500
AUDIT_FILTER=""
AUDIT_EXPORT_DIR="${ANDROID_TOOLKIT_ROOT_DIR}/audit"

##############################################
# Record an audit entry.
audit_record() {
    local category="$1" action="$2" detail="${3:-}" result="${4:-info}"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local entry="[$timestamp] [$category] $action"
    [[ -n "$detail" ]] && entry+=" — $detail"
    [[ -n "$result" ]] && entry+=" [$result]"
    AUDIT_LOG+=("$entry")
    # Trim to max
    while [[ "${#AUDIT_LOG[@]}" -gt "$AUDIT_LOG_MAX" ]]; do
        AUDIT_LOG=("${AUDIT_LOG[@]:1}")
    done
    # Also append to file
    local logfile="${AUDIT_EXPORT_DIR}/audit.log"
    mkdir -p "$AUDIT_EXPORT_DIR" 2>/dev/null || true
    echo "$entry" >> "$logfile" 2>/dev/null || true
    # Rotate log file if too large
    local size
    size="$(stat -c%s "$logfile" 2>/dev/null || echo "0")"
    if [[ "$size" -gt 1048576 ]]; then  # 1MB
        mv -f "$logfile" "${logfile}.old" 2>/dev/null || true
    fi
}

##############################################
# Export audit trail.
audit_export() {
    local format="${1:-txt}"
    local ts
    ts="$(date +%Y%m%d_%H%M%S)"
    local filename="audit_export_${ts}.${format}"
    mkdir -p "$AUDIT_EXPORT_DIR" 2>/dev/null || true
    case "$format" in
        csv)
            {
                echo "Timestamp,Category,Action,Detail,Result"
                local entry
                for entry in "${AUDIT_LOG[@]}"; do
                    # Parse structured log entry
                    local ts_entry="${entry%%]*}"
                    ts_entry="${ts_entry#[}"
                    local rest="${entry#*] }"
                    local cat="${rest%%]*}"
                    cat="${cat#[}"
                    rest="${rest#*] }"
                    local act="${rest%% — *}"
                    local rest2="${rest#* — }"
                    local det="${rest2% \[*}"
                    local res="${rest2##*\[}"
                    res="${res%\]}"
                    echo "\"$ts_entry\",\"$cat\",\"$act\",\"$det\",\"$res\""
                done
            } > "${AUDIT_EXPORT_DIR}/${filename}" 2>/dev/null || return 1
            ;;
        json)
            {
                echo "["
                local sep=""
                local entry
                for entry in "${AUDIT_LOG[@]}"; do
                    echo "${sep}  {\"entry\": \"${entry}\"}"
                    sep=","
                done
                echo "]"
            } > "${AUDIT_EXPORT_DIR}/${filename}" 2>/dev/null || return 1
            ;;
        txt|*)
            {
                echo "Audit Trail Export — $ts"
                echo "Entries: ${#AUDIT_LOG[@]}"
                echo "---"
                local entry
                for entry in "${AUDIT_LOG[@]}"; do
                    echo "$entry"
                done
            } > "${AUDIT_EXPORT_DIR}/${filename}" 2>/dev/null || return 1
            ;;
    esac
    echo "${AUDIT_EXPORT_DIR}/${filename}"
}

##############################################
# Get audit summary counts.
audit_summary() {
    local total="${#AUDIT_LOG[@]}"
    local success=0 error=0 info=0 warning=0
    local entry
    for entry in "${AUDIT_LOG[@]}"; do
        case "$entry" in
            *"[success]")  ((success++));;
            *"[error]")    ((error++));;
            *"[warning]")  ((warning++));;
            *"[info]")     ((info++));;
        esac
    done
    echo "total=$total success=$success error=$error warning=$warning info=$info"
}

##############################################
# Render audit trail page.
_page_render_audit_trail() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Audit Trail'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Action log (%d entries)' "${#AUDIT_LOG[@]}"
    renderer_reset

    local row=$(( top + 2 ))
    local col="$left"

    # Summary bar
    eval "$(audit_summary)"
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get success)"
    printf ' ✓%d' "${success:-0}"
    renderer_reset
    renderer_fg_256 "$(theme_get warning)"
    printf ' ⚠%d' "${warning:-0}"
    renderer_reset
    renderer_fg_256 "$(theme_get error)"
    printf ' ✗%d' "${error:-0}"
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' ℹ%d' "${info:-0}"
    renderer_reset
    ((row++))

    # Action buttons
    local actions=(
        "e" "Export (TXT)" 
        "c" "Export (CSV)"
        "j" "Export (JSON)"
        "f" "Clear Filter"
    )
    renderer_cursor_goto "$row" "$col"
    local i=0
    while (( i < ${#actions[@]} )); do
        local key="${actions[$i]}"
        local label="${actions[$((i+1))]}"
        renderer_fg_256 "$(theme_get info)"
        renderer_bold
        printf ' [%s]' "$key"
        renderer_reset
        renderer_fg_256 "$(theme_get fg)"
        printf ' %s ' "$label"
        renderer_reset
        ((i += 2))
    done
    ((row++))

    # Filter indicator
    if [[ -n "$AUDIT_FILTER" ]]; then
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get warning)"
        printf ' Filter: %s' "$AUDIT_FILTER"
        renderer_reset
        ((row++))
    fi

    # Log entries (reverse chronological)
    local max_rows=$(( height - 8 ))
    local start_idx=$(( ${#AUDIT_LOG[@]} - max_rows ))
    [[ "$start_idx" -lt 0 ]] && start_idx=0

    local idx
    for (( idx = ${#AUDIT_LOG[@]} - 1; idx >= start_idx; idx-- )); do
        [[ "$row" -ge $(( top + height - 1 )) ]] && break
        local entry="${AUDIT_LOG[$idx]}"
        # Apply filter
        if [[ -n "$AUDIT_FILTER" ]]; then
            [[ "$entry" != *"$AUDIT_FILTER"* ]] && continue
        fi

        renderer_cursor_goto "$row" "$col"
        if [[ "$entry" == *"[error]"* ]]; then
            renderer_fg_256 "$(theme_get error)"
        elif [[ "$entry" == *"[warning]"* ]]; then
            renderer_fg_256 "$(theme_get warning)"
        elif [[ "$entry" == *"[success]"* ]]; then
            renderer_fg_256 "$(theme_get success)"
        else
            renderer_fg_256 "$(theme_get muted)"
        fi
        local display="${entry:0:$((width - 2))}"
        printf ' %s' "$display"
        renderer_reset
        ((row++))
    done
}

_page_key_audit_trail() {
    local key="$1"
    case "$key" in
        "e")
            local file
            file="$(audit_export "txt")"
            menu_textbox "Audit Export" "Exported to: $file"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "c")
            local file
            file="$(audit_export "csv")"
            menu_textbox "Audit Export" "Exported to: $file"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "j")
            local file
            file="$(audit_export "json")"
            menu_textbox "Audit Export" "Exported to: $file"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "f"|"F")
            AUDIT_FILTER=""
            notify_push "Filter cleared" "info"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "/")
            local filter
            filter="$(menu_input "Audit Filter" "Enter search term:")" || return 0
            AUDIT_FILTER="$filter"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
    esac
}
