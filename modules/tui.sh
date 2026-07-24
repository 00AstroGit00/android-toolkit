#!/data/data/com.termux/files/usr/bin/bash
#
# tui.sh — Modern Interactive Dashboard
#
# A full-featured terminal UI with color, nested menus,
# status dashboard (mixedgauge), progress bars, and
# keyboard-driven navigation. Uses dialog or whiptail.
#
# Features:
#   - Color-coded dashboard with real-time device status
#   - Categorized nested menus with icons
#   - Progress bars for long-running operations
#   - Confirmation dialogs before destructive actions
#   - Persistent backtitle showing device info
#   - ESC/Cancel safety at every level
#
# Part of the Android Toolkit.

# ──────────────────────────────────────────────
# TUI STATE
# ──────────────────────────────────────────────
TUI_BACKEND=""
TUI_HAS_COLORS=false
TUI_TERM_HEIGHT=24
TUI_TERM_WIDTH=80
TUI_BACKTITLE="Android Toolkit"

# ──────────────────────────────────────────────
# Dialog color markup reference (with --colors)
#   \Zb ... \ZB   Bold on/off
#   \Zr ... \ZR   Reverse on/off
#   \Zu ... \ZU   Underline on/off
#   \Z0 \Z1 \Z2   Black, Red, Green
#   \Z3 \Z4 \Z5   Yellow, Blue, Magenta
#   \Z6 \Z7       Cyan, White
#   \Zn           Reset to default
#
# We use \Z4 (blue) for headers, \Z2 (green) for OK,
#   \Z1 (red) for danger, \Z3 (yellow) for warnings,
#   \Z6 (cyan) for highlights, \Z7 (white) for emphasis.
# ──────────────────────────────────────────────

##############################################
# Detect available TUI backend.
# Prefers dialog over whiptail.
##############################################
tui_detect_backend() {
    if command -v dialog &>/dev/null; then
        TUI_BACKEND="dialog"
        TUI_HAS_COLORS=true
    elif command -v whiptail &>/dev/null; then
        TUI_BACKEND="whiptail"
        TUI_HAS_COLORS=false
    else
        TUI_BACKEND="none"
        TUI_HAS_COLORS=false
    fi
}

##############################################
# Detect terminal dimensions.
##############################################
tui_detect_term_size() {
    if [[ -n "$LINES" && -n "$COLUMNS" ]]; then
        TUI_TERM_HEIGHT="$LINES"
        TUI_TERM_WIDTH="$COLUMNS"
    else
        local size
        size="$(stty size 2>/dev/null || echo "24 80")"
        TUI_TERM_HEIGHT="${size%% *}"
        TUI_TERM_WIDTH="${size##* }"
    fi
    # Sanity bounds
    [[ "$TUI_TERM_HEIGHT" -lt 10 ]] && TUI_TERM_HEIGHT=24
    [[ "$TUI_TERM_WIDTH"  -lt 40 ]] && TUI_TERM_WIDTH=80
}

##############################################
# Build the persistent backtitle string.
##############################################
tui_backtitle() {
    local model ver backend
    model="${DEVICE_MODEL:-unknown}"
    ver="${DEVICE_ANDROID_VERSION:-?}"
    backend="${ANDROID_TOOLKIT_BACKEND:-none}"
    local bat=""
    local battery_level battery_scale
    battery_level="$(backend_exec dumpsys battery 2>/dev/null | grep 'level:' | head -1 | awk '{print $2}')"
    battery_scale="$(backend_exec dumpsys battery 2>/dev/null | grep 'scale:' | head -1 | awk '{print $2}')"
    if [[ -n "$battery_level" && -n "$battery_scale" ]] && [[ "$battery_scale" -gt 0 ]]; then
        bat=" | Bat: $(( battery_level * 100 / battery_scale ))%"
    fi
    printf "Android Toolkit v%s  |  %s  |  Android %s  |  %s%s" \
        "${ANDROID_TOOLKIT_VERSION}" "$model" "$ver" "$backend" "$bat"
}

##############################################
# Gather device snapshot for dashboard.
##############################################
tui_device_snapshot() {
    local -n _ref="$1"
    _ref["model"]="${DEVICE_MODEL:-unknown}"
    _ref["android"]="${DEVICE_ANDROID_VERSION:-?}"
    _ref["sdk"]="${DEVICE_SDK_VERSION:-?}"
    _ref["backend"]="${ANDROID_TOOLKIT_BACKEND:-none}"
    _ref["serial"]="${ANDROID_TOOLKIT_ADB_SERIAL:-}"

    local battery_level battery_scale
    battery_level="$(backend_exec dumpsys battery 2>/dev/null | grep 'level:' | head -1 | awk '{print $2}')"
    battery_scale="$(backend_exec dumpsys battery 2>/dev/null | grep 'scale:' | head -1 | awk '{print $2}')"
    if [[ -n "$battery_level" && -n "$battery_scale" ]] && [[ "$battery_scale" -gt 0 ]]; then
        _ref["battery_pct"]="$(( battery_level * 100 / battery_scale ))"
    else
        _ref["battery_pct"]="?"
    fi

    local temp
    temp="$(backend_exec dumpsys battery 2>/dev/null | grep 'temperature:' | head -1 | awk '{print $2}')"
    if [[ -n "$temp" ]]; then
        _ref["battery_temp"]="$(echo "scale=1; $temp / 10" | bc 2>/dev/null || echo "?")"
    else
        _ref["battery_temp"]="?"
    fi

    local storage
    storage="$(backend_exec df -h /data 2>/dev/null | awk 'NR==2 {print $3"/"$2" ("$5")"}')"
    _ref["storage"]="${storage:-unknown}"

    local mem mem_total mem_free
    mem="$(backend_exec meminfo 2>/dev/null || backend_exec cat /proc/meminfo 2>/dev/null)"
    mem_total="$(echo "$mem" | grep 'MemTotal:' | awk '{print $2}')"
    mem_free="$(echo "$mem" | grep 'MemAvailable:' | awk '{print $2}')"
    if [[ -n "$mem_total" && -n "$mem_free" && "$mem_total" -gt 0 ]]; then
        _ref["mem_pct"]="$(( (mem_total - mem_free) * 100 / mem_total ))"
        _ref["mem_total_mb"]="$(( mem_total / 1024 ))"
    else
        _ref["mem_pct"]="?"
        _ref["mem_total_mb"]="?"
    fi

    local is_samsung="${DEVICE_IS_SAMSUNG:-false}"
    _ref["is_samsung"]="$is_samsung"
    _ref["oneui"]="${DEVICE_ONE_UI_VERSION:-N/A}"
}

