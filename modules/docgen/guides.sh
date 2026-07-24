#!/data/data/com.termux/files/usr/bin/bash
#
# docgen/guides.sh — Guide documentation generators (migration, troubleshooting, FAQ, module)
# Part of the Android Toolkit.

docgen_migration_guide() {
    local output_dir="$1"
    local file="${output_dir}/guides/migration-guide.md"

    log_info "Generating migration guide..."

    cat > "$file" << 'MIGRATION'
# Migration Guide

## v3.x → v4.0

### Summary

v4.0 is a major stabilization release. All v3.x commands continue to work.

### What Changed

- **Plugin SDK**: Updated from v2.0 to v3.0. Plugins using the old SDK continue
  to work. New certification metadata is optional but recommended for all plugins.
- **New Libraries**: `lib/api.sh`, `lib/commands.sh`, `lib/capability_graph.sh`,
  `lib/events.sh`, `lib/json_output.sh`, `lib/dependencies.sh`, `lib/json_schema.sh`
  are all backward-compatible additions.
- **New Modules**: `devices.sh`, `docgen.sh`, `compare.sh`, `profile_manager.sh`,
  `watch.sh`, `release_check.sh`, `packages_analysis.sh`, `performance_test.sh`
  — all optional additions.

### Breaking Changes

None. All existing commands, profiles, and plugins continue to work.

### Deprecations

None in this release.

### Recommended Actions

1. Run `toolkit.sh --release-check` to validate your installation
2. Run `toolkit.sh --docgen` to generate updated documentation
3. Update plugins to declare `plugin_min_toolkit="4.0.0"`
4. Run `toolkit.sh --deps-check` to verify all dependencies

## v2.x → v3.0

### Summary

v3.0 introduced plugin support, OEM framework, settings database, and rollback.

### What Changed

- Plugin system added (`plugins/` directory)
- OEM framework validates settings against device manufacturer
- Settings database (`lib/settings-db.json`) provides canonical defaults
- Rollback engine tracks all changes
- New commands: `--doctor`, `--rollback`, `--benchmark`, `--plugin`

### Breaking Changes

Config files should be regenerated from templates.

## v1.x → v2.0

### Summary

v2.0 added capability detection, settings database, rollback, and comprehensive testing.
MIGRATION

    log_success "  guides/migration-guide.md"
}

##############################################
# Generate troubleshooting guide.
# Arguments:
#   $1: output directory
##############################################
docgen_troubleshooting_guide() {
    local output_dir="$1"
    local file="${output_dir}/guides/troubleshooting.md"

    log_info "Generating troubleshooting guide..."

    cat > "$file" << 'TROUBLE'
# Troubleshooting Guide

## ADB Issues

### "No ADB device found"
1. Verify USB debugging is enabled in Developer Options
2. Run `adb devices` to check connectivity
3. Try `adb kill-server && adb start-server`
4. For wireless: `adb connect <ip>:5555`

### "ADB command not found"
- Install platform-tools: `pkg install android-tools`

## Shizuku Issues

### "rish not found"
1. Install Shizuku from Google Play
2. Enable Shizuku in Developer Options
3. Run `adb shell sh /data/local/tmp/shizu...` to start
4. Install rish: Download from Shizuku settings → Terminal

### Permission denied
- Ensure Shizuku is running
- Check that rish has execute permissions

## Settings Application

### "Setting write failed"
1. Check namespace (global/secure/system)
2. Verify backend (ADB/rish) has sufficient permissions
3. Some settings require root and cannot be changed
4. Use `--dry-run` first to preview changes

### "Setting reverted after reboot"
1. Some Samsung One UI settings reset on boot
2. Use `--schedule` to re-apply settings after boot
3. Consider Termux:Boot for persistent settings

## Benchmark

### "Benchmark score seems low"
1. Close background apps
2. Ensure device is not thermally throttling
3. Run `--enhanced-benchmark 5` for median values
4. Compare against similar devices in history

## Plugin Issues

### "Plugin not loaded"
1. Check syntax: `bash -n plugins/<name>.sh`
2. Verify Android/OEM compatibility
3. Check dependencies with `plugin_dependencies()`
4. Run `toolkit.sh --release-check` for diagnostics

### "Plugin command not found"
1. Ensure plugin declares `plugin_commands()`
2. Verify plugin loads: check `--plugin list`

## Performance

### "Toolkit is slow"
1. First run initializes caches — subsequent runs are faster
2. Benchmark and report generation take time on large device configs
3. Use `--status` for quick overview instead of `--report`

### "High memory usage"
1. Report generation loads multiple modules
2. Plugin system caches plugin metadata
3. Individual commands use minimal memory
TROUBLE

    log_success "  guides/troubleshooting.md"
}

