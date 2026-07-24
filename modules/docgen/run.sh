#!/data/data/com.termux/files/usr/bin/bash
#
# docgen/run.sh — Documentation generator dispatcher
# Sources all docgen submodules and provides docgen_run().
# Part of the Android Toolkit.


docgen_run() {
    local output_dir="${1:-${ANDROID_TOOLKIT_ROOT_DIR}/docs}"

    if [[ -z "$output_dir" ]]; then
        output_dir="${ANDROID_TOOLKIT_ROOT_DIR}/docs"
    fi

    mkdir -p "$output_dir/guides" 2>/dev/null || true

    log_section "Documentation Generation"
    log_info "Output directory: $output_dir"

    docgen_command_reference "$output_dir"
    docgen_settings_reference "$output_dir"
    docgen_changelog_snippet "$output_dir"
    docgen_plugin_api "$output_dir"
    docgen_man_page "$output_dir"
    docgen_architecture "$output_dir"
    docgen_migration_guide "$output_dir/guides"
    docgen_troubleshooting_guide "$output_dir/guides"
    docgen_faq "$output_dir/guides"
    docgen_module_guide "$output_dir/guides"

    log_success "Documentation generated in $output_dir"
    ls -lh "$output_dir"/*.md "$output_dir"/*.1 2>/dev/null | sed "s/^/    /"
    ls -lh "${output_dir}/guides/"*.md 2>/dev/null | sed "s/^/    /"
}

