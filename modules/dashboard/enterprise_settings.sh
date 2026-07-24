#!/data/data/com.termux/files/usr/bin/bash
#
# enterprise_settings.sh — Enterprise Configuration
#
# Central settings hub for:
#   - ADB / backend configuration
#   - Theme and display options
#   - Security and audit policies
#   - Session and automation defaults
#   - Network and proxy settings
#   - Environment configuration
#
# Part of the Android Toolkit Dashboard.

ENTERPRISE_CONFIG_FILE="${ANDROID_TOOLKIT_ROOT_DIR}/enterprise.conf"
ENTERPRISE_CONFIG=()

##############################################
# Load enterprise configuration.
enterprise_load_config() {
    ENTERPRISE_CONFIG=()
    if [[ -f "$ENTERPRISE_CONFIG_FILE" ]]; then
        while IFS='=' read -r key val; do
            key="${key// /}"
            [[ -z "$key" || "$key" == "#"* ]] && continue
            ENTERPRISE_CONFIG["$key"]="$val"
        done < "$ENTERPRISE_CONFIG_FILE"
    fi
    # Set defaults for unset keys
    [[ -z "${ENTERPRISE_CONFIG[adb_port]}" ]]     && ENTERPRISE_CONFIG["adb_port"]="5555"
    [[ -z "${ENTERPRISE_CONFIG[theme_name]}" ]]   && ENTERPRISE_CONFIG["theme_name"]="default"
    [[ -z "${ENTERPRISE_CONFIG[audit_enabled]}" ]] && ENTERPRISE_CONFIG["audit_enabled"]="true"
    [[ -z "${ENTERPRISE_CONFIG[auto_refresh]}" ]] && ENTERPRISE_CONFIG["auto_refresh"]="3"
    [[ -z "${ENTERPRISE_CONFIG[session_autosave]}" ]] && ENTERPRISE_CONFIG["session_autosave"]="false"
    [[ -z "${ENTERPRISE_CONFIG[backend_mode]}" ]] && ENTERPRISE_CONFIG["backend_mode"]="auto"
    [[ -z "${ENTERPRISE_CONFIG[log_level]}" ]]    && ENTERPRISE_CONFIG["log_level"]="info"
}

##############################################
# Save enterprise configuration.
enterprise_save_config() {
    {
        echo "# Android Toolkit Enterprise Configuration"
        echo "# Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        # Network
        echo "# ADB Port (default: 5555)"
        echo "adb_port=${ENTERPRISE_CONFIG[adb_port]:-5555}"
        echo ""
        # Display
        echo "# Theme name (default: default)"
        echo "theme_name=${ENTERPRISE_CONFIG[theme_name]:-default}"
        echo ""
        # Audit
        echo "# Audit trail enabled (true/false)"
        echo "audit_enabled=${ENTERPRISE_CONFIG[audit_enabled]:-true}"
        echo ""
        # Performance
        echo "# Auto-refresh interval in seconds (0=disable)"
        echo "auto_refresh=${ENTERPRISE_CONFIG[auto_refresh]:-3}"
        echo ""
        # Session
        echo "# Auto-save sessions (true/false)"
        echo "session_autosave=${ENTERPRISE_CONFIG[session_autosave]:-false}"
        echo ""
        # Backend
        echo "# Backend mode: auto, adb, shizuku"
        echo "backend_mode=${ENTERPRISE_CONFIG[backend_mode]:-auto}"
        echo ""
        # Logging
        echo "# Log level: debug, info, warn, error"
        echo "log_level=${ENTERPRISE_CONFIG[log_level]:-info}"
    } > "$ENTERPRISE_CONFIG_FILE"
    notify_push "Configuration saved" "success"
    audit_record "Settings" "save" "$ENTERPRISE_CONFIG_FILE" "success"
}

##############################################
# Get a config value.
enterprise_get() {
    local key="$1"
    local default="${2:-}"
    echo "${ENTERPRISE_CONFIG[$key]:-$default}"
}

##############################################
# Set a config value.
enterprise_set() {
    local key="$1" value="$2"
    ENTERPRISE_CONFIG["$key"]="$value"
}

