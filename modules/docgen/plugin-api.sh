#!/data/data/com.termux/files/usr/bin/bash
#
# docgen/plugin-api.sh — Plugin API documentation generator
# Part of the Android Toolkit.

docgen_plugin_api() {
    local output_dir="$1"
    local file="${output_dir}/plugin-api.md"

    log_info "Generating plugin API reference..."

    cat > "$file" << 'PLUGIN_API'
# Plugin API v2.1 Reference

## Overview

The Android Toolkit Plugin SDK allows extending the toolkit with custom
functionality. Plugins are bash scripts loaded from the `plugins/` directory.

## Lifecycle

1. **Load** — `plugin_load_all()` sources each plugin and validates it.
2. **Register** — `plugin_register()` is called once on load.
3. **Pre-run** — `plugin_pre_run()` is called before execution.
4. **Run** — `plugin_run()` is the main entry point.
5. **Post-run** — `plugin_post_run()` is called after execution.
6. **Cleanup** — `plugin_cleanup()` is called on exit or error.

## Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `plugin_name` | Human-readable name | `"My Plugin"` |
| `plugin_version` | Semver string | `"1.0.0"` |
| `plugin_supported_oems` | Space-separated OEM list or "all" | `"samsung google"` |
| `plugin_supported_android` | Space-separated SDK list or "all" | `"33 34 35"` |

## Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `plugin_priority` | Numeric priority (lower = earlier) | `50` |

## Functions

### Core (v2.0)

#### `plugin_run()`
Main entry point called when the plugin is executed.
```bash
plugin_run() {
    local arg1="$1"
    # ... implementation
}
```

#### `plugin_register()`
Called once at load time. Use to initialize state.
```bash
plugin_register() {
    log_info "My plugin loaded!"
}
```

#### `plugin_pre_run()`
Called before `plugin_run()`. Can set up prerequisites.
```bash
plugin_pre_run() {
    log_debug "Preparing..."
}
```

#### `plugin_post_run()`
Called after `plugin_run()` with the exit code.
```bash
plugin_post_run() {
    local exit_code="$1"
    log_debug "Finished with code $exit_code"
}
```

#### `plugin_cleanup()`
Called on exit or error. Use to clean up temporary files.
```bash
plugin_cleanup() {
    rm -f /tmp/my_plugin_*
}
```

#### `plugin_config()`
Return default configuration as KEY=VALUE lines.
```bash
plugin_config() {
    cat << 'EOF'
INTERVAL=30
ENABLE_FEATURE=true
EOF
}
```

#### `plugin_dependencies()`
Return space-separated names of required plugins.
```bash
plugin_dependencies() {
    echo "base-plugin"
}
```

### Enhanced (v2.1)

#### `plugin_config_schema()`
Return JSON Schema for config validation (minimal format).
```bash
plugin_config_schema() {
    cat << 'EOF'
{
  "INTERVAL": "integer",
  "ENABLE_FEATURE": "boolean",
  "LOG_FILE": "string|required"
}
EOF
}
```

Supported types: `integer`, `boolean`, `string`, `string|required`.

#### `plugin_commands()`
Register custom CLI commands. Each line: `command_name:description`
```bash
plugin_commands() {
    cat << 'EOF'
myplugin-do:Perform a custom action
myplugin-status:Check plugin status
EOF
}
```

#### `plugin_on_event()`
Respond to internal events. Receives event name and JSON payload.
```bash
plugin_on_event() {
    local event="$1" payload="$2"
    case "$event" in
        backend_selected)
            log_info "Backend changed: $payload"
            ;;
        setting_applied)
            log_info "Setting applied: $payload"
            ;;
    esac
}
```

## Public API Functions

| Function | Description |
|----------|-------------|
| `plugin_is_loaded <name>` | Check if a plugin is loaded |
| `plugin_config_get <name> <key>` | Get a plugin's config value |
| `plugin_config_set <name> <key> <value>` | Set a plugin's config value |
| `plugin_meta <name> <key>` | Get plugin metadata (version, oems, android, file, priority) |
| `plugin_list` | List all loaded plugins |
| `plugin_help <name>` | Show detailed plugin info |
| `plugin_load <file> [name]` | Load a single plugin from file |
| `plugin_unload <name>` | Unload a plugin |
| `plugin_reload <name>` | Reload a plugin |

## Plugin Directory

Plugins are discovered from `${ANDROID_TOOLKIT_ROOT_DIR}/plugins/`.
Each `.sh` file in this directory is treated as a plugin.
PLUGIN_API

    log_success "  plugin-api.md"
}

##############################################
# Generate settings reference from settings registry.
