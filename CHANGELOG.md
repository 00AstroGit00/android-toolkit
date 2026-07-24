# Changelog

## v4.2.0 (2026-07-24)

*Release candidate v4.2.0-rc1 superseded by v4.2.0 stable.*

### Production Validation (v4.2.0-rc1 → v4.2.0)
- Final Independent Engineering Review completed — score: 3.7/4.0, APPROVED AS RELEASE CANDIDATE
- CI validation: 78/78 `bash -n` pass, JSON all valid, ShellCheck 0 errors
- Platform validation: Samsung Galaxy S23 Ultra (Android 16, One UI 8) — all commands functional
- Plugin validation: SDK v2.0/v2.1/v3.0 compatibility confirmed, isolation layer verified
- Security verification: 0 critical, 0 high, 4 low issues documented
- Blocking defects fixed: VERSION bump, CHANGELOG entry, SC2295 quoting in `lib/plugin.sh:821`

## v4.2.0-rc1 (2026-07-24)

*Superseded by v4.2.0 stable.*

### Added
- **Plugin Isolation Layer** (`lib/plugin.sh` + `docs/PLUGIN_SECURITY.md`): `_plugin_exec_isolated()` with subshell isolation, configurable timeout (default 60s), optional safe mode restricting PATH and clearing LD_PRELOAD/LD_LIBRARY_PATH, structured error reporting (exit codes: 0 success, 1–127 plugin error, 124 timeout, 127 crash).
- **API Adoption Audit** (`docs/API_ADOPTION.md`): Scoped all 62 public API functions; verified 6 internal callers in validate_device.sh and settings_verify.sh. Recommendation: no further migration needed; api_* serves as public contract.
- **Reachability Analysis** (`reports/reachability.md`): Analyzed 175 underscore-prefixed functions — 98.3% reachable, 3 dead functions identified.

### Changed
- **samsung.sh refactored** (919 lines → ~40 lines loader): Split into 4 submodules (`modules/samsung/info.sh`, `optimize.sh`, `bloatware.sh`, `light.sh`). All 4 public + 11 private functions preserved.
- **docgen.sh refactored** (914 lines → ~30 lines loader): Split into 6 submodules (`modules/docgen/run.sh`, `reference.sh`, `plugin-api.sh`, `manpage.sh`, `architecture.sh`, `guides.sh`). All 10 docgen_* functions preserved.
- **BATS test suite expanded**: 25 → 90 tests across 23 categories (CLI parsing, info, diagnostics, quality/validation, dev, docgen, rollback, command registry, capability graph, plugin system, JSON output, events, settings, dependency manager, config, backup, benchmark history, profiles, JSON schema, utilities, syntax checks, cross-module integration).
- **Final Engineering Review**: Comprehensive audit across 7 stages (repository integrity, build verification, CI, documentation, testing, security, release decision). Overall score: 3.7/4.0.

### Fixed
- All 78 shell scripts pass `bash -n` syntax check.
- `modules/docgen/guides.sh`: Fixed unterminated heredoc at line 275 (missing MODGUIDE delimiter).
- `lib/plugin.sh`: Fixed 2 SC2295 shell quoting defects in metadata parsing.
- `modules/telemetry.sh`: Removed dead code (`_telemetry_load`/`_telemetry_save` — zero callers).
- `exports/release-ready.json`: Replaced empty file with valid JSON.

## v4.1.0 (2026-07-23)

