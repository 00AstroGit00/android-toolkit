# Android Toolkit v5 Roadmap

> **Status:** Planning — No development has begun.  
> **Reference implementation:** v4.2.0 Stable  
> **Target:** H2 2027 at earliest  

---

## Principles

1. **No speculative features.** Every proposal must be backed by verified issues, community demand, or Android platform evolution.
2. **Backward compatibility.** v4.x plugins, profiles, and commands continue to work in v5.
3. **Incremental migration.** No flag-day rewrites.
4. **Evidence-based.** Proposals reference specific issues, CHANGELOG entries, or audit findings.

---

## Proposed Workstreams

### 1. Plugin Namespace Isolation

**Motivation:** Issue PLG-01 (identified in v4.2.0 production validation). Multiple plugins cannot coexist because all plugins define the same `plugin_run()` function name in global scope.

**Proposed approach:**
- Plugins define uniquely-named functions (e.g., `plugin_run_<name>()`).
- The plugin registry dispatches to the correct function based on the plugin name.
- `_plugin_exec_isolated()` uses the registered function name instead of hardcoded `plugin_run`.
- Legacy plugins (SDK v2.0/v2.1/v3.0) without unique function names are dispatched through a compatibility shim.

**Evidence:** `reports/plugin-validation.md` Issue #PLG-01. Confirmed by ShellCheck analysis: multiple plugins with same function names silently overwrite each other.

### 2. JSON Output Wiring

**Motivation:** Issue JSON-01 (identified in v4.2.0). The `--json` flag exists and sets `JSON_OUTPUT=true`, but no command actually checks this variable.

**Proposed approach:**
- `reporting_status()` and `reporting_full_report()` check `api_json_enabled()`.
- When JSON mode is active, output structured JSON instead of formatted text.
- All modules that produce output support `--json` (opt-in per module).

**Evidence:** `reports/platform-validation.md` Issue #JSON-01. Pre-existing since v4.1.0 CHANGELOG entry.

### 3. Android 17+ Support

**Motivation:** Android 17 (SDK 37) is already in preview. New privacy restrictions, permission models, and backend changes require toolkit updates.

**Proposed approach:**
- Extend OEM profiles for Android 17 behavior changes.
- Update backend abstraction for any new ADB/rish protocol changes.
- Test all commands against Android 17 preview builds.
- Add SDK 37 to `plugin_supported_android` validation.

**Evidence:** `LTS-POLICY.md` shows Android 17 as "Preview / Capability-limited". Community demand expected as devices ship with Android 17.

### 4. ShellCheck Zero-Warnings Baseline

**Motivation:** Currently 6 warnings (SC2155, SC2046, SC2294, SC2206) and ~100 info/style-level findings exist across the codebase.

**Proposed approach:**
- Fix all remaining warnings (SC2155: declare+assign separately, SC2046/SC2206: quoting).
- Evaluate info/style findings and suppress or fix each.
- Add CI enforcement: `shellcheck` must pass at warning level for PRs.

**Evidence:** `reports/ci-validation.md` ShellCheck section. 6 warnings documented with file/line references.

### 5. Performance Baselining

**Motivation:** No formal performance regression detection. The CI benchmarking job exists but lacks automated threshold enforcement.

**Proposed approach:**
- Establish baseline timings for `--help`, `--status`, `--report`, and `--benchmark`.
- Enforce <10% regression threshold in CI.
- Track startup time, command dispatch, and device query latency.

**Evidence:** `STABLE_RELEASE_REPORT.md` Performance Results section. Current timings on reference device (Samsung S23U) establish informal baseline.

### 6. Generated Documentation Synchronization

**Motivation:** `docs/COMPATIBILITY.md` has never been generated. `--docgen` output is not committed, making it impossible to verify against source.

**Proposed approach:**
- Run `compat_matrix_generate` and `docgen_run` as CI steps.
- Commit generated docs alongside source changes.
- Add CI check: generated docs must be up to date with source.

**Evidence:** `STABLE_RELEASE_REPORT.md` Documentation Results — COMPATIBILITY.md missing.

### 7. Plugin SDK v4.0

**Motivation:** The namespace issue (workstream #1) requires a new SDK version. v4.0 should also add:
- Event-driven plugin hooks (react to device state changes).
- Plugin-to-plugin communication.
- Safe mode by default.

**Proposed approach:**
- SDK v4.0 = SDK v3.0 + namespace isolation + event hooks.
- Backward compatibility: v3.0 plugins load under a compatibility shim.
- Plugin certification (v4.0) checks for namespace compliance.

**Evidence:** Plugin community growth projections. No breaking changes to existing plugins.

### 8. CI Pipeline Consolidation

**Motivation:** Issue CI-01: 6 individual jobs duplicate work done in `static-analysis-full`. The `version-consistency` job has incorrect checks.

**Proposed approach:**
- Remove duplicate individual jobs.
- Make `static-analysis-full` a required check for all PRs.
- Fix `version-consistency` to check `VERSION` file and `CHANGELOG.md` correctly.

**Evidence:** `reports/ci-validation.md` CI Pipeline Audit section.

---

## Non-Proposals (Explicitly Excluded)

The following are **not** planned for v5:

| Proposal | Reason for Exclusion |
|----------|---------------------|
| Python/Rust rewrite | Would break all existing workflows and plugins. No user demand. |
| GUI application | Out of scope. Tool is designed as a CLI toolkit. |
| Root support | Contradicts security model. ADB/rish are sufficient. |
| iOS support | Different platform, different architecture. Separate project. |
| Cloud sync/telemetry | Privacy principle: all data stays local. |
| Package manager distribution | Increases maintenance burden. Git/zip distribution works. |

---

## v5 Migration Guide (Preliminary)

When v5 is released, migrations from v4.x will involve:

1. **Plugin updates** (if using multiple plugins): Plugin authors may need to adopt namespace isolation. Single-plugin setups require no changes.
2. **SDK v3.0 plugins** continue to work with a compatibility shim.
3. **Profiles** (v3.x and v4.x) are forward-compatible without changes.
4. **Commands** remain identical. No CLI breaking changes expected.
5. **Configuration files** maintain the same format.

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-07-24 | Plugin namespace isolation is highest priority | Verified defect (PLG-01), impacts all multi-plugin users |
| 2026-07-24 | SDK v4.0 tied to namespace work | Cannot fix namespace without SDK version bump |
| 2026-07-24 | No GUI or root support | Contradicts project philosophy |
| 2026-07-24 | v5 targeted H2 2027 at earliest | v4.2.0 is production-ready; no urgency |

---

## How to Propose Additions

To propose a workstream for v5:

1. Open a GitHub issue using the Feature Request template.
2. Include evidence (user reports, Android changelog references, metrics).
3. Explain why it cannot be done in v4.x.
4. If the proposal involves a breaking change, include a migration plan.

Proposals that lack evidence, duplicate existing functionality, or contradict project principles will be declined.
