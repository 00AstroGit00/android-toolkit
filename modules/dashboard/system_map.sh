#!/data/data/com.termux/files/usr/bin/bash
#
# system_map.sh — Interactive System Map
#
# Generates a live dependency map visualizing:
#   Dashboard → Modules → Plugins → Reports → API Layer
#   Device Connections → Automation Workflows
#
# Shows execution paths and dependencies.
#
# Part of the Android Toolkit Dashboard.

SYSTEM_MAP_NODES=()
SYSTEM_MAP_EDGES=()

##############################################
# Build the system dependency map.
system_map_build() {
    SYSTEM_MAP_NODES=()
    SYSTEM_MAP_EDGES=()

    # Core nodes
    SYSTEM_MAP_NODES+=("dashboard|Dashboard|core|◉")
    SYSTEM_MAP_NODES+=("modules|Modules|core|◆")
    SYSTEM_MAP_NODES+=("plugins|Plugins|plugin|🔌")
    SYSTEM_MAP_NODES+=("reports|Reports|report|📊")
    SYSTEM_MAP_NODES+=("api|API Layer|core|🔗")
    SYSTEM_MAP_NODES+=("devices|Device Connections|device|🖥")
    SYSTEM_MAP_NODES+=("automation|Automation|workflow|⚙")
    SYSTEM_MAP_NODES+=("events|Event Bus|core|📨")
    SYSTEM_MAP_NODES+=("twin|Digital Twin|data|📋")
    SYSTEM_MAP_NODES+=("timeline|Timeline|data|📅")
    SYSTEM_MAP_NODES+=("health|Health Intel|analytics|📈")
    SYSTEM_MAP_NODES+=("predictive|Predictive|analytics|🔮")
    SYSTEM_MAP_NODES+=("recommend|Recommendations|analytics|💡")
    SYSTEM_MAP_NODES+=("fleet|Fleet|enterprise|🏢")
    SYSTEM_MAP_NODES+=("policies|Policies|enterprise|📜")
    SYSTEM_MAP_NODES+=("profiler|Profiler|tool|⏱")
    SYSTEM_MAP_NODES+=("sandbox|Plugin Sandbox|plugin|🔒")
    SYSTEM_MAP_NODES+=("recovery|Recovery|tool|🔄")
    SYSTEM_MAP_NODES+=("knowledge|Knowledge Base|data|📖")
    SYSTEM_MAP_NODES+=("profiles|Profiles|enterprise|👤")

    # Edges (dependencies)
    SYSTEM_MAP_EDGES+=("dashboard|modules|depends_on")
    SYSTEM_MAP_EDGES+=("dashboard|plugins|depends_on")
    SYSTEM_MAP_EDGES+=("dashboard|reports|depends_on")
    SYSTEM_MAP_EDGES+=("dashboard|api|depends_on")
    SYSTEM_MAP_EDGES+=("dashboard|devices|depends_on")
    SYSTEM_MAP_EDGES+=("dashboard|automation|depends_on")
    SYSTEM_MAP_EDGES+=("modules|events|depends_on")
    SYSTEM_MAP_EDGES+=("modules|twin|depends_on")
    SYSTEM_MAP_EDGES+=("modules|timeline|depends_on")
    SYSTEM_MAP_EDGES+=("twin|health|feeds")
    SYSTEM_MAP_EDGES+=("twin|predictive|feeds")
    SYSTEM_MAP_EDGES+=("health|recommend|feeds")
    SYSTEM_MAP_EDGES+=("predictive|recommend|feeds")
    SYSTEM_MAP_EDGES+=("timeline|reports|feeds")
    SYSTEM_MAP_EDGES+=("fleet|devices|manages")
    SYSTEM_MAP_EDGES+=("policies|devices|governs")
    SYSTEM_MAP_EDGES+=("sandbox|plugins|monitors")
    SYSTEM_MAP_EDGES+=("profiler|modules|traces")
    SYSTEM_MAP_EDGES+=("recovery|twin|restores")
    SYSTEM_MAP_EDGES+=("knowledge|modules|documents")
    SYSTEM_MAP_EDGES+=("profiles|dashboard|configures")
    SYSTEM_MAP_EDGES+=("events|dashboard|notifies")
    SYSTEM_MAP_EDGES+=("events|timeline|records")
    SYSTEM_MAP_EDGES+=("events|twin|updates")
}