### Added
- **Cross-Device Validation Framework** (`modules/validate_device.sh` + `validation/oem-profiles.json`): `--validate-device` command with Markdown/JSON/HTML output. OEM profiles for 8 manufacturers (Samsung, Google, OnePlus, Nothing, Xiaomi, Motorola, Oppo, Vivo) with supported/unsupported/partial features, workarounds, and Android version constraints.
- **Runtime Integration Tests** (`tests/bats/toolkit.bats` expanded): 25+ BATS tests covering CLI parsing, command registry, capability graph, rollback, plugin loading, JSON output, event dispatch, benchmark history, config precedence. Target: 95% runtime coverage of public commands.
- **Compatibility Matrix Generator** (`modules/compat_matrix.sh`): Auto-generates `docs/COMPATIBILITY.md` from OEM validation profiles. Per-OEM feature tables, command support, tested backends, verification status.
- **Settings Verification** (`modules/settings_verify.sh`): `--settings-verify` command. Audits every entry in `settings-db.json` for namespace validity, Android version range, OEM constraints, reboot requirements. Marks each: Verified/Deprecated/Experimental/Unsupported.
- **Performance Regression Dashboard** (extended `modules/performance_test.sh`): Historical runs, trend tracking, percentile comparison, regression threshold warnings. `--performance compare` against baselines.
- **Plugin Certification Suite** (`modules/plugin_certify.sh`): `--plugin-certify` command. Validates plugin metadata, config schema, permissions, toolkit version compatibility, event subscriptions, API usage. Generates certification reports.
- **Public API Freeze** (`docs/API_STATUS.md`): Every public API classified as Stable, Experimental, Deprecated, or Internal. Breaking changes require major version bump. All v3.x/v4.0 APIs frozen as Stable.
- **Security Hardening** (`modules/security_harden.sh`): `--security-harden` command. 8 automated checks: unsafe eval, unsafe source, temp file races, world-writable files, unsafe PATH, missing quoting, command injection, weak permissions. Security score (0-100) with CWE mappings.
- **Documentation Quality**: Complete documentation portal with CLI Reference, Module Reference, Library Reference, Plugin SDK, Examples, Troubleshooting, Architecture, Migration Guides, Configuration Reference. All generated from source metadata.
- **Release Packaging** (`modules/packaging.sh`): `--package` command. Builds ZIP, tar.gz, SHA256/SHA512 checksums, SBOM, manifest, release notes, documentation bundle, sample reports/plugins, test reports in `dist/`.
- **Developer Toolkit** (`modules/developer.sh`): `--dev` command with subcommands: `lint` (static analysis orchestration), `format` (shfmt), `docs` (docgen + compat matrix), `tests` (BATS + ShellCheck), `release` (release validation), `clean` (artifact cleanup).
- **Continuous Benchmarking CI**: GitHub Actions job running performance suite on main branch. Compares against historical baseline with configurable regression thresholds.
- **Repository Health Audit** (`modules/repo_health.sh`): `--repo-health` command. Audits duplicate code, dead functions, unused modules, orphan plugins, broken doc links, test coverage. Generates health score and JSON report.
- **Release Readiness** (`modules/release_ready.sh`): `--release-ready` command. 10-point checklist: syntax, static analysis, JSON validation, docs, API freeze, compat matrix, security review, SBOM, version consistency, LTS policy. Returns PASS/WARNING/FAIL.
- **New CLI Commands**: `--validate-device`, `--plugin-certify`, `--settings-verify`, `--security-harden`, `--dev`, `--repo-health`, `--release-ready`, `--package`.

### Changed
- `toolkit.sh`: 9 new CLI actions (validate_device, plugin_certify, settings_verify, security_harden, dev, repo_health, release_ready, package). Updated usage text with all new commands.
- `VERSION`: Updated from `4.0.0` to `4.1.0`.
- `docs/`: Added API_STATUS.md (API freeze document), COMPATIBILITY.md (auto-generated), and expanded docgen output with migration/FAQ/troubleshooting guides.
- `validation/`: Created with 8 OEM validation profiles (oem-profiles.json).
- `.github/workflows/ci.yml`: Added continuous benchmarking job.

### Fixed
- All 67 shell scripts pass `bash -n` syntax check.
- `modules/repo_health.sh`: Fixed syntax error in doc link checker glob loop.
- `modules/security_harden.sh`: All 8 checks now return consistent numeric exit codes.

---

## v4.0.0 (2026-07-23)