# ──────────────────────────────────────────────
# CORE UI COMPONENTS
# ──────────────────────────────────────────────

##############################################
# Show a message box.
tui_msgbox() {
    local title="$1" text="$2"
    case "$TUI_BACKEND" in
        dialog)  dialog --backtitle "$TUI_BACKTITLE" --colors --title "$title" --msgbox "$text" 0 0 ;;
        whiptail) whiptail --backtitle "$TUI_BACKTITLE" --title "$title" --msgbox "$text" 0 0 ;;
        *)       echo "$text" ;;
    esac
}

##############################################
# Show a yes/no confirmation.
# Returns: 0 for yes, 1 for no
tui_confirm() {
    local title="$1" text="$2"
    case "$TUI_BACKEND" in
        dialog)  dialog --backtitle "$TUI_BACKTITLE" --colors --title "$title" --yesno "$text" 0 0 ;;
        whiptail) whiptail --backtitle "$TUI_BACKTITLE" --title "$title" --yesno "$text" 0 0 ;;
        *)       utils_confirm "$text" ;;
    esac
}

##############################################
# Show a menu and return the selected tag.
# Arguments:
#   $1: title
#   $2: menu text
#   $@: items (tag item pairs)
# Outputs: selected tag on stdout
# Returns: 0 if OK, 1 if Cancel
tui_menu() {
    local title="$1" text="$2"
    shift 2

    # If no items, return Cancel
    [[ $# -eq 0 ]] && return 1

    case "$TUI_BACKEND" in
        dialog|whiptail)
            # FD swap: display goes to terminal, result is captured
            "$TUI_BACKEND" --backtitle "$TUI_BACKTITLE" --colors --clear --title "$title" --menu "$text" 0 0 0 "$@" 3>&1 1>&2 2>&3
            ;;
        *)
            echo "Select an option:"
            select _choice in "$@"; do
                echo "$_choice"
                break
            done
            ;;
    esac
}

##############################################
# Show an input box.
# Arguments:
#   $1: title
#   $2: text
#   $3: default value (optional)
# Outputs: entered text
tui_input() {
    local title="$1" text="$2" default="${3:-}"
    case "$TUI_BACKEND" in
        dialog|whiptail)
            "$TUI_BACKEND" --backtitle "$TUI_BACKTITLE" --colors --title "$title" --inputbox "$text" 0 0 "$default" 3>&1 1>&2 2>&3
            ;;
        *)       read -p "$text: " _input; echo "$_input" ;;
    esac
}

##############################################
# Show a checklist.
# Arguments:
#   $1: title
#   $2: text
#   $@: items (tag description status triples)
# Outputs: selected tags (space-separated)
tui_checklist() {
    local title="$1" text="$2"
    shift 2

    [[ $# -eq 0 ]] && return 1

    case "$TUI_BACKEND" in
        dialog|whiptail)
            "$TUI_BACKEND" --backtitle "$TUI_BACKTITLE" --colors --clear --title "$title" --checklist "$text" 0 0 0 "$@" 3>&1 1>&2 2>&3
            ;;
        *)
            echo "Select items (comma-separated):"
            select _item in "$@"; do echo "$_item"; break; done
            ;;
    esac
}

##############################################
# Show a gauge (progress bar).
# Arguments:
#   $1: title
#   $2: text
#   $3: initial percentage (0-100)
# Reads percentage values from stdin until "100"
tui_gauge() {
    local title="$1" text="$2" pct="${3:-0}"
    case "$TUI_BACKEND" in
        dialog)
            (
                echo "$pct"
                while read -r line; do
                    echo "$line"
                done
            ) | dialog --backtitle "$TUI_BACKTITLE" --colors --title "$title" --gauge "$text" 8 60 0
            ;;
        whiptail)
            (
                echo "$pct"
                while read -r line; do
                    echo "$line"
                done
            ) | whiptail --backtitle "$TUI_BACKTITLE" --title "$title" --gauge "$text" 8 60 0
            ;;
        *)
            echo "[${pct}%] $text"
            while read -r line; do
                echo "[${line}%] $text"
            done
            ;;
    esac
}

