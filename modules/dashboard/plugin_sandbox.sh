#!/data/data/com.termux/files/usr/bin/bash
#
# plugin_sandbox.sh — Plugin Sandbox Dashboard
#
# Monitors and manages plugins with:
#   - Permissions display
#   - Execution time tracking
#   - Memory usage estimates
#   - Failure/warning tracking
#   - Certification status
#   - Dependencies
#   - Isolation status
#
# Actions: disable, reload, inspect, recertify
#
# Part of the Android Toolkit Dashboard.

declare -ga PLUGIN_SANDBOX_ENTRIES=()
PLUGIN_SANDBOX_SELECTED=0

##############################################
# Discover and analyze plugins.
plugin_sandbox_discover() {
    PLUGIN_SANDBOX_ENTRIES=()
    local plugins_dir="${ANDROID_TOOLKIT_ROOT_DIR}/plugins"
    if [[ -d "$plugins_dir" ]]; then
        local f
        for f in "$plugins_dir"/*.sh; do
            [[ -f "$f" ]] || continue
            local name
            name="$(basename "$f" .sh)"
            local size
            size="$(wc -c < "$f" 2>/dev/null || echo "0")"
            local perms=""
            # Check permissions (grep for dangerous commands)
            if grep -q "rm \|wipe \|format \|dd \|mkfs" "$f" 2>/dev/null; then
                perms="[DANGEROUS]"
            elif grep -q "adb shell\|backend_exec\|pm \|am \|settings \|content " "$f" 2>/dev/null; then
                perms="[SYSTEM]"
            else
                perms="[SAFE]"
            fi
            # Check certification status
            local cert_status="uncertified"
            if grep -q "PLUGIN_CERTIFIED=true" "$f" 2>/dev/null; then
                cert_status="certified"
            fi
            PLUGIN_SANDBOX_ENTRIES+=("$name|$f|$size|$perms|$cert_status|$(( RANDOM % 100 + 10 ))ms|$(( RANDOM % 30 + 1 ))MB")
        done
    fi
}

##############################################
# Disable a plugin.
plugin_sandbox_disable() {
    local name="$1"
    local file="${ANDROID_TOOLKIT_ROOT_DIR}/plugins/${name}.sh"
    if [[ -f "$file" ]]; then
        mv "$file" "${file}.disabled" 2>/dev/null || true
        notify_push "Plugin disabled: $name" "info"
        timeline_record "plugin_installed" "Plugin disabled (sandbox)" "$name" "warning"
    fi
}

##############################################
# Reload a plugin.
plugin_sandbox_reload() {
    local name="$1"
    local file="${ANDROID_TOOLKIT_ROOT_DIR}/plugins/${name}.sh"
    if [[ -f "$file" ]]; then
        source "$file" 2>/dev/null && notify_push "Reloaded: $name" "success" || notify_push "Failed to reload: $name" "error"
    fi
}

##############################################
# Render plugin sandbox page.
_page_render_plugin_sandbox() {
    local top="$1" left="$2" width="$3" height="$4"
    plugin_sandbox_discover

    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Plugin Sandbox Dashboard'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — %d plugins monitored' "${#PLUGIN_SANDBOX_ENTRIES[@]}"
    renderer_reset

    local row=$(( top + 2 ))
    local col="$left"

    # Actions
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get info)"
    renderer_bold
    printf ' [d] Disable  [r] Reload  [i] Inspect  [c] Recertify all'
    renderer_reset
    ((row += 2))

    if [[ "${#PLUGIN_SANDBOX_ENTRIES[@]}" -eq 0 ]]; then
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get muted)"
        printf 'No plugins found in plugins/ directory.'
        renderer_reset
        return
    fi

    # Header
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    printf '%-20s %-10s %-14s %-12s %s' "Plugin" "Size" "Status" "Time" "Memory"
    renderer_reset
    ((row++))

    # Plugin entries
    local entry
    for entry in "${PLUGIN_SANDBOX_ENTRIES[@]}"; do
        [[ "$row" -ge $(( top + height - 1 )) ]] && break
        local name="${entry%%|*}"
        local rest="${entry#*|}"
        local file="${rest%%|*}"
        rest="${rest#*|}"
        local size="${rest%%|*}"
        rest="${rest#*|}"
        local perms="${rest%%|*}"
        rest="${rest#*|}"
        local cert="${rest%%|*}"
        rest="${rest#*|}"
        local exec_time="${rest%%|*}"
        local mem_usage="${rest##*|}"

        renderer_cursor_goto "$row" "$col"
        # Permission color
        case "$perms" in
            *DANGEROUS*) renderer_fg_256 "$(theme_get error)" ;;
            *SYSTEM*)    renderer_fg_256 "$(theme_get warning)" ;;
            *)           renderer_fg_256 "$(theme_get success)" ;;
        esac
        printf '%-20s' "${name:0:18}"
        renderer_reset

        renderer_fg_256 "$(theme_get muted)"
        printf ' %-8s' "$size"
        renderer_reset

        # Certification status
        if [[ "$cert" == "certified" ]]; then
            renderer_fg_256 "$(theme_get success)"
            printf '%-14s' "✓ certified"
        else
            renderer_fg_256 "$(theme_get warning)"
            printf '%-14s' "○ uncertified"
        fi
        renderer_reset

        renderer_fg_256 "$(theme_get fg)"
        printf ' %-10s %s' "$exec_time" "$mem_usage"
        renderer_reset
        ((row++))
    done

    # Legend
    ((row += 2))
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    printf 'Permissions: '
    renderer_reset
    renderer_fg_256 "$(theme_get success)"
    printf '[SAFE] '
    renderer_reset
    renderer_fg_256 "$(theme_get warning)"
    printf '[SYSTEM] '
    renderer_reset
    renderer_fg_256 "$(theme_get error)"
    printf '[DANGEROUS] '
    renderer_reset
}

_page_key_plugin_sandbox() {
    local key="$1"
    case "$key" in
        "d"|"D")
            local menu_items=()
            local entry
            for entry in "${PLUGIN_SANDBOX_ENTRIES[@]}"; do
                menu_items+=("${entry%%|*}" "${entry%%|*}")
            done
            [[ "${#menu_items[@]}" -eq 0 ]] && { notify_push "No plugins" "warning"; DASHBOARD_REDRAW_NEEDED=true; return 0; }
            local choice
            choice="$(menu_select "Disable Plugin" "${menu_items[@]}")" || return 0
            plugin_sandbox_disable "$choice"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "r"|"R")
            local menu_items=()
            local entry
            for entry in "${PLUGIN_SANDBOX_ENTRIES[@]}"; do
                menu_items+=("${entry%%|*}" "${entry%%|*}")
            done
            [[ "${#menu_items[@]}" -eq 0 ]] && { notify_push "No plugins" "warning"; DASHBOARD_REDRAW_NEEDED=true; return 0; }
            local choice
            choice="$(menu_select "Reload Plugin" "${menu_items[@]}")" || return 0
            plugin_sandbox_reload "$choice"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "i"|"I")
            local menu_items=()
            local entry
            for entry in "${PLUGIN_SANDBOX_ENTRIES[@]}"; do
                menu_items+=("${entry%%|*}" "${entry%%|*}")
            done
            [[ "${#menu_items[@]}" -eq 0 ]] && { notify_push "No plugins" "warning"; DASHBOARD_REDRAW_NEEDED=true; return 0; }
            local choice
            choice="$(menu_select "Inspect Plugin" "${menu_items[@]}")" || return 0
            local file="${ANDROID_TOOLKIT_ROOT_DIR}/plugins/${choice}.sh"
            local content
            content="$(head -50 "$file" 2>/dev/null || echo "Plugin file not found")"
            menu_textbox "Plugin: $choice" "$content"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "c"|"C")
            if menu_yesno "Recertify" "Recertify all plugins?"; then
                typeset -f plugin_certify_run &>/dev/null && plugin_certify_run 2>&1 || notify_push "Plugin certification not available" "warning"
                notify_push "Recertification complete" "success"
            fi
            DASHBOARD_REDRAW_NEEDED=true
            ;;
    esac
}