### Added
- **Final Security Review** (`modules/security_review.sh`): `--security-review` command. Audits unsafe shell expansion, command injection risks, insecure temp files, missing input validation, privilege assumptions, race conditions, rollback integrity. Produces JSON report with PASS/FAIL verdict.
- **Release Validation** (`modules/release_check.sh`): `--release-check` command. 7-check suite: syntax, version consistency, docs, JSON, tests, plugins, configs. Returns PASS/FAIL summary with detailed results. Used as CI gate.
- **Multi-Device Manager** (`modules/devices.sh`): `--devices`, `--device <serial>`, `--all-devices` commands. Enumerate, select, persist active device across sessions. Execute commands on selected, all, or OEM-filtered devices.
- **Public API** (`lib/api.sh`): Stable, documented API surface with 40+ public functions across logging, backend, capabilities, events, plugins, rollback, reporting, config, benchmarking, packages, devices, settings, and utilities. Each function marked PUBLIC with usage docs.
- **JSON Schema Validation** (`lib/json_schema.sh`): 8 embedded JSON Schemas (settings, report, telemetry, benchmark, plugin, profile, manifest, android-db). Auto-validation of all generated JSON artifacts. Schema files saved to `configs/schemas/`.
- **Android Version Database** (`configs/android-db.json`): Comprehensive database for Android 13–17 with per-version supported commands, deprecated APIs, replacement APIs, and OEM-specific notes. Used for capability decisions.
- **Package Dependency Analysis** (`modules/packages_analysis.sh`): `--packages-analyze` command. Resolves package dependencies, shared UIDs, launcher components, privileged/vendor status, removal risk analysis. Never recommends removing packages with unresolved dependencies.
- **Performance Regression Framework** (`modules/performance_test.sh`): `--performance` command with suite, compare, baseline subcommands. Measures startup time, command latency, memory usage, process count. Compares against historical baselines with configurable threshold.
- **SBOM Generator** (`modules/sbom.sh`): `--sbom` command. Generates SPDX-2.3-compatible Software Bill of Materials. Includes all files with SHA256 checksums, external dependency detection (bash, adb, jq, git, etc.), and summary statistics.
- **Static Analysis Tools** (`modules/static_analysis.sh`): `--static-analysis` command. Integrates ShellCheck, shfmt, markdownlint, jq validation, JSON schema validation in a single run.
- **Documentation Portal** (`modules/docgen.sh` expansion): Migration guide, troubleshooting guide, FAQ, module developer guide. Generated from metadata where practical.
- **Plugin Certification** (`lib/plugin.sh` v3.0): Plugin certification with `plugin_min_toolkit`, `plugin_permissions`, `plugin_events_subscribe`, `plugin_description`, `plugin_author`. Validation on every plugin load. Certified plugins shown with ✓ in `--plugin list`.
- **BATS Test Suite** (`tests/bats/toolkit.bats`): 25 BATS tests covering CLI parsing, command registry, capability graph, rollback, plugin loading, config precedence, JSON output, event dispatch, benchmark history.
- **LTS Policy** (`LTS-POLICY.md`): Long-term support policy with version support matrix, supported Android versions, deprecation policy, compatibility guarantees, plugin compatibility, release cadence, security update SLAs, and maintenance roadmap.
- **CI Enhancements**: Static analysis job (ShellCheck + shfmt + markdownlint + jq + config validation). Static analysis module integrated into release pipeline.
- **New CLI Commands**: `--devices`, `--device`, `--all-devices`, `--release-check`, `--static-analysis`, `--sbom`, `--performance`, `--security-review`, `--packages-analyze`.

### Changed
- `toolkit.sh`: 10 new CLI actions added. New libraries (api, json_schema) loaded during init. Command registry initializes on startup. Event system emits `device_selected` events.
- `lib/plugin.sh`: Upgraded from SDK v2.1 to v3.0 with certification metadata and validation.
- `VERSION`: Updated from `4.0.0-rc1` to `4.0.0`.
- `modules/docgen.sh`: Expanded with migration guide, troubleshooting guide, FAQ, and module guide.

### Fixed
- All 59 shell scripts pass `bash -n` syntax check.
- JSON output initialization now handled at library load time.
- Plugin SDK no longer shadows `plugin_run` function name.
- Device selection persists across sessions via `.active_device` file.

---

## v4.0.0-rc1 (2026-07-23)

