#!/data/data/com.termux/files/usr/bin/bash
#
# ai_assistant.sh — AI Assistant Panel
#
# Integrated assistant that consumes toolkit public APIs
# to explain metrics, recommend optimizations, diagnose
# errors, and generate reports.
#
# Part of the Android Toolkit Dashboard.

AI_QUERY_HISTORY=()
AI_QUERY_HISTORY_MAX=20
AI_CACHED_RESPONSES=""

##############################################
# Run a diagnostic query through the AI assistant.
# This uses the toolkit's own analysis APIs rather
# than an external LLM — it's a rules-based expert
# system that consumes the toolkit's public functions.
ai_assistant_query() {
    local query="$1"
    local response=""

    # Add to history
    AI_QUERY_HISTORY+=("$query")
    [[ "${#AI_QUERY_HISTORY[@]}" -gt "$AI_QUERY_HISTORY_MAX" ]] && AI_QUERY_HISTORY=("${AI_QUERY_HISTORY[@]:1}")

    case "$(echo "$query" | tr '[:upper:]' '[:lower:]' | xargs)" in
        *health*|*status*|*dashboard*)
            local bat="$(status_get battery_pct 2>/dev/null || echo "?")"
            local mem="$(status_get mem_pct 2>/dev/null || echo "?")"
            local storage="$(status_get storage_pct 2>/dev/null || echo "?")"
            local temp="$(status_get thermal 2>/dev/null || echo "?")"
            response="Device Health Summary:"
            response+=$'\n'"  • Battery: ${bat}%"
            [[ "$bat" != "?" && "$bat" -lt 20 ]] && response+=$' (LOW — consider charging)'
            response+=$'\n'"  • Memory: ${mem}% used"
            [[ "$mem" != "?" && "$mem" -gt 85 ]] && response+=$' (HIGH — close background apps)'
            response+=$'\n'"  • Storage: ${storage}% used"
            [[ "$storage" != "?" && "$storage" -gt 90 ]] && response+=$' (CRITICAL — free up space)'
            response+=$'\n'"  • Temperature: ${temp}°C"
            [[ "$temp" != "?" && "$(echo "$temp > 45" | bc -l 2>/dev/null)" -eq 1 ]] && response+=$' (HIGH — avoid heavy use)'
            ;;
        *optimiz*|*performance*|*speed*)
            response="Optimization Recommendations:"
            response+=$'\n'"  1. Apply 'balanced' profile: toolkit.sh --apply balanced"
            response+=$'\n'"  2. Trim caches: toolkit.sh --trim-cache"
            response+=$'\n'"  3. Force ART compilation: toolkit.sh --compile"
            response+=$'\n'"  4. Disable bloatware: toolkit.sh --list-bloatware safe"
            response+=$'\n'"  5. Refresh network: toolkit.sh --refresh-network"
            response+=$'\n'"  For Samsung devices: toolkit.sh --samsung-light"
            ;;
        *battery*|*power*)
            local bat="$(status_get battery_pct 2>/dev/null || echo "?")"
            local health="$(status_get battery_health 2>/dev/null || echo "?")"
            response="Battery Analysis:"
            response+=$'\n'"  • Level: ${bat}%"
            response+=$'\n'"  • Health: ${health}"
            response+=$'\n'"  • Temperature: $(status_get battery_temp 2>/dev/null || echo "?")°C"
            response+=$'\n'"  Recommendations:"
            [[ "$bat" != "?" && "$bat" -lt 20 ]] && response+=$'\n'"    - Charge device soon"
            response+=$'\n'"    - Enable power saving mode"
            response+=$'\n'"    - Reduce screen brightness"
            response+=$'\n'"    - Disable background sync"
            response+=$'\n'"  Apply: toolkit.sh --apply powersave"
            ;;
        *security*|*audit*|*vulnerability*)
            response="Security Assessment:"
            response+=$'\n'"  • SELinux: $(status_get selinux 2>/dev/null || echo "?")"
            response+=$'\n'"  • Security Patch: $(status_get security_patch 2>/dev/null || echo "?")"
            response+=$'\n'"  • Root Status: $(status_get root 2>/dev/null || echo "?")"
            response+=$'\n'"  Recommendations:"
            response+=$'\n'"    1. Run full audit: toolkit.sh --audit"
            response+=$'\n'"    2. Security hardening: toolkit.sh --security-harden"
            response+=$'\n'"    3. Review permissions: toolkit.sh --settings-verify"
            response+=$'\n'"    4. Check for updates regularly"
            ;;
        *storage*|*disk*|*space*)
            local used="$(status_get storage_used 2>/dev/null || echo "?")"
            local total="$(status_get storage_total 2>/dev/null || echo "?")"
            local pct="$(status_get storage_pct 2>/dev/null || echo "?")"
            response="Storage Analysis:"
            response+=$'\n'"  • Used: ${used} / ${total} (${pct}%)"
            response+=$'\n'"  Recommendations:"
            response+=$'\n'"    1. Clear app caches: toolkit.sh --trim-cache"
            response+=$'\n'"    2. Remove unused packages"
            response+=$'\n'"    3. Clean download folders"
            [[ "$pct" != "?" && "$pct" -gt 90 ]] && response+=$'\n'"    ⚠ Storage critically low — free up space immediately"
            ;;
        *network*|*wifi*|*connect*)
            response="Network Diagnostics:"
            response+=$'\n'"  • Status: $(status_get network 2>/dev/null || echo "?")"
            response+=$'\n'"  Commands:"
            response+=$'\n'"    - Refresh network: toolkit.sh --refresh-network"
            response+=$'\n'"    - Check DNS: nslookup google.com"
            response+=$'\n'"    - Ping test: ping -c 4 8.8.8.8"
            ;;
        *memory*|*ram*)
            local pct="$(status_get mem_pct 2>/dev/null || echo "?")"
            local avail="$(status_get mem_avail_mb 2>/dev/null || echo "?")"
            response="Memory Analysis:"
            response+=$'\n'"  • Usage: ${pct}%"
            response+=$'\n'"  • Available: ${avail}MB"
            [[ "$pct" != "?" && "$pct" -gt 85 ]] && response+=$'\n'"  ⚠ High memory pressure — close apps"
            response+=$'\n'"  Tips:"
            response+=$'\n'"    - Reduce animation scale in Developer Options"
            response+=$'\n'"    - Disable live wallpapers"
            response+=$'\n'"    - Limit background processes"
            ;;
        *benchmark*|*score*)
            response="Benchmark Information:"
            response+=$'\n'"  Run a benchmark: toolkit.sh --benchmark"
            response+=$'\n'"  Enhanced (multi-run): toolkit.sh --enhanced-benchmark 5"
            response+=$'\n'"  View history: toolkit.sh --benchmark-history"
            response+=$'\n'"  Compare devices from the Device Comparison page"
            ;;
        *help*|*commands*|*cli*)
            response="Available CLI Commands:"
            response+=$'\n'"  • --status        Quick device overview"
            response+=$'\n'"  • --report        Full device report"
            response+=$'\n'"  • --doctor        Run system diagnostics"
            response+=$'\n'"  • --audit         Security audit"
            response+=$'\n'"  • --benchmark     Device benchmark"
            response+=$'\n'"  • --apply <prof>  Apply profile"
            response+=$'\n'"  • --backup        Create backup"
            response+=$'\n'"  • --compile       Force ART compilation"
            response+=$'\n'"  • --trim-cache    Clear caches"
            response+=$'\n'"  • --help          Full help"
            response+=$'\n'"  See Dashboard > Help for keyboard shortcuts"
            ;;
        *about*|*version*|*toolkit*)
            response="Android Toolkit v$(status_get version 2>/dev/null || echo "?")"
            response+=$'\n'"  A modular, non-root Android optimization"
            response+=$'\n'"  and diagnostics toolkit for modern devices."
            response+=$'\n'"  Supports Android 13–16 and Samsung One UI 5–8."
            response+=$'\n'"  Backend: $(status_get backend 2>/dev/null || echo "?")"
            response+=$'\n'"  Model: $(status_get model 2>/dev/null || echo "?")"
            response+=$'\n'"  Repository: github.com/00AstroGit00/android-toolkit"
            ;;
        *)
            response="I can help you with:"
            response+=$'\n'"  • Device health and status"
            response+=$'\n'"  • Performance optimization"
            response+=$'\n'"  • Battery analysis"
            response+=$'\n'"  • Security assessment"
            response+=$'\n'"  • Storage management"
            response+=$'\n'"  • Network diagnostics"
            response+=$'\n'"  • Memory optimization"
            response+=$'\n'"  • Benchmark information"
            response+=$'\n'"  • CLI command reference"
            response+=$'\n'"  • Toolkit version info"
            response+=$'\n'"  Try typing: health, optimize, battery, security,"
            response+=$'\n'"  storage, network, memory, benchmark, help, or about"
            ;;
    esac

    AI_CACHED_RESPONSES="$response"
    echo "$response"
}

