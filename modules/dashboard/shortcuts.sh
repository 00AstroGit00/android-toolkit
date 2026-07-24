#!/data/data/com.termux/files/usr/bin/bash
#
# shortcuts.sh — Keyboard Shortcut System
#
# Registers and manages keyboard bindings.
# Each page registers its own handlers.
#
# Part of the Android Toolkit Dashboard.

# Key codes (from raw terminal input)
KEY_UP=$'\033[A'
KEY_DOWN=$'\033[B'
KEY_RIGHT=$'\033[C'
KEY_LEFT=$'\033[D'
KEY_ENTER=$'\n'
KEY_ESC=$'\033'
KEY_TAB=$'\t'
KEY_BACKSPACE=$'\177'
KEY_SPACE=' '

# Function keys
KEY_F1=$'\033OP'
KEY_F2=$'\033OQ'
KEY_F3=$'\033OR'
KEY_F4=$'\033OS'
KEY_F5=$'\033[15~'
KEY_F6=$'\033[17~'
KEY_F7=$'\033[18~'
KEY_F8=$'\033[19~'
KEY_F9=$'\033[20~'
KEY_F10=$'\033[21~'
KEY_F11=$'\033[23~'
KEY_F12=$'\033[24~'

# Special sequences
KEY_HOME=$'\033[H'
KEY_END=$'\033[F'
KEY_PGUP=$'\033[5~'
KEY_PGDN=$'\033[6~'
KEY_DEL=$'\033[3~'
KEY_INS=$'\033[2~'

KEY_CTRL_A=$'\001'
KEY_CTRL_C=$'\003'
KEY_CTRL_D=$'\004'
KEY_CTRL_E=$'\005'
KEY_CTRL_F=$'\006'
KEY_CTRL_L=$'\014'
KEY_CTRL_R=$'\022'
KEY_CTRL_U=$'\025'
KEY_CTRL_W=$'\027'
KEY_CTRL_X=$'\030'

# Shorter aliases for common keys
KEY_Q='q'
KEY_R='r'
KEY_S='s'
KEY_SLASH='/'

##############################################
# Read a single keypress from stdin.
# Handles multi-byte escape sequences for
# arrow keys, function keys, etc.
# Outputs: the key sequence
shortcuts_read_key() {
    # Save terminal settings
    local old_settings
    old_settings="$(stty -g 2>/dev/null || echo "")"

    # Set raw mode
    stty raw -echo 2>/dev/null || true

    local key
    # Read first byte
    key="$(dd bs=1 count=1 2>/dev/null)"

    # If escape, check for multi-byte sequence
    if [[ "$key" == $'\033' ]]; then
        local extra
        # Try to read more bytes with 5ms timeout
        if extra="$(dd bs=1 count=1 2>/dev/null)"; then
            key+="$extra"
            # For '[' prefix (CSI sequences like arrows, F1-F4)
            if [[ "$extra" == '[' ]]; then
                if extra="$(dd bs=1 count=1 2>/dev/null)"; then
                    key+="$extra"
                    # For F1-F4: ESC [ O P/Q/R/S -> ESC O P/Q/R/S
                    # For 3-byte sequences like ESC [ A (up)
                    # For potential 4-byte sequences like ESC [ 1 5 ~ (F5)
                    if [[ "$extra" == [0-9] ]]; then
                        local more
                        more="$(dd bs=1 count=1 2>/dev/null)"
                        key+="$more"
                        if [[ "$more" == '~' ]]; then
                            # F5-F12: ESC [ 1 5 ~ etc. Complete
                            :
                        elif [[ "$more" == ';' ]]; then
                            # ESC [ 1 ; 2 R etc. Read two more
                            key+="$(dd bs=1 count=2 2>/dev/null)"
                        fi
                    fi
                fi
            elif [[ "$extra" == 'O' ]]; then
                # ESC O P/Q/R/S (F1-F4 alternative encoding)
                extra="$(dd bs=1 count=1 2>/dev/null)"
                key+="$extra"
            fi
        fi
    fi

    # Restore terminal settings
    if [[ -n "$old_settings" ]]; then
        stty "$old_settings" 2>/dev/null || true
    fi

    echo "$key"
}

##############################################
# Wait for any keypress (blocking).
shortcuts_wait_key() {
    shortcuts_read_key > /dev/null 2>&1
}