##############################################
# Generate FAQ.
# Arguments:
#   $1: output directory
##############################################
docgen_faq() {
    local output_dir="$1"
    local file="${output_dir}/guides/faq.md"

    log_info "Generating FAQ..."

    cat > "$file" << 'FAQ'
# Frequently Asked Questions

## General

### What is the Android Toolkit?
A non-root optimization and diagnostics toolkit for modern Android devices.
Supports ADB and Shizuku backends for privileged operations.

### Does it require root?
No. All operations work via ADB or Shizuku (rish). Root is never required.

### Which devices are supported?
Android 13+ on Samsung, Google Pixel, OnePlus, Nothing, Xiaomi, Motorola,
Oppo, and Vivo devices.

### Is it safe?
Yes. All settings changes are recorded in a rollback journal. Use `--dry-run`
to preview changes before applying them.

## Commands

### How do I get help?
Run `toolkit.sh --help` for command overview or `toolkit.sh --about` for
version information.

### How do I backup my settings?
`toolkit.sh --backend adb --backup` creates a full settings and packages backup.

### How do I restore a backup?
`toolkit.sh --backend adb --restore <backup-file>`

### How do I benchmark my device?
`toolkit.sh --benchmark` for a single run
`toolkit.sh --enhanced-benchmark 5` for repeated runs with median/variance

### How do I check for updates?
`toolkit.sh --update [stable|beta|nightly]`

## Profiles

### What profiles are available?
- `balanced` — Default optimization
- `performance` — Maximum performance
- `powersave` — Battery efficient
- `light` — Samsung light optimizations

### Can I create custom profiles?
Yes. Use `--profile-manager clone` to copy an existing profile, then
`--profile-manager edit` to customize it.

## Multiple Devices

### How do I use multiple devices?
Use `--device <serial>` to target a specific device.
Use `--all-devices` to run commands on all connected devices.
Run `toolkit.sh devices` to list connected devices.

## Plugins

### How do I write a plugin?
See the Plugin API Reference (`plugin-api.md`) or the example plugin in
`plugins/00-example.sh`.

### Can plugins break the toolkit?
Plugins run in a sandboxed environment. A failing plugin will not crash
the toolkit. Use `--release-check` to validate plugins before deployment.

## Troubleshooting

### A setting didn't apply
Check the rollback journal with `--rollback list`.
Verify the setting is writable on your device/OEM combination.

### The toolkit says "Backend not available"
Ensure ADB is installed and a device is connected, or Shizuku is running
with rish available.

## Development

### How do I contribute?
See CONTRIBUTING.md for guidelines. All contributions must pass syntax
checks (`bash -n`) and follow existing code patterns.

### How do I run tests?
`bash tests/run_tests.sh` for functional tests
`bats tests/bats/` for BATS unit tests
FAQ

    log_success "  guides/faq.md"
}

##############################################
# Generate module developer guide.
# Arguments:
#   $1: output directory
##############################################
docgen_module_guide() {
    local output_dir="$1"
    local file="${output_dir}/guides/module-guide.md"

    log_info "Generating module guide..."

    cat > "$file" << 'MODGUIDE'
# Module Developer Guide

## Overview

Modules extend the toolkit's functionality. Each module is a standalone
shell script in `modules/` that can be loaded on demand.

## Module Structure

```bash
#!/data/data/com.termux/files/usr/bin/bash
#
# mymodule.sh — Description of the module
#
# Part of the Android Toolkit.

# ── Public Functions ─────────────────────────

# Module dispatch — called from toolkit.sh
mymodule_run() {
    local action="${1:-}"
    case "$action" in
        info)  mymodule_info ;;
        *)     echo "Usage: mymodule run info" ;;
    esac
}

# ── Private Helpers ──────────────────────────

_mymodule_helper() {
    log_debug "Helper function called"
}
```

## Adding a New Module

1. Create `modules/yourmodule.sh` following the template above.
2. Add dispatch in `_main()`:
   ```bash
   yourmodule)
       _load_module "yourmodule"
       yourmodule_run "${ACTION_ARGS[@]}"
       ;;
   ```
3. Generate docs with `--docgen`.
4. Add BATS tests in `tests/bats/`.
5. Submit for certfication with `--plugin-certify`.

## Best Practices

- Always guard device-facing operations with backend availability checks.
- Use `log_*` functions instead of `echo` for consistent output formatting.
- Support `--json` output via `JSON_OUTPUT` checks.
- Use `rollback_begin`/`rollback_record`/`rollback_close` for reversible operations.
- Handle errors gracefully — never leave device in an inconsistent state.
MODGUIDE

    log_success "  guides/module-guide.md"
}
