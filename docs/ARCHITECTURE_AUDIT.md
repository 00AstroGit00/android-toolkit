# Architecture Audit — v4.1.0

> Generated: 2026-07-23 | Scope: Final Engineering Audit

## Overview

Android Toolkit is a modular, non-root Android optimization and diagnostics toolkit.

| Dimension | Value |
|-----------|-------|
| Version | 4.1.0 |
| Total `.sh` files | 67 |
| Total functions | 577 |
| Libraries (`lib/`) | 16 |
| Modules (`modules/`) | 41 |
| OEM modules (`modules/oem/`) | 8 |
| Plugins (`plugins/`) | 1 (example) |
| CLI actions | 45+ |
| CI jobs | 14 |

## Architecture Layers

```
┌──────────────────────────────────────────────┐
│  toolkit.sh — CLI entry point (975 lines)     │
│  ┌────────────────────────────────────────┐   │
│  │  lib/ — Shared subsystems (16 files)    │   │
│  │  ├── logging.sh      log_*             │   │
│  │  ├── backend.sh      backend_*          │   │
│  │  ├── detection.sh    detect_*           │   │
│  │  ├── config.sh       config_*           │   │
│  │  ├── rollback.sh     rollback_*         │   │
│  │  ├── plugin.sh       plugin_* (SDK v3)  │   │
│  │  ├── commands.sh     command_* (29)     │   │
│  │  ├── events.sh       events_* (9 types) │   │
│  │  ├── settings.sh     settings_* (120+)  │   │
│  │  ├── api.sh          api_* (55 public)  │   │
│  │  ├── dependencies.sh deps_* (15 tools)  │   │
│  │  ├── json_output.sh  json_*             │   │
│  │  ├── json_schema.sh  schema_*           │   │
│  │  ├── backup.sh       backup_*           │   │
│  │  ├── capability_graph.sh  cap_graph_*   │   │
│  │  └── utils.sh        utils_*            │   │
│  └────────────────────────────────────────┘   │
│  ┌────────────────────────────────────────┐   │
│  │  modules/ — Lazy-loaded (41 files)      │   │
│  │  ├── Core: reporting, performance,      │   │
│  │  │        maintenance, network,          │   │
│  │  │        packages, display, battery     │   │
│  │  ├── Samsung: samsung.sh (919 lines)    │   │
│  │  ├── OEM framework: oem.sh + 8 modules  │   │
│  │  ├── Quality: release_check,            │   │
│  │  │   release_ready, static_analysis,     │   │
│  │  │   security_review, security_harden,   │   │
│  │  │   repo_health, plugin_certify,        │   │
│  │  │   validate_device, settings_verify    │   │
│  │  ├── Benchmark: benchmark, compare,      │   │
│  │  │   performance_test, compat_matrix     │   │
│  │  └── Tooling: docgen, export, tui,       │   │
│  │      updater, scheduler, telemetry,      │   │
│  │      watch, builder, packaging,          │   │
│  │      developer, devices, profile_manager,│   │
│  │      audit, analyzer, packages_analysis, │   │
│  │      sbom                                │   │
│  └────────────────────────────────────────┘   │
│  ┌────────────────────────────────────────┐   │
│  │  plugins/ — Third-party extensibility   │   │
│  │  (SDK v2.0, v2.1, v3.0 compatible)    │   │
│  └────────────────────────────────────────┘   │
└──────────────────────────────────────────────┘
```

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **Lazy module loading** (`_load_module`) | Startup time stays fast; only needed modules are sourced |
| **OEM framework** (`modules/oem/`) | Isolates vendor-specific logic; Samsung code never runs on Google devices |
| **Plugin SDK v3.0** | Backward compatible with v2.0/v2.1; certification metadata enables quality gates |
| **Settings database** (`configs/settings-db.json`) | ~120 entries with metadata (namespace, OEM filter, risk, rollback key); declarative, not hardcoded |
| **Command registry** (`lib/commands.sh`) | 29 commands with aliases, categories, capabilities, constraints; drives `--help` and validation |
| **Capability graph** (`lib/capability_graph.sh`) | Transitive dependency resolution for features (e.g., `benchmark → dumpsys → adb/rish`) |
| **Event system** (`lib/events.sh`) | 9 event types with subscribe/emit; cycle detection; used by plugins and telemetry |
| **JSON schema validation** (`lib/json_schema.sh`) | 8 schemas for settings, reports, telemetry, benchmarks, plugins, profiles, manifests, android-db |
| **Dependency manager** (`lib/dependencies.sh`) | Detects 15 tools (8 required, 7 optional); installs via Termux packages |