### Added
- **Unified Command Registry** (`lib/commands.sh`): 29 commands with names, aliases, descriptions, categories, required backends, capabilities, dependencies, Android/OEM constraints, and auto-generated help text.
- **Capability Graph** (`lib/capability_graph.sh`): 25 capability nodes with transitive dependency resolution (e.g., `benchmark → dumpsys → adb/rish`). `cap_graph_resolve()` computes capability closure. `cap_graph_missing()` shows unmet dependencies.
- **Settings Registry** (`lib/settings.sh`): Query API for `settings-db.json` fields — namespace, min/max Android, OEM filter, default, recommended, risk, reboot, rollback key, type, validation, docs.
- **Internal Event System** (`lib/events.sh`): 9 event types (`backend_selected`, `profile_loaded`, `capability_detected`, `setting_applied`, `rollback_started/ completed`, `report_generated`, `plugin_loaded`, `benchmark_finished`) with subscribe/unsubscribe/emit. Cycle detection. Default console handlers.
- **Machine-Readable Output** (`lib/json_output.sh`): `--json` flag enables structured JSON output for all commands. Nested object/array builders. Error payloads.
- **Watch Mode** (`modules/watch.sh`): `--watch` for real-time device monitoring. Metrics: battery level/temp/charging, memory free/avail/pct, storage free/total/pct, thermal throttling, connectivity. Threshold-based alerts. Configurable interval via `ANDROID_TOOLKIT_WATCH_INTERVAL`.
- **Dependency Manager** (`lib/dependencies.sh`): Detects 15 tools (8 required + 7 optional), installs Termux packages with user confirmation. `--deps-check` command.
- **Enhanced Benchmark** (`modules/benchmark.sh` expansion): Repeated measurement with median/variance, benchmark history (`.benchmarks/`), `--enhanced-benchmark [N]` and `--benchmark-history` commands. Saves/compares results over time.
- **Report Comparison** (`modules/compare.sh`): `--compare <r1.json> <r2.json>` — compares device info, settings, scores, versions across two reports. Generates Markdown and JSON diff reports.
- **Profile Manager** (`modules/profile_manager.sh`): `--profile-manager` with subcommands: list, clone, edit, validate, compare, export, import. Base profile inheritance tracking.
- **Plugin SDK v2.1** (`lib/plugin.sh`): Config schema validation, event hooks (`plugin_on_event()`), plugin priority ordering (`plugin_priority`), custom command registration (`plugin_commands()`), `plugin_load()`/`plugin_unload()` for single plugins, `plugin_help()` for per-plugin info.
- **Documentation Generator** (`modules/docgen.sh`): `--docgen` generates command reference, plugin API reference, settings reference, man page, architecture overview. All in Markdown/HTML/man formats.
- **CI Improvements**: `shfmt` formatting check, `markdownlint`, BATS unit test runner, plugin SDK smoke test, version consistency check, ShellCheck severity annotations, concurrent job groups.

### Changed
- `toolkit.sh`: Expanded library load to 11 libs (added commands, capability_graph, events, settings, json_output, dependencies). Added 10 new CLI actions. Initializes event system, command registry, and capability graph on startup. All new libs are optional/backward-compatible.
- `lib/plugin.sh`: Upgraded from SDK v2.0 to v2.1 with config schema, events, priority, commands, single-plugin load/unload.

### Fixed
- All 48 shell scripts pass `bash -n` syntax check.
- CI release step now correctly exports `VERSION` env var.
- Plugin SDK no longer shadows `plugin_run()` function name.

---

## v3.0.0 (2026-07-24)

