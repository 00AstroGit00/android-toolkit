# API Adoption Report — v4.2.0

> Generated: 2026-07-24 | Scope: Stabilization Sprint

## Summary

| Metric | Value |
|--------|-------|
| `api_*` functions defined | 62 |
| Internal callers of `api_*` | 6 (across 2 modules) |
| Direct calls to internal libs | ~520 (across all modules) |
| Adoption ratio | ~1.1% |

## Migrated Calls

| Module | Function | API Used | Instead of | Rationale |
|--------|----------|----------|------------|-----------|
| `validate_device.sh` | `validate_check_features` | `api_device_manufacturer` | `cap_get CAP_MANUFACTURER` | Public API provides stable interface |
| `validate_device.sh` | `validate_check_features` | `api_device_model` | `cap_get CAP_MODEL` | Public API provides stable interface |
| `validate_device.sh` | `validate_check_features` | `api_android_version` | `detect_android_version_at_least` | Public API provides stable interface |
| `validate_device.sh` | `validate_check_features` | `api_android_sdk` | `detect_sdk_at_least` | Public API provides stable interface |
| `settings_verify.sh` | `settings_verify_run` | `api_android_sdk` | `detect_sdk_at_least` | Adopted by original author |
| `settings_verify.sh` | `settings_verify_run` | `api_android_version` | `detect_android_version_at_least` | Adopted by original author |

## Remaining Direct Calls (Not Migrated — Justified)

### Category 1: Logging (api_log / api_info / api_error etc.)

```bash
# Current:
log_info "Device detected: $model"
log_error "Backend required"

# Would become:
api_info "Device detected: $model"
api_error "Backend required"
```

**Not migrated because:** The `api_*` logging wrappers are one-line pass-throughs to `log_*`. Replacing 200+ calls would create pure code churn with zero functional benefit. The `log_*` functions are themselves stable public API (`API_STATUS.md` classifies them as Stable).

### Category 2: Backend Operations

```bash
# Current:
backend_shell "settings get global airplane_mode_on"
backend_settings_put global airplane_mode_on 1
```

**Not migrated because:** The `api_backend_*` wrappers add no abstraction value for internal use. Direct calls are more transparent about what's happening. External plugin/script authors should use `api_backend_*`.

### Category 3: Module-Specific Functions

```bash
# Current:
benchmark_run
samsung_optimize
rollback_begin
```

**Not migrated because:** These are module-level public functions that are already stable. The `api_*` wrappers (`api_benchmark`, `api_rollback_begin`) add no value for internal cross-module calls.

## Recommendation

The `api_*` layer serves its primary purpose as a **documented public contract** for external consumers (plugins, scripts, SDK users). Internal code should continue using the native `lib_*` and `module_*` functions directly for **clarity and performance**.

No further migration is recommended unless:
1. A future refactoring changes the underlying `lib_*` API
2. External consumers report issues with `api_*` wrappers
3. The `api_*` layer adds logic beyond simple delegation (e.g., validation, normalization)
