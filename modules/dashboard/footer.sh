#!/data/data/com.termux/files/usr/bin/bash
#
# footer.sh — Dashboard Bottom Bar
#
# Shows context-sensitive keyboard shortcuts
# and status messages.
#
# Part of the Android Toolkit Dashboard.

FOOTER_HEIGHT=2
FOOTER_MESSAGE=""
FOOTER_MESSAGE_TTL=0
FOOTER_MESSAGE_TYPE="info"

##############################################
# Set a transient footer message.
# Arguments:
#   $1: message text
#   $2: type (info|success|warning|error)
#   $3: duration in seconds (default: 5)
footer_message() {
    FOOTER_MESSAGE="$1"
    FOOTER_MESSAGE_TYPE="${2:-info}"
    local duration="${3:-5}"
    FOOTER_MESSAGE_TTL=$(( $(date +%s) + duration ))
}

##############################################
# Render the footer bar.
# Arguments:
#   $1: current page ID (for context-sensitive keys)
footer_render() {
    local page_id="${1:-dashboard}"
    local theme_bg theme_fg
    theme_bg="$(theme_get footer_bg)"
    theme_fg="$(theme_get footer_fg)"
    local success="$(theme_get success)"
    local warning="$(theme_get warning)"
    local error="$(theme_get error)"
    local info="$(theme_get info)"

    local foot_row=$(( RENDERER_HEIGHT - FOOTER_HEIGHT + 1 ))

    # Fill footer background
    renderer_fill_rect "$foot_row" 1 "$FOOTER_HEIGHT" "$RENDERER_WIDTH" "$theme_bg"

    # Top separator
    renderer_draw_separator $(( foot_row - 1 ))

    # ── Row 1: Message area ──
    local now
    now="$(date +%s)"
    renderer_cursor_goto "$foot_row" 3
    if [[ "$now" -lt "$FOOTER_MESSAGE_TTL" && -n "$FOOTER_MESSAGE" ]]; then
        case "$FOOTER_MESSAGE_TYPE" in
            success) renderer_fg_256 "$success" ;;
            warning) renderer_fg_256 "$warning" ;;
            error)   renderer_fg_256 "$error" ;;
            *)       renderer_fg_256 "$info" ;;
        esac
        printf '%s' "$FOOTER_MESSAGE"
        renderer_reset
    fi

    # ── Row 2: Shortcuts ──
    local shortcuts_str=""
    case "$page_id" in
        dashboard)
            shortcuts_str=" ↑↓ Navigate  |  Enter Select  |  F1 Help  |  F5 Refresh  |  Q Quit"
            ;;
        devices)
            shortcuts_str=" ↑↓ Select  |  Enter Switch  |  F1 Help  |  ESC Back  |  Q Quit"
            ;;
        performance|optimization|packages|bloatware|battery|display|network|security|plugins|reports|benchmarks|validation|compatibility|logs|settings|help|about)
            shortcuts_str=" ↑↓ Navigate  |  Enter Select  |  F1 Help  |  ESC Back  |  Q Quit"
            ;;
        multi_device)
            shortcuts_str=" ↑↓ Select  |  Space Toggle  |  B Broadcast  |  G Group   |  F1 Help  |  ESC Back"
            ;;
        device_compare)
            shortcuts_str=" ↑↓ Scroll  |  F5 Refresh  |  F1 Help  |  ESC Back  |  Q Quit"
            ;;
        ai_assistant)
            shortcuts_str=" h Health  |  o Optimize  |  b Battery  |  s Security  |  t Storage  |  m Memory  |  ? Help  |  ESC Back"
            ;;
        terminal)
            shortcuts_str=" Type command + Enter  |  ↑↓ History  |  T Toggle Safe  |  C Clear  |  F1 Help  |  ESC Back"
            ;;
        automation)
            shortcuts_str=" ↑↓ Select  |  Enter Run  |  B Builder  |  S Scheduler  |  F1 Help  |  ESC Back"
            ;;
        diagnostics)
            shortcuts_str=" 1-6 Category  |  A All  |  F5 Refresh  |  F1 Help  |  ESC Back"
            ;;
        perf_monitor)
            shortcuts_str=" S Snapshot  |  R Reset  |  Auto-refresh 2s  |  F1 Help  |  ESC Back"
            ;;
        plugin_center)
            shortcuts_str=" 1 List  |  2 Validate  |  3 Certify  |  4 API Docs  |  F1 Help  |  ESC Back"
            ;;
        doc_browser)
            shortcuts_str=" 1-8 Browse  |  V View  |  F1 Help  |  ESC Back  |  Q Quit"
            ;;
        audit_trail)
            shortcuts_str=" e TXT  |  c CSV  |  j JSON  |  f Clear  |  / Search  |  F1 Help  |  ESC Back"
            ;;
        session_manager)
            shortcuts_str=" n New  |  s Save  |  r Restore  |  d Delete  |  F1 Help  |  ESC Back"
            ;;
        enterprise_settings)
            shortcuts_str=" 1-7 Edit  |  s Save  |  r Reload  |  q Apply  |  F1 Help  |  ESC Back"
            ;;
        security_center)
            shortcuts_str=" 1-0 Category  |  a Audit  |  h Harden  |  F5 Refresh  |  F1 Help  |  ESC Back"
            ;;
        event_bus)
            shortcuts_str=" c Clear  |  s Stats  |  1-8 Filter category  |  F1 Help  |  ESC Back"
            ;;
        digital_twin)
            shortcuts_str=" u Update  |  c Compare  |  e Export  |  r Reset  |  F1 Help  |  ESC Back"
            ;;
        timeline)
            shortcuts_str=" e Export  |  f Filter  |  / Search  |  r Replay  |  1-6 Type  |  F1 Help"
            ;;
        health_intel)
            shortcuts_str=" r Refresh  |  F1 Help  |  ESC Back  |  Q Quit"
            ;;
        predictive)
            shortcuts_str=" r Refresh  |  d Detailed view  |  F1 Help  |  ESC Back"
            ;;
        recommendations)
            shortcuts_str=" r Refresh  |  1-9 Execute  |  F1 Help  |  ESC Back"
            ;;
        fleet)
            shortcuts_str=" r Refresh  |  p Policy  |  b Bulk Report  |  F1 Help  |  ESC Back"
            ;;
        policies)
            shortcuts_str=" c Check  |  s Save  |  1-8 Edit  |  F1 Help  |  ESC Back"
            ;;
        report_studio)
            shortcuts_str=" 1-9 Generate  |  F1 Help  |  ESC Back  |  Q Quit"
            ;;
        system_map)
            shortcuts_str=" p Find path  |  F1 Help  |  ESC Back"
            ;;
        workflow_recorder)
            shortcuts_str=" r Record  |  s Stop  |  l Load  |  p Play  |  d Delete  |  F1 Help"
            ;;
        recovery_center)
            shortcuts_str=" n New  |  r Restore  |  v Validate  |  f Failures  |  F1 Help"
            ;;
        knowledge_base)
            shortcuts_str=" / Search  |  c Clear  |  1-7 Category  |  F1 Help  |  ESC Back"
            ;;
        perf_profiler)
            shortcuts_str=" s Start  |  u Update  |  v View log  |  g Suggestions  |  F1 Help"
            ;;
        plugin_sandbox)
            shortcuts_str=" d Disable  |  r Reload  |  i Inspect  |  c Recertify  |  F1 Help"
            ;;
        profiles)
            shortcuts_str=" 1-6 Switch profile  |  F1 Help  |  ESC Back"
            ;;
        offline_mode)
            shortcuts_str=" t Toggle  |  c Cache Docs  |  s Sync  |  F1 Help  |  ESC Back"
            ;;
        *)
            shortcuts_str=" F1 Help  |  ESC Back  |  Q Quit"
            ;;
    esac

    renderer_cursor_goto $(( foot_row + 1 )) 3
    renderer_fg_256 "$theme_fg"
    printf '%s' "$shortcuts_str"
    renderer_reset

    # Right side: version and theme indicator
    local right_info
    right_info="v$(status_get version) | ${THEME_NAME^}"
    renderer_cursor_goto $(( foot_row + 1 )) $(( RENDERER_WIDTH - ${#right_info} - 2 ))
    renderer_fg_256 "$theme_fg"
    renderer_dim
    printf '%s' "$right_info"
    renderer_reset
}

##############################################
# Return the number of rows consumed by footer.
footer_height() {
    echo "$(( FOOTER_HEIGHT + 1 ))"  # +1 for separator
}
