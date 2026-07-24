#!/data/data/com.termux/files/usr/bin/bash
#
# doc_browser.sh — Documentation Browser
#
# Integrated searchable documentation system.
# Browses modules, APIs, CLI commands, reports,
# plugin SDK, troubleshooting, and examples.
#
# Part of the Android Toolkit Dashboard.

DOC_BROWSER_ITEMS=()
DOC_BROWSER_CONTENT=""
DOC_BROWSER_CATEGORY=""

##############################################
# Discover available documentation.
doc_browser_discover() {
    DOC_BROWSER_ITEMS=()
    local docs_dir="${ANDROID_TOOLKIT_ROOT_DIR}/docs"
    if [[ -d "$docs_dir" ]]; then
        local f
        for f in "$docs_dir"/*.md; do
            [[ -f "$f" ]] && DOC_BROWSER_ITEMS+=("$(basename "$f" .md)" "$f")
        done
    fi
    # Add built-in references
    DOC_BROWSER_ITEMS+=(
        "README"        "${ANDROID_TOOLKIT_ROOT_DIR}/README.md"
        "CHANGELOG"     "${ANDROID_TOOLKIT_ROOT_DIR}/CHANGELOG.md"
        "CLI Commands"  "${ANDROID_TOOLKIT_ROOT_DIR}/toolkit.sh"
    )
}

##############################################
# Render documentation browser.
_page_render_doc_browser() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Documentation Browser'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Browse and search documentation'
    renderer_reset

    doc_browser_discover
    local row=$(( top + 2 ))
    local col="$left"

    # Categories
    local categories=(
        "1" "User Guide (README)"
        "2" "Dashboard Docs"
        "3" "CLI Reference"
        "4" "Plugin SDK"
        "5" "Architecture"
        "6" "Troubleshooting"
        "7" "Changelog"
        "8" "Browse All Docs"
    )

    local i=0
    while (( i < ${#categories[@]} )); do
        [[ "$row" -ge $(( top + height - 1 )) ]] && break
        local key="${categories[$i]}"
        local label="${categories[$((i+1))]}"
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get info)"
        renderer_bold
        printf ' [%s]' "$key"
        renderer_reset
        renderer_fg_256 "$(theme_get fg)"
        printf ' %s' "$label"
        renderer_reset
        ((row++))
        ((i += 2))
    done

    # Currently viewing indicator
    if [[ -n "$DOC_BROWSER_CONTENT" ]]; then
        ((row++))
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get muted)"
        renderer_dim
        printf 'Press V to view full content'
        renderer_reset
    fi
}

_page_key_doc_browser() {
    local key="$1"
    local content=""
    case "$key" in
        "1")
            local readme="${ANDROID_TOOLKIT_ROOT_DIR}/README.md"
            [[ -f "$readme" ]] && content="$(head -80 "$readme" 2>/dev/null)" || content="README.md not found"
            DOC_BROWSER_CONTENT="$content"
            menu_textbox "User Guide" "$content"
            ;;
        "2")
            content="Available dashboard documentation:"
            local f
            for f in DASHBOARD.md THEMES.md SHORTCUTS.md TUI_ARCHITECTURE.md MULTI_DEVICE.md AI_ASSISTANT.md AUTOMATION.md SECURITY_CENTER.md SESSION_MANAGER.md ENTERPRISE_SETTINGS.md DIAGNOSTICS_CENTER.md; do
                local path="${ANDROID_TOOLKIT_ROOT_DIR}/docs/$f"
                if [[ -f "$path" ]]; then
                    content+=$'\n'"  ✓ $f"
                else
                    content+=$'\n'"  ○ $f"
                fi
            done
            DOC_BROWSER_CONTENT="$content"
            menu_textbox "Dashboard Docs" "$content"
            ;;
        "3")
            content="CLI Reference — toolkit.sh [OPTIONS] <ACTION>"
            content+=$'\n\n'"Information:"
            content+=$'\n'"  --version          Show version"
            content+=$'\n'"  --help             Show help"
            content+=$'\n'"  --about            Show detailed info"
            content+=$'\n'"  --changelog        Display changelog"
            content+=$'\n\n'"Diagnostics:"
            content+=$'\n'"  --status           Device status"
            content+=$'\n'"  --report           Full report"
            content+=$'\n'"  --doctor           System diagnostics"
            content+=$'\n'"  --audit            Security audit"
            content+=$'\n'"  --benchmark        Performance test"
            content+=$'\n\n'"Operations:"
            content+=$'\n'"  --backup           Backup device"
            content+=$'\n'"  --apply <profile>  Apply profile"
            content+=$'\n'"  --compile          ART compilation"
            content+=$'\n'"  --trim-cache       Clear caches"
            content+=$'\n'"  --tui              Launch dashboard"
            DOC_BROWSER_CONTENT="$content"
            menu_textbox "CLI Reference" "$content"
            ;;
        "4")
            local plugin_docs="${ANDROID_TOOLKIT_ROOT_DIR}/docs/PLUGIN_API.md"
            if [[ -f "$plugin_docs" ]]; then
                content="$(cat "$plugin_docs" 2>/dev/null | head -80)"
            else
                content="Plugin SDK Documentation"
                content+=$'\n\n'"Key API Functions:"
                content+=$'\n'"  plugin_load_all() — Load all plugins"
                content+=$'\n'"  plugin_list() — List installed plugins"
                content+=$'\n'"  plugin_run() — Execute a plugin"
                content+=$'\n'"  plugin_certify_run() — Validate plugins"
                content+=$'\n\n'"See: docs/PLUGIN_API.md for full reference"
            fi
            DOC_BROWSER_CONTENT="$content"
            menu_textbox "Plugin SDK" "$content"
            ;;
        "5")
            content="Android Toolkit Architecture"
            content+=$'\n\n'"Core Layers:"
            content+=$'\n'"  toolkit.sh      — Entry point and CLI dispatcher"
            content+=$'\n'"  lib/            — Core libraries (logging, detection, etc.)"
            content+=$'\n'"  modules/        — Feature modules (performance, battery, etc.)"
            content+=$'\n'"  modules/dashboard/ — Interactive dashboard (13 modules)"
            content+=$'\n'"  plugins/        — Community extensions"
            content+=$'\n'"  profiles/       — Optimization profiles"
            content+=$'\n'"  docs/           — Documentation"
            content+=$'\n\n'"Backend Support: ADB (USB/wireless), Shizuku (rish)"
            content+=$'\n'"Target: Android 13–16, Samsung One UI 5–8"
            DOC_BROWSER_CONTENT="$content"
            menu_textbox "Architecture" "$content"
            ;;
        "6")
            content="Troubleshooting Guide"
            content+=$'\n\n'"No device found:"
            content+=$'\n'"  • Connect USB and enable USB debugging"
            content+=$'\n'"  • Run: adb devices"
            content+=$'\n'"  • For wireless: adb connect <ip>:5555"
            content+=$'\n\n'"Permission denied:"
            content+=$'\n'"  • Ensure Shizuku is running for rish backend"
            content+=$'\n'"  • Grant USB debugging authorization"
            content+=$'\n\n'"Module not found:"
            content+=$'\n'"  • Run: toolkit.sh --deps-check"
            content+=$'\n'"  • Install missing dependencies"
            content+=$'\n\n'"Dashboard not rendering:"
            content+=$'\n'"  • Ensure TERM=xterm-256color"
            content+=$'\n'"  • Install dialog or whiptail for popups"
            DOC_BROWSER_CONTENT="$content"
            menu_textbox "Troubleshooting" "$content"
            ;;
        "7")
            local changelog="${ANDROID_TOOLKIT_ROOT_DIR}/CHANGELOG.md"
            if [[ -f "$changelog" ]]; then
                content="$(head -80 "$changelog" 2>/dev/null)"
            else
                content="CHANGELOG.md not found"
            fi
            DOC_BROWSER_CONTENT="$content"
            menu_textbox "Changelog" "$content"
            ;;
        "8")
            # Browse all docs
            content="Available Documentation:"
            local item
            local idx=0
            while (( idx < ${#DOC_BROWSER_ITEMS[@]} )); do
                local name="${DOC_BROWSER_ITEMS[$idx]}"
                local path="${DOC_BROWSER_ITEMS[$((idx+1))]}"
                if [[ -f "$path" ]]; then
                    local size
                    size="$(wc -l < "$path" 2>/dev/null || echo "0")"
                    content+=$'\n'"  • $name (${size} lines)"
                fi
                ((idx += 2))
            done
            DOC_BROWSER_CONTENT="$content"
            menu_textbox "All Documentation" "$content"
            ;;
        "v"|"V")
            if [[ -n "$DOC_BROWSER_CONTENT" ]]; then
                menu_textbox "Documentation" "$DOC_BROWSER_CONTENT"
            fi
            ;;
    esac
    DASHBOARD_REDRAW_NEEDED=true
}
