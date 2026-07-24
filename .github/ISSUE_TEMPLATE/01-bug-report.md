---
name: Bug Report
about: Report a problem with the Android Toolkit
title: ''
labels: bug
assignees: ''

---

## Bug Description

<!-- Clear and concise description of the bug. -->

## Environment

- **Toolkit version:** <!-- output of `./toolkit.sh --version` -->
- **Device model:**
- **Android version:**
- **OEM / ROM:**
- **Backend:** <!-- ADB (USB/wireless) / Shizuku (rish) / auto -->
- **Shell:** <!-- bash --version -->
- **Install method:** <!-- git clone / release ZIP / package manager -->

## Reproduction Steps

```bash
# Exact command used
./toolkit.sh <flags> <command>
```

1.
2.
3.

## Expected Behavior

## Actual Behavior

<!-- Include error messages, unexpected output, or crash logs. -->

```
```

## Diagnostic Information

```bash
# Please include the output of:
./toolkit.sh --doctor 2>&1 | tail -30
```

<details>
<summary>Diagnostic output</summary>

```
```

</details>

## Logs

<!-- If available, attach the log file (logs/toolkit-*.log) -->

## Screenshots

<!-- If applicable, add screenshots to help explain the problem. -->

## Additional Context

- [ ] This bug appeared after updating from a previous version
- [ ] This bug happens consistently
- [ ] This bug happens intermittently
- [ ] I can reproduce with `--dry-run`

## Workaround

<!-- If you found a way to work around the bug, describe it here. -->
