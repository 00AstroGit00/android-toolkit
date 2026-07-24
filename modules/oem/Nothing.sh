#!/data/data/com.termux/files/usr/bin/bash
#
# Nothing.sh — Nothing OS OEM module
#
# Part of the Android Toolkit.

oem_nothing_name="Nothing"
oem_nothing_version="1.0.0"
oem_nothing_supported_android="33 34 35 36"

oem_nothing_register() {
    log_debug "Nothing OEM registered"
}

oem_nothing_optimize() {
    log_debug "Nothing OEM — no specific optimizations"
}

oem_nothing_validate_setting() {
    return 0
}
