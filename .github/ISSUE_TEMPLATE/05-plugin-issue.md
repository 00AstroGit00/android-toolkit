---
name: Plugin Issue
about: Report a plugin compatibility or execution problem
title: ''
labels: plugin
assignees: ''

---

## Plugin Information

- **Plugin name:**
- **Plugin version:**
- **SDK version:** <!-- v2.0 / v2.1 / v3.0 -->
- **Toolkit version:** <!-- output of `./toolkit.sh --version` -->

## Environment

- **Device model:**
- **Android version:**
- **OEM / ROM:**
- **Backend:** <!-- ADB (USB/wireless) / Shizuku (rish) -->
- **Toolkit command used:** <!-- e.g., `--plugin <name>`, `--plugin-certify <name>` -->

## Issue Type

- [ ] Plugin fails to load
- [ ] Plugin executes with wrong output
- [ ] Plugin causes toolkit crash
- [ ] Plugin timeout
- [ ] Plugin certification fails
- [ ] Metadata / variables not recognized
- [ ] Conflict with another plugin
- [ ] Other

## Reproduction Steps

```bash
# Full command used
./toolkit.sh --plugin <name> [args]
```

1.
2.
3.

## Expected Behavior

## Actual Behavior

## Logs

<!-- Paste relevant output, including any [ERROR] or [WARNING] messages. -->

```
```

## Plugin Code

<!-- If the plugin is not private, paste or link to its source. -->

```bash

```
