#!/data/data/com.termux/files/usr/bin/bash
#
# tui.sh — Interactive Terminal UI
#
# Uses dialog or whiptail for a terminal-based menu system.
# All toolkit actions are accessible through the menu.
#
# Features:
#   Main menu with all actions
#   Progress bars for long operations
#   Confirmation dialogs before destructive actions
#   Status dashboard
#
# Part of the Android Toolkit.

TUI_BACKEND=""

##############################################
# Detect available TUI backend.
# Prefers dialog over whiptail.
##############################################
tui_detect_backend() {
    if command -v dialog &>/dev/null; then
        TUI_BACKEND="dialog"
    elif command -v whiptail &>/dev/null; then
        TUI_BACKEND="whiptail"
    else
        TUI_BACKEND="none"
    fi
}

##############################################
# Show a message box.
# Arguments:
#   $1: title
#   $2: text
##############################################
tui_msgbox() {
    local title="$1" text="$2"
    case "$TUI_BACKEND" in
        dialog)  dialog --title "$title" --msgbox "$text" 15 60 ;;
        whiptail) whiptail --title "$title" --msgbox "$text" 15 60 ;;
        *)       echo "$text" ;;
    esac
}

##############################################
# Show a yes/no confirmation.
# Arguments:
#   $1: title
#   $2: text
# Returns: 0 for yes, 1 for no
##############################################
tui_confirm() {
    local title="$1" text="$2"
    case "$TUI_BACKEND" in
        dialog)  dialog --title "$title" --yesno "$text" 10 60 ;;
        whiptail) whiptail --title "$title" --yesno "$text" 10 60 ;;
        *)       utils_confirm "$text" ;;
    esac
}

##############################################
# Show a menu and return the selected item.
# Arguments:
#   $1: title
#   $2: menu text
#   $@: menu items (tag item pairs)
# Outputs: selected tag
##############################################
tui_menu() {
    local title="$1" text="$2"
    shift 2

    case "$TUI_BACKEND" in
        dialog|whiptail)
            # 3>&1 1>&2 2>&3 swaps stdout/stderr so the selected tag
            # (written to stderr) is captured by $() while the display
            # (written to stdout) goes to the terminal.
            "$TUI_BACKEND" --clear --title "$title" --menu "$text" 0 0 0 "$@" 3>&1 1>&2 2>&3
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
#   $3: default value
# Outputs: entered text
##############################################
tui_input() {
    local title="$1" text="$2" default="${3:-}"
    case "$TUI_BACKEND" in
        dialog|whiptail)
            "$TUI_BACKEND" --title "$title" --inputbox "$text" 10 60 "$default" 3>&1 1>&2 2>&3
            ;;
        *)       read -p "$text: " _input; echo "$_input" ;;
    esac
}

##############################################
# Show a gauge (progress bar).
# Arguments:
#   $1: title
#   $2: text
#   $3: percentage (0-100)
##############################################
tui_gauge() {
    local title="$1" text="$2" pct="$3"
    case "$TUI_BACKEND" in
        dialog)
            echo "$pct" | dialog --title "$title" --gauge "$text" 8 60 0
            ;;
        whiptail)
            echo "$pct" | whiptail --title "$title" --gauge "$text" 8 60 0
            ;;
        *)
            echo "[${pct}%] $text"
            ;;
    esac
}

##############################################
# Show a checklist.
# Arguments:
#   $1: title
#   $2: text
#   $@: items (tag description status)
# Outputs: selected tags (space-separated)
##############################################
tui_checklist() {
    local title="$1" text="$2"
    shift 2

    case "$TUI_BACKEND" in
        dialog|whiptail)
            "$TUI_BACKEND" --clear --title "$title" --checklist "$text" 15 60 10 "$@" 3>&1 1>&2 2>&3
            ;;
        *)
            echo "Select items (comma-separated numbers):"
            select _item in "$@"; do
                echo "$_item"
                break
            done
            ;;
    esac
}

##############################################
# Show informational text in a scrollable box.
# Arguments:
#   $1: title
#   $2: text
##############################################
tui_textbox() {
    local title="$1" text="$2"
    local tmpfile

    tmpfile="$(mktemp /tmp/toolkit_tui.XXXXXX)"
    echo "$text" > "$tmpfile"

    case "$TUI_BACKEND" in
        dialog)  dialog --title "$title" --textbox "$tmpfile" 20 70 ;;
        whiptail) whiptail --title "$title" --textbox "$tmpfile" 20 70 ;;
        *)       echo "$text" ;;
    esac

    rm -f "$tmpfile"
}

