#!/data/data/com.termux/files/usr/bin/bash
#
# Oppo.sh — Oppo ColorOS OEM module (also covers Realme)
#
# Part of the Android Toolkit.

oem_oppo_name="Oppo"
oem_oppo_version="1.0.0"
oem_oppo_supported_android="33 34 35 36"

oem_oppo_register() {
    log_debug "Oppo OEM registered"
}

oem_oppo_optimize() {
    log_debug "Oppo OEM — no specific optimizations"
}

oem_oppo_validate_setting() {
    return 0
}
