#!/data/data/com.termux/files/usr/bin/bash
#
# themes.sh — Theme System
#
# Provides color schemes for the dashboard.
# Supports: Dark, Light, Classic, Nord, Dracula, Catppuccin
# Each theme defines 16 color slots as 256-color indices.
#
# Part of the Android Toolkit Dashboard.

# ──────────────────────────────────────────────
# THEME STATE
# ──────────────────────────────────────────────
THEME_NAME="dark"
# Color slots (all 256-color indices):
declare -a THEME_BG=()      # Background
declare -a THEME_FG=()      # Foreground (text)
declare -a THEME_HEADER_BG=()
declare -a THEME_HEADER_FG=()
declare -a THEME_SIDEBAR_BG=()
declare -a THEME_SIDEBAR_FG=()
declare -a THEME_SIDEBAR_ACTIVE_BG=()
declare -a THEME_SIDEBAR_ACTIVE_FG=()
declare -a THEME_FOOTER_BG=()
declare -a THEME_FOOTER_FG=()
declare -a THEME_CARD_BG=()
declare -a THEME_CARD_FG=()
declare -a THEME_CARD_BORDER=()
declare -a THEME_SUCCESS=()
declare -a THEME_WARNING=()
declare -a THEME_ERROR=()
declare -a THEME_INFO=()
declare -a THEME_MUTED=()
declare -a THEME_ACCENT=()
declare -a THEME_SCROLLBAR=()

# ──────────────────────────────────────────────
# THEME DEFINITIONS
# ──────────────────────────────────────────────

theme_load_dark() {
    THEME_BG=(16)                    # Near-black
    THEME_FG=(255)                   # Near-white
    THEME_HEADER_BG=(24)             # Dark blue
    THEME_HEADER_FG=(255)
    THEME_SIDEBAR_BG=(233)           # Darker gray
    THEME_SIDEBAR_FG=(250)           # Light gray
    THEME_SIDEBAR_ACTIVE_BG=(33)     # Blue accent
    THEME_SIDEBAR_ACTIVE_FG=(255)
    THEME_FOOTER_BG=(234)            # Dark gray
    THEME_FOOTER_FG=(244)            # Muted gray
    THEME_CARD_BG=(232)              # Slightly lighter than bg
    THEME_CARD_FG=(255)
    THEME_CARD_BORDER=(237)          # Subtle border
    THEME_SUCCESS=(82)               # Green
    THEME_WARNING=(220)              # Yellow
    THEME_ERROR=(196)                # Red
    THEME_INFO=(75)                  # Blue
    THEME_MUTED=(244)                # Gray
    THEME_ACCENT=(39)                # Cyan-blue
    THEME_SCROLLBAR=(239)
}

theme_load_light() {
    THEME_BG=(231)
    THEME_FG=(16)
    THEME_HEADER_BG=(25)
    THEME_HEADER_FG=(231)
    THEME_SIDEBAR_BG=(253)
    THEME_SIDEBAR_FG=(233)
    THEME_SIDEBAR_ACTIVE_BG=(33)
    THEME_SIDEBAR_ACTIVE_FG=(231)
    THEME_FOOTER_BG=(250)
    THEME_FOOTER_FG=(236)
    THEME_CARD_BG=(255)
    THEME_CARD_FG=(16)
    THEME_CARD_BORDER=(247)
    THEME_SUCCESS=(34)
    THEME_WARNING=(214)
    THEME_ERROR=(160)
    THEME_INFO=(26)
    THEME_MUTED=(242)
    THEME_ACCENT=(27)
    THEME_SCROLLBAR=(245)
}

