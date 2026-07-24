#!/data/data/com.termux/files/usr/bin/bash
#
# profiles.sh — Enterprise Dashboard Profiles
#
# Role-based dashboard layouts and tool access levels.
# Supports: Administrator, Technician, Developer,
# Power User, Security Analyst, Plugin Developer.
#
# Each profile exposes relevant pages and tools.
#
# Part of the Android Toolkit Dashboard.

declare -gA PROFILE_PAGES=()
declare -gA PROFILE_DESCRIPTION=()
CURRENT_PROFILE="administrator"

##############################################
# Define all profiles and their page access.
profiles_init() {
    # Administrator — full access to everything
    PROFILE_PAGES["administrator"]="*"
    PROFILE_DESCRIPTION["administrator"]="Full system access — all pages and tools available"

    # Technician — device operations & diagnostics
    PROFILE_PAGES["technician"]="dashboard:devices:diagnostics:perf_monitor:battery:storage:network:recovery:reports:timeline"
    PROFILE_DESCRIPTION["technician"]="Device repair & diagnostics — hardware/software operations"

    # Developer — modules, plugins, system
    PROFILE_PAGES["developer"]="dashboard:plugin_center:plugin_sandbox:perf_profiler:system_map:knowledge_base:event_bus:terminal:automation:workflow_recorder:settings"
    PROFILE_DESCRIPTION["developer"]="Module & plugin development — SDK, profiler, automation"

    # Power User — optimization & monitoring
    PROFILE_PAGES["power_user"]="dashboard:performance:optimization:battery:display:storage:network:security_center:health_intel:predictive:recommendations:perf_monitor:policies:reports"
    PROFILE_DESCRIPTION["power_user"]="Device optimization & health monitoring — daily operations"

    # Security Analyst — security focus
    PROFILE_PAGES["security_analyst"]="dashboard:security_center:audit_trail:predictive:recommendations:policies:fleet:reports:timeline:health_intel:event_bus:knowledge_base"
    PROFILE_DESCRIPTION["security_analyst"]="Security assessment & compliance — audits, policies, fleet"

    # Plugin Developer — plugins & SDK
    PROFILE_PAGES["plugin_developer"]="dashboard:plugin_center:plugin_sandbox:perf_profiler:knowledge_base:system_map:event_bus:terminal:automation:settings"
    PROFILE_DESCRIPTION["plugin_developer"]="Plugin development & testing — sandbox, profiler, SDK docs"
}

##############################################
# Switch to a profile.
profiles_switch() {
    local profile="$1"
    if [[ -n "${PROFILE_PAGES[$profile]}" ]]; then
        CURRENT_PROFILE="$profile"
        notify_push "Switched to: ${profile} profile" "success"
        event_bus_emit "system" "profile_switched" "$profile" "info"
        return 0
    fi
    return 1
}

##############################################
# Check if a page is accessible in current profile.
profiles_can_access() {
    local page="$1"
    local pages="${PROFILE_PAGES[$CURRENT_PROFILE]:-}"
    [[ "$pages" == "*" ]] && return 0
    [[ ",$pages," == *",$page,"* ]] && return 0
    return 1
}

##############################################
# Get current profile description.
profiles_description() {
    echo "${PROFILE_DESCRIPTION[$CURRENT_PROFILE]:-}"
}

##############################################
# Render enterprise profiles page.
_page_render_profiles() {
    local top="$1" left="$2" width="$3" height="$4"
    profiles_init

    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Enterprise Dashboard Profiles'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Role-based layouts'
    renderer_reset

    local row=$(( top + 2 ))
    local col="$left"

    # Current profile
    renderer_cursor_goto "$row" "$col"
    renderer_bold
    renderer_fg_256 "$(theme_get success)"
    printf 'Active Profile: %s' "$CURRENT_PROFILE"
    renderer_reset
    ((row++))
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get muted)"
    printf '%s' "$(profiles_description)"
    renderer_reset
    ((row += 2))

    # Profile list
    renderer_cursor_goto "$row" "$col"
    renderer_bold
    renderer_fg_256 "$(theme_get info)"
    printf 'Available Profiles'
    renderer_reset
    ((row++))

    local profiles=(
        "1" "administrator"   "Administrator"
        "2" "technician"      "Technician"
        "3" "developer"       "Developer"
        "4" "power_user"      "Power User"
        "5" "security_analyst" "Security Analyst"
        "6" "plugin_developer" "Plugin Developer"
    )

    local i=0
    while (( i < ${#profiles[@]} )); do
        [[ "$row" -ge $(( top + height - 1 )) ]] && break
        local num="${profiles[$i]}"
        local pid="${profiles[$((i+1))]}"
        local plabel="${profiles[$((i+2))]}"

        renderer_cursor_goto "$row" "$col"
        if [[ "$pid" == "$CURRENT_PROFILE" ]]; then
            renderer_fg_256 "$(theme_get success)"
            renderer_bold
            printf ' [%s] %s ← active' "$num" "$plabel"
        else
            renderer_fg_256 "$(theme_get info)"
            renderer_bold
            printf ' [%s] %s' "$num" "$plabel"
        fi
        renderer_reset
        ((row++))
        ((i += 3))
    done

    # Page access for current profile
    ((row += 2))
    renderer_cursor_goto "$row" "$col"
    renderer_bold
    renderer_fg_256 "$(theme_get info)"
    printf 'Accessible Pages'
    renderer_reset
    ((row++))

    local pages="${PROFILE_PAGES[$CURRENT_PROFILE]:-}"
    if [[ "$pages" == "*" ]]; then
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get success)"
        printf '  All pages (full system access)'
        renderer_reset
    else
        local page
        IFS=',' read -ra page_list <<< "$pages"
        for page in "${page_list[@]}"; do
            [[ "$row" -ge $(( top + height - 1 )) ]] && break
            renderer_cursor_goto "$row" "$col"
            renderer_fg_256 "$(theme_get fg)"
            printf '  • %s' "$page"
            renderer_reset
            ((row++))
        done
    fi
}

_page_key_profiles() {
    local key="$1"
    case "$key" in
        [1-6])
            local pids=("administrator" "technician" "developer" "power_user" "security_analyst" "plugin_developer")
            local idx=$((key - 1))
            profiles_switch "${pids[$idx]}"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
    esac
}
