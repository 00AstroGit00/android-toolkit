#!/data/data/com.termux/files/usr/bin/bash
#
# docgen.sh — Documentation generator module
#
# Generates comprehensive documentation for the Android Toolkit.
# Split into submodules in modules/docgen/ for maintainability.
#
# Submodules:
#   modules/docgen/run.sh          — dispatcher (docgen_run)
#   modules/docgen/reference.sh    — CLI, settings, changelog references
#   modules/docgen/plugin-api.sh   — Plugin API docs
#   modules/docgen/manpage.sh      — Man page
#   modules/docgen/architecture.sh — Architecture docs
#   modules/docgen/guides.sh       — Migration, troubleshooting, FAQ, module guides
#
# All public functions remain available at the module level.
#
# Part of the Android Toolkit.

DOCGEN_DIR="${ANDROID_TOOLKIT_ROOT_DIR}/modules/docgen"

for _sub in run.sh reference.sh plugin-api.sh manpage.sh architecture.sh guides.sh; do
    _sub_path="${DOCGEN_DIR}/${_sub}"
    if [[ -f "$_sub_path" ]]; then
        source "$_sub_path"
    else
        log_warn "Documentation submodule not found: $_sub_path"
    fi
done
unset _sub _sub_path
