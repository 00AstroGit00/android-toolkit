# Developer Guide

## Architecture Overview

The Android Toolkit follows a layered architecture:

```
CLI (toolkit.sh)
  ├── Library Layer    — Core infrastructure (logging, backend, backup, rollback, plugin)
  ├── Module Layer     — Feature implementations (performance, battery, network, etc.)
  ├── OEM Layer        — Device manufacturer logic (Samsung, Google, etc.)
  └── Plugin Layer     — Third-party extensions (auto-loaded from plugins/)
```

### Data Flow

1. `toolkit.sh` parses CLI arguments → sets `ACTION` and `ACTION_ARGS`
2. Library files are sourced at startup
3. Device detection runs → populates device info globals
4. Capabilities are probed → results cached in `CAP_*` globals
5. OEM framework loads → `OEM_LOADED` set based on manufacturer
6. Plugins loaded → `plugin_register()` called for each
7. Action dispatch → `_main()` delegates to the appropriate module function

## Adding a New Module

### 1. Create the module file

```bash
touch modules/myfeature.sh
```

### 2. Implement module functions

```bash
# modules/myfeature.sh
myfeature_do_something() {
    log_section "My Feature"
    log_info "Doing something..."
    # Use backend_exec for all device operations
    backend_exec "settings get global something"
}
```

### 3. Register in toolkit.sh

Add a CLI argument parser entry and action handler:

```bash
# In the argument parser (around line 110):
--my-action)
    ACTION="my_action"
    shift
    ;;

# In the _main() dispatch (around line 360):
my_action)
    _load_module "myfeature"
    myfeature_do_something
    ;;
```

### 4. Register in tests/run_tests.sh

Add your module to the `test_file_integrity` function's module list.

## Writing Safe Settings Operations

Always use the verified write protocol via `backend_settings_put()`:

```bash
backend_settings_put "global" "my_setting" "1"
```

This automatically:
1. Probes that the namespace is accessible
2. Reads the current value
3. Skips the write if the value is already correct
4. Records a rollback journal entry
5. Checks dry-run mode
6. Applies the change
7. Verifies by re-reading (auto-restore on mismatch)

## Adding Settings to settings-db.json

Each entry requires:

```json
{
  "my_setting": {
    "namespace": "global",
    "min_android": 33,
    "max_android": 36,
    "oem": "all",
    "default": "0",
    "recommended": "1",
    "risk": "low",
    "requires_reboot": false,
    "rollback": "my_setting",
    "note": "Description of this setting"
  }
}
```

Fields:
- `namespace`: `global`, `secure`, or `system`
- `min_android` / `max_android`: Android SDK version range
- `oem`: `"all"` or specific OEM name (e.g., `"samsung"`)
- `default`: Factory default value
- `recommended`: Toolkit-recommended value
- `risk`: `"low"`, `"medium"`, or `"high"`
- `requires_reboot`: Whether the device needs to reboot for the change to take effect
- `rollback`: The key used to restore the previous value
- `note`: Description of what the setting controls

## Using Capabilities

Probe capabilities before using features:

```bash
if cap_get "CAP_SAMSUNG_GOS" > /dev/null 2>&1; then
    # GOS settings exist — safe to modify
    backend_settings_put "global" "game_auto_temperature_control" "0"
fi
```

Capabilities are cached. Re-run detection by clearing the cache:

```bash
cap_clear_cache
detect_device_info  # re-triggers capability detection
```

## OEM Framework

Add OEM support by creating `modules/oem/<Manufacturer>.sh`:

```bash
# Required variables
oem_<lowercase_name>_name="Manufacturer Name"
oem_<lowercase_name>_version="1.0.0"
oem_<lowercase_name>_supported_android="33 34 35 36"

# Required functions (all must return 0)
oem_<lowercase_name>_register() { ... }
oem_<lowercase_name>_optimize() { ... }
oem_<lowercase_name>_validate_setting() { ... }
```

The OEM framework auto-loads the correct module based on `ro.product.manufacturer`.

## Testing

Run all tests:

```bash
bash tests/run_tests.sh
```

Run specific suites:

```bash
bash tests/run_tests.sh --shellcheck   # Static analysis
bash tests/run_tests.sh --functional   # File integrity, config parsing, DB validation
```

All new scripts must pass `bash -n`. ShellCheck is recommended but not required.

## Logging Conventions

| Function       | Purpose                                   |
|----------------|-------------------------------------------|
| `log_debug`    | Detailed debugging information             |
| `log_info`     | Normal informational messages              |
| `log_success`  | Successful operation                       |
| `log_warning`  | Something unexpected but non-fatal         |
| `log_error`    | Operation failure                          |
| `log_section`  | Section header for readable output         |
| `log_show_file`| Display result file path to user           |

## Checklist for New Contributions

- [ ] Module passes `bash -n`
- [ ] Module passes ShellCheck (SC1091, SC1090, SC2034, SC2154 excluded)
- [ ] All backend operations use `backend_exec` or `backend_settings_put`
- [ ] Settings operations probed before write
- [ ] Dry-run respected (`ANDROID_TOOLKIT_DRY_RUN`)
- [ ] Rollback journal entry recorded for all state changes
- [ ] Capabilities probed before use
- [ ] OEM-constrained settings validated via `oem_setting_applicable()`
- [ ] Module registered in `tests/run_tests.sh`
- [ ] Documentation updated in README.md or relevant docs
