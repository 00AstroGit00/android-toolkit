# Reachability Analysis — v4.2.0

> Generated: 2026-07-24 | Scanner: `grep`-based static analysis

## Summary

| Metric | Count |
|--------|-------|
| Total `_`-prefixed functions | 175 |
| Reachable (called from ≥1 other function) | 172 (98.3%) |
| **Truly dead** (zero callers anywhere) | **3 (1.7%)** |

## Dead Functions to Remove

| Function | File | Reason |
|----------|------|--------|
| `_telemetry_load` | `modules/telemetry.sh:51` | Never called — public functions read `$TELEMETRY_FILE` directly |
| `_telemetry_save` | `modules/telemetry.sh:63` | Never called — public functions write `$TELEMETRY_FILE` directly |
| `_mymodule_helper` | `modules/docgen/guides.sh:305` | Template stub function — only exists as documentation example |

## Action Required

**Remove `_telemetry_load` and `_telemetry_save`** (telemetry.sh lines 51–67):

```diff
- # Load telemetry data into a global variable.
- _telemetry_load() {
-     if command -v jq &>/dev/null; then
-         TELEMETRY_DATA="$(cat "$TELEMETRY_FILE" 2>/dev/null || echo '{}')"
-     else
-         TELEMETRY_DATA=""
-     fi
- }
-
- # Save telemetry data.
- _telemetry_save() {
-     if command -v jq &>/dev/null; then
-         echo "$TELEMETRY_DATA" > "$TELEMETRY_FILE"
-     fi
- }
-
```

**Keep `_mymodule_helper`** as-is — it serves as a documentation template for third-party developers writing module guides. The entire `mymodule_run()` block on lines 288–307 is part of docgen's educational output.

## Methodology

- Scanned all `.sh` files in `lib/`, `modules/`, and `toolkit.sh`
- Extracted `_`-prefixed function definitions via regex `^\s*_\w+\s*\(\)`
- For each function, counted ALL callers across the entire codebase, excluding the definition line itself
- Functions with zero total callers classified as "truly dead"

## Observations

- All library `_`-prefixed functions (`_log_*`, `_plugin_*`, `_backend_*`) are reachable through their public wrappers within the same file
- All module `_`-prefixed helpers are called by their corresponding public module functions
- No module is completely orphaned
- The `_telemetry_*` pair appears to be vestigial code from an earlier iteration where the module used `TELEMETRY_DATA` as an in-memory buffer; the current implementation reads/writes the JSON file directly
