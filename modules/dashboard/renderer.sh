#!/data/data/com.termux/files/usr/bin/bash
#
# renderer.sh — ANSI Terminal Rendering Engine
#
# Provides low-level terminal rendering:
#   - Screen buffer management
#   - Cursor movement and styling
#   - Color support (16, 256, truecolor)
#   - Unicode with ASCII fallback
#   - Terminal size detection
#   - Alternate screen buffer
#
# Part of the Android Toolkit Dashboard.

# ──────────────────────────────────────────────
# RENDERER STATE
# ──────────────────────────────────────────────
RENDERER_INITIALIZED=false
RENDERER_COLORS=0          # 0=mono, 8=16color, 256=256color, 16777216=truecolor
RENDERER_WIDTH=80
RENDERER_HEIGHT=24
RENDERER_HAS_UNICODE=false
RENDERER_SCREEN_BUFFER=()  # Off-screen buffer for double-buffering
RENDERER_BUFFER_DIRTY=false

# Box-drawing characters (with ASCII fallback)
RENDERER_HLINE="─"
RENDERER_VLINE="│"
RENDERER_TL="┌"
RENDERER_TR="┐"
RENDERER_BL="└"
RENDERER_BR="┘"
RENDERER_CROSS="┼"
RENDERER_TEE_L="├"
RENDERER_TEE_R="┤"
RENDERER_TEE_T="┬"
RENDERER_TEE_B="┴"
RENDERER_ARROW_R="▶"
RENDERER_ARROW_L="◀"
RENDERER_ARROW_U="▲"
RENDERER_ARROW_D="▼"
RENDERER_BULLET="•"
RENDERER_CHECK="✓"
RENDERER_CROSS_MARK="✗"
RENDERER_ELLIPSIS="…"

# ──────────────────────────────────────────────
# INITIALIZATION
# ──────────────────────────────────────────────

##############################################
# Initialize the renderer.
# Detects terminal capabilities and sets globals.
renderer_init() {
    renderer_detect_terminal_size
    renderer_detect_colors
    renderer_detect_unicode
    renderer_apply_ascii_fallback
    RENDERER_INITIALIZED=true
}

##############################################
# Detect terminal width and height.
renderer_detect_terminal_size() {
    if [[ -n "$LINES" && -n "$COLUMNS" ]] && [[ "$LINES" -gt 0 && "$COLUMNS" -gt 0 ]]; then
        RENDERER_HEIGHT="$LINES"
        RENDERER_WIDTH="$COLUMNS"
    else
        local size
        size="$(stty size 2>/dev/null || echo "24 80")"
        RENDERER_HEIGHT="${size%% *}"
        RENDERER_WIDTH="${size##* }"
    fi
    # Sanity
    [[ "$RENDERER_HEIGHT" -lt 10 ]] && RENDERER_HEIGHT=24
    [[ "$RENDERER_WIDTH" -lt 40 ]] && RENDERER_WIDTH=80
}

##############################################
# Detect color capabilities.
renderer_detect_colors() {
    RENDERER_COLORS=8  # safe default
    if [[ "$COLORTERM" == "truecolor" || "$COLORTERM" == "24bit" ]]; then
        RENDERER_COLORS=16777216
    elif [[ "$TERM" == *"256color"* ]]; then
        RENDERER_COLORS=256
    fi
    # Check via tput if available
    if command -v tput &>/dev/null; then
        local tc
        tc="$(tput colors 2>/dev/null || echo 8)"
        [[ "$tc" -gt "$RENDERER_COLORS" ]] && RENDERER_COLORS="$tc"
    fi
}

##############################################
# Detect Unicode support.
renderer_detect_unicode() {
    RENDERER_HAS_UNICODE=false
    [[ "$TERM" == *"xterm"* || "$TERM" == *"256color"* || "$TERM" == *"linux"* ]] && RENDERER_HAS_UNICODE=true
    LC_ALL="${LC_ALL:-C.UTF-8}" locale charmap 2>/dev/null | grep -qi 'utf-8' && RENDERER_HAS_UNICODE=true
}

##############################################
# Apply ASCII fallback when Unicode unavailable.
renderer_apply_ascii_fallback() {
    if [[ "$RENDERER_HAS_UNICODE" != "true" ]]; then
        RENDERER_HLINE="-"
        RENDERER_VLINE="|"
        RENDERER_TL="+"
        RENDERER_TR="+"
        RENDERER_BL="+"
        RENDERER_BR="+"
        RENDERER_CROSS="+"
        RENDERER_TEE_L="+"
        RENDERER_TEE_R="+"
        RENDERER_TEE_T="+"
        RENDERER_TEE_B="+"
        RENDERER_ARROW_R=">"
        RENDERER_ARROW_L="<"
        RENDERER_ARROW_U="^"
        RENDERER_ARROW_D="v"
        RENDERER_BULLET="*"
        RENDERER_CHECK="+"
        RENDERER_CROSS_MARK="x"
        RENDERER_ELLIPSIS="..."
    fi
}

# ──────────────────────────────────────────────
# SCREEN MANAGEMENT
# ──────────────────────────────────────────────

