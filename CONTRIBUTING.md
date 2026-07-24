# Contributing to Android Toolkit

Thank you for your interest in contributing! This document outlines the guidelines for contributing to the Android Toolkit project.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Ways to Contribute](#ways-to-contribute)
- [Reporting Bugs](#reporting-bugs)
- [Reporting Security Vulnerabilities](#reporting-security-vulnerabilities)
- [Suggesting Enhancements](#suggesting-enhancements)
- [Submitting Pull Requests](#submitting-pull-requests)
- [Coding Standards](#coding-standards)
- [Testing Requirements](#testing-requirements)
- [Review Process](#review-process)
- [Plugin Development](#plugin-development)
- [Documentation](#documentation)
- [Project Structure](#project-structure)
- [License](#license)

---

## Code of Conduct

We expect all contributors to be respectful and constructive. Harassment or disruptive behaviour is not tolerated.

---

## Ways to Contribute

1. **Bug reports** — Open a GitHub issue using the Bug Report template.
2. **Feature requests** — Open a GitHub issue using the Feature Request template.
3. **Security disclosures** — See [SECURITY.md](SECURITY.md) for private disclosure.
4. **Documentation** — Fix typos, clarify explanations, add examples.
5. **Plugins** — Develop and share plugins via the plugin ecosystem.
6. **Code contributions** — Submit pull requests for bug fixes or approved features.

---

## Reporting Bugs

1. **Check existing issues** first — your bug may already be reported.
2. Use the **Bug Report template** (`.github/ISSUE_TEMPLATE/01-bug-report.md`).
3. **Include the output of:**
   ```bash
   ./toolkit.sh --version
   ./toolkit.sh --doctor 2>&1 | tail -30
   ```
4. Include your device model, Android version, and backend (ADB/Shizuku).
5. Provide clear, minimal reproduction steps.
6. Attach relevant log files from `logs/`.

---

## Reporting Security Vulnerabilities

**Do not open a public GitHub issue for security vulnerabilities.**

See [SECURITY.md](SECURITY.md) for:
- Private disclosure via GitHub Security Advisories
- Encryption keys (if available)
- 14-day disclosure timeline
- Severity classification

---

## Suggesting Enhancements

1. Use the **Feature Request template** (`.github/ISSUE_TEMPLATE/02-feature-request.md`).
2. Explain the problem clearly — focus on *what* you need, not *how* to implement it.
3. Describe use cases and expected behaviour.
4. Note whether the feature requires root, ADB, or Shizuku.
5. Indicate if you're willing to implement it.

---

## Submitting Pull Requests

### Prerequisites

- Read this entire guide.
- Fork the repository.
- Create a branch following the naming convention.

### Branch Naming

| Type | Format | Example |
|------|--------|---------|
| Feature | `feat/short-description` | `feat/add-battery-cycle-count` |
| Bug fix | `fix/short-description` | `fix/rollback-empty-journal` |
| Documentation | `docs/short-description` | `docs/api-correction` |
| Refactoring | `refactor/short-description` | `refactor/samsung-submodules` |
| CI | `ci/short-description` | `ci/fix-duplicate-jobs` |
| Plugin | `plugin/short-description` | `plugin/battery-health` |
| Hotfix | `hotfix/cve-YYYY-XXXX` | `hotfix/cve-2026-1234` |

### Commit Messages

Use conventional commits:

```
type(scope): description

[optional body]

[optional footer]
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `ci`, `chore`  
Scope: `cli`, `plugin`, `backend`, `samsung`, `docgen`, `ci`, etc.

Examples:
```
fix(plugin): correct namespace collision in plugin_run dispatch

feat(samsung): add battery cycle count reporting

docs(api): fix parameter order in api_settings_lookup
```

### Pre-Submit Checklist

- [ ] I have read CONTRIBUTING.md
- [ ] The PR template checklist is complete
- [ ] All existing tests pass
- [ ] New code passes `bash -n`
- [ ] ShellCheck reports 0 new warnings
- [ ] JSON files are valid
- [ ] CHANGELOG.md is updated (if user-facing change)
- [ ] VERSION is bumped (only for releases)

---

## Coding Standards

### Shell

- **Minimum Bash version:** 5.0 (checked at startup)
- **Do NOT use:** `set -e` in toolkit.sh (failures handled gracefully)
- **Do use:** `set -o pipefail` in entry point scripts
- **Do use:** `local` for all function-scoped variables
- **Preferred over `eval`:** arrays, indirect references, or restructure

### Style

Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) with these clarifications:

| Rule | Standard | Example |
|------|----------|---------|
| Indentation | 4 spaces, no tabs | `    local x=1` |
| Line length | 120 characters max | Break long pipes |
| Quoting | Always quote variables | `"${var}"` not `${var}` |
| Subshells | Use `$()` not backticks | `result="$(cmd)"` |
| Tests | Use `[[ ]]` not `[ ]` | `[[ -f "$file" ]]` |
| Arithmetic | Use `$(( ))` | `$(( x + 1 ))` |
| Functions | `name()` not `function name` | `my_func() {` |
| Braces | Always use braces for variables | `"${var}"` not `$var` |

### Naming Conventions

| Pattern | Scope | Example |
|---------|-------|---------|
| `snake_case` | Functions and local variables | `detect_device_info()` |
| `UPPER_SNAKE_CASE` | Exported globals, constants | `ANDROID_TOOLKIT_VERSION` |
| `_prefixed` | Private/internal functions | `_audit_add()` |
| `CAP_*` | Capability names | `CAP_ADB`, `CAP_DUMPSYS` |
| `api_*` | Public API functions | `api_device_manufacturer()` |
| `module_*` | Module entry points | `benchmark_run()` |

### Function Documentation

Every public function must have a comment block:

```bash
##############################################
# Brief description of purpose.
# Arguments:
#   $1: first argument (type, expected values)
#   $2: second argument
# Returns: description of return value/stdout
# Outputs: side effects or files created
##############################################
my_function() {
```

### Error Handling

- Return non-zero on failure — never call `exit` in library/module code.
- Use `|| true` for operations that may fail in non-critical paths.
- Use `log_error` for user-facing errors, `log_debug` for internal diagnostics.
- Prefer early return over deep nesting:

```bash
# Good
my_func() {
    [[ -f "$file" ]] || { log_error "File not found"; return 1; }
    # ... main logic
}

# Avoid
my_func() {
    if [[ -f "$file" ]]; then
        # ... deep nesting
    else
        log_error "File not found"
    fi
}
```

---

## Testing Requirements

### Mandatory Checks

Every contribution must pass:

```bash
# 1. Syntax check
bash -n toolkit.sh
bash -n lib/*.sh modules/*.sh

# 2. ShellCheck (0 errors)
shellcheck -x $(find . -name '*.sh' -not -path '*/.git/*')

# 3. JSON validation
jq empty configs/*.json validation/*.json exports/*.json

# 4. Functional tests
bash tests/run_tests.sh

# 5. Formatting check
shfmt -d -i 4 -bn -ci $(find . -name '*.sh' -not -path '*/.git/*')
```

### BATS Tests

- New modules require BATS test coverage.
- Run BATS tests: `bats tests/bats/` (requires `bats-core`).
- Test categories should match module structure.
- Aim for ≥80% command coverage.

### Test Categories (Existing)

| Category | Tests | File |
|----------|-------|------|
| CLI parsing | 8 | `tests/bats/toolkit.bats` |
| Info/help | 4 | `tests/bats/toolkit.bats` |
| Diagnostics | 6 | `tests/bats/toolkit.bats` |
| Quality/validation | 6 | `tests/bats/toolkit.bats` |
| Developer | 4 | `tests/bats/toolkit.bats` |
| Docgen | 4 | `tests/bats/toolkit.bats` |
| Rollback | 4 | `tests/bats/toolkit.bats` |
| Command registry | 4 | `tests/bats/toolkit.bats` |
| Capability graph | 4 | `tests/bats/toolkit.bats` |
| Plugin system | 6 | `tests/bats/toolkit.bats` |
| JSON output | 4 | `tests/bats/toolkit.bats` |
| Events | 4 | `tests/bats/toolkit.bats` |
| Settings | 4 | `tests/bats/toolkit.bats` |
| Dependencies | 4 | `tests/bats/toolkit.bats` |
| Config | 4 | `tests/bats/toolkit.bats` |
| Backup | 4 | `tests/bats/toolkit.bats` |
| Benchmark history | 4 | `tests/bats/toolkit.bats` |
| Profiles | 4 | `tests/bats/toolkit.bats` |
| JSON schema | 4 | `tests/bats/toolkit.bats` |
| Utilities | 4 | `tests/bats/toolkit.bats` |
| Sytnax checks | 4 | `tests/bats/toolkit.bats` |
| Cross-module | 2 | `tests/bats/toolkit.bats` |

---

## Review Process

1. **Draft PR** — Submitter opens PR with completed template.
2. **CI validation** — Automated checks run (syntax, ShellCheck, JSON, BATS).
3. **Initial review** — Maintainer reviews within 5 business days.
4. **Feedback** — Reviewer requests changes or approves.
5. **Revisions** — Submitter addresses feedback.
6. **Final review** — Maintainer re-reviews.
7. **Merge** — Squash-merge to `main` with conventional commit message.

### Merge Criteria

All must be satisfied:

- [ ] All CI checks pass
- [ ] At least one maintainer approval
- [ ] No unresolved review comments
- [ ] CHANGELOG.md updated (user-facing changes)
- [ ] Tests added/updated (if changing functionality)
- [ ] ShellCheck: 0 errors, warnings reviewed
- [ ] `bash -n` passes on all modified files

---

## Plugin Development

See [PLUGIN_API.md](PLUGIN_API.md) for the complete Plugin SDK reference.

### Getting Started

```bash
cp plugins/00-example.sh plugins/my-plugin.sh
# Edit the required variables and functions
# Test: toolkit.sh --plugin my-plugin
# Certify: toolkit.sh --plugin-certify my-plugin
```

### Example Plugins

The `plugins/examples/` directory contains annotated examples:

| File | Demonstrates |
|------|-------------|
| `10-command-extension.sh` | Custom CLI commands via `plugin_commands()` |
| `20-reporting.sh` | Device data collection using `api_*` functions |
| `30-validation.sh` | Prerequisite validation, config schema, dependencies |
| `40-configuration.sh` | Persistent config via `plugin_config_*` API |

### Publishing Guidelines

When sharing plugins:

1. Use a unique `plugin_name` that doesn't conflict with existing plugins.
2. Set `plugin_version` following SemVer.
3. Set `plugin_supported_oems` and `plugin_supported_android` accurately.
4. Include a `plugin_register()` function for capability declaration.
5. Implement `plugin_cleanup()` for resource cleanup.
6. Certify your plugin: `toolkit.sh --plugin-certify my-plugin`.
7. License your plugin (MIT recommended for compatibility).

---

## Documentation

### When to Update Documentation

- **CLI changes**: Update `toolkit.sh` usage text + `lib/commands.sh`.
- **New modules**: Update `DEVELOPER.md` architecture section.
- **API changes**: Update `lib/api.sh` function headers + `docs/API_STATUS.md`.
- **Plugin SDK changes**: Update `PLUGIN_API.md` + `modules/plugin_certify.sh`.
- **Release**: Update `CHANGELOG.md` + `VERSION`.

### Generated Documentation

Some documentation is auto-generated:

```bash
# Generate all docs
./toolkit.sh --docgen

# Generate compatibility matrix
./toolkit.sh --compat-matrix
```

Generated files should be committed alongside source changes.

---

## Project Structure

```
toolkit.sh              — CLI entry point (lazy-loads modules)
lib/                    — Core libraries (loaded at startup)
  logging.sh            — Logging framework
  backend.sh            — ADB/rish backend abstraction
  plugin.sh             — Plugin loading and isolation
  rollback.sh           — State change journaling
  commands.sh           — Command registry
  ...                   — (13 libraries total)
modules/                — Feature modules (lazy-loaded)
  performance.sh        — Profile application
  battery.sh            — Battery diagnostics
  samsung/              — Samsung-specific features (4 submodules)
  docgen/               — Documentation generator (6 submodules)
  ...                   — (40+ modules total)
plugins/                — User plugins (auto-loaded)
  examples/             — Annotated example plugins
 00-example.sh          — Default example plugin
configs/                — JSON configuration databases
tests/                  — Test suites
  bats/                 — BATS integration tests
  run_bats.sh           — Bash shim for BATS
  run_tests.sh          — Test runner
docs/                   — Documentation files
.github/                — GitHub configuration
  workflows/            — CI pipeline
  ISSUE_TEMPLATE/       — Issue templates
  PULL_REQUEST_TEMPLATE.md — PR template
```

---

## License

By contributing, you agree that your contributions will be licensed under the MIT License (see [LICENSE](LICENSE)).
