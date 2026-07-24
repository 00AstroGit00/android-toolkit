# API Review — v4.1.0

> Generated: 2026-07-23 | Scope: Final Engineering Audit

## Public API Surface

The public API is defined in `lib/api.sh` and exports 55 `api_*` functions across 13 categories.

### Classification (per `API_STATUS.md`)

| Label | Meaning | Count |
|-------|---------|-------|
| **Stable** | Fully supported, won't break without major bump | 43 |
| **Experimental** | May change in minor versions | 12 |
| **Deprecated** | Scheduled for removal | 0 |
| **Internal** | Not for external use | N/A (private functions are `_`-prefixed) |

### API Categories

| Category | Functions | Stability | Notes |
|----------|-----------|-----------|-------|
| **Logging** | `api_log`, `api_info`, `api_warn`, `api_error`, `api_success`, `api_debug`, `api_section`, `api_table_header`, `api_table_row` | ✅ Stable | Wrappers around `log_*` functions |
| **Output** | `api_json_enabled`, `api_dry_run`, `api_confirm` | ✅ Stable | Query/confirm helpers |
| **Backend** | `api_backend`, `api_adb_serial`, `api_backend_available`, `api_backend_type`, `api_backend_shell`, `api_backend_settings_put`, `api_get_prop` | ✅ Stable | Wraps `backend_*` functions |
| **Capabilities** | `api_has_capability`, `api_list_capabilities`, `api_android_sdk`, `api_android_version`, `api_device_manufacturer`, `api_device_model`, `api_device_oem` | ✅ Stable | Wraps `cap_*` / `detect_*` |
| **Events** | `api_on`, `api_emit` | ✅ Stable | Wraps `events_*` |
| **Plugins** | `api_plugin_load_all`, `api_plugin_load`, `api_plugin_loaded`, `api_plugin_list`, `api_plugin_config`, `api_plugin_help` | ✅ Stable | Wraps `plugin_*` |
| **Rollback** | `api_rollback_begin`, `api_rollback_record`, `api_rollback_close`, `api_rollback_perform`, `api_rollback_list` | ✅ Stable | Wraps `rollback_*` |
| **Reporting** | `api_status`, `api_report`, `api_last_report` | ✅ Stable | Loads modules on demand |
| **Config** | `api_config_get`, `api_root_dir`, `api_version` | ✅ Stable | Wraps `config_*` |
| **Benchmark** | `api_benchmark`, `api_benchmark_history` | ✅ Stable | Loads benchmark module |
| **Packages** | `api_disable_package`, `api_enable_package`, `api_package_installed`, `api_packages_recommend` | ✅ Stable | Wraps `packages_*` |
| **Devices** | `api_devices_list`, `api_devices_set_active`, `api_devices_get_active` | ✅ Stable | Wraps `devices_*` |
| **Settings** | `api_settings_lookup`, `api_settings_writable` | ✅ Stable | Wraps `settings_*` |
| **Utilities** | `api_temp_file`, `api_timestamp`, `api_read_file`, `api_write_file`, `api_has_command`, `api_timeout` | ✅ Stable | Wraps `utils_*` |

### Coverage

Each `api_*` function delegates to an internal function:

```
api_log()       → log_*()
api_backend()   → backend functions
api_has_capability() → cap_has()
api_on/emit()   → events_subscribe/emit()
api_plugin_*()  → plugin_*()
api_rollback_*() → rollback_*()
api_config_get() → config_get()
api_*_package() → packages_*()
api_devices_*() → devices_*()
api_settings_*() → settings_*()
api_*()         → utils_*()
```

All 55 functions have valid underlying implementations. **No dangling references** found.

## Internal API Surface (lib/*.sh)

The internal API comprises ~520 functions across 16 library files. Key interfaces:

| Library | Key Functions | Consumers |
|---------|---------------|-----------|
| `backend.sh` | `backend_shell`, `backend_exec`, `backend_getprop`, `backend_settings_put` | All modules that interact with device |
| `logging.sh` | `log_info`, `log_warn`, `log_error`, `log_debug`, `log_success`, `log_section` | Every module and lib |
| `plugin.sh` | `plugin_load_all`, `plugin_run`, `plugin_list` | `toolkit.sh`, CLI dispatch |
| `commands.sh` | `command_define`, `command_find`, `command_generate_help` | `toolkit.sh`, `--help` generation |
| `rollback.sh` | `rollback_begin`, `rollback_record`, `rollback_perform` | Any module that makes changes |
| `events.sh` | `events_subscribe`, `events_emit` | Plugin system, telemetry |
| `settings.sh` | `settings_get_field`, `settings_applicable`, `settings_validate_value` | Settings verification, performance module |

## API Consistency

| Check | Result |
|-------|--------|
| **Naming convention** | `snake_case` throughout — consistent |
| **Prefix convention** | `api_` (public), `_`-prefixed (private/internal), module-specific prefix (e.g., `backend_`, `log_`) — consistent |
| **Parameter validation** | Most functions validate critical parameters; some accept unvalidated strings |
| **Return codes** | Functions return 0/1 consistently |
| **Error handling** | Uses `log_error` pattern; no silent failures |

## External API Contracts

| Consumer | Interface | Status |
|----------|-----------|--------|
| **Plugins** (SDK v2.0/v2.1/v3.0) | `plugin_*` variables and lifecycle hooks | ✅ Stable, backward compatible |
| **OEM modules** | `oem_load`, `oem_is`, `oem_name`, `cap_*` for registration | ✅ Stable |
| **Profiles** | JSON format in `profiles/` directory | ✅ Stable |
| **Settings database** | JSON format in `configs/settings-db.json` | ✅ Stable |

## Findings

### ✅ Strengths

1. **Clear API layering**: `api_*` → `lib/*_*` → internal helpers — clean delegation
2. **All 55 public functions delegate to real implementations**: no stubs or TODOs
3. **Consistent naming**: snake_case with prefix scoping
4. **API freeze documented**: `API_STATUS.md` classifies every API
5. **Backward compatibility maintained**: v2.0, v2.1, v3.0 plugin SDKs all supported

### ⚠️ Concerns

1. **Zero internal adoption**: No module or `toolkit.sh` calls any `api_*` function. The public API is never exercised through actual CLI paths. External consumers may face untested code paths.
2. **No API tests**: The BATS test suite does not include any tests against `api_*` functions.
3. **Thin wrappers**: Most `api_*` functions are one-liners that delegate immediately — they add discoverability and documentation but no logic.