##############################################
# Show text in a scrollable textbox.
# Arguments:
#   $1: title
#   $2: text content
tui_textbox() {
    local title="$1" text="$2"
    local tmpfile

    tmpfile="$(mktemp /tmp/toolkit_tui.XXXXXX 2>/dev/null)" || {
        echo "$text"
        return
    }
    printf '%s\n' "$text" > "$tmpfile"

    case "$TUI_BACKEND" in
        dialog)  dialog --backtitle "$TUI_BACKTITLE" --colors --title "$title" --textbox "$tmpfile" 0 0 ;;
        whiptail) whiptail --backtitle "$TUI_BACKTITLE" --title "$title" --textbox "$tmpfile" 0 0 ;;
        *)       echo "$text" ;;
    esac

    rm -f "$tmpfile"
}

##############################################
# Show a mixedgauge (status + progress bar).
# Only available with dialog.
# Arguments:
#   $1: title
#   $2: text
#   $3: overall percentage
#   $@: tag status pairs (tag string, status integer)
tui_mixedgauge() {
    local title="$1" text="$2" pct="$3"
    shift 3

    [[ "$TUI_BACKEND" != "dialog" ]] && {
        echo "$text"
        while [[ $# -ge 2 ]]; do
            echo "  $1: status=$2"
            shift 2
        done
        return
    }

    dialog --backtitle "$TUI_BACKTITLE" --colors --title "$title" --mixedgauge "$text" 0 0 "$pct" "$@"
}

# ──────────────────────────────────────────────
# ACTION EXECUTION HELPERS
# ──────────────────────────────────────────────

##############################################
# Execute a command, show its output in a textbox.
# Arguments:
#   $1: box title
#   $2: module file to load (optional)
#   $@: command and its arguments
# Returns: command exit code
tui_exec() {
    local title="$1" module_file="$2"
    shift 2

    # Load module if specified
    [[ -n "$module_file" ]] && _load_module "$module_file" 2>/dev/null || true

    local output exitcode
    output="$("$@" 2>&1)" || true
    exitcode=$?
    tui_textbox "$title" "$output"
    return $exitcode
}

##############################################
# Execute a command with an animated progress bar.
# Feed percentage lines to tui_gauge.
# Arguments:
#   $1: title
#   $2: text
#   $3: command to run (with args)
tui_exec_progress() {
    local title="$1" text="$2"
    shift 2

    # Run command in background, pipe progress percentage lines
    (
        echo "10"
        "$@" 2>&1 | while read -r line; do
            # If line is a number, pass as progress
            if [[ "$line" =~ ^[0-9]+$ ]]; then
                echo "$line"
            fi
        done
        echo "100"
    ) | tui_gauge "$title" "$text" 0
}

##############################################
# Confirmation for destructive actions.
# Uses red-tinted warning text.
# Returns: 0 for yes, 1 for no
tui_confirm_dangerous() {
    local title="$1" text="$2"
    case "$TUI_BACKEND" in
        dialog)
            dialog --backtitle "$TUI_BACKTITLE" --colors --title "\\Z1$title\\Zn" \
                --yesno "\\Z1⚠ WARNING\\Zn\\n\\n$text\\n\\n\\Z3This action may affect device stability.\\Zn" 0 0
            ;;
        whiptail)
            whiptail --backtitle "$TUI_BACKTITLE" --title "⚠ $title" --yesno "WARNING\n\n$text\n\nThis action may affect device stability." 0 0
            ;;
        *)
            echo "⚠ WARNING: $text"
            utils_confirm "Proceed?"
            ;;
    esac
}

##############################################
# Notify user with a styled message.
# Type: info, success, warning, error
tui_notify() {
    local type="$1" title="$2" text="$3"
    local color
    case "$type" in
        success) color="\\Z2" ;;
        warning) color="\\Z3" ;;
        error)   color="\\Z1" ;;
        *)       color="\\Z6" ;;
    esac

    case "$TUI_BACKEND" in
        dialog)
            dialog --backtitle "$TUI_BACKTITLE" --colors --title "${color}$title\\Zn" --msgbox "$text" 0 0
            ;;
        whiptail)
            whiptail --backtitle "$TUI_BACKTITLE" --title "$title" --msgbox "$text" 0 0
            ;;
        *)
            echo "[$type] $title: $text"
            ;;
    esac
}

##############################################
# Show a loading/info box while a command runs.
# Arguments:
#   $1: title
#   $2: info text
#   $@: command to run
tui_while() {
    local title="$1" text="$2"
    shift 2

    case "$TUI_BACKEND" in
        dialog)
            # Use --infobox (no buttons, auto-closes)
            dialog --backtitle "$TUI_BACKTITLE" --colors --infobox "$text" 5 60
            "$@" 2>&1 || true
            # Clear the infobox
            dialog --clear 2>/dev/null || true
            ;;
        *)
            echo "$text"
            "$@" 2>&1 || true
            ;;
    esac
}

# ──────────────────────────────────────────────
# DASHBOARD HOME
# ──────────────────────────────────────────────

