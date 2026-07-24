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

    # 4. Pages & main controller (depends on all above)
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
