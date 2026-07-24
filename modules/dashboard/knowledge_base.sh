#!/data/data/com.termux/files/usr/bin/bash
#
# knowledge_base.sh — Knowledge Base
#
# Integrated searchable knowledge system covering:
#   Commands, API, Modules, Plugin SDK, Troubleshooting,
#   Release Notes, Architecture, Best Practices, Examples.
# Cross-references related topics.
#
# Part of the Android Toolkit Dashboard.

declare -ga KNOWLEDGE_BASE_ENTRIES=()
KNOWLEDGE_BASE_SEARCH=""

##############################################
# Build knowledge base entries.
knowledge_base_build() {
    KNOWLEDGE_BASE_ENTRIES=()
    local docs_dir="${ANDROID_TOOLKIT_ROOT_DIR}/docs"

    # Commands
    KNOWLEDGE_BASE_ENTRIES+=("commands|CLI Commands|reference|How to use toolkit.sh CLI interface|toolkit.sh [--version|--help|--status|--doctor|--audit|--benchmark|--backup|--apply|--compile|--trim-cache|--tui]")
    KNOWLEDGE_BASE_ENTRIES+=("commands|Dashboard Shortcuts|reference|Keyboard shortcuts for interactive dashboard|↑↓ Navigate, Enter Select, F1 Help, F5 Refresh, Q Quit")

    # API
    KNOWLEDGE_BASE_ENTRIES+=("api|Public API Overview|api|Core API functions for modules and plugins|status_get(), backend_exec(), devices_list(), plugin_list(), audit_run()")
    KNOWLEDGE_BASE_ENTRIES+=("api|Status Functions|api|Query device metrics and state|status_get battery_pct, status_get model, status_get android_version, status_get thermal")
    KNOWLEDGE_BASE_ENTRIES+=("api|Backend Execution|api|Execute commands on device|backend_exec <command> — uses ADB or Shizuku backend")

    # Modules
    KNOWLEDGE_BASE_ENTRIES+=("modules|Dashboard Overview|module|Interactive full-screen dashboard|Header + Sidebar + Content + Footer architecture")
    KNOWLEDGE_BASE_ENTRIES+=("modules|Multi-Device Workspace|module|Manage multiple devices simultaneously|Broadcast commands, group operations, selection management")
    KNOWLEDGE_BASE_ENTRIES+=("modules|Digital Twin|module|Virtual device representation|Maintains hardware/software inventory and history")
    KNOWLEDGE_BASE_ENTRIES+=("modules|Health Intelligence Score|module|Weighted multi-category health scoring|10 categories: performance, battery, security, storage, thermals, network, configuration, plugins, reliability, compatibility")

    # Plugin SDK
    KNOWLEDGE_BASE_ENTRIES+=("plugins|Plugin SDK Overview|sdk|Develop custom plugins for the toolkit|plugin_run(), plugin_list(), plugin_certify_run()")
    KNOWLEDGE_BASE_ENTRIES+=("plugins|Plugin Lifecycle|sdk|How plugins are loaded and executed|discovery → validation → certification → execution")

    # Troubleshooting
    KNOWLEDGE_BASE_ENTRIES+=("troubleshooting|No Device Found|troubleshoot|Device not detected by toolkit|Connect USB, enable USB debugging, run 'adb devices'")
    KNOWLEDGE_BASE_ENTRIES+=("troubleshooting|Permission Denied|troubleshoot|Backend authorization issues|Ensure Shizuku is running or ADB is authorized")
    KNOWLEDGE_BASE_ENTRIES+=("troubleshooting|Dashboard Not Rendering|troubleshoot|Display issues in dashboard|Set TERM=xterm-256color, install dialog/whiptail")
    KNOWLEDGE_BASE_ENTRIES+=("troubleshooting|Plugin Load Failure|troubleshoot|Plugin certification or compatibility issues|Run plugin validation and check plugin SDK requirements")

    # Release Notes
    KNOWLEDGE_BASE_ENTRIES+=("releases|v5.0 Release Notes|release|Autonomous operations, enterprise intelligence, digital twin|Phase 4: Event bus, predictive analytics, fleet management, recovery center")
    KNOWLEDGE_BASE_ENTRIES+=("releases|v4.0 Release Notes|release|Enterprise console, AI assistant, multi-device|Phase 3: Terminal, automation, diagnostics, security center, session manager")

    # Architecture
    KNOWLEDGE_BASE_ENTRIES+=("architecture|System Architecture|arch|High-level toolkit architecture|toolkit.sh → modules/ + plugins/ + dashboard/ + lib/")
    KNOWLEDGE_BASE_ENTRIES+=("architecture|Event Bus Architecture|arch|Centralized inter-module communication|event_bus_emit/subscribe — pub/sub message system")
    KNOWLEDGE_BASE_ENTRIES+=("architecture|Digital Twin Data Model|arch|JSON-based device twin storage|twins/{device_id}.json — hardware, state, history sections")

    # Best Practices
    KNOWLEDGE_BASE_ENTRIES+=("practices|Create Recovery Points|practice|Before major operations|Always create a recovery point before applying profiles or removing packages")
    KNOWLEDGE_BASE_ENTRIES+=("practices|Monitor Health Score|practice|Track device reliability|Check Health Intelligence dashboard regularly for early warnings")
    KNOWLEDGE_BASE_ENTRIES+=("practices|Keep Plugins Certified|practice|Plugin safety|Regularly run plugin certification to ensure compatibility")
}