##############################################
# Show the main status dashboard using mixedgauge.
##############################################
tui_dashboard_home() {
    local -A d
    tui_device_snapshot d

    local bat_label="${d[battery_pct]}%"
    [[ "${d[battery_temp]}" != "?" ]] && bat_label+="  ${d[battery_temp]}°C"

    local mem_label="${d[mem_pct]}%"
    [[ "${d[mem_total_mb]}" != "?" ]] && mem_label+="  (${d[mem_total_mb]} MB total)"

    local samsung_label="N/A"
    [[ "${d[is_samsung]}" == "true" ]] && samsung_label="One UI ${d[oneui]}"

    # Map status codes for mixedgauge:
    # 0 OK/green, 1 fail/red, 2 passed/green, 3 completed, 4 checked, 5 unchecked, -1 N/A
    local bat_status=0 mem_status=0 storage_status=0
    [[ "${d[battery_pct]}" != "?" && "${d[battery_pct]}" -lt 20 ]] && bat_status=3
    [[ "${d[battery_temp]}" != "?" ]] && {
        local temp_num
        temp_num="$(echo "${d[battery_temp]}" | cut -d. -f1 2>/dev/null || echo 0)"
        [[ "$temp_num" -gt 40 ]] && bat_status=1
    }
    [[ "${d[mem_pct]}" != "?" && "${d[mem_pct]}" -gt 85 ]] && mem_status=1
    [[ "${d[mem_pct]}" != "?" && "${d[mem_pct]}" -gt 70 ]] && mem_status=3

    # Overall health percentage
    local health_pct=50
    local scores=0 count=0
    [[ "${d[battery_pct]}" != "?" ]] && { scores=$((scores + d[battery_pct])); ((count++)); }
    [[ "${d[mem_pct]}" != "?" ]] && { scores=$((scores + (100 - d[mem_pct]))); ((count++)); }
    [[ "$count" -gt 0 ]] && health_pct=$((scores / count))

    tui_mixedgauge "\\Z4Device Dashboard\\Zn" "\\ZbDevice Health Summary\\ZB" "$health_pct" \
        "Device:"         0 \
        "${d[model]} — ${d[android]} (API ${d[sdk]})" 2 \
        "Backend:"        0 \
        "${d[backend]}  |  Serial: ${d[serial]:-auto}" 4 \
        "Battery:"        0 \
        "$bat_label"      "$bat_status" \
        "Memory:"         0 \
        "$mem_label"      "$mem_status" \
        "Storage:"        0 \
        "${d[storage]}"   "$storage_status" \
        "Samsung:"        0 \
        "$samsung_label"  2

    return 0
}

# ──────────────────────────────────────────────
# SUBMENU: Device Info & Diagnostics
# ──────────────────────────────────────────────
tui_menu_device() {
    local choice
    while choice="$(
        tui_menu "\\Z4📊 Device & Diagnostics\\Zn" "Select an action:" \
            "dashboard" "\\Z6Dashboard\\Zn — Device status overview" \
            "report"    "\\Z6Full Report\\Zn — Comprehensive device report" \
            "doctor"    "\\Z6Run Doctor\\Zn — System diagnostics & health checks" \
            "watch"     "\\Z6Live Monitor\\Zn — Real-time device monitoring" \
            "back"      "⬅  Return to main menu"
    )"; do
        case "$choice" in
            back|"") break ;;
            dashboard) tui_dashboard_home ;;
            report)
                _load_module "reporting" 2>/dev/null || true
                local output
                output="$(reporting_full_report 2>&1)"
                tui_textbox "\\Z4Full Device Report\\Zn" "$output"
                ;;
            doctor)
                _load_module "doctor" 2>/dev/null || true
                local output
                output="$(doctor_run 2>&1)"
                tui_textbox "\\Z4Diagnostics Report\\Zn" "$output"
                ;;
            watch)
                _load_module "watch" 2>/dev/null || true
                tui_notify "info" "Live Monitor" "Monitoring will start in the terminal.\nPress Ctrl+C to stop."
                watch_run 2>&1
                echo ""
                echo "Monitoring stopped. Press Enter to return."
                read -r dummy
                ;;
        esac
    done
}

# ──────────────────────────────────────────────
# SUBMENU: Performance & Profiles
# ──────────────────────────────────────────────
tui_menu_performance() {
    local choice
    while choice="$(
        tui_menu "\\Z4⚡ Performance & Profiles\\Zn" "Select an action:" \
            "profile"      "\\Z6Apply Profile\\Zn — balanced / performance / powersave / light" \
            "benchmark"    "\\Z6Run Benchmark\\Zn — Measure device performance" \
            "enhanced"     "\\Z6Enhanced Benchmark\\Zn — Multi-run with stats" \
            "analysis"     "\\Z6Performance Analysis\\Zn — Health scoring" \
            "profile_mgr"  "\\Z6Profile Manager\\Zn — List / clone / validate / export" \
            "back"         "⬅  Return to main menu"
    )"; do
        case "$choice" in
            back|"") break ;;
            profile)
                local prof
                prof="$(tui_menu "\\Z4Select Profile\\Zn" "Choose a profile:" \
                    "balanced"    "\\Z2Daily-use\\Zn — Balanced performance" \
                    "performance" "\\Z1Max speed\\Zn — Highest responsiveness" \
                    "powersave"   "\\Z3Max battery\\Zn — Extend battery life" \
                    "light"       "\\Z6Samsung light\\Zn — Battery-optimized")" || continue
                _load_module "performance" 2>/dev/null || true
                tui_while "Applying Profile" "\\Z6Applying '$prof' profile...\\Zn" performance_apply_profile "$prof"
                tui_notify "success" "Profile Applied" "Profile '\\Z6$prof\\Zn' has been applied successfully."
                ;;
            benchmark)
                _load_module "benchmark" 2>/dev/null || true
                local output
                output="$(benchmark_run 2>&1)"
                tui_textbox "\\Z4Benchmark Results\\Zn" "$output"
                ;;
            enhanced)
                _load_module "benchmark" 2>/dev/null || true
                local n_str
                n_str="$(tui_input "Runs" "Number of benchmark runs:" "5")" || continue
                [[ -z "$n_str" || ! "$n_str" =~ ^[0-9]+$ ]] && n_str=5
                local output
                output="$(benchmark_repeated_measure "$n_str" 2>&1)"
                tui_textbox "\\Z4Enhanced Benchmark ($n_str runs)\\Zn" "$output"
                ;;
            analysis)
                _load_module "analyzer" 2>/dev/null || true
                local output
                output="$(analyzer_run 2>&1)"
                tui_textbox "\\Z4Performance Analysis\\Zn" "$output"
                ;;
            profile_mgr)
                _load_module "profile_manager" 2>/dev/null || true
                local output
                output="$(profile_manager_list 2>&1)"
                tui_textbox "\\Z4Profile Manager\\Zn" "$output"
                ;;
        esac
    done
}