theme_load_classic() {
    THEME_BG=(17)                    # Navy
    THEME_FG=(255)
    THEME_HEADER_BG=(20)             # Dark navy
    THEME_HEADER_FG=(255)
    THEME_SIDEBAR_BG=$(printf '%s\n' "${THEME_BG[@]}")
    THEME_SIDEBAR_FG=(255)
    THEME_SIDEBAR_ACTIVE_BG=(34)     # Green
    THEME_SIDEBAR_ACTIVE_FG=(255)
    THEME_FOOTER_BG=(236)
    THEME_FOOTER_FG=(248)
    THEME_CARD_BG=(18)
    THEME_CARD_FG=(255)
    THEME_CARD_BORDER=$(printf '%s\n' "${THEME_HEADER_BG[@]}")
    THEME_SUCCESS=(82)
    THEME_WARNING=(220)
    THEME_ERROR=(196)
    THEME_INFO=(75)
    THEME_MUTED=$(printf '%s\n' "${THEME_FOOTER_FG[@]}")
    THEME_ACCENT=(46)
    THEME_SCROLLBAR=$(printf '%s\n' "${THEME_FOOTER_BG[@]}")
}

theme_load_nord() {
    THEME_BG=(235)                   # Polar Night base
    THEME_FG=(255)                   # Snow Storm text
    THEME_HEADER_BG=(238)            # Polar Night lighter
    THEME_HEADER_FG=(255)
    THEME_SIDEBAR_BG=(236)           # Polar Night medium
    THEME_SIDEBAR_FG=(249)           # Frost muted
    THEME_SIDEBAR_ACTIVE_BG=(67)     # Frost blue
    THEME_SIDEBAR_ACTIVE_FG=(255)
    THEME_FOOTER_BG=(237)
    THEME_FOOTER_FG=(244)
    THEME_CARD_BG=(236)
    THEME_CARD_FG=(255)
    THEME_CARD_BORDER=$(printf '%s\n' "${THEME_HEADER_BG[@]}")
    THEME_SUCCESS=(150)              # Aurora green
    THEME_WARNING=(221)              # Aurora yellow
    THEME_ERROR=(203)                # Aurora red
    THEME_INFO=(109)                 # Frost
    THEME_MUTED=(245)
    THEME_ACCENT=$(printf '%s\n' "${THEME_SIDEBAR_ACTIVE_BG[@]}")
    THEME_SCROLLBAR=$(printf '%s\n' "${THEME_HEADER_BG[@]}")
}

theme_load_dracula() {
    THEME_BG=(234)                   # Dracula bg
    THEME_FG=(255)                   # Foreground
    THEME_HEADER_BG=(236)            # Current line
    THEME_HEADER_FG=(255)
    THEME_SIDEBAR_BG=$(printf '%s\n' "${THEME_BG[@]}")
    THEME_SIDEBAR_FG=(248)           # Comment
    THEME_SIDEBAR_ACTIVE_BG=(62)     # Purple
    THEME_SIDEBAR_ACTIVE_FG=(231)
    THEME_FOOTER_BG=$(printf '%s\n' "${THEME_HEADER_BG[@]}")
    THEME_FOOTER_FG=$(printf '%s\n' "${THEME_SIDEBAR_FG[@]}")
    THEME_CARD_BG=$(printf '%s\n' "${THEME_HEADER_BG[@]}")
    THEME_CARD_FG=(255)
    THEME_CARD_BORDER=$(printf '%s\n' "${THEME_SIDEBAR_FG[@]}")
    THEME_SUCCESS=(84)               # Green
    THEME_WARNING=(228)              # Yellow
    THEME_ERROR=(197)                # Pink/Red
    THEME_INFO=(117)                 # Cyan
    THEME_MUTED=$(printf '%s\n' "${THEME_SIDEBAR_FG[@]}")
    THEME_ACCENT=(141)               # Purple
    THEME_SCROLLBAR=$(printf '%s\n' "${THEME_FOOTER_BG[@]}")
}