##############################################
# Enter alternate screen buffer (full-screen mode).
renderer_enter_alt_screen() {
    printf '\033[?1049h'
}

##############################################
# Exit alternate screen buffer.
renderer_exit_alt_screen() {
    printf '\033[?1049l'
}

##############################################
# Clear entire screen.
renderer_clear_screen() {
    printf '\033[2J\033[H'
}

##############################################
# Clear from cursor to end of screen.
renderer_clear_to_end() {
    printf '\033[J'
}

##############################################
# Clear current line.
renderer_clear_line() {
    printf '\033[2K\r'
}

##############################################
# Hide cursor.
renderer_hide_cursor() {
    printf '\033[?25l'
}

##############################################
# Show cursor.
renderer_show_cursor() {
    printf '\033[?25h'
}

##############################################
# Save cursor position.
renderer_save_cursor() {
    printf '\033[s'
}

##############################################
# Restore cursor position.
renderer_restore_cursor() {
    printf '\033[u'
}

# ──────────────────────────────────────────────
# CURSOR MOVEMENT
# ──────────────────────────────────────────────

renderer_cursor_goto() {
    local row="$1" col="$2"
    printf '\033[%d;%dH' "$row" "$col"
}

renderer_cursor_up()    { printf '\033[%dA' "${1:-1}"; }
renderer_cursor_down()  { printf '\033[%dB' "${1:-1}"; }
renderer_cursor_right() { printf '\033[%dC' "${1:-1}"; }
renderer_cursor_left()  { printf '\033[%dD' "${1:-1}"; }

# ──────────────────────────────────────────────
# STYLING
# ──────────────────────────────────────────────

renderer_reset()     { printf '\033[0m'; }
renderer_bold()      { printf '\033[1m'; }
renderer_dim()       { printf '\033[2m'; }
renderer_italic()    { printf '\033[3m'; }
renderer_underline() { printf '\033[4m'; }
renderer_blink()     { printf '\033[5m'; }
renderer_reverse()   { printf '\033[7m'; }

renderer_fg_color() {
    local color="$1"
    if [[ "$RENDERER_COLORS" -ge 16777216 ]]; then
        printf '\033[38;2;%d;%d;%dm' \
            "$(( (color >> 16) & 0xFF ))" \
            "$(( (color >> 8) & 0xFF ))" \
            "$(( color & 0xFF ))"
    elif [[ "$RENDERER_COLORS" -ge 256 ]]; then
        printf '\033[38;5;%dm' "$color"
    else
        # Map basic 0-7
        printf '\033[%dm' "$(( 30 + (color % 8) ))"
    fi
}

renderer_bg_color() {
    local color="$1"
    if [[ "$RENDERER_COLORS" -ge 16777216 ]]; then
        printf '\033[48;2;%d;%d;%dm' \
            "$(( (color >> 16) & 0xFF ))" \
            "$(( (color >> 8) & 0xFF ))" \
            "$(( color & 0xFF ))"
    elif [[ "$RENDERER_COLORS" -ge 256 ]]; then
        printf '\033[48;5;%dm' "$color"
    else
        printf '\033[%dm' "$(( 40 + (color % 8) ))"
    fi
}

renderer_fg_256() { printf '\033[38;5;%dm' "$1"; }
renderer_bg_256() { printf '\033[48;5;%dm' "$1"; }

renderer_fg_rgb() { printf '\033[38;2;%d;%d;%dm' "$1" "$2" "$3"; }
renderer_bg_rgb() { printf '\033[48;2;%d;%d;%dm' "$1" "$2" "$3"; }

# ──────────────────────────────────────────────
# DRAWING PRIMITIVES
# ──────────────────────────────────────────────

##############################################
# Draw horizontal line from (row, col) of given length.
renderer_draw_hline() {
    local row="$1" col="$2" len="$3" char="${4:-$RENDERER_HLINE}"
    renderer_cursor_goto "$row" "$col"
    local i=0
    while (( i < len )); do
        printf '%s' "$char"
        ((i++))
    done
}

##############################################
# Draw vertical line at (row, col) of given height.
renderer_draw_vline() {
    local row="$1" col="$2" len="$3" char="${4:-$RENDERER_VLINE}"
    local i=0
    while (( i < len )); do
        renderer_cursor_goto "$((row + i))" "$col"
        printf '%s' "$char"
        ((i++))
    done
}