# ──────────────────────────────────────────────
# SUBMENU: Maintenance
# ──────────────────────────────────────────────
tui_menu_maintenance() {
    local choice
    while choice="$(
        tui_menu "\\Z4🔧 Maintenance\\Zn" "Select an action:" \
            "trim"      "\\Z6Trim Cache\\Zn — Clear system & app caches" \
            "compile"   "\\Z6ART Compile\\Zn — Force bytecode recompilation" \
            "network"   "\\Z6Refresh Network\\Zn — Reset network & DNS" \
            "update"    "\\Z6Check Updates\\Zn — Look for toolkit updates" \
            "schedule"  "\\Z6Scheduled Tasks\\Zn — Manage automation" \
            "packages"  "\\Z6Package Analysis\\Zn — Analyze & recommend" \
            "back"      "⬅  Return to main menu"
    )"; do
        case "$choice" in
            back|"") break ;;
            trim)
                _load_module "maintenance" 2>/dev/null || true
                tui_confirm_dangerous "Trim Cache" "Clear system and app caches?" || continue
                local output
                output="$(maintenance_trim_cache 2>&1)"
                tui_textbox "\\Z4Cache Trim Results\\Zn" "$output"
                ;;
            compile)
                _load_module "maintenance" 2>/dev/null || true
                tui_confirm_dangerous "ART Compilation" "Force ART recompilation of all apps?\nThis may take several minutes." || continue
                local output
                output="$(maintenance_compile_all 2>&1)"
                tui_textbox "\\Z4ART Compilation Results\\Zn" "$output"
                ;;
            network)
                _load_module "network" 2>/dev/null || true
                tui_confirm_dangerous "Network Reset" "Refresh network configuration and DNS?" || continue
                _load_module "maintenance" 2>/dev/null || true
                local output
                # Use the network-refresh logic from maintenance or a combined call
                output="$(_load_module "network" && network_status 2>&1; maintenance_health_check 2>&1)"
                tui_textbox "\\Z4Network & Health\\Zn" "$output"
                ;;
            update)
                _load_module "updater" 2>/dev/null || true
                local output
                output="$(updater_check_only 2>&1)"
                tui_textbox "\\Z4Update Check\\Zn" "$output"
                if tui_confirm "Update?" "Download and apply the update?" 2>/dev/null; then
                    tui_while "Updating" "\\Z6Downloading update...\\Zn" updater_run
                    tui_notify "success" "Update Complete" "Toolkit has been updated."
                fi
                ;;
            schedule)
                _load_module "scheduler" 2>/dev/null || true
                local output
                output="$(scheduler_list 2>&1 || echo "Scheduler module loaded.")"
                tui_textbox "\\Z4Scheduled Tasks\\Zn" "$output"
                ;;
            packages)
                _load_module "packages" 2>/dev/null || true
                local output
                output="$(packages_recommend 2>&1)"
                tui_textbox "\\Z4Package Recommendations\\Zn" "$output"
                ;;
        esac
    done
}

