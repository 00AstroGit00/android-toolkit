#!/data/data/com.termux/files/usr/bin/bash
#
# menus.sh — Context Menu System
#
# Provides popup menus for selecting options,
# confirming actions, and navigating lists.
# Falls back to dialog/whiptail when available.
#
# Part of the Android Toolkit Dashboard.

MENU_USE_DIALOG=true

##############################################
# Detect if dialog/whiptail should be used
# for input-heavy operations.
menu_detect() {
    if command -v dialog &>/dev/null; then
        MENU_USE_DIALOG=true
    elif command -v whiptail &>/dev/null; then
        MENU_USE_DIALOG=true
    else
        MENU_USE_DIALOG=false
    fi
}

##############################################
# Show a selection menu using dialog/whiptail.
# Arguments:
#   $1: title
#   $2: prompt text
#   $3-N: items (tag description pairs)
# Outputs: selected tag
menu_select() {
    local title="$1" text="$2"
    shift 2

    if command -v dialog &>/dev/null; then
        dialog --backtitle "$TUI_BACKTITLE" --colors --title "$title" \
            --menu "$text" 0 0 0 "$@" 3>&1 1>&2 2>&3
        return $?
    elif command -v whiptail &>/dev/null; then
        whiptail --backtitle "$TUI_BACKTITLE" --title "$title" \
            --menu "$text" 0 0 0 "$@" 3>&1 1>&2 2>&3
        return $?
    fi

    # No dialog fallback
    echo "--- $title ---"
    echo "$text"
    local i=1
    local items=()
    while [[ $# -ge 2 ]]; do
        echo "  $i) $1 — $2"
        items+=("$1")
        shift 2
        ((i++))
    done
    echo ""
    read -r -p "Select [1-$((i-1))]: " sel
    local idx=$(( sel - 1 ))
    [[ "$idx" -ge 0 && "$idx" -lt "${#items[@]}" ]] && echo "${items[$idx]}"
}

##############################################
# Show a yes/no confirmation dialog.
# Arguments:
#   $1: title
#   $2: text
# Returns: 0 for yes, 1 for no
menu_confirm() {
    local title="$1" text="$2"

    if command -v dialog &>/dev/null; then
        dialog --backtitle "$TUI_BACKTITLE" --colors --title "$title" \
            --yesno "$text" 0 0
        return $?
    elif command -v whiptail &>/dev/null; then
        whiptail --backtitle "$TUI_BACKTITLE" --title "$title" \
            --yesno "$text" 0 0
        return $?
    fi

    echo "--- $title ---"
    echo "$text"
    read -r -p "[y/N]: " resp
    [[ "$resp" == "y" || "$resp" == "Y" ]]
}

##############################################
# Show an input box.
# Arguments:
#   $1: title
#   $2: text
#   $3: default value
# Outputs: entered text
menu_input() {
    local title="$1" text="$2" default="${3:-}"

    if command -v dialog &>/dev/null; then
        dialog --backtitle "$TUI_BACKTITLE" --colors --title "$title" \
            --inputbox "$text" 0 0 "$default" 3>&1 1>&2 2>&3
        return $?
    elif command -v whiptail &>/dev/null; then
        whiptail --backtitle "$TUI_BACKTITLE" --title "$title" \
            --inputbox "$text" 0 0 "$default" 3>&1 1>&2 2>&3
        return $?
    fi

    echo "--- $title ---"
    echo "$text"
    read -r -p "> " input
    echo "${input:-$default}"
}

##############################################
# Show a message box.
# Arguments:
#   $1: title
#   $2: text
menu_msgbox() {
    local title="$1" text="$2"

    if command -v dialog &>/dev/null; then
        dialog --backtitle "$TUI_BACKTITLE" --colors --title "$title" \
            --msgbox "$text" 0 0
        return $?
    elif command -v whiptail &>/dev/null; then
        whiptail --backtitle "$TUI_BACKTITLE" --title "$title" \
            --msgbox "$text" 0 0
        return $?
    fi

    echo "--- $title ---"
    echo "$text"
    echo "Press Enter to continue."
    read -r dummy
}

##############################################
# Show a progress gauge for long operations.
# Arguments:
#   $1: title
#   $2: text
#   $3: command to run (sends % lines to stdin)
menu_gauge() {
    local title="$1" text="$2"
    shift 2

    if command -v dialog &>/dev/null; then
        (
            echo "0"
            "$@" 2>&1 | while read -r line; do
                [[ "$line" =~ ^[0-9]+$ ]] && echo "$line"
            done
            echo "100"
        ) | dialog --backtitle "$TUI_BACKTITLE" --colors --title "$title" \
            --gauge "$text" 8 60 0
    elif command -v whiptail &>/dev/null; then
        (
            echo "0"
            "$@" 2>&1 | while read -r line; do
                [[ "$line" =~ ^[0-9]+$ ]] && echo "$line"
            done
            echo "100"
        ) | whiptail --backtitle "$TUI_BACKTITLE" --title "$title" \
            --gauge "$text" 8 60 0
    else
        echo "$text"
        "$@" 2>&1 || true
    fi
}

##############################################
# Show a text information box.
# Arguments:
#   $1: title
#   $2: text content
menu_textbox() {
    local title="$1" text="$2"
    local tmpfile

    tmpfile="$(mktemp /tmp/toolkit_menu.XXXXXX 2>/dev/null)" || {
        echo "$text"
        return
    }
    printf '%s\n' "$text" > "$tmpfile"

    if command -v dialog &>/dev/null; then
        dialog --backtitle "$TUI_BACKTITLE" --colors --title "$title" \
            --textbox "$tmpfile" 0 0
    elif command -v whiptail &>/dev/null; then
        whiptail --backtitle "$TUI_BACKTITLE" --title "$title" \
            --textbox "$tmpfile" 0 0
    else
        echo "$text"
    fi

    rm -f "$tmpfile"
}
