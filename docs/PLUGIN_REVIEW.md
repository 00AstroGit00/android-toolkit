# Plugin Review — v4.1.0

> Generated: 2026-07-23 | Scope: Final Engineering Audit

## Plugin SDK Overview

The plugin system lives in `lib/plugin.sh` (754 lines) and supports SDK versions v2.0, v2.1, and v3.0.

| SDK Version | Key Features | Added In | Stability |
|-------------|-------------|----------|-----------|
| **v2.0** | Core lifecycle: `plugin_register`, `plugin_pre_run`, `plugin_run`, `plugin_post_run`, `plugin_cleanup`, `plugin_config`, `plugin_dependencies` | v4.0.0-rc1 | ✅ Stable |
| **v2.1** | Enhanced: `plugin_config_schema`, `plugin_commands`, `plugin_on_event`, `plugin_priority` | v4.0.0-rc1 | ✅ Stable |
| **v3.0** | Certification: `plugin_min_toolkit`, `plugin_permissions`, `plugin_events_subscribe`, `plugin_description`, `plugin_author`, `plugin_certified` | v4.0.0 | ⚠️ Experimental |

## Plugin Lifecycle

```
Source plugin.sh (load)
       │
       ▼
plugin_load_all() / plugin_load()
       │
       ▼
_plugin_validate()         ← checks SDK requirements
       │
       ▼
_plugin_certify()          ← checks v3.0 certification metadata
       │
       ▼
_plugin_check_version()    ← toolkit version compatibility
_plugin_check_android()    ← Android SDK range
_plugin_check_oem()        ← OEM compatibility
_plugin_check_deps()       ← plugin dependencies
       │
       ▼
_plugin_load_config()      ← parse config via plugin_config()
_plugin_validate_config()  ← validate via plugin_config_schema()
       │
       ▼
_plugin_register_commands() ← register via plugin_commands()
       │
       ▼
plugin_register()          ← called once (user-defined init)
       │
       ▼
[plugin is now loaded and ready]
       │
       ▼ (when executed)
plugin_pre_run()   (optional)
plugin_run()       (required)
plugin_post_run()  (optional)
plugin_cleanup()   (optional, on exit/error)
```

## Certification Checks

The certification suite (`modules/plugin_certify.sh`) validates:

| Check | Description | Failure |
|-------|-------------|---------|
| Metadata completeness | `plugin_name`, `plugin_version`, `plugin_supported_oems`, `plugin_supported_android` | Cannot load |
| `plugin_min_toolkit` | Minimum toolkit version requirement | Cannot load if toolkit is older |
| `plugin_permissions` | Declared permissions must be <= granted permissions | Warning |
| Config schema | `plugin_config_schema()` must return valid JSON Schema | Cannot validate config |
| Event subscriptions | `plugin_events_subscribe` events must exist in event registry | Warning |
| API usage | Plugin must not call internal (`_`-prefixed) functions | Warning |

## Example Plugin

`plugins/00-example.sh` demonstrates:

```bash
plugin_name="Example Plugin"
plugin_version="1.0.0"
plugin_supported_oems="all"
plugin_supported_android="33 34 35 36"

plugin_register() { ... }
plugin_run() { ... }
plugin_cleanup() { ... }
```

## Backward Compatibility

| Consumed By | SDK Version | Status |
|-------------|-------------|--------|
| v4.0.0 toolkit | v2.0, v2.1, v3.0 plugins | ✅ Compatible |
| v4.1.0 toolkit | v2.0, v2.1, v3.0 plugins | ✅ Compatible |
| v4.1.0 toolkit | v4.0.0-era plugins | ✅ Compatible |
| Future v5.x | v2.0–v3.0 plugins | Guaranteed (LTS policy) |

## Findings

### ✅ Strengths

1. **Clean lifecycle**: Load → validate → certify → register → run → cleanup — well-defined stages
2. **Defensive loading**: Plugin load failures never crash the toolkit (all guarded with `2>/dev/null || true`)
3. **Backward compatibility**: v2.0/v2.1 patterns continue to work without changes
4. **Certification as additive**: v3.0 adds metadata checks without breaking existing plugins
5. **Example plugin**: `plugins/00-example.sh` serves as living documentation
6. **Event integration**: Plugins can subscribe to 9 internal events for deep integration

### ⚠️ Concerns

1. **No plugin sandboxing**: Plugins run in the same shell process with full access to all functions and variables. A malicious or buggy plugin can affect the entire toolkit.
2. **No plugin dependency resolution**: `plugin_dependencies()` is declared but the framework doesn't resolve dependency order or detect cycles.
3. **Certification is optional**: `plugin_certified` is advisory; uncertified plugins load and run without restriction.
4. **Single example plugin**: Only one example exists; no real-world plugins to validate the API against.
5. **No plugin tests**: The BATS suite tests plugin loading (`plugin_load_all`) but has no tests for plugin execution, events, or certification.

### Recommendations

1. **Future**: Consider process isolation (subshell or container) for untrusted plugins
2. **Future**: Implement dependency resolution with topological sort
3. **Future**: Add plugin registry with signing for verified publishers
4. **Documentation**: Expand PLUGIN_API.md with certification walkthrough