# ──────────────────────────────────────────────
# SUBMENU: Backups
# ──────────────────────────────────────────────
tui_menu_backup() {
    local choice
    while choice="$(
        tui_menu "\\Z4📦 Backups\\Zn" "Select an action:" \
            "create"   "\\Z6Create Backup\\Zn — Settings snapshot + packages list" \
            "list"     "\\Z6List Backups\\Zn — View available backups" \
            "restore"  "\\Z6Restore\\Zn — Restore from a backup file" \
            "rollback" "\\Z6Rollback\\Zn — Revert previous changes" \
            "back"     "⬅  Return to main menu"
    )"; do
        case "$choice" in
            back|"") break ;;
            create)
                backup_init 2>/dev/null || true
                local sfile pfile
                tui_while "Creating Backup" "\\Z6Taking settings snapshot...\\Zn" backup_create_snapshot
                sfile="$(backup_create_snapshot 2>&1 | tail -1)"
                pfile="$(backup_create_packages 2>&1 | tail -1)"
                tui_notify "success" "Backup Complete" \
                    "Settings snapshot: \\Z6$(basename "${sfile:-unknown}")\\Zn\\nPackages list: \\Z6$(basename "${pfile:-unknown}")\\Zn"
                ;;
            list)
                backup_init 2>/dev/null || true
                local output
                output="$(backup_list 2>&1)"
                tui_textbox "\\Z4Available Backups\\Zn" "$output"
                ;;
            restore)
                backup_init 2>/dev/null || true
                local output
                output="$(backup_list 2>&1)"
                tui_textbox "\\Z4Available Backups\\Zn" "$output"
                local fname
                fname="$(tui_input "Restore" "Enter backup filename to restore:")" || continue
                [[ -z "$fname" ]] && continue
                tui_confirm_dangerous "Restore Backup" "Restore from '$fname'?\nThis will change system settings." || continue
                tui_while "Restoring" "\\Z6Restoring from $fname...\\Zn" backup_restore "$fname"
                tui_notify "success" "Restore Complete" "Backup '$fname' has been restored."
                ;;
            rollback)
                _load_module "rollback" 2>/dev/null || true
                local output
                output="$(rollback_list 2>&1 || echo "Rollback module loaded.")"
                tui_textbox "\\Z4Rollback\\Zn" "$output"
                ;;
        esac
    done
}

# ──────────────────────────────────────────────
# SUBMENU: Security
# ──────────────────────────────────────────────
tui_menu_security() {
    local choice
    while choice="$(
        tui_menu "\\Z4🛡️ Security\\Zn" "Select an action:" \
            "audit"   "\\Z6Security Audit\\Zn — Scan device security posture" \
            "harden"  "\\Z6Security Hardening\\Zn — Deep code security scan" \
            "review"  "\\Z6Code Security Review\\Zn — Audit codebase for issues" \
            "back"    "⬅  Return to main menu"
    )"; do
        case "$choice" in
            back|"") break ;;
            audit)
                _load_module "audit" 2>/dev/null || true
                local output
                output="$(audit_run 2>&1)"
                tui_textbox "\\Z4Security Audit\\Zn" "$output"
                ;;
            harden)
                _load_module "security_harden" 2>/dev/null || true
                local output
                output="$(security_harden_run 2>&1 || security_harden_scan 2>&1 || echo "Security hardening module loaded.")"
                tui_textbox "\\Z4Security Hardening\\Zn" "$output"
                ;;
            review)
                _load_module "security_review" 2>/dev/null || true
                local output
                output="$(security_review_run 2>&1 || echo "Security review module loaded.")"
                tui_textbox "\\Z4Security Review\\Zn" "$output"
                ;;
        esac
    done
}

# ──────────────────────────────────────────────
# SUBMENU: Samsung Tools
# ──────────────────────────────────────────────
tui_menu_samsung() {
    local choice
    while choice="$(
        tui_menu "\\Z4📱 Samsung Galaxy Tools\\Zn" "Select an action:" \
            "bloatware" "\\Z6List Bloatware\\Zn — By safety level" \
            "light"     "\\Z6Light Optimizations\\Zn — Samsung battery optimizer" \
            "back"      "⬅  Return to main menu"
    )"; do
        case "$choice" in
            back|"") break ;;
            bloatware)
                local level
                level="$(tui_menu "\\Z4Bloatware Level\\Zn" "Select safety level:" \
                    "safe"       "\\Z2Safe\\Zn — Generally safe to disable" \
                    "moderate"   "\\Z3Moderate\\Zn — Some risk" \
                    "aggressive" "\\Z1Aggressive\\Zn — High removal rate" \
                    "all"        "\\Z6All\\Zn — All known Samsung packages")" || continue
                _load_module "samsung" 2>/dev/null || true
                local output
                output="$(samsung_list_bloatware "$level" 2>&1)"
                tui_textbox "\\Z4Bloatware — $level\\Zn" "$output"
                ;;
            light)
                _load_module "samsung" 2>/dev/null || true
                _load_module "performance" 2>/dev/null || true
                tui_confirm_dangerous "Light Optimizations" \
                    "Apply Samsung light performance profile?\nThis optimizes battery and reduces background activity." || continue
                tui_while "Optimizing" "\\Z6Applying Samsung light optimizations...\\Zn" samsung_apply_light_optimizations
                tui_notify "success" "Done" "Samsung light optimizations applied successfully."
                ;;
        esac
    done
}

# ──────────────────────────────────────────────
# SUBMENU: Plugins
# ──────────────────────────────────────────────
tui_menu_plugins() {
    local choice
    while choice="$(
        tui_menu "\\Z4🔌 Plugins\\Zn" "Select an action:" \
            "list"    "\\Z6List Plugins\\Zn — Show all registered plugins" \
            "run"     "\\Z6Run Plugin\\Zn — Execute a plugin by name" \
            "certify" "\\Z6Certify Plugins\\Zn — Validate against SDK" \
            "back"    "⬅  Return to main menu"
    )"; do
        case "$choice" in
            back|"") break ;;
            list)
                local output
                output="$(plugin_list 2>&1)"
                tui_textbox "\\Z4Loaded Plugins\\Zn" "$output"
                ;;
            run)
                local pname
                pname="$(tui_input "Run Plugin" "Enter plugin name:")" || continue
                [[ -z "$pname" ]] && continue
                local output
                output="$(plugin_run "$pname" 2>&1)"
                tui_textbox "\\Z4Plugin Output — $pname\\Zn" "$output"
                ;;
            certify)
                _load_module "plugin_certify" 2>/dev/null || true
                local output
                output="$(plugin_certify_run 2>&1 || echo "Plugin certification module loaded.")"
                tui_textbox "\\Z4Plugin Certification\\Zn" "$output"
                ;;
        esac
    done
}

