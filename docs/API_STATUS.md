# API Status

> Auto-generated. Last updated: 2026-07-23

## Stability Classification

| Label | Meaning | Version Requirement |
|-------|---------|-------------------|
| **Stable** | Fully supported. Will not break without major version bump. | All v4.x |
| **Experimental** | Usable but may change in minor versions. | v4.1.0+ |
| **Deprecated** | Scheduled for removal. Migration path documented. | v4.1.0+ |
| **Internal** | Private API. Not for external use. May change without notice. | N/A |

## Libraries

| Library | API | Stability | Notes |
|---------|-----|-----------|-------|
| `lib/api.sh` | All `api_*` functions | **Stable** | Public API surface |
| `lib/logging.sh` | `log_*` functions | **Stable** | |
| `lib/backend.sh` | `backend_shell`, `backend_settings_put` | **Stable** | |
| `lib/rollback.sh` | `rollback_*` functions | **Stable** | |
| `lib/plugin.sh` | SDK v2.0 functions | **Stable** | Full backward compat |
| `lib/plugin.sh` | SDK v2.1 functions | **Stable** | Additive to v2.0 |
| `lib/plugin.sh` | SDK v3.0 certification | **Experimental** | May refine in v4.2 |
| `lib/commands.sh` | All `command_*` functions | **Stable** | |
| `lib/capability_graph.sh` | All `cap_graph_*` functions | **Stable** | |
| `lib/events.sh` | All `events_*` functions | **Stable** | |
| `lib/json_output.sh` | All `json_*` functions | **Stable** | |
| `lib/settings.sh` | All `settings_*` functions | **Stable** | |
| `lib/dependencies.sh` | All `deps_*` functions | **Stable** | |
| `lib/json_schema.sh` | All `schema_*` functions | **Experimental** | Schema validation API |

## Modules

| Module | CLI Command | Stability | Notes |
|--------|-------------|-----------|-------|
| `modules/reporting.sh` | `--status`, `--report` | **Stable** | |
| `modules/performance.sh` | `--apply` | **Stable** | |
| `modules/benchmark.sh` | `--benchmark`, `--enhanced-benchmark` | **Stable** | |
| `modules/doctor.sh` | `--doctor` | **Stable** | |
| `modules/audit.sh` | `--audit` | **Stable** | |
| `modules/analyzer.sh` | `--analyze` | **Stable** | |
| `modules/packages.sh` | `--disable/--enable-package`, `--packages` | **Stable** | |
| `modules/samsung.sh` | `--list-bloatware`, `--samsung-light` | **Stable** | |
| `modules/network.sh` | `--refresh-network` | **Stable** | |
| `modules/maintenance.sh` | `--compile`, `--trim-cache` | **Stable** | |
| `modules/export.sh` | `--export` | **Stable** | |
| `modules/tui.sh` | `--tui` | **Stable** | |
| `modules/updater.sh` | `--update` | **Stable** | |
| `modules/scheduler.sh` | `--schedule` | **Stable** | |
| `modules/telemetry.sh` | `--stats` | **Stable** | |
| `modules/watch.sh` | `--watch` | **Stable** | |
| `modules/compare.sh` | `--compare` | **Stable** | |
| `modules/docgen.sh` | `--docgen` | **Stable** | |
| `modules/profile_manager.sh` | `--profile-manager` | **Stable** | |
| `modules/devices.sh` | `--devices`, `--device`, `--all-devices` | **Stable** | |
| `modules/release_check.sh` | `--release-check` | **Experimental** | May refine checks |
| `modules/performance_test.sh` | `--performance` | **Experimental** | |
| `modules/sbom.sh` | `--sbom` | **Experimental** | |
| `modules/static_analysis.sh` | `--static-analysis` | **Experimental** | External tool wrapper |
| `modules/security_review.sh` | `--security-review` | **Experimental** | |
| `modules/packages_analysis.sh` | `--packages-analyze` | **Experimental** | |
| `modules/validate_device.sh` | `--validate-device` | **Experimental** | Needs more OEM data |
| `modules/compat_matrix.sh` | Auto-generated | **Experimental** | |
| `modules/settings_verify.sh` | `--settings-verify` | **Experimental** | |
| `modules/plugin_certify.sh` | `--plugin-certify` | **Experimental** | |
| `modules/developer.sh` | `--dev` | **Experimental** | |
| `modules/repo_health.sh` | `--repo-health` | **Experimental** | |
| `modules/release_ready.sh` | `--release-ready` | **Experimental** | |

## Version Compatibility

| Toolkit Version | API Stability |
|----------------|---------------|
| v4.0.x | All Stable APIs frozen |
| v4.1.x | Adding Experimental APIs only |
| v5.0.0 | May deprecate v3.x-era APIs |

## Breaking Changes Policy

1. Any breaking API change requires a **major** version bump (v4 → v5).
2. Deprecated APIs receive a minimum 2-minor-version notice period.
3. Deprecated APIs produce a warning at runtime.
4. Migration guides are published with each deprecation announcement.

## Deprecated APIs

None currently.

## Experimental APIs

- `plugin_certify_*` functions (may change as certification matures)
- `release_check_*` functions (may add/remove checks)
- `schema_validate_all` (schema format may evolve)
- All `modules/validate_device.sh` functions
- All `modules/repo_health.sh` functions
- All `modules/release_ready.sh` functions
- All `modules/developer.sh` functions
