---
name: Pull Request
about: Submit changes to Android Toolkit
title: ''
labels: ''
assignees: ''

---

## Description

<!-- Briefly describe the change and why it is needed. -->

Fixes #ISSUE_NUMBER

## Type of Change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that changes existing API/CLI behavior)
- [ ] Documentation update
- [ ] Test improvement
- [ ] CI/build improvement
- [ ] Plugin SDK change
- [ ] Refactoring (no functional change)

## Checklist

### Required

- [ ] I have read CONTRIBUTING.md
- [ ] All existing tests pass: `bash tests/run_tests.sh`
- [ ] New code passes `bash -n` (syntax check)
- [ ] ShellCheck reports 0 new warnings: `shellcheck -x $(find . -name '*.sh')`
- [ ] JSON files are valid: `jq empty` on all modified `.json` files
- [ ] CHANGELOG.md is updated (if user-facing change)
- [ ] VERSION is bumped (if releasing)

### If Adding a New Command or Flag

- [ ] CLI help updated in `toolkit.sh` usage text
- [ ] Command registered in `lib/commands.sh` (if applicable)
- [ ] Module lazy-loads via `_load_module` in dispatch

### If Adding a New Module

- [ ] Module file created in `modules/` with `_load_module` support
- [ ] Module registered in `tests/run_tests.sh`
- [ ] BATS test(s) added in `tests/bats/`
- [ ] Module documented in DEVELOPER.md

### If Changing Plugin SDK

- [ ] PLUGIN_API.md updated
- [ ] Plugin certification updated in `modules/plugin_certify.sh`
- [ ] Example plugin updated in `plugins/00-example.sh`
- [ ] SDK version documented in LTS-POLICY.md

### If Adding a Dependency

- [ ] Dependency added to `lib/dependencies.sh`
- [ ] Dependency check added to `--deps-check`
- [ ] CI install step added in `.github/workflows/ci.yml`

## Testing Performed

<!-- Describe how you tested this change. Include device/backend info. -->

- [ ] Tested on real device (specify model + Android version)
- [ ] Tested with ADB backend
- [ ] Tested with rish/Shizuku backend
- [ ] Tested dry-run mode (`--dry-run`)
- [ ] BATS test(s) added/updated

## Screenshots / Logs

<!-- If applicable, add logs or screenshots to demonstrate the change. -->

## Additional Context

<!-- Add any other context about the PR here. -->