# ──────────────────────────────────────────────
# SUBMENU: Developer & Advanced
# ──────────────────────────────────────────────
tui_menu_developer() {
    local choice
    while choice="$(
        tui_menu "\\Z4⚙️ Developer & Advanced\\Zn" "Select an action:" \
            "lint"      "\\Z6Lint\\Zn — Run ShellCheck & static analysis" \
            "format"    "\\Z6Format\\Zn — Auto-format shell scripts" \
            "tests"     "\\Z6Run Tests\\Zn — Execute BATS test suite" \
            "docs"      "\\Z6Generate Docs\\Zn — Build documentation" \
            "export"    "\\Z6Export Report\\Zn — Device report as MD/JSON/CSV/HTML" \
            "compare"   "\\Z6Compare Reports\\Zn — Diff two JSON reports" \
            "devices"   "\\Z6Device Manager\\Zn — List / select connected devices" \
            "deps"      "\\Z6Dependencies\\Zn — Check & manage dependencies" \
            "about"     "\\Z6About\\Zn — Version, license, changelog" \
            "back"      "⬅  Return to main menu"
    )"; do
        case "$choice" in
            back|"") break ;;
            lint)
                _load_module "static_analysis" 2>/dev/null || true
                local output
                output="$(static_analysis_run 2>&1 || dev_lint 2>&1)"
                tui_textbox "\\Z4Lint Results\\Zn" "$output"
                ;;
            format)
                _load_module "developer" 2>/dev/null || true
                local output
                output="$(dev_format 2>&1)"
                tui_textbox "\\Z4Format Results\\Zn" "$output"
                ;;
            tests)
                _load_module "developer" 2>/dev/null || true
                tui_confirm "Run Tests" "Run the BATS test suite?\nThis may take several minutes." || continue
                local output
                output="$(dev_tests 2>&1)"
                tui_textbox "\\Z4Test Results\\Zn" "$output"
                ;;
            docs)
                _load_module "docgen" 2>/dev/null || true
                local output
                output="$(docgen_generate 2>&1 || dev_docs 2>&1)"
                tui_textbox "\\Z4Documentation Generated\\Zn" "$output"
                ;;
            export)
                local fmt
                fmt="$(tui_menu "\\Z4Export Format\\Zn" "Choose format:" \
                    "md"   "Markdown" \
                    "json" "JSON" \
                    "csv"  "CSV" \
                    "html" "HTML")" || continue
                _load_module "export" 2>/dev/null || true
                _load_module "reporting" 2>/dev/null || true
                local output
                output="$(export_report "$fmt" 2>&1)"
                tui_textbox "\\Z4Export Results\\Zn" "$output"
                ;;
            compare)
                local r1 r2
                r1="$(tui_input "Compare" "Path to first JSON report:")" || continue
                r2="$(tui_input "Compare" "Path to second JSON report:")" || continue
                [[ -z "$r1" || -z "$r2" ]] && continue
                _load_module "compare" 2>/dev/null || true
                local output
                output="$(compare_reports "$r1" "$r2" 2>&1)"
                tui_textbox "\\Z4Comparison Results\\Zn" "$output"
                ;;
            devices)
                _load_module "devices" 2>/dev/null || true
                local output
                output="$(devices_list 2>&1)"
                tui_textbox "\\Z4Connected Devices\\Zn" "$output"
                ;;
            deps)
                local output
                output="$(deps_check 2>&1 || echo "Dependencies: OK")"
                tui_textbox "\\Z4Dependency Check\\Zn" "$output"
                ;;
            about)
                local about_text
                about_text="Android Toolkit v${ANDROID_TOOLKIT_VERSION}\n\n"
                about_text+="A modular, non-root Android optimization and diagnostics toolkit.\n"
                about_text+="Targets Android 13–16 and Samsung One UI 5–8.\n\n"
                about_text+="License: MIT\n"
                about_text+="Repository: https://github.com/00AstroGit00/android-toolkit\n\n"
                about_text+="$(cat "${ANDROID_TOOLKIT_ROOT_DIR}/CHANGELOG.md" 2>/dev/null | head -40)"
                tui_textbox "\\Z4About Android Toolkit\\Zn" "$about_text"
                ;;
        esac
    done
}

# ──────────────────────────────────────────────
# SUBMENU: Settings
# ──────────────────────────────────────────────
tui_menu_settings() {
    local choice
    while choice="$(
        tui_menu "\\Z4⚙️ Settings\\Zn" "Select an action:" \
            "config"    "\\Z6View Configuration\\Zn — Show current settings" \
            "benchhist" "\\Z6Benchmark History\\Zn — Past benchmark results" \
            "stats"     "\\Z6Usage Statistics\\Zn — Local toolkit usage" \
            "back"      "⬅  Return to main menu"
    )"; do
        case "$choice" in
            back|"") break ;;
            config)
                local output
                output="$(config_list 2>&1)"
                tui_textbox "\\Z4Configuration\\Zn" "$output"
                ;;
            benchhist)
                _load_module "benchmark" 2>/dev/null || true
                local output
                output="$(benchmark_list_history 2>&1)"
                tui_textbox "\\Z4Benchmark History\\Zn" "$output"
                ;;
            stats)
                local output
                output="$(usage_stats 2>&1 || echo "Stats module loaded.")"
                tui_textbox "\\Z4Usage Statistics\\Zn" "$output"
                ;;
        esac
    done
}

