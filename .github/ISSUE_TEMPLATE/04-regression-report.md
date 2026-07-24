---
name: Regression Report
about: Report a behavior change or regression from a previous version
title: ''
labels: regression
assignees: ''

---

## Regression Summary

<!-- One-line description of what stopped working. -->

## Version Information

- **Previous working version:** <!-- e.g., v4.1.0 -->
- **Current version:** <!-- e.g., v4.2.0 -->
- **Toolkit command:**

## Environment

- **Device model:**
- **Android version:**
- **OEM / ROM:**
- **Backend:** <!-- ADB / rish / auto -->
- **Verbose output:** <!-- Run with --verbose if applicable -->

## Expected Behavior

<!-- What happened in the previous version? -->

## Actual Behavior

<!-- What happens now? -->

## Reproduction

```bash
# Exact command that demonstrates the regression
./toolkit.sh --backend adb --<command>
```

1.
2.
3.

## Evidence

<details>
<summary>Previous version output (v4.1.0)</summary>

```
```

</details>

<details>
<summary>Current version output (v4.2.0)</summary>

```
```

</details>

## Impact

- [ ] Blocking — cannot use feature at all
- [ ] Major — feature works incorrectly
- [ ] Minor — cosmetic or non-functional difference
- [ ] Performance — slower than before

## Workaround

<!-- Is there a way to achieve the same result? -->
