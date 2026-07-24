# Diagnostics Center

Comprehensive device health diagnostics with scoring.

## Diagnostic Categories

| Key | Category | What It Checks |
|-----|----------|----------------|
| `1` | **Battery** | Level, temperature, voltage, technology, health |
| `2` | **Thermal** | Zone temperatures, throttling status |
| `3` | **Memory** | RAM usage, swap, available memory |
| `4` | **Network** | WiFi status, signal strength, IP connectivity |
| `5` | **SELinux** | Enforcing/permissive status, contexts |
| `6` | **All** | Run all diagnostics and compute health score |

## Health Score

- **0–40** ⚠ Critical — Immediate attention needed
- **41–70** ⚡ Warning — Issues detected
- **71–90** ✓ Good — Normal operation
- **91–100** ★ Excellent — Optimal health

Color-coded by severity:
- Red (score < 40): Critical
- Yellow (score < 70): Warning
- Green (score >= 70): Good

## Usage

| Key | Action |
|-----|--------|
| `1-5` | Run individual diagnostic category |
| `6` / `a` | Run all diagnostics |
| `F5` | Refresh results |

## API

```bash
diagnostics_run <category>   # Run specific diagnostics
diagnostics_score             # Compute overall health score
diagnostics_all               # Run full diagnostic suite
```