## Scalability Assessment

| Factor | Assessment |
|--------|------------|
| **Codebase growth** | 67 files, 577 functions — moderate. Largest files: samsung.sh (919), docgen.sh (914), toolkit.sh (975) |
| **Module independence** | Most modules can be loaded independently; shared dependencies are in `lib/` |
| **Plugin extensibility** | Plugin SDK allows third-party modules without modifying core; certification provides quality gate |
| **CI/CD scalability** | 14 jobs with parallel execution; benchmarking job tracks regressions |
| **OEM coverage** | 8 manufacturers; profiles in `validation/oem-profiles.json` with feature matrices |
| **Android version coverage** | Android 13–17 in `configs/android-db.json` with per-version command support |

## Issues Found

### Fixed During This Audit

| ID | Severity | File | Issue | Fix |
|----|----------|------|-------|-----|
| H1 | 🔴 High | `.github/workflows/ci.yml:19,107` | Duplicate job ID `static-analysis` caused comprehensive static analysis (ShellCheck, shfmt, markdownlint, jq) to be silently overridden by a bare bash syntax check. | Renamed to `static-analysis-full` and `bash-syntax`; build `needs` updated |
| H2 | 🔴 High | `.github/workflows/ci.yml:288` | Build job referenced `bash-syntax` as a dependency but no job with that ID existed | Fixed as consequence of H1 |
| H3 | 🔴 High | `modules/oem.sh:33` | OEM case statement had `xiaomi\|redmi\|poco\|*` — the `*` wildcard matched ANY manufacturer as Xiaomi, making all subsequent cases unreachable | Removed `\|*` wildcard; proper `*)` fallback now works |
| M4 | 🟡 Medium | `modules/oem.sh:35` | Duplicate `oneplus` mapping in both OnePlus and Oppo cases | Removed `oneplus` from Oppo case |
| M1 | 🟡 Medium | 55 `.sh` files | Missing "Part of the Android Toolkit" attribution header | Added to all files |
| L4 | 🟢 Low | `lib/backend.sh:18` | Stale template URL `github.com/yourusername/android-toolkit` | Removed |

### Known (Not Yet Fixed)

| ID | Severity | File | Issue | Notes |
|----|----------|------|-------|-------|
| M2 | 🟡 Medium | `modules/compat_matrix.sh` | Never loaded from `toolkit.sh` directly; only accessible via `--dev docs` | Low impact — it's a support module for doc generation |
| M3 | 🟡 Medium | `modules/samsung.sh` (919) `modules/docgen.sh` (914) | Two largest modules approaching 1K lines | Candidate for future refactoring, not blocking |
| L1 | 🟢 Low | `lib/api.sh` | All 55 `api_*` functions are wrappers with zero internal adoption | Public API exists for external consumers but is untested through CLI paths |

## Recommendations

1. **CI**: ✅ Fixed — no duplicate job IDs; all `needs` reference valid IDs
2. **OEM detection**: ✅ Fixed — no wildcard fallthrough; all 8 manufacturers matched correctly
3. **Module decomposition**: Future: consider splitting `samsung.sh` (>900 lines) into sub-modules
4. **API adoption**: Future: consider using `api_*` functions internally to validate and exercise the public API
5. **compat_matrix.sh**: Future: consider adding a direct CLI entry point if users need standalone access