theme_load_catppuccin() {
    THEME_BG=(236)                   # Mantle
    THEME_FG=(255)                   # Text
    THEME_HEADER_BG=(237)            # Surface0
    THEME_HEADER_FG=(255)
    THEME_SIDEBAR_BG=$(printf '%s\n' "${THEME_BG[@]}")
    THEME_SIDEBAR_FG=(249)           # Subtext0
    THEME_SIDEBAR_ACTIVE_BG=(110)    # Blue
    THEME_SIDEBAR_ACTIVE_FG=(255)
    THEME_FOOTER_BG=$(printf '%s\n' "${THEME_HEADER_BG[@]}")
    THEME_FOOTER_FG=$(printf '%s\n' "${THEME_SIDEBAR_FG[@]}")
    THEME_CARD_BG=$(printf '%s\n' "${THEME_HEADER_BG[@]}")
    THEME_CARD_FG=$(printf '%s\n' "${THEME_FOOTER_FG[@]}")
    THEME_CARD_BORDER=(239)
    THEME_SUCCESS=(120)              # Green
    THEME_WARNING=(222)              # Yellow
    THEME_ERROR=(210)                # Red
    THEME_INFO=(116)                 # Teal
    THEME_MUTED=$(printf '%s\n' "${THEME_SIDEBAR_FG[@]}")
    THEME_ACCENT=(117)               # Lavender-ish blue
    THEME_SCROLLBAR=$(printf '%s\n' "${THEME_FOOTER_BG[@]}")
}

# ──────────────────────────────────────────────
# THEME API
# ──────────────────────────────────────────────

##############################################
# Load a theme by name.
# Arguments:
#   $1: theme name (dark|light|classic|nord|dracula|catppuccin)
theme_load() {
    local name="${1:-dark}"
    case "$name" in
        dark)       theme_load_dark ;;
        light)      theme_load_light ;;
        classic)    theme_load_classic ;;
        nord)       theme_load_nord ;;
        dracula)    theme_load_dracula ;;
        catppuccin) theme_load_catppuccin ;;
        *)
            log_warning "Unknown theme '$name', falling back to dark"
            theme_load_dark
            return 1
            ;;
    esac
    THEME_NAME="$name"
}

##############################################
# List available theme names.
theme_list() {
    echo "dark"
    echo "light"
    echo "classic"
    echo "nord"
    echo "dracula"
    echo "catppuccin"
}

##############################################
# Get a theme color value (for use in renderer calls).
# Arguments:
#   $1: color slot name (e.g., "THEME_BG", "THEME_ACCENT")
# Outputs: numeric color value
theme_get() {
    local slot="$1"
    case "$slot" in
        bg)              echo "${THEME_BG[0]}" ;;
        fg)              echo "${THEME_FG[0]}" ;;
        header_bg)       echo "${THEME_HEADER_BG[0]}" ;;
        header_fg)       echo "${THEME_HEADER_FG[0]}" ;;
        sidebar_bg)      echo "${THEME_SIDEBAR_BG[0]}" ;;
        sidebar_fg)      echo "${THEME_SIDEBAR_FG[0]}" ;;
        sidebar_active_bg) echo "${THEME_SIDEBAR_ACTIVE_BG[0]}" ;;
        sidebar_active_fg) echo "${THEME_SIDEBAR_ACTIVE_FG[0]}" ;;
        footer_bg)       echo "${THEME_FOOTER_BG[0]}" ;;
        footer_fg)       echo "${THEME_FOOTER_FG[0]}" ;;
        card_bg)         echo "${THEME_CARD_BG[0]}" ;;
        card_fg)         echo "${THEME_CARD_FG[0]}" ;;
        card_border)     echo "${THEME_CARD_BORDER[0]}" ;;
        success)         echo "${THEME_SUCCESS[0]}" ;;
        warning)         echo "${THEME_WARNING[0]}" ;;
        error)           echo "${THEME_ERROR[0]}" ;;
        info)            echo "${THEME_INFO[0]}" ;;
        muted)           echo "${THEME_MUTED[0]}" ;;
        accent)          echo "${THEME_ACCENT[0]}" ;;
        scrollbar)       echo "${THEME_SCROLLBAR[0]}" ;;
        *)               echo "${THEME_FG[0]}" ;;
    esac
}
