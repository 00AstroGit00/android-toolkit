#!/data/data/com.termux/files/usr/bin/bash
#
# samsung/info.sh — Samsung/One UI detection and info reporting
#
# Provides samsung_info() for reporting Samsung-specific device details.
#
# Part of the Android Toolkit.

##############################################
# Report Samsung/One UI specific device info.
##############################################
samsung_info() {
    if ! detect_is_samsung; then
        log_info "Not a Samsung device — skipping Samsung-specific checks"
        return 0
    fi

    local oneui_version
    oneui_version="$(cap_get CAP_ONEUI_VERSION 2>/dev/null || echo "unknown")"
    local android_sdk
    android_sdk="$(cap_get CAP_ANDROID_SDK 2>/dev/null || echo "unknown")"

    log_section "Samsung / One UI"

    utils_print_kv "One UI Version" "$oneui_version"

    # Determine Game Controller app (varies by One UI version)
    local game_app="com.samsung.android.game.gos"
    if backend_package_installed "com.samsung.android.game.gamehome" 2>/dev/null; then
        game_app="com.samsung.android.game.gamehome"
    fi
    utils_print_kv "Game Service" "$(backend_package_installed "$game_app" 2>/dev/null && echo "Installed ($game_app)" || echo "Not found")"

    utils_print_kv "Game Driver" "$(backend_package_installed "com.samsung.android.game.gametools" 2>/dev/null && echo "Installed" || echo "Not found")"
    utils_print_kv "Game Optimizing Service" "$(backend_package_installed "com.samsung.android.game.gos" 2>/dev/null && echo "Installed" || echo "Not found")"
    utils_print_kv "AR Zone" "$(backend_package_installed "com.samsung.android.arzone" 2>/dev/null && echo "Installed" || echo "Not found")"

    # Light Performance Profile (One UI 7+ / Android 16+)
    if [[ "$oneui_version" != "unknown" ]] && [[ "${oneui_version%.*}" -ge 7 ]] 2>/dev/null; then
        if android_sdk_at_least 36; then
            local light_perf
            light_perf="$(backend_getprop "persist.sys.light_perf" 2>/dev/null || echo "unknown")"
            utils_print_kv "Light Performance Profile" "$light_perf"
        fi
    fi

    # RAM Plus (One UI 5+ feature)
    local ram_plus
    ram_plus="$(backend_settings_get "global" "zram_size" 2>/dev/null || echo "default")"
    utils_print_kv "RAM Plus (ZRAM)" "$ram_plus"

    # Refresh rate capabilities
    local peak_refresh
    peak_refresh="$(backend_getprop "debug.sf.peak_refresh_rate" 2>/dev/null || echo "unknown")"
    local min_refresh
    min_refresh="$(backend_getprop "debug.sf.min_refresh_rate" 2>/dev/null || echo "unknown")"
    utils_print_kv "Peak Refresh Rate" "$peak_refresh Hz"
    utils_print_kv "Min Refresh Rate" "$min_refresh Hz"

    # Multicore scheduler
    local multi_core
    if backend_package_installed "com.samsung.android.rubin.app" 2>/dev/null; then
        multi_core="Available"
    else
        multi_core="Not available"
    fi
    utils_print_kv "Multi-core Scheduler" "$multi_core"

    # Support status
    local support_models=("SM-S918B" "SM-S928B" "SM-S938B" "SM-S931B" "SM-S936B" "SM-S937B" "SM-S911B" "SM-S921B")
    local model
    model="$(cap_get CAP_MODEL 2>/dev/null || echo "unknown")"
    local supported=false
    for sm in "${support_models[@]}"; do
        if [[ "$model" == "$sm" ]]; then
            supported=true
            break
        fi
    done
    if $supported; then
        utils_print_kv "Support Status" "✅ Full support"
    else
        utils_print_kv "Support Status" "⚠️ General support (${model})"
    fi
}
