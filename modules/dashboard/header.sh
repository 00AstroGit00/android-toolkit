#!/data/data/com.termux/files/usr/bin/bash
#
# header.sh — Dashboard Top Bar
#
# Renders the persistent header showing:
#   - Toolkit title and version
#   - Device connection status
#   - Active backend
#   - Live battery indicator
#
# Part of the Android Toolkit Dashboard.

HEADER_HEIGHT=2

##############################################
# Render the header bar.
header_render() {
    local theme_bg theme_fg
    theme_bg="$(theme_get header_bg)"
    theme_fg="$(theme_get header_fg)"
    local muted="$(theme_get muted)"
    local accent="$(theme_get accent)"

    # Fill header background
    renderer_fill_rect 1 1 "$HEADER_HEIGHT" "$RENDERER_WIDTH" "$theme_bg"

    # ── Row 1: Title + Version + Connection Status ──
    local title="Android Toolkit"
    local version
    version="$(status_get version)"
    local model
    model="$(status_get model)"
    local backend
    backend="$(status_get backend)"

    # Left: Title badge
    renderer_cursor_goto 1 3
    renderer_bold
    renderer_fg_256 "$accent"
    printf '%s' "◆ $title"
    renderer_reset
    renderer_fg_256 "$muted"
    printf ' v%s' "$version"
    renderer_reset

    # Center: Device model
    renderer_cursor_goto 1 $(( RENDERER_WIDTH / 2 - ${#model} / 2 ))
    renderer_fg_256 "$theme_fg"
    printf '%s' "$model"
    renderer_reset

    # Right: Connection status
    local status_label status_color
    if [[ "$backend" != "none" ]]; then
        status_label="● Online"
        status_color="$(theme_get success)"
        renderer_fg_256 "$(theme_get muted)"
        printf '  '
        renderer_fg_256 "$status_color"
        printf '%s' "$status_label"
        renderer_reset
        renderer_fg_256 "$muted"
        printf ' [%s]' "$backend"
    else
        status_label="○ Offline"
        status_color="$(theme_get error)"
        renderer_fg_256 "$status_color"
        printf '  %s' "$status_label"
    fi
    renderer_reset

    # ── Row 2: Battery + Status bar ──
    local bat_pct
    bat_pct="$(status_get battery_pct)"
    local bat_temp
    bat_temp="$(status_get battery_temp)"
    local is_plugged
    is_plugged="$(status_get battery_plugged)"
    local mem_pct
    mem_pct="$(status_get mem_pct)"
    local storage_pct
    storage_pct="$(status_get storage_pct)"

    renderer_cursor_goto 2 3

    # Battery
    if [[ "$bat_pct" != "?" ]]; then
        renderer_fg_256 "$muted"
        printf 'Battery: '
        if [[ "$bat_pct" -lt 20 ]]; then
            renderer_fg_256 "$(theme_get error)"
        elif [[ "$bat_pct" -lt 50 ]]; then
            renderer_fg_256 "$(theme_get warning)"
        else
            renderer_fg_256 "$(theme_get success)"
        fi
        printf '%d%%' "$bat_pct"
        renderer_reset
        [[ "$bat_temp" != "?" ]] && {
            renderer_fg_256 "$muted"
            printf ' %s°C' "$bat_temp"
            renderer_reset
        }
        [[ "$is_plugged" == "true" ]] && {
            renderer_fg_256 "$(theme_get info)"
            printf ' ⚡'
            renderer_reset
        }
    fi

    # Memory
    if [[ "$mem_pct" != "?" ]]; then
        renderer_fg_256 "$muted"
        printf '  |  Mem: '
        if [[ "$mem_pct" -gt 85 ]]; then
            renderer_fg_256 "$(theme_get error)"
        elif [[ "$mem_pct" -gt 70 ]]; then
            renderer_fg_256 "$(theme_get warning)"
        else
            renderer_fg_256 "$(theme_get success)"
        fi
        printf '%d%%' "$mem_pct"
        renderer_reset
    fi

    # Storage
    if [[ -n "$storage_pct" && "$storage_pct" != "?" && "$storage_pct" != "" ]]; then
        renderer_fg_256 "$muted"
        printf '  |  Storage: '
        if [[ "$storage_pct" -gt 90 ]]; then
            renderer_fg_256 "$(theme_get error)"
        elif [[ "$storage_pct" -gt 75 ]]; then
            renderer_fg_256 "$(theme_get warning)"
        else
            renderer_fg_256 "$(theme_get success)"
        fi
        printf '%s%%' "$storage_pct"
        renderer_reset
    fi

    renderer_reset

    # Bottom separator
    renderer_draw_separator $(( HEADER_HEIGHT + 1 ))
}

##############################################
# Return the number of rows consumed by header.
header_height() {
    echo "$(( HEADER_HEIGHT + 1 ))"  # +1 for separator
}
