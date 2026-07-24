#!/data/data/com.termux/files/usr/bin/bash
#
# security_center.sh — Security Center
#
# Comprehensive security assessment with:
#   - Root detection
#   - USB debugging status
#   - Developer options status
#   - Lock screen status
#   - Encryption status
#   - Verified boot
#   - Security patch level
#   - Play Integrity (if available)
#   - OEM lock status
#   - Security score and recommendations
#
# Part of the Android Toolkit Dashboard.

SECURITY_SCORE=0
SECURITY_FINDINGS=""

##############################################
# Assess device security posture.
security_assess() {
    local report=""
    local score=100

    report+="═══ Security Assessment ═══"$'\n'

    # 1. Root detection
    local root="$(status_get root 2>/dev/null || echo "false")"
    report+=$'\n'"  Root Status: ${root}"
    if [[ "$root" == "true" ]]; then
        report+=" 🔴 WARNING"
        score=$(( score - 30 ))
    else
        report+=" ✓ SECURE"
    fi

    # 2. USB Debugging
    local usb_debug
    usb_debug="$(backend_exec settings get global adb_enabled 2>/dev/null || echo "?")"
    report+=$'\n'"  USB Debugging: ${usb_debug}"
    if [[ "$usb_debug" == "1" ]]; then
        report+=" ⚠ ENABLED"
        score=$(( score - 10 ))
    elif [[ "$usb_debug" == "0" ]]; then
        report+=" ✓ DISABLED"
    else
        report+=" ?"
    fi

    # 3. Developer Options
    local dev_opts
    dev_opts="$(backend_exec settings get global development_settings_enabled 2>/dev/null || echo "?")"
    report+=$'\n'"  Developer Options: ${dev_opts}"
    if [[ "$dev_opts" == "1" ]]; then
        report+=" ⚠ ENABLED"
        score=$(( score - 5 ))
    elif [[ "$dev_opts" == "0" ]]; then
        report+=" ✓ DISABLED"
    fi

    # 4. Unknown Sources
    local unknown_sources
    unknown_sources="$(backend_exec settings get global install_non_market_apps 2>/dev/null || echo "?")"
    report+=$'\n'"  Unknown Sources: ${unknown_sources}"
    if [[ "$unknown_sources" == "1" ]]; then
        report+=" ⚠ ENABLED"
        score=$(( score - 10 ))

    elif [[ "$unknown_sources" == "0" ]]; then
        report+=" ✓ DISABLED"
    fi

    # 5. Lock screen
    local lock_screen
    lock_screen="$(backend_exec dumpsys lock_settings 2>/dev/null | grep -i 'lock\|password\|pattern\|pin' | head -1 || echo "?")"
    report+=$'\n'"  Lock Screen: "
    if echo "$lock_screen" | grep -qi "none\|disabled"; then
        report+=" ⚠ NONE"
        score=$(( score - 25 ))
    elif [[ "$lock_screen" != "?" ]]; then
        report+=" ✓ ENABLED"
    else
        report+=" ?"
    fi

    # 6. Encryption
    local encryption
    encryption="$(backend_exec getprop ro.crypto.state 2>/dev/null || echo "?")"
    report+=$'\n'"  Encryption: ${encryption}"
    if echo "$encryption" | grep -qi "encrypted"; then
        report+=" ✓ SECURE"
    else
        report+=" ⚠ NOT ENCRYPTED"
        score=$(( score - 20 ))
    fi

    # 7. Verified Boot
    local vbmeta
    vbmeta="$(backend_exec getprop ro.boot.verifiedbootstate 2>/dev/null || echo "?")"
    report+=$'\n'"  Verified Boot: ${vbmeta}"
    if echo "$vbmeta" | grep -qi "green\|verified"; then
        report+=" ✓ SECURE"
    elif echo "$vbmeta" | grep -qi "orange\|yellow"; then
        report+=" ⚠ WARNING"
        score=$(( score - 10 ))
    fi

    # 8. Security Patch
    local patch="$(status_get security_patch 2>/dev/null || echo "?")"
    report+=$'\n'"  Security Patch: ${patch}"
    if [[ "$patch" != "?" ]]; then
        # Extract year
        local patch_year="${patch:0:4}"
        if [[ -n "$patch_year" && "$patch_year" -ge 2024 ]]; then
            report+=" ✓ RECENT"
        else
            report+=" ⚠ OLD"
            score=$(( score - 10 ))
        fi
    fi

    # 9. SELinux
    local selinux="$(status_get selinux 2>/dev/null || echo "?")"
    report+=$'\n'"  SELinux: ${selinux}"
    if echo "$selinux" | grep -qi "enforcing"; then
        report+=" ✓ ENFORCING"
    else
        report+=" ⚠ PERMISSIVE"
        score=$(( score - 15 ))
    fi

    # 10. OEM Lock
    local oem_lock
    oem_lock="$(backend_exec getprop ro.oem_unlock_supported 2>/dev/null || echo "?")"
    report+=$'\n'"  OEM Unlock: ${oem_lock}"

    [[ "$score" -lt 0 ]] && score=0
    SECURITY_SCORE=$score
    SECURITY_FINDINGS="$report"

    # Generate recommendations
    report+=$'\n\n'"═══ Recommendations ═══"
    if [[ "$root" == "true" ]]; then
        report+=$'\n'"  🔴 Device is rooted — this reduces security significantly"
    fi
    if [[ "$usb_debug" == "1" ]]; then
        report+=$'\n'"  ⚠ Disable USB Debugging when not in use"
    fi
    if [[ "$unknown_sources" == "1" ]]; then
        report+=$'\n'"  ⚠ Disable installation from unknown sources"
    fi
    if echo "$lock_screen" | grep -qi "none\|disabled"; then
        report+=$'\n'"  🔴 Set a lock screen PIN or password"
    fi
    if ! echo "$encryption" | grep -qi "encrypted"; then
        report+=$'\n'"  🔴 Enable device encryption in Settings > Security"
    fi
    report+=$'\n'"  Run full audit: toolkit.sh --audit"
    report+=$'\n'"  Security hardening: toolkit.sh --security-harden"

    SECURITY_FINDINGS="$report"
    audit_record "Security" "assess" "" "score: $score"
}