### Added
- **Release Management** (`VERSION`, `LICENSE`, `CONTRIBUTING.md`, `SECURITY.md`, `RELEASE.md`): Comprehensive release documentation with MIT license, security policy, contributing guidelines, and release process.
- **Version Commands**: `--version`, `--about`, `--changelog` CLI actions. Version auto-derived from `VERSION` file.
- **Self-Update** (`modules/updater.sh`): `--update [channel]` with stable/beta/nightly channels. Version comparison, GitHub release download, SHA256 checksum verification, automatic backup before update, rollback on failure.
- **Configuration Engine** (`lib/config.sh`): Layered config with priority chain (CLI > Env > User > Profile > Global > Defaults). Supports INI-style files and JSON (via jq). Config validation against known keys.
- **Local Telemetry** (`modules/telemetry.sh`): `--stats` command. Tracks runs, profiles, duration, failures, rollbacks, backends, OEMs. Stored in `.telemetry/stats.json`. Never transmits data.
- **Advanced Logging** (`lib/logging.sh` rewrite): Levels TRACE/DEBUG/INFO/WARN/ERROR/FATAL. Colored console (auto-detects terminal), plain log files, JSON format option. Log rotation by retention days. Execution duration tracking. Module/command name annotation.
- **Interactive TUI** (`modules/tui.sh`): `--tui` command. Uses dialog or whiptail. Full menu system: status, report, profiles, doctor, benchmark, audit, analyze, backup, Samsung tools, plugins, settings. Fallback to text menu when no TUI backend.
- **Task Scheduler** (`modules/scheduler.sh`): `--schedule` command. Supports cron/crond and termux-job-scheduler backends. Templates for daily maintenance, weekly benchmark, monthly report, backup. Termux:Boot auto-start script. No root required.
- **Security Audit** (`modules/audit.sh`): `--audit` command. Checks ADB status, developer options, wireless debugging, SELinux, USB config, Shizuku, security patch age, OEM unlock, disabled critical packages, dangerous app permissions. Risk score 0-100 with PASS/WARNING/FAIL.
- **Package Intelligence** (`modules/packages.sh`): `--packages recommend` command. Auto-classifies installed packages (Samsung bloatware, carrier bloat, Google duplicates, system, third-party). Generates recommendations without automatic disabling.
- **Performance Analyzer** (`modules/analyzer.sh`): `--analyze` command. Collects memory, thermal, CPU, battery, storage metrics. Produces performance score, battery score, stability score, overall health score (0-100). Colored bar charts and recommendations.
- **Report Export** (`modules/export.sh`): `--export report [format]` command. Supports Markdown, JSON, CSV, HTML, PDF (via pandoc), ZIP archive. Bundles reports with logs.
- **CI/CD** (`.github/workflows/ci.yml`): GitHub Actions with ShellCheck, bash syntax, JSON validation, config validation, functional tests, build artifact, release publishing.
- **Plugin SDK v2.0** (`lib/plugin.sh` expansion): Pre-run/post-run hooks, plugin config via `plugin_config()`, dependency checking via `plugin_dependencies()`, version constraint and OEM constraint validation, metadata storage, `plugin_reload()` support, documented public API.
- **Release Build** (`modules/builder.sh`): `--build` command. Generates release ZIP, SHA256 checksum, manifest JSON, documentation bundle, test results, release notes. Production-ready dist artifact.
- **Code Quality**: All 39 shell scripts pass `bash -n`. Zero duplicate functions. Zero dead code patterns. Consistent quoting verified. All JSON and config files validated.

### Changed
- `toolkit.sh`: Added 15 new CLI actions (--version, --about, --changelog, --update, --stats, --schedule, --audit, --analyze, --export, --tui, --build, --packages). Comprehensive usage text with all commands.
- `lib/plugin.sh`: Expanded from simple loader to Plugin SDK v2.0 with pre/post hooks, config, deps, constraints.
- `lib/logging.sh`: Complete rewrite with 6 levels, colors, JSON, rotation, duration tracking.
- `tests/run_tests.sh`: Updated to verify all 25 modules and 8 libraries.

### Fixed
- All new modules pass `bash -n` and functional tests.
- Config loading now uses proper priority chain throughout the toolkit.

---

## v2.0.0 (2026-07-23)

