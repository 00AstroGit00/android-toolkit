# Plugin Security Model — v4.2.0

> Generated: 2026-07-24 | Scope: Stabilization Sprint

## Trust Model

The Android Toolkit plugin system operates on an **opt-in trust model**:

- **Plugins are bash scripts** loaded into the same shell process as the toolkit.
- **Plugin authors are trusted** by the user who installs them.
- **No code signing** — plugins are loaded from the local `plugins/` directory.
- **Certification is advisory** — `plugin_certified` metadata indicates the plugin has passed SDK validation, but does not guarantee safety.

## Execution Architecture

### Before v4.2.0 (Direct Execution)

```
toolkit.sh → plugin_run() → plugin_run() directly
  │                           │
  │                           └── if plugin crashes, toolkit crashes
  │
  └── No timeout, no error boundary
```

### After v4.2.0 (Isolated Execution)

```
toolkit.sh → plugin_run() → _plugin_exec_isolated()
                              │
                              ├── Spawns subshell
                              ├── Sets trap 'exit 127' on ERR
                              ├── Applies timeout (ANDROID_TOOLKIT_PLUGIN_TIMEOUT)
                              ├── Optionally restricts PATH (safe mode)
                              │
                              ├── On success → propagates exit code
                              ├── On timeout → returns 124
                              ├── On plugin error → returns 127
                              ├── On crash → returns non-zero
                              │
                              └── toolkit continues regardless
```

## Isolation Mechanisms

### 1. Subshell Execution

Every plugin function (`plugin_run`, `plugin_pre_run`, `plugin_post_run`) executes in a **subshell**. This means:

- `exit` calls only terminate the plugin, not the toolkit
- `set -e` in the plugin doesn't abort the toolkit
- Variable leaks from the plugin don't affect the toolkit
- `cd` in the plugin doesn't change toolkit's working directory

### 2. Error Trapping

Each isolated execution has:

```bash
trap 'exit 127' ERR
```

This catches:
- Command failures (non-zero exit from critical commands)
- Unset variable access (if plugin uses `set -u`)
- Pipeline failures (if plugin uses `set -o pipefail`)

### 3. Execution Timeout

| Variable | Default | Description |
|----------|---------|-------------|
| `ANDROID_TOOLKIT_PLUGIN_TIMEOUT` | 60 | Maximum seconds for plugin execution |

If `timeout` command is available on the system, plugin execution is bounded. A timeout returns exit code **124**.

### 4. Safe Mode (Optional)

| Variable | Default | Description |
|----------|---------|-------------|
| `ANDROID_TOOLKIT_PLUGIN_SAFE` | false | When `true`, restricts plugin environment |

In safe mode:
- `PATH` restricted to `/system/bin:/system/xbin:/data/data/com.termux/files/usr/bin`
- `LD_PRELOAD` and `LD_LIBRARY_PATH` unset
- Plugin runs with `set -e` (any error aborts the plugin)
- Only `timeout`-wrapped execution

Enable with:
```bash
ANDROID_TOOLKIT_PLUGIN_SAFE=true toolkit.sh --plugin myplugin
```

## Failure Handling

| Scenario | Behavior | Exit Code |
|----------|----------|-----------|
| Plugin executes successfully | Normal return | 0 |
| Plugin returns error | Warning logged, toolkit continues | 1–127 |
| Plugin crashes (syntax error) | Error logged, toolkit continues | 127 |
| Plugin times out | Warning logged, toolkit continues | 124 |
| Plugin function missing | Warning logged, skipped | 0 |
| Plugin not loaded | Error logged | 1 |

### Example Failure Scenarios

```
# Plugin with syntax error still loads but fails on run
$ toolkit.sh --plugin buggy
[WARNING] Plugin 'buggy' execution failed (exit 127)

# Plugin that hangs gets timed out
$ ANDROID_TOOLKIT_PLUGIN_TIMEOUT=10 toolkit.sh --plugin slow
[WARNING] Plugin 'slow' timed out after 10s

# One plugin failure doesn't block others
$ toolkit.sh --plugin bad --plugin good
[WARNING] Plugin 'bad' returned error exit code 1
[INFO] Plugin 'good' executed successfully
```

## Limitations

1. **No filesystem isolation**: Plugins can read/write any file the user has access to.
2. **No network isolation**: Plugins can make network connections.
3. **No memory limits**: A plugin can exhaust system memory.
4. **No kernel isolation**: All isolation is at the bash process level.
5. **Safe mode is optional**: Must be explicitly enabled by the user.
6. **Timeout requires `timeout` command**: Not available on all systems.
7. **Subshell is not a sandbox**: A determined malicious plugin can still cause damage.

## Recommended Practices

### For Plugin Developers

```bash
# Always check prerequisites
plugin_pre_run() {
    if ! command -v adb &>/dev/null; then
        log_error "ADB required"
        return 1  # plugin_run will be skipped
    fi
}

# Use local variables to avoid global scope pollution
plugin_run() {
    local tmpfile
    tmpfile="$(mktemp)"
    # ... work ...
    rm -f "$tmpfile"
}

# Clean up resources
plugin_cleanup() {
    rm -f /tmp/my_plugin_temp_* 2>/dev/null || true
}
```

### For Users

```bash
# Enable safe mode for untrusted plugins
export ANDROID_TOOLKIT_PLUGIN_SAFE=true

# Set a shorter timeout
export ANDROID_TOOLKIT_PLUGIN_TIMEOUT=30

# Run with isolation
toolkit.sh --plugin myplugin

# Certify before running
toolkit.sh --plugin-certify myplugin
```

## Execution Flow Diagram

```
plugin_run("myplugin")
  │
  ├── plugin_is_loaded("myplugin")? ─── NO → error, return
  │
  ├── _plugin_exec_isolated("myplugin", "plugin_pre_run")
  │     └── subshell { trap 'exit 127' ERR; plugin_pre_run "$@"; }
  │
  ├── _plugin_exec_isolated("myplugin", "plugin_run")
  │     └── subshell {
  │           trap 'exit 127' ERR
  │           [safe mode] → PATH restricted
  │           [timeout]   → timeout $PLUGIN_TIMEOUT plugin_run "$@"
  │           [normal]    → plugin_run "$@"
  │         }
  │     └── exit_code = $?
  │
  ├── _plugin_exec_isolated("myplugin", "plugin_post_run", $exit_code)
  │     └── subshell { plugin_post_run "$exit_code"; }
  │
  └── return $exit_code
```

## Version History

| Version | Change |
|---------|--------|
| v2.0 | Direct execution, no isolation |
| v2.1 | Added plugin_pre_run/post_run hooks |
| v3.0 | Added certification metadata |
| **v4.2.0** | **Subshell isolation, timeout, safe mode, error trapping** |
