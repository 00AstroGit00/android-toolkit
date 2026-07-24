#!/data/data/com.termux/files/usr/bin/bash
#
# loader.sh — Dashboard Module Loader
#
# Sources all dashboard modules in dependency order.
# Called from toolkit.sh to initialize the dashboard.
#
# Part of the Android Toolkit Dashboard.

_dashboard_load_modules() {
    local dash_dir="${ANDROID_TOOLKIT_ROOT_DIR}/modules/dashboard"

    # Dependency-ordered load:
    # 1. Core engine (no dependencies)
    source "${dash_dir}/renderer.sh"      || { log_error "renderer.sh load failed"; return 1; }
    source "${dash_dir}/themes.sh"        || { log_error "themes.sh load failed"; return 1; }
    source "${dash_dir}/shortcuts.sh"     || { log_error "shortcuts.sh load failed"; return 1; }

    # 2. Data & menus (depends on core)
    source "${dash_dir}/status.sh"        || { log_error "status.sh load failed"; return 1; }
    source "${dash_dir}/menus.sh"         || { log_error "menus.sh load failed"; return 1; }

    # 3. UI components (depends on core + data)
    source "${dash_dir}/header.sh"        || { log_error "header.sh load failed"; return 1; }
    source "${dash_dir}/sidebar.sh"       || { log_error "sidebar.sh load failed"; return 1; }
    source "${dash_dir}/footer.sh"        || { log_error "footer.sh load failed"; return 1; }
    source "${dash_dir}/notifications.sh" || { log_error "notifications.sh load failed"; return 1; }
    source "${dash_dir}/widgets.sh"       || { log_error "widgets.sh load failed"; return 1; }

    # 4. Audit trail & notifications (needed by other modules)
    source "${dash_dir}/audit_trail.sh"       || { log_error "audit_trail.sh load failed"; return 1; }

    # 5. Phase 3 — Enterprise Console modules (depends on core + UI + audit)
    source "${dash_dir}/multi_device.sh"      || { log_error "multi_device.sh load failed"; return 1; }
    source "${dash_dir}/device_compare.sh"    || { log_error "device_compare.sh load failed"; return 1; }
    source "${dash_dir}/ai_assistant.sh"      || { log_error "ai_assistant.sh load failed"; return 1; }
    source "${dash_dir}/terminal.sh"          || { log_error "terminal.sh load failed"; return 1; }
    source "${dash_dir}/automation.sh"        || { log_error "automation.sh load failed"; return 1; }
    source "${dash_dir}/diagnostics.sh"       || { log_error "diagnostics.sh load failed"; return 1; }
    source "${dash_dir}/security_center.sh"   || { log_error "security_center.sh load failed"; return 1; }
    source "${dash_dir}/perf_monitor.sh"      || { log_error "perf_monitor.sh load failed"; return 1; }
    source "${dash_dir}/plugin_center.sh"     || { log_error "plugin_center.sh load failed"; return 1; }
    source "${dash_dir}/doc_browser.sh"       || { log_error "doc_browser.sh load failed"; return 1; }
    source "${dash_dir}/session_manager.sh"   || { log_error "session_manager.sh load failed"; return 1; }
    source "${dash_dir}/enterprise_settings.sh" || { log_error "enterprise_settings.sh load failed"; return 1; }

    # 4b. Phase 4 — Autonomous Operations & Intelligence (depends on Phase 3)
    source "${dash_dir}/event_bus.sh"          || { log_error "event_bus.sh load failed"; return 1; }
    source "${dash_dir}/digital_twin.sh"       || { log_error "digital_twin.sh load failed"; return 1; }
    source "${dash_dir}/timeline.sh"           || { log_error "timeline.sh load failed"; return 1; }
    source "${dash_dir}/health_intel.sh"       || { log_error "health_intel.sh load failed"; return 1; }
    source "${dash_dir}/predictive.sh"         || { log_error "predictive.sh load failed"; return 1; }
    source "${dash_dir}/recommendations.sh"    || { log_error "recommendations.sh load failed"; return 1; }
    source "${dash_dir}/fleet.sh"              || { log_error "fleet.sh load failed"; return 1; }
    source "${dash_dir}/policies.sh"           || { log_error "policies.sh load failed"; return 1; }
    source "${dash_dir}/report_studio.sh"      || { log_error "report_studio.sh load failed"; return 1; }
    source "${dash_dir}/system_map.sh"         || { log_error "system_map.sh load failed"; return 1; }
    source "${dash_dir}/workflow_recorder.sh"  || { log_error "workflow_recorder.sh load failed"; return 1; }
    source "${dash_dir}/recovery_center.sh"    || { log_error "recovery_center.sh load failed"; return 1; }
    source "${dash_dir}/knowledge_base.sh"     || { log_error "knowledge_base.sh load failed"; return 1; }
    source "${dash_dir}/perf_profiler.sh"      || { log_error "perf_profiler.sh load failed"; return 1; }
    source "${dash_dir}/plugin_sandbox.sh"     || { log_error "plugin_sandbox.sh load failed"; return 1; }
    source "${dash_dir}/profiles.sh"           || { log_error "profiles.sh load failed"; return 1; }
    source "${dash_dir}/offline_mode.sh"       || { log_error "offline_mode.sh load failed"; return 1; }

    # 5. Pages & main controller (depends on all above)
    source "${dash_dir}/pages.sh"         || { log_error "pages.sh load failed"; return 1; }
    source "${dash_dir}/dashboard.sh"     || { log_error "dashboard.sh load failed"; return 1; }

    return 0
}

# Load and start the dashboard
dashboard_launch() {
    _dashboard_load_modules || return 1
    dashboard_register_all_pages
    dashboard_run
}