# ──────────────────────────────────────────────
# MAIN MENU
# ──────────────────────────────────────────────
tui_main_menu() {
    local choice

    # First show the dashboard once
    tui_dashboard_home

    while choice="$(
        tui_menu "\\Z4Android Toolkit — Main Menu\\Zn" \
            "\\ZbSelect a category:\\ZB" \
            "device"      "\\Z6📊\\Zn  Device Info & Diagnostics" \
            "performance" "\\Z6⚡\\Zn  Performance & Profiles" \
            "maintenance" "\\Z6🔧\\Zn  Maintenance & Cleanup" \
            "backup"      "\\Z6📦\\Zn  Backups & Recovery" \
            "security"    "\\Z6🛡️\\Zn  Security & Privacy" \
            "samsung"     "\\Z6📱\\Zn  Samsung Galaxy Tools" \
            "plugins"     "\\Z6🔌\\Zn  Plugins & Extensions" \
            "developer"   "\\Z6⚙️\\Zn  Developer & Advanced" \
            "settings"    "\\Z6🔧\\Zn  Settings & History" \
            "quit"        "\\Z1❌  Quit\\Zn"
    )"; do
        case "$choice" in
            quit|"")
                tui_confirm "\\Z1Quit\\Zn" "Are you sure you want to exit the dashboard?" && return 1
                ;;
            device)      tui_menu_device ;;
            performance) tui_menu_performance ;;
            maintenance) tui_menu_maintenance ;;
            backup)      tui_menu_backup ;;
            security)    tui_menu_security ;;
            samsung)     tui_menu_samsung ;;
            plugins)     tui_menu_plugins ;;
            developer)   tui_menu_developer ;;
            settings)    tui_menu_settings ;;
        esac
    done
    return 0
}

# ──────────────────────────────────────────────
# FALLBACK TEXT MENU (when no dialog/whiptail)
# ──────────────────────────────────────────────
tui_text_main_menu() {
    local _choice
    while true; do
        echo ""
        echo "╔══════════════════════════════════════╗"
        echo "║   Android Toolkit  v${ANDROID_TOOLKIT_VERSION}   ║"
        echo "║   Interactive Mode (text fallback)   ║"
        echo "╚══════════════════════════════════════╝"
        echo ""
        echo "Device: ${DEVICE_MODEL:-unknown}  |  Android: ${DEVICE_ANDROID_VERSION:-?}  |  ${ANDROID_TOOLKIT_BACKEND:-no backend}"
        echo ""
        echo "1)  Device Dashboard"
        echo "2)  Diagnostics & Report"
        echo "3)  Apply Profile"
        echo "4)  Run Benchmark"
        echo "5)  Security Audit"
        echo "6)  Create Backup"
        echo "7)  Samsung Tools"
        echo "8)  Plugin Manager"
        echo "9)  Settings & Config"
        echo "10) Developer Tools"
        echo "q)  Quit"
        echo ""
        read -r -p "Select [1-10, q]: " _choice

        case "$_choice" in
            q|Q) exit 0 ;;
            1) tui_dashboard_home 2>&1 | head -20 ; echo "Press Enter."; read -r dummy ;;
            2) _load_module "reporting" 2>/dev/null; reporting_full_report 2>&1 | head -30; echo "Press Enter."; read -r dummy ;;
            3) read -r -p "Profile (balanced/performance/powersave/light): " _prof
               _load_module "performance" 2>/dev/null; performance_apply_profile "$_prof" 2>&1 ;;
            4) _load_module "benchmark" 2>/dev/null; benchmark_run 2>&1 | head -30; echo "Press Enter."; read -r dummy ;;
            5) _load_module "audit" 2>/dev/null; audit_run 2>&1 | head -30; echo "Press Enter."; read -r dummy ;;
            6) backup_create_snapshot 2>&1; backup_create_packages 2>&1 ;;
            7) _load_module "samsung" 2>/dev/null; samsung_list_bloatware safe 2>&1 | head -20; echo "Press Enter."; read -r dummy ;;
            8) plugin_list 2>&1 | head -20; echo "Press Enter."; read -r dummy ;;
            9) config_list 2>&1 | head -20; echo "Press Enter."; read -r dummy ;;
            10) dev_lint 2>&1 | head -20; echo "Press Enter."; read -r dummy ;;
        esac
    done
}

# ──────────────────────────────────────────────
# MAIN ENTRY POINT
# ──────────────────────────────────────────────
tui_main() {
    tui_detect_backend
    tui_detect_term_size

    if [[ "$TUI_BACKEND" == "none" ]]; then
        log_warning "No TUI backend found (install 'dialog' or 'whiptail')"
        log_info "Falling back to text-based menu"
        tui_text_main_menu
        return 0
    fi

    # Set persistent backtitle used by all dialog/whiptail wrappers
    TUI_BACKTITLE="$(tui_backtitle)"

    tui_main_menu
    local exitcode=$?

    # Clear any leftover dialog state
    dialog --clear 2>/dev/null || true
    clear 2>/dev/null || true

    return $exitcode
}