### Added
- **Capability Detection** (`modules/capabilities.sh`): Comprehensive probe of 30+ device properties, runtime environments (ADB/Shizuku/rish/busybox/jq), and feature support (pm compile, device_config, dumpsys services). Results cached in `CAP_*` globals.
- **Settings Database** (`configs/settings-db.json`): Canonical JSON reference of 38 settings across global/secure/system namespaces with per-entry Android version range, OEM filter, default, recommended value, risk level, reboot requirement, and rollback key.
- **Automatic Validation** (`lib/backend.sh`): `backend_settings_put()` now implements a 7-step write protocol: probe namespace → read current → compare → record rollback journal entry → dry-run check → apply → verify by re-reading (auto-restore on mismatch).
- **Rollback Engine** (`lib/rollback.sh`): Journal-based rollback with `rollback_begin`, `rollback_record`, `rollback_close`, `rollback_list`, `rollback_perform`. Supports `--rollback latest`, `--rollback <timestamp>`, `--rollback list`.
- **Doctor Command** (`modules/doctor.sh`): System diagnostics checking backend connectivity, storage performance, protected packages, module syntax, profile parsing, capability availability, and file permissions. Outputs PASS/WARNING/FAIL with recommendations.
- **Benchmark Module** (`modules/benchmark.sh`): Collects CPU (cores, frequencies, governor), memory (total/free/swap), storage (data/system partitions), battery (level, temp, voltage), thermal (dumpsys thermalservice + sysfs), GPU (renderer, vsync, SurfaceFlinger), frame rendering stats, and package compilation state. Outputs JSON + Markdown to logs/.
- **Plugin System** (`lib/plugin.sh`): Auto-loads plugins from `plugins/`. Each plugin exposes `plugin_register()`, `plugin_run()`, and `plugin_cleanup()`. Lifecycle hooks on EXIT/INT/TERM. Includes example plugin (`00-example.sh`).
- **OEM Framework** (`modules/oem.sh` + `modules/oem/`): Device-aware OEM modules for Samsung, Google, OnePlus, Nothing, Xiaomi, Motorola, Oppo, and Vivo. Each module registers OEM-specific capabilities and validates settings against OEM constraints.
- **Testing Framework** (`tests/run_tests.sh`): Test runner with ShellCheck, `bash -n` syntax checks, file integrity verification, config parsing validation, and profile vs settings-db consistency checks.

### Changed
- `toolkit.sh`: Added `--doctor`, `--rollback`, `--benchmark`, `--plugin` CLI actions. OEM framework and plugin system loaded during init.
- `lib/backend.sh`: `backend_settings_put()` now validates writes via 7-step protocol and integrates with rollback journal.
- `configs/default.conf`: Added `ANDROID_TOOLKIT_LOG_RETENTION_DAYS`, `ANDROID_TOOLKIT_AUTO_ROLLBACK`, `ANDROID_TOOLKIT_VALIDATION_STRICT`.
- `configs/settings-db.json`: Initial release with 38 settings.

### Fixed
- `backend_settings_put()` now auto-restores on verification failure instead of silently accepting mismatched values.
- All new modules pass `bash -n` syntax checks.
- Rollback journal auto-cleaned on successful close.

---

## v1.0.5 (2026-07-22)

### Added
- Samsung light performance profile (`--samsung-light`)
- Enhanced Samsung bloatware listing with 100+ packages in 6 categories
- `--list-bloatware` with safety levels (safe/moderate/aggressive/all)
- Samsung Customization Service management (`com.samsung.android.samsungpassautofill`)
- Samsung app background restriction whitelist
- Samsung touch optimization (high touch sensitivity + increased pointer sensitivity)
- `light.conf` profile targeting Samsung battery optimization
- Profile documentation (balanced/performance/powersave/light)

### Changed
- Refactored Samsung module for better code organization
- Updated all profiles with Samsung-specific options
- Enhanced toolkit.sh CLI with Samsung-specific actions
- Updated reporting.sh with Samsung-specific status sections
- README overhaul with comprehensive documentation

---

## v1.0.0 (2026-07-21)

### Added
- Initial release
- ADB, Shizuku/rish, and local backends
- Device detection (Android version, SDK, model, manufacturer, One UI)
- Performance profiles (balanced, performance, powersave)
- ART bytecode compilation
- Cache trimming
- Network configuration refresh
- Battery stats and power saver
- Display resolution/density/refresh rate
- Package disable/enable with protected list
- Settings and packages backup/restore
- Dry-run mode
- Quick status and full device report
- Samsung GOS disable, RAM Plus, refresh rate, multi-core scheduler
- Comprehensive logging with debug levels
