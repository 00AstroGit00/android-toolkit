#!/data/data/com.termux/files/usr/bin/bash
#
# plugin_center.sh — Plugin Development Center
#
# Interactive environment for plugin management:
#   - Installed plugins list
#   - API documentation reference
#   - SDK compatibility check
#   - Plugin validation and certification
#   - Test execution
#
# Part of the Android Toolkit Dashboard.

PLUGIN_CENTER_PLUGINS=()
PLUGIN_CENTER_SELECTED=0

##############################################
# Discover installed plugins.
plugin_center_discover() {
    PLUGIN_CENTER_PLUGINS=()
    local output
    output="$(plugin_list 2>&1 || true)"
    while IFS= read -r line; do
        [[ -n "$line" && "$line" != "No plugins"* && "$line" != "Plugin"* ]] && PLUGIN_CENTER_PLUGINS+=("$line")
    done <<< "$output"
    [[ "${#PLUGIN_CENTER_PLUGINS[@]}" -eq 0 ]] && PLUGIN_CENTER_PLUGINS=("No plugins installed")
}

##############################################
# Render plugin development center.
_page_render_plugin_center() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Plugin Development Center'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Manage and develop plugins'
    renderer_reset

    plugin_center_discover
    local row=$(( top + 2 ))
    local col="$left"

    # Quick actions
    local actions=(
        "1" "List Plugins"
        "2" "Validate"
        "3" "Certify"
        "4" "API Docs"
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
    ((row += 2))

    # Plugin list
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    printf 'Installed Plugins:'
    renderer_reset
    ((row++))

    local plugin
    for plugin in "${PLUGIN_CENTER_PLUGINS[@]}"; do
        [[ "$row" -ge $(( top + height - 2 )) ]] && break
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get fg)"
        printf '  • %s' "$plugin"
        renderer_reset
        ((row++))
    done

    # Documentation reference
    ((row++))
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    printf 'SDK Reference: PLUGIN_API.md, plugin_run(), plugin_list(), plugin_load_all()'
    renderer_reset
}

_page_key_plugin_center() {
    local key="$1"
    case "$key" in
        "1")
            local output
            output="$(plugin_list 2>&1)"
            menu_textbox "Installed Plugins" "$output"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "2")
            local output
            output="$(_load_module "plugin_certify" 2>/dev/null && plugin_certify_run 2>&1 || echo "Certify module loaded.")"
            menu_textbox "Plugin Validation" "$output"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "3")
            local pname
            pname="$(menu_input "Certify" "Plugin name (or leave empty for all):")" || return 0
            local output
            if [[ -n "$pname" ]]; then
                _load_module "plugin_certify" 2>/dev/null || true
                output="$(plugin_certify_run "$pname" 2>&1 || echo "Plugin certification not available.")"
            else
                _load_module "plugin_certify" 2>/dev/null || true
                output="$(plugin_certify_run 2>&1 || echo "Plugin certification not available.")"
            fi
            menu_textbox "Certification Results" "$output"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "4")
            local docs="${ANDROID_TOOLKIT_ROOT_DIR}/docs/PLUGIN_API.md"
            if [[ -f "$docs" ]]; then
                menu_textbox "Plugin SDK API" "$(cat "$docs" 2>/dev/null | head -100)"
            else
                menu_textbox "Plugin SDK" "Plugin API documentation not found.\nSee: docs/PLUGIN_API.md\n\nKey functions:\n  plugin_load_all()\n  plugin_list()\n  plugin_run()\n  plugin_certify_run()"
            fi
            DASHBOARD_REDRAW_NEEDED=true
            ;;
    esac
}