##############################################
# Render AI assistant panel.
_page_render_ai_assistant() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'AI Assistant'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Expert system for device diagnostics'
    renderer_reset

    local row=$(( top + 2 ))

    # Input prompt
    renderer_cursor_goto "$row" "$left"
    renderer_fg_256 "$(theme_get success)"
    printf '✦'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' Ask a question or press a quick-action key:'
    renderer_reset
    ((row++))

    # Quick action buttons
    local actions=(
        "h" "Health" "o" "Optimize" "b" "Battery"
        "s" "Security" "t" "Storage" "m" "Memory"
    )
    renderer_cursor_goto "$row" "$left"
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

    # Response area
    local response
    if [[ -n "$AI_CACHED_RESPONSES" ]]; then
        response="$AI_CACHED_RESPONSES"
    else
        response="Ask me about device health, optimization, battery, security, storage, network, memory, benchmarks, CLI commands, or about the toolkit."
    fi

    # Draw response in a bordered box
    local box_h=$(( height - (row - top) - 2 ))
    [[ "$box_h" -lt 5 ]] && box_h=5
    renderer_draw_box "$row" "$left" "$box_h" "$width" "Response"
    ((row++))
    ((left += 2))

    local line_count=0
    while IFS= read -r line; do
        renderer_cursor_goto "$row" "$left"
        if [[ "$line" =~ ^[[:space:]]*[0-9]\. ]]; then
            renderer_fg_256 "$(theme_get fg)"
        elif [[ "$line" =~ ^[[:space:]]*• ]]; then
            renderer_fg_256 "$(theme_get info)"
        elif [[ "$line" =~ ^[[:space:]]*⚙ ]]; then
            renderer_fg_256 "$(theme_get warning)"
        elif [[ "$line" =~ ^[[:space:]]*[A-Z][a-z] ]]; then
            renderer_bold
            renderer_fg_256 "$(theme_get accent)"
        else
            renderer_fg_256 "$(theme_get muted)"
        fi
        printf '%-*s' "$((width - 4))" "${line:0:$((width-4))}"
        renderer_reset
        ((row++))
        ((line_count++))
        [[ "$line_count" -ge "$box_h" ]] && break
    done <<< "$response"
}

_page_key_ai_assistant() {
    local key="$1"
    case "$key" in
        "h"|"H") ai_assistant_query "health" ;;
        "o"|"O") ai_assistant_query "optimize" ;;
        "b"|"B") ai_assistant_query "battery" ;;
        "s"|"S") ai_assistant_query "security" ;;
        "t"|"T") ai_assistant_query "storage" ;;
        "m"|"M") ai_assistant_query "memory" ;;
        "?"|"/")
            local query
            query="$(menu_input "AI Query" "Ask about device:")" || return 0
            [[ -z "$query" ]] && return 0
            ai_assistant_query "$query"
            ;;
    esac
    DASHBOARD_REDRAW_NEEDED=true
}
