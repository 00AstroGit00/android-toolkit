#!/data/data/com.termux/files/usr/bin/bash
#
# samsung.sh — Samsung/One UI module loader
#
# Loads Samsung submodules from modules/samsung/.
# Provides unified access to all Samsung-specific functions.
#
# Splitting rationale (v4.2.0 refactoring):
#   Original file was 919 lines. Split into 4 submodules:
#     modules/samsung/info.sh       — device info reporting
#     modules/samsung/optimize.sh   — optimization functions
#     modules/samsung/bloatware.sh  — bloatware listing
#     modules/samsung/light.sh      — light optimization profile
#
# All public functions remain available at the module level:
#   samsung_info()
#   samsung_optimize()
#   samsung_list_bloatware()
#   samsung_apply_light_optimizations()
#
# Private functions (_samsung_*) are defined in optimize.sh
# and expected by light.sh. They are NOT for external use.
#
# Part of the Android Toolkit.

SAMSUNG_DIR="${ANDROID_TOOLKIT_ROOT_DIR}/modules/samsung"

for _sub in info.sh optimize.sh bloatware.sh light.sh; do
    _sub_path="${SAMSUNG_DIR}/${_sub}"
    if [[ -f "$_sub_path" ]]; then
        source "$_sub_path"
    else
        log_warn "Samsung submodule not found: $_sub_path"
    fi
done
unset _sub _sub_path