##############################################
# Render security center.
_page_render_security_center() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Security Center'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Score: %d/100' "$SECURITY_SCORE"
    renderer_reset

    local row=$(( top + 2 ))
    local col="$left"

    # Score indicator
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get muted)"
    printf 'Security Score: '
    renderer_reset
    if [[ "$SECURITY_SCORE" -ge 80 ]]; then
        renderer_fg_256 "$(theme_get success)"
        local bar="████████░░"
    elif [[ "$SECURITY_SCORE" -ge 50 ]]; then
        renderer_fg_256 "$(theme_get warning)"
        local bar="█████░░░░░"
    else
        renderer_fg_256 "$(theme_get error)"
        local bar="██░░░░░░░░"
    fi
    renderer_bold
    printf '%s %d/100' "$bar" "$SECURITY_SCORE"
    renderer_reset
    ((row += 2))

    # Quick actions
    local actions=(
        "1" "Run Full Assessment"
        "2" "Recommendations"
        "3" "Run Audit"
        "4" "Security Hardening"
    )
    renderer_cursor_goto "$row" "$col"
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

    # Findings
    if [[ -n "$SECURITY_FINDINGS" ]]; then
        local box_h=$(( height - (row - top) - 2 ))
        [[ "$box_h" -lt 5 ]] && box_h=5
        renderer_draw_box "$row" "$col" "$box_h" "$width" "Assessment"
        local content_row=$(( row + 1 ))
        local content_col=$(( col + 2 ))
        local line_count=0
        while IFS= read -r line; do
            renderer_cursor_goto "$content_row" "$content_col"
            if [[ "$line" =~ ^═══ ]]; then
                renderer_bold
                renderer_fg_256 "$(theme_get accent)"
            elif echo "$line" | grep -q "🔴\|WARNING\|OLD\|PERMISSIVE\|NOT ENCRYPTED\|NONE\|ENABLED"; then
                renderer_fg_256 "$(theme_get error)"
            elif echo "$line" | grep -q "✓\|SECURE\|RECENT\|ENFORCING\|DISABLED"; then
                renderer_fg_256 "$(theme_get success)"
            else
                renderer_fg_256 "$(theme_get fg)"
            fi
            printf '%-*s' "$((width - 4))" "${line:0:$((width-4))}"
            renderer_reset
            ((content_row++))
            ((line_count++))
            [[ "$line_count" -ge "$box_h" ]] && break
        done <<< "$SECURITY_FINDINGS"
    fi
}

_page_key_security_center() {
    local key="$1"
    case "$key" in
        "1") security_assess ;;
        "2")
            if [[ -n "$SECURITY_FINDINGS" ]]; then
                local recs
                recs="$(echo "$SECURITY_FINDINGS" | grep -A 20 "Recommendations")"
                menu_textbox "Recommendations" "$recs"
            else
                notify_push "Run a full assessment first (press 1)" "warning"
            fi
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "3")
            _load_module "audit" 2>/dev/null || true
            local output
            output="$(audit_run 2>&1 | head -50)"
            menu_textbox "Security Audit" "$output"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "4")
            _load_module "security_harden" 2>/dev/null || true
            local output
            output="$(security_harden_scan 2>&1 | head -50 || echo "Module loaded.")"
            menu_textbox "Security Hardening" "$output"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
    esac
}

# Run initial assessment on load
security_assess