##############################################
# Get execution path from one node to another.
system_map_path() {
    local from="$1" to="$2"
    echo "Execution path: $from → $to"
    local edge
    for edge in "${SYSTEM_MAP_EDGES[@]}"; do
        local src="${edge%%|*}"
        local rest="${edge#*|}"
        local dst="${rest%|*}"
        local rel="${edge##*|}"
        [[ "$src" == "$from" && "$dst" == "$to" ]] && echo "  $src --[$rel]--> $dst"
    done
}

##############################################
# Render system map page.
_page_render_system_map() {
    local top="$1" left="$2" width="$3" height="$4"
    system_map_build

    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Interactive System Map'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Live dependency visualization'
    renderer_reset

    local row=$(( top + 2 ))
    local col="$left"

    # Legend
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get info)"
    printf ' ◉ Core'
    renderer_reset
    renderer_fg_256 "$(theme_get success)"
    printf '  ◆ Modules'
    renderer_reset
    renderer_fg_256 "$(theme_get warning)"
    printf '  🔌 Plugins'
    renderer_reset
    renderer_fg_256 "$(theme_get error)"
    printf '  📊 Reports'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf '  🔗 API'
    renderer_reset
    ((row += 2))

    # Display nodes grouped by type
    local types=("core" "data" "analytics" "enterprise" "plugin" "device" "workflow" "report" "tool")
    local type_labels=("Core System" "Data Layer" "Analytics" "Enterprise" "Plugin System" "Device Layer" "Workflow" "Reporting" "Tools")

    local ti=0
    for tgroup in "${types[@]}"; do
        [[ "$row" -ge $(( top + height - 2 )) ]] && break
        renderer_cursor_goto "$row" "$col"
        renderer_bold
        renderer_fg_256 "$(theme_get info)"
        printf '%s:' "${type_labels[$ti]}"
        renderer_reset
        ((row++))

        local node
        for node in "${SYSTEM_MAP_NODES[@]}"; do
            [[ "$row" -ge $(( top + height - 1 )) ]] && break
            local nid="${node%%|*}"
            local rest="${node#*|}"
            local nlabel="${rest%%|*}"
            rest="${rest#*|}"
            local ntype="${rest%%|*}"
            local nicon="${node##*|}"

            [[ "$ntype" != "$tgroup" ]] && continue

            renderer_cursor_goto "$row" "$col"
            renderer_fg_256 "$(theme_get fg)"
            printf '  %s %s' "$nicon" "$nlabel"
            renderer_reset

            # Show connections
            local edge
            for edge in "${SYSTEM_MAP_EDGES[@]}"; do
                local src="${edge%%|*}"
                local erest="${edge#*|}"
                local dst="${erest%|*}"
                [[ "$src" != "$nid" ]] && continue
                renderer_fg_256 "$(theme_get muted)"
                printf ' → %s' "$dst"
                renderer_reset
            done
            ((row++))
        done
        ((ti++))
    done

    ((row++))
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    printf 'Total: %d nodes, %d edges. Press [p] to find path.' "${#SYSTEM_MAP_NODES[@]}" "${#SYSTEM_MAP_EDGES[@]}"
    renderer_reset
}

_page_key_system_map() {
    local key="$1"
    case "$key" in
        "p"|"P")
            local from to
            from="$(menu_input "Path Finder" "From node:")" || return 0
            to="$(menu_input "Path Finder" "To node:")" || return 0
            local result
            result="$(system_map_path "$from" "$to")"
            menu_textbox "Execution Path" "$result"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
    esac
}