##############################################
# Render enterprise settings.
_page_render_enterprise_settings() {
    local top="$1" left="$2" width="$3" height="$4"

    enterprise_load_config

    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Enterprise Settings'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Dashboard configuration'
    renderer_reset

    local row=$(( top + 2 ))
    local col="$left"

    # Settings card
    local settings=(
        "1" "ADB Port"             "adb_port"
        "2" "Theme"               "theme_name"
        "3" "Auto-refresh (sec)"  "auto_refresh"
        "4" "Session Auto-save"   "session_autosave"
        "5" "Backend Mode"        "backend_mode"
        "6" "Audit Trail"         "audit_enabled"
        "7" "Log Level"           "log_level"
    )

    local i=0
    while (( i < ${#settings[@]} )); do
        local num="${settings[$i]}"
        local label="${settings[$((i+1))]}"
        local skey="${settings[$((i+2))]}"
        local val="${ENTERPRISE_CONFIG[$skey]}"

        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get info)"
        renderer_bold
        printf ' [%s]' "$num"
        renderer_reset
        renderer_fg_256 "$(theme_get fg)"
        printf ' %-22s ' "$label"
        renderer_reset

        # Value with color coding
        if [[ "$val" == "true" ]] || [[ "$val" == "enabled" ]] || [[ "$val" == "auto" ]]; then
            renderer_fg_256 "$(theme_get success)"
        elif [[ "$val" == "false" ]] || [[ "$val" == "disabled" ]]; then
            renderer_fg_256 "$(theme_get error)"
        else
            renderer_fg_256 "$(theme_get info)"
        fi
        printf '%s' "$val"
        renderer_reset

        ((row++))
        ((i += 3))
    done

    ((row++))
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get info)"
    renderer_bold
    printf ' [s] '
    renderer_reset
    renderer_fg_256 "$(theme_get fg)"
    printf 'Save Configuration'
    renderer_reset

    renderer_cursor_goto "$row" $(( col + 20 ))
    renderer_fg_256 "$(theme_get info)"
    renderer_bold
    printf ' [r] '
    renderer_reset
    renderer_fg_256 "$(theme_get fg)"
    printf 'Reload from file'
    renderer_reset

    ((row++))
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get info)"
    renderer_bold
    printf ' [q] '
    renderer_reset
    renderer_fg_256 "$(theme_get fg)"
    printf 'Apply & Back'
    renderer_reset

    local config_file_display
    config_file_display="${ENTERPRISE_CONFIG_FILE/#$HOME/\~}"
    ((row++))
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    printf 'Config file: %s' "$config_file_display"
    renderer_reset
}

_page_key_enterprise_settings() {
    local key="$1"
    local val=""
    case "$key" in
        "1")
            val="$(menu_input "ADB Port" "ADB port number:" "${ENTERPRISE_CONFIG[adb_port]}")" || return 0
            [[ -n "$val" && "$val" =~ ^[0-9]+$ ]] && enterprise_set "adb_port" "$val"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "2")
            local themes=("default" "Default" "dark" "Dark" "light" "Light" "high-contrast" "High Contrast")
            local choice
            choice="$(menu_select "Theme" "${themes[@]}")" || return 0
            [[ -n "$choice" ]] && enterprise_set "theme_name" "$choice"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "3")
            val="$(menu_input "Auto-refresh" "Refresh interval in seconds (0=disable):" "${ENTERPRISE_CONFIG[auto_refresh]}")" || return 0
            [[ -n "$val" && "$val" =~ ^[0-9]+$ ]] && enterprise_set "auto_refresh" "$val"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "4")
            if menu_yesno "Session Auto-save" "Enable automatic session saving?"; then
                enterprise_set "session_autosave" "true"
            else
                enterprise_set "session_autosave" "false"
            fi
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "5")
            local modes=("auto" "Auto-detect" "adb" "ADB only" "shizuku" "Shizuku only")
            local choice
            choice="$(menu_select "Backend Mode" "${modes[@]}")" || return 0
            [[ -n "$choice" ]] && enterprise_set "backend_mode" "$choice"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "6")
            if menu_yesno "Audit Trail" "Enable audit trail logging?"; then
                enterprise_set "audit_enabled" "true"
            else
                enterprise_set "audit_enabled" "false"
            fi
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "7")
            local levels=("debug" "Debug" "info" "Info" "warn" "Warning" "error" "Error")
            local choice
            choice="$(menu_select "Log Level" "${levels[@]}")" || return 0
            [[ -n "$choice" ]] && enterprise_set "log_level" "$choice"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "s"|"S")
            enterprise_save_config
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "r"|"R")
            enterprise_load_config
            notify_push "Configuration reloaded" "info"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "q"|"Q")
            enterprise_save_config
            notify_push "Configuration applied" "success"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
    esac
}