##############################################
# Search knowledge base.
knowledge_base_search() {
    local query="${1:-$KNOWLEDGE_BASE_SEARCH}"
    local results=()
    local entry
    for entry in "${KNOWLEDGE_BASE_ENTRIES[@]}"; do
        if [[ -z "$query" ]]; then
            results+=("$entry")
        else
            local lower_entry="${entry,,}"
            local lower_query="${query,,}"
            [[ "$lower_entry" == *"$lower_query"* ]] && results+=("$entry")
        fi
    done
    if [[ "${#results[@]}" -eq 0 ]]; then
        echo "No results found for: $query"
    else
        local i
        for i in "${results[@]}"; do
            local id="${i%%|*}"
            local rest="${i#*|}"
            local title="${rest%%|*}"
            rest="${rest#*|}"
            local cat="${rest%%|*}"
            rest="${rest#*|}"
            local summary="${rest%%|*}"
            echo "[${cat}] ${title}: ${summary}"
        done
    fi
}

##############################################
# Get knowledge entry by ID.
knowledge_base_get() {
    local target_id="$1"
    local entry
    for entry in "${KNOWLEDGE_BASE_ENTRIES[@]}"; do
        local id="${entry%%|*}"
        [[ "$id" == "$target_id" ]] && { echo "$entry"; return 0; }
    done
    return 1
}

##############################################
# Render knowledge base page.
_page_render_knowledge_base() {
    local top="$1" left="$2" width="$3" height="$4"
    knowledge_base_build

    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Knowledge Base'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — %d entries' "${#KNOWLEDGE_BASE_ENTRIES[@]}"
    renderer_reset

    local row=$(( top + 2 ))
    local col="$left"

    # Search bar
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get info)"
    renderer_bold
    printf ' [/] Search  [c] Clear  [1-7] Browse category'
    renderer_reset
    ((row++))

    if [[ -n "$KNOWLEDGE_BASE_SEARCH" ]]; then
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get warning)"
        printf ' Searching: %s' "$KNOWLEDGE_BASE_SEARCH"
        renderer_reset
        ((row++))
    fi
    ((row++))

    # Category browser
    local categories=(
        "1" "commands" "CLI & Shortcuts"
        "2" "api" "API Reference"
        "3" "modules" "Modules Guide"
        "4" "plugins" "Plugin SDK"
        "5" "troubleshooting" "Troubleshooting"
        "6" "releases" "Release Notes"
        "7" "architecture" "Architecture"
    )

    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    printf 'Categories:'
    renderer_reset
    ((row++))
    local ci=0
    while (( ci < ${#categories[@]} )); do
        renderer_cursor_goto "$row" "$col"
        local num="${categories[$ci]}"
        local cid="${categories[$((ci+1))]}"
        local clabel="${categories[$((ci+2))]}"
        renderer_fg_256 "$(theme_get info)"
        renderer_bold
        printf ' [%s] %s' "$num" "$clabel"
        renderer_reset
        ((row++))
        ((ci += 3))
    done
    ((row++))

    # Entries display
    local query
    if [[ -n "$KNOWLEDGE_BASE_SEARCH" ]]; then
        query="$KNOWLEDGE_BASE_SEARCH"
    else
        query=""
    fi
    local results
    results="$(knowledge_base_search "$query")"

    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    printf 'Results:'
    renderer_reset
    ((row++))

    local max_rows=$(( height - (row - top) - 1 ))
    local line_count=0
    while IFS= read -r line; do
        [[ "$line_count" -ge "$max_rows" ]] && break
        renderer_cursor_goto "$row" "$col"
        # Color by category
        case "$line" in
            \[commands\]*) renderer_fg_256 "$(theme_get success)" ;;
            \[api\]*)      renderer_fg_256 "$(theme_get info)" ;;
            \[module\]*)   renderer_fg_256 "$(theme_get accent)" ;;
            \[sdk\]*)      renderer_fg_256 "$(theme_get warning)" ;;
            \[troubleshoot\]*) renderer_fg_256 "$(theme_get error)" ;;
            *)             renderer_fg_256 "$(theme_get fg)" ;;
        esac
        printf '  %s' "$line"
        renderer_reset
        ((row++))
        ((line_count++))
    done <<< "$results"
}

_page_key_knowledge_base() {
    local key="$1"
    case "$key" in
        "/")
            local search
            search="$(menu_input "Knowledge Base" "Search:")" || return 0
            KNOWLEDGE_BASE_SEARCH="$search"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "c"|"C")
            KNOWLEDGE_BASE_SEARCH=""
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        [1-7])
            local cats=("commands" "api" "modules" "plugins" "troubleshooting" "releases" "architecture")
            local labels=("CLI & Shortcuts" "API Reference" "Modules Guide" "Plugin SDK" "Troubleshooting" "Release Notes" "Architecture")
            local idx=$((key - 1))
            local cat="${cats[$idx]}"
            local results
            results="$(knowledge_base_search "$cat")"
            menu_textbox "${labels[$idx]}" "$results"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
    esac
}
