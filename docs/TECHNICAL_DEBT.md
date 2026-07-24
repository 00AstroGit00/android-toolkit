# Technical Debt Inventory — v4.1.0

> Generated: 2026-07-23 | Scope: Final Engineering Audit

## Summary

| Quadrant | Count | Description |
|----------|-------|-------------|
| 🔴 **Critical** | 0 | Must fix before next release |
| 🔴 **High** | 3 | Should fix; causes incorrect behavior |
| 🟡 **Medium** | 4 | Should fix; impacts maintainability |
| 🟢 **Low** | 4 | Monitor; cosmetic or future concerns |

**Total items: 11**

---

## 🔴 High Severity

### H1 — CI job ID collision (FIXED)

- **File**: `.github/workflows/ci.yml` (lines 19, 107)
- **Issue**: Duplicate job ID `static-analysis` caused the comprehensive static analysis suite (ShellCheck, shfmt, markdownlint, jq, config validation) to be silently overridden by a bare bash syntax check.
- **Impact**: CI never ran ShellCheck, shfmt, markdownlint, JSON validation, or config validation.
- **Fix**: ✅ Renamed to `static-analysis-full` (line 19) and `bash-syntax` (line 107). Build dependency updated.
- **Effort**: 5 minutes

### H2 — Build dependency referencing non-existent job (FIXED)

- **File**: `.github/workflows/ci.yml` (line 288)
- **Issue**: Build job `needs` referenced `bash-syntax` which did not exist as a job ID.
- **Impact**: Build job could not resolve dependency graph correctly.
- **Fix**: ✅ Fixed as consequence of H1.
- **Effort**: 0 (fixed by H1)

### H3 — OEM case wildcard fallthrough (FIXED)

- **File**: `modules/oem.sh` (line 33)
- **Issue**: `xiaomi|redmi|poco|*` — the `*` wildcard matched ANY manufacturer, causing Motorola, Oppo, Vivo, and the default fallback to be unreachable.
- **Impact**: Wrong OEM module could load; OEM-specific features broken for 3+ manufacturers.
- **Fix**: ✅ Removed `|*` wildcard. Verified all 8 OEM patterns match correctly.
- **Effort**: 2 minutes

---

## 🟡 Medium Severity

### M1 — Missing attribution headers (FIXED)

- **Files**: 55 `.sh` files across `lib/` and `modules/`
- **Issue**: Files did not contain "Part of the Android Toolkit" header line.
- **Impact**: Inconsistent project identity; files could be confused as standalone scripts.
- **Fix**: ✅ Added to all 55 files.
- **Effort**: 10 minutes

### M2 — compat_matrix.sh not directly invocable

- **File**: `modules/compat_matrix.sh`
- **Issue**: Module is never loaded from `toolkit.sh`; only indirectly via `modules/developer.sh` in `--dev docs`.
- **Impact**: No direct CLI command for users; the compatibility matrix generator is hidden.
- **Recommendation**: Add a `--compat-matrix` CLI action or document as "support module".
- **Effort**: 20 minutes (to add CLI entry)

### M3 — Two oversized modules

- **Files**: `modules/samsung.sh` (919 lines), `modules/docgen.sh` (914 lines)
- **Issue**: Largest modules approach 1K lines, exceeding typical maintainability threshold.
- **Impact**: Harder to review, test, and maintain.
- **Recommendation**: Split into smaller sub-modules (e.g., `samsung-bloatware.sh`, `samsung-optimize.sh`; `docgen-cli.sh`, `docgen-format.sh`).
- **Effort**: 4–8 hours (refactoring, careful not to break existing API)

### M4 — Stale template URL (FIXED)

- **File**: `lib/backend.sh` (line 18)
- **Issue**: Header contained `https://github.com/yourusername/android-toolkit` (placeholder URL).
- **Impact**: Unprofessional appearance; broken if anyone followed the link.
- **Fix**: ✅ Removed the URL.
- **Effort**: 1 minute

---

## 🟢 Low Severity

### L1 — Public API layer unused internally

- **File**: `lib/api.sh`
- **Issue**: All 55 `api_*` functions are wrappers that delegate to internal functions. No module or `toolkit.sh` calls any `api_*` function directly.
- **Impact**: Public API exists for external consumers but has zero internal adoption. Risk of API drift — internal functions could change while wrappers remain unchanged.
- **Recommendation**: Adopt `api_*` functions in `toolkit.sh` action dispatch as the interface layer, reserving direct internal calls for module-internal use.
- **Effort**: 2–4 hours

### L2 — Underscore-prefixed internal functions need verification

- **File**: Multiple `lib/*.sh` files
- **Issue**: Functions like `_rish_validate`, `_backend_build_cmd`, `_plugin_load_single`, `_log_*`, etc. are marked internal with `_` prefix but some may be unreachable.
- **Impact**: Dead code that can confuse maintainers.
- **Recommendation**: Audit call chains with `bash --dump-po-strings` or grep to verify each `_`-prefixed function is called at least once.
- **Effort**: 1 hour

### L3 — No test coverage for 30+ modules

- **Files**: `tests/bats/toolkit.bats` (25 tests), `tests/performance/`
- **Issue**: BATS test suite covers CLI parsing, command registry, capability graph, rollback, plugin loading, config, JSON output, events, benchmark history — but only 8 core areas. 30+ modules have zero test coverage.
- **Impact**: Regressions in untested modules may go undetected.
- **Recommendation**: Prioritize tests for device-facing modules (samsung, performance, packages, network, display, battery) that can change device state.
- **Effort**: 8–16 hours

### L4 — No plugin sandboxing

- **File**: `lib/plugin.sh`
- **Issue**: Plugins run in the same shell process with full access to all functions and variables.
- **Impact**: A malicious or buggy plugin can corrupt toolkit state, read internal data, or execute arbitrary commands.
- **Recommendation**: Consider subshell execution or function unsetting after plugin runs.
- **Effort**: 4–8 hours

---

## Debt Trend

| Version | Items Added | Items Fixed | Net Debt |
|---------|-------------|-------------|----------|
| v4.0.0-rc1 | 0 (baseline) | — | 0 |
| v4.0.0 | 4 (L1, L2, L3, L4) | 0 | +4 |
| v4.1.0 (pre-audit) | 4 (H1, H2, H3, M4) | 0 | +8 |
| **v4.1.0 (post-audit)** | 0 | **6** | **+2** |

## Recommendations

1. **Before v4.2.0**: Add direct CLI entry for `compat_matrix.sh` (M2), adopt `api_*` in toolkit.sh (L1)
2. **Before v5.0.0**: Split oversized modules (M3), add plugin sandboxing (L4), expand test coverage (L3)
3. **Ongoing**: Verify `_`-prefixed function reachability (L2) as part of repo health checks