##############################################
# Main TUI entry point.
##############################################
tui_main() {
    tui_detect_backend

    if [[ "$TUI_BACKEND" == "none" ]]; then
        log_warning "No TUI backend found (install 'dialog' or 'whiptail')"
        log_info "Falling back to text-based menu"

        echo ""
        echo "Android Toolkit — Interactive Mode"
        echo "=================================="
        echo ""
        echo "1)  Status Dashboard"
        echo "2)  Device Report"
        echo "3)  Apply Profile"
        echo "4)  Run Doctor"
        echo "5)  Run Benchmark"
        echo "6)  Security Audit"
        echo "7)  Backup"
        echo "8)  Samsung Tools"
        echo "9)  Plugin Manager"
        echo "10) Settings"
        echo "q)  Quit"
        echo ""
        read -p "Select [1-10, q]: " _choice

        case "$_choice" in
            1)  _load_module "reporting"; reporting_status ;;
            2)  _load_module "reporting"; _load_module "battery" 2>/dev/null; _load_module "display" 2>/dev/null
                _load_module "network" 2>/dev/null; _load_module "samsung" 2>/dev/null
                reporting_full_report ;;
            3)  read -p "Profile (balanced/performance/powersave/light): " _prof
                _load_module "performance"; performance_apply_profile "$_prof" ;;
            4)  _load_module "doctor"; doctor_run ;;
            5)  _load_module "benchmark"; benchmark_run ;;
            6)  _load_module "audit" 2>/dev/null; audit_run ;;
            7)  backup_create_snapshot; backup_create_packages ;;
            8)  _load_module "samsung"; tui_samsung_menu ;;
            9)  plugin_list ;;
            10) config_list ;;
            q|Q) exit 0 ;;
        esac
        return 0
    fi

    # dialog/whiptail menu loop
    while true; do
        local choice
        choice="$(tui_menu "Android Toolkit v${ANDROID_TOOLKIT_VERSION}" "Select an action:" \
            "status"   "Device Status Dashboard" \
            "report"   "Full Device Report" \
            "profile"  "Apply Performance Profile" \
            "doctor"   "Run Diagnostics" \
            "benchmark" "Device Benchmark" \
            "audit"    "Security Audit" \
            "analyze"  "Performance Analysis" \
            "backup"   "Create Backup" \
            "samsung"  "Samsung Tools" \
            "plugins"  "Plugin Manager" \
            "settings" "Configuration" \
            "quit"     "Exit")" || break

        case "$choice" in
            quit) break ;;
            status)
                _load_module "reporting"
                local output
                output="$(reporting_status 2>&1)"
                tui_textbox "Device Status" "$output"
                ;;
            report)
                _load_module "reporting"
                _load_module "battery" 2>/dev/null || true
                _load_module "display" 2>/dev/null || true
                _load_module "network" 2>/dev/null || true
                _load_module "samsung" 2>/dev/null || true
                local output
                output="$(reporting_full_report 2>&1)"
                tui_textbox "Device Report" "$output"
                ;;
            profile)
                local prof
                prof="$(tui_menu "Select Profile" "Choose a profile to apply:" \
                    "balanced"    "Daily-use settings" \
                    "performance" "Max responsiveness" \
                    "powersave"   "Max battery life" \
                    "light"       "Samsung battery-optimized")" || continue
                _load_module "performance"
                performance_apply_profile "$prof"
                tui_msgbox "Profile Applied" "Profile '$prof' has been applied."
                ;;
            doctor)
                _load_module "doctor"
                local output
                output="$(doctor_run 2>&1)"
                tui_textbox "Diagnostics" "$output"
                ;;
            benchmark)
                _load_module "benchmark"
                local output
                output="$(benchmark_run 2>&1)"
                tui_textbox "Benchmark Results" "$output"
                ;;
            audit)
                _load_module "audit" 2>/dev/null || { tui_msgbox "Not Available" "Audit module not loaded"; continue; }
                local output
                output="$(audit_run 2>&1)"
                tui_textbox "Security Audit" "$output"
                ;;
            analyze)
                _load_module "analyzer" 2>/dev/null || { tui_msgbox "Not Available" "Analyzer module not loaded"; continue; }
                local output
                output="$(analyzer_run 2>&1)"
                tui_textbox "Performance Analysis" "$output"
                ;;
            backup)
                local sfile pfile
                sfile="$(backup_create_snapshot 2>&1)"
                pfile="$(backup_create_packages 2>&1)"
                tui_msgbox "Backup Complete" "Settings: $(basename "$sfile")\nPackages: $(basename "$pfile")"
                ;;
            samsung)
                tui_samsung_menu
                ;;
            plugins)
                local output
                output="$(plugin_list 2>&1)"
                tui_textbox "Loaded Plugins" "$output"
                ;;
            settings)
                local output
                output="$(config_list 2>&1)"
                tui_textbox "Configuration" "$output"
                ;;
        esac
    done
}

##############################################
# Samsung-specific submenu.
##############################################
tui_samsung_menu() {
    while true; do
        local choice
        choice="$(tui_menu "Samsung Tools" "Select a Samsung action:" \
            "bloatware" "List bloatware by safety level" \
            "light"     "Apply light performance profile" \
            "back"      "Return to main menu")" || break

        case "$choice" in
            back) break ;;
            bloatware)
                local level
                level="$(tui_menu "Bloatware Level" "Select safety level:" \
                    "safe"       "Generally safe to disable" \
                    "moderate"   "Moderate risk packages" \
                    "aggressive" "Aggressive removal candidates" \
                    "all"        "All known Samsung packages")" || continue
                local output
                output="$(_load_module "samsung" 2>/dev/null && samsung_list_bloatware "$level" 2>&1)"
                tui_textbox "Bloatware — $level" "$output"
                ;;
            light)
                _load_module "samsung" 2>/dev/null
                _load_module "performance" 2>/dev/null
                backup_create_snapshot "before_samsung_light" > /dev/null
                samsung_apply_light_optimizations 2>&1
                tui_msgbox "Done" "Samsung light optimizations applied."
                ;;
        esac
    done
}