##############################################
# Draw a bordered box.
# Arguments:
#   $1: top row
#   $2: left col
#   $3: height (content area)
#   $4: width (content area)
#   $5: title (optional)
renderer_draw_box() {
    local row="$1" col="$2" height="$3" width="$4" title="${5:-}"

    # Top border
    renderer_cursor_goto "$row" "$col"
    printf '%s' "$RENDERER_TL"
    local i=0
    while (( i < width )); do
        printf '%s' "$RENDERER_HLINE"
        ((i++))
    done
    printf '%s' "$RENDERER_TR"

    # Title in top border
    if [[ -n "$title" ]]; then
        local title_len="${#title}"
        local title_col=$(( col + (width - title_len) / 2 + 1 ))
        renderer_cursor_goto "$row" "$title_col"
        printf '%s' "$title"
    fi

    # Sides
    i=0
    while (( i < height )); do
        renderer_cursor_goto "$((row + 1 + i))" "$col"
        printf '%s' "$RENDERER_VLINE"
        renderer_cursor_goto "$((row + 1 + i))" "$((col + width + 1))"
        printf '%s' "$RENDERER_VLINE"
        ((i++))
    done

    # Bottom border
    renderer_cursor_goto "$((row + height + 1))" "$col"
    printf '%s' "$RENDERER_BL"
    i=0
    while (( i < width )); do
        printf '%s' "$RENDERER_HLINE"
        ((i++))
    done
    printf '%s' "$RENDERER_BR"
}

##############################################
# Render text at position with optional styling.
# Arguments:
#   $1: row (1-based)
#   $2: col (1-based)
#   $3: text
#   $4: max width (default: remaining)
renderer_draw_text() {
    local row="$1" col="$2" text="$3" max_width="${4:-999}"
    renderer_cursor_goto "$row" "$col"
    printf '%s' "${text:0:max_width}"
}

##############################################
# Render styled text at position.
# Arguments:
#   $1: row
#   $2: col
#   $3: text
#   $4: fg color (256-color index)
#   $5: bg color (optional)
#   $6: bold (true/false)
renderer_draw_styled() {
    local row="$1" col="$2" text="$3" fg="$4" bg="${5:-}" bold="${6:-false}"

    renderer_cursor_goto "$row" "$col"
    [[ "$bold" == "true" ]] && renderer_bold
    renderer_fg_256 "$fg"
    [[ -n "$bg" ]] && renderer_bg_256 "$bg"
    printf '%s' "$text"
    renderer_reset
}

##############################################
# Fill a rectangular area with spaces.
renderer_fill_rect() {
    local row="$1" col="$2" height="$3" width="$4" bg="${5:-}"
    local i=0
    while (( i < height )); do
        renderer_cursor_goto "$((row + i))" "$col"
        if [[ -n "$bg" ]]; then
            renderer_bg_256 "$bg"
            printf '%*s' "$width" ""
            renderer_reset
        else
            printf '%*s' "$width" ""
        fi
        ((i++))
    done
}

# ──────────────────────────────────────────────
# STATUS HELPERS
# ──────────────────────────────────────────────

##############################################
# Draw a colored status indicator.
# Arguments:
#   $1: row
#   $2: col
#   $3: status (ok, warn, error, info, muted)
#   $4: label
renderer_draw_status() {
    local row="$1" col="$2" status="$3" label="$4"
    local fg
    case "$status" in
        ok)    fg=82 ;;
        warn)  fg=220 ;;
        error) fg=196 ;;
        info)  fg=75 ;;
        muted) fg=244 ;;
        *)     fg=244 ;;
    esac
    local icon
    case "$status" in
        ok)    icon="$RENDERER_CHECK" ;;
        error) icon="$RENDERER_CROSS_MARK" ;;
        warn)  icon="!" ;;
        info)  icon="$RENDERER_BULLET" ;;
        muted) icon="-" ;;
        *)     icon="$RENDERER_BULLET" ;;
    esac
    renderer_fg_256 "$fg"
    printf ' %s %s' "$icon" "$label"
    renderer_reset
}

##############################################
# Draw a progress bar.
# Arguments:
#   $1: row
#   $2: col
#   $3: width in chars
#   $4: percentage (0-100)
renderer_draw_progress_bar() {
    local row="$1" col="$2" width="$3" pct="$4"
    [[ "$pct" -gt 100 ]] && pct=100
    [[ "$pct" -lt 0 ]] && pct=0
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))

    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 82
    printf '%*s' "$filled" "" | tr ' ' '█'
    renderer_fg_256 235
    printf '%*s' "$empty" "" | tr ' ' '░'
    renderer_reset
    renderer_fg_256 244
    printf ' %3d%%' "$pct"
    renderer_reset
}

##############################################
# Draw a separator line across the screen.
renderer_draw_separator() {
    local row="$1" char="${2:-$RENDERER_HLINE}"
    renderer_cursor_goto "$row" 1
    renderer_fg_256 236
    local i=0
    while (( i < RENDERER_WIDTH )); do
        printf '%s' "$char"
        ((i++))
    done
    renderer_reset
}

# ──────────────────────────────────────────────
# REFRESH
# ──────────────────────────────────────────────

##############################################
# Full screen refresh - redraw everything.
# This is called by the dashboard when state changes.
# Notification receivers should call this after updates.
renderer_refresh() {
    # Placeholder — the dashboard module registers
    # a callback that redraws all components.
    if typeset -f _dashboard_redraw &>/dev/null; then
        _dashboard_redraw
    fi
}

##############################################
# Cleanup - restore terminal state.
renderer_cleanup() {
    renderer_show_cursor
    renderer_exit_alt_screen
    renderer_reset
    clear 2>/dev/null || printf '\033[2J\033[H'
}
