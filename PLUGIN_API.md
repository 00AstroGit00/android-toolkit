# Plugin API

## Overview

Plugins extend the Android Toolkit with custom functionality. They are auto-loaded
from the `plugins/` directory at startup and can be executed via:

```bash
./toolkit.sh --plugin <plugin_name> [args...]
```

## Plugin Contract

Each plugin is a `.sh` file that defines the following:

### Required Variables

| Variable                   | Description                            | Example                  |
|----------------------------|----------------------------------------|--------------------------|
| `plugin_name`              | Human-readable name                    | `"Example Plugin"`       |
| `plugin_version`           | Semver version                         | `"1.0.0"`                |
| `plugin_supported_oems`    | Space-separated OEM names or `"all"`   | `"samsung google"`       |
| `plugin_supported_android` | Space-separated Android SDK versions   | `"33 34 35 36"`          |

### Required Functions

#### `plugin_register()`

Called once when the plugin is loaded. Use this to declare capabilities,
register hooks, or validate prerequisites.

```bash
plugin_register() {
    log_debug "Plugin registered: $plugin_name"
}
```

#### `plugin_run()`

Called when the plugin is executed via `--plugin <name> [args...]`.
All arguments after the plugin name are passed to this function.

```bash
plugin_run() {
    log_section "$plugin_name"
    log_info "Arguments: $*"
    # Your plugin logic here
}
```

#### `plugin_cleanup()`

Called on normal exit, interrupt, or error via trap handler.
Use this to clean up temporary files, restore state, etc.

```bash
plugin_cleanup() {
    log_debug "Plugin cleaned up: $plugin_name"
}
```

## Example Plugin

See `plugins/00-example.sh` for a complete example:

```bash
plugin_name="Example Plugin"
plugin_version="1.0.0"
plugin_supported_oems="all"
plugin_supported_android="33 34 35 36"

plugin_register() {
    log_debug "Example plugin registered"
}

plugin_run() {
    log_section "Example Plugin"
    log_info "Plugin: $plugin_name v$plugin_version"
    log_info "Args: $*"
    log_success "Example plugin executed"
}

plugin_cleanup() {
    log_debug "Example plugin cleaned up"
}
```

## Available APIs

Plugins have full access to all toolkit libraries and modules:

### Backend Operations

```bash
backend_exec "settings get global airplane_mode_on"
backend_settings_put "global" "my_setting" "value"
```

### Logging

```bash
log_debug "debug message"
log_info "info message"
log_success "success message"
log_warning "warning message"
log_error "error message"
log_section "Section Title"
```

### Capability Detection

```bash
cap_get CAP_MANUFACTURER       # Returns manufacturer name
cap_get CAP_ANDROID_SDK         # Returns Android SDK level
cap_get CAP_IS_SAMSUNG          # Returns "1" if Samsung device
cap_get CAP_HAS_SHIZUKU         # Returns "1" if Shizuku available
```

### OEM Framework

```bash
oem_name                        # Returns current OEM name or "generic"
oem_is "samsung"                # Returns 0 if current device is Samsung
oem_setting_applicable "global" "my_key"  # Check OEM applicability
```

### Rollback Engine

```bash
journal=$(rollback_begin "my-plugin operation")
rollback_record "$journal" "global" "my_setting" "old_value" "new_value"
rollback_close "$journal" "completed"
```

### Plugin Utilities

```bash
plugin_is_loaded "other-plugin"   # Check if another plugin is loaded
plugin_list                       # List all loaded plugins
```

## Testing Your Plugin

1. Place your plugin in `plugins/your-plugin.sh`
2. Run `bash -n plugins/your-plugin.sh` to check syntax
3. Execute: `./toolkit.sh --plugin your-plugin --arg1 value1`
4. Check logs in `logs/toolkit_*.log` for debug output

## Best Practices

1. **Always probe capabilities** — never assume features are available
2. **Log all operations** — use `log_debug` for internal state, `log_info` for progress
3. **Use rollback for state changes** — record every setting or state change in the journal
4. **Respect dry-run** — check `$ANDROID_TOOLKIT_DRY_RUN` before making changes
5. **Clean up on exit** — the `plugin_cleanup()` trap handler covers EXIT, INT, and TERM
6. **OEM-constrain when needed** — use `oem_is` and `oem_setting_applicable` for device-specific logic
7. **Prefix global variables** — use a unique prefix to avoid collisions with other plugins
