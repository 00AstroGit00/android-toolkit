# Security Policy

## Supported Versions

| Version | Status | Supported Android | LTS End |
|---------|--------|-------------------|---------|
| 4.x     | Active | Android 13–17     | TBD     |
| 3.x     | Legacy | Android 13–16     | 2027-07 |
| 2.x     | EOL    | Android 13–15     | 2026-07 |
| 1.x     | EOL    | Android 13–14     | 2026-01 |

**Active**: Full support, new features, bug fixes, security patches.  
**Legacy**: Critical bug fixes and security patches only.  
**EOL (End of Life)**: No further updates.

## Reporting a Vulnerability

The Android Toolkit never requires root access. It operates via ADB or Shizuku,
both of which require explicit user authorization.

If you discover a security vulnerability:

1. **Do not open a public issue.**
2. Open a [draft security advisory](https://github.com/android-toolkit/toolkit/security/advisories/new) on GitHub.
3. Alternatively, email the maintainers directly (contact information in commit history).
4. Include a clear description, reproduction steps, and impact assessment.
5. Allow **14 days** for triage and remediation before public disclosure.

### What to Include

- Toolkit version (`./toolkit.sh --version`)
- Device model, Android version, backend (ADB/Shizuku)
- Steps to reproduce
- Impact assessment (what could an attacker achieve?)
- CVSS score (if known)
- Suggested fix (if available)

## Response Timeline

| Priority | CVSS Score | Response Time | Patch Target |
|----------|------------|---------------|--------------|
| Critical | 9.0–10.0 | 48 hours | 7 days |
| High | 7.0–8.9 | 72 hours | 14 days |
| Medium | 4.0–6.9 | 5 business days | 30 days |
| Low | 0.1–3.9 | 10 business days | Next patch |

## Disclosure Process

1. **Report received** — Maintainer acknowledges within 48 hours.
2. **Triage** — Severity confirmed, affected versions identified.
3. **Fix development** — Patch created in a `hotfix/` branch.
4. **Patch release** — Tagged as a patch version (v4.2.1, v4.3.1, etc.).
5. **Public disclosure** — Advisory published after patch is available.
6. **CVE assignment** — Requested for Critical/High severity issues.

## Security Properties

### No Root
The toolkit never attempts to gain root access. All operations use authorised
backends (ADB USB, ADB wireless, or Shizuku rish).

### No Network Telemetry
All telemetry is local-only. The toolkit never transmits data over the network
unless explicitly triggered by the `toolkit update` command (which fetches
release metadata from GitHub).

### Write Verification
Every settings change follows a 7-step protocol:
1. Probe namespace accessibility
2. Read current value
3. Skip if unchanged
4. Record rollback journal entry
5. Check dry-run mode
6. Apply change
7. Verify by re-reading and auto-restore on mismatch

### Protected Packages
Critical system packages (phone, system UI, settings, launcher, keyboard,
Google Play Services) cannot be disabled via the toolkit.

### Rollback
All state changes are recorded in a journal. Use `--rollback latest` to undo
the most recent change. The rollback engine auto-restores on write verification
failure.

### Dry-Run
Use `--dry-run` to preview every change before applying it. Dry-run works
across all write operations.

### Plugin Isolation
Plugins execute in isolated subshells with configurable timeouts. Safe mode
restricts PATH and clears environment variables. See `docs/PLUGIN_SECURITY.md`.

## Dependency Security

The toolkit has minimal dependencies:
- Bash 5.x (system-provided)
- Optional: ADB (`android-tools` package)
- Optional: Shizuku/rish

No npm, pip, gem, or other package manager dependencies are required.
Verifiable checksums are provided for releases.

## Vulnerability Disclosure History

| CVE | Date | Version | Severity | Description |
|-----|------|---------|----------|-------------|
| — | — | — | — | No reported vulnerabilities to date |
