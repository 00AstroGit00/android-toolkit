---
name: Security Report
about: Report a security vulnerability (private disclosure)
title: ''
labels: security
assignees: ''

---

> **⚠️ IMPORTANT:** If this is a security vulnerability, please do **NOT** open a public issue.  
> See [SECURITY.md](../blob/main/SECURITY.md) for our disclosure policy.

## Description

<!-- Briefly describe the vulnerability. -->

## Severity Estimate

- [ ] Critical — Remote code execution or privilege escalation
- [ ] High — Unauthorized data access or persistent DoS
- [ ] Medium — Limited information disclosure or crash
- [ ] Low — Best practice violation with limited impact

## Component

- [ ] CLI / toolkit.sh
- [ ] Plugin system (lib/plugin.sh)
- [ ] Backend (lib/backend.sh) — ADB / rish
- [ ] Module (specify):
- [ ] Library (specify):
- [ ] Update mechanism (modules/updater.sh)
- [ ] CI pipeline (.github/workflows/)
- [ ] Dependencies
- [ ] Other:

## Attack Vector

<!-- How would an attacker exploit this? What prerequisites are needed? -->

## Steps to Reproduce

```bash
# Commands or steps to reproduce
```

1.
2.
3.

## Impact

<!-- What could an attacker achieve? -->

## Proposed Fix

<!-- If known, describe or link to a fix. -->

## Disclosure

- [ ] I would like to be credited for this finding (provide name/handle)
- [ ] I prefer to remain anonymous

## Checklist

- [ ] I have confirmed this is a security issue, not a bug
- [ ] I have checked existing advisories for duplicates
- [ ] I understand the 14-day disclosure timeline
