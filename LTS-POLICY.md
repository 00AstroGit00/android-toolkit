# Long-Term Support Policy

## Version Support

| Version | Status | Supported Android | LTS End |
|---------|--------|-------------------|---------|
| 4.x     | Active | Android 13–17     | TBD     |
| 3.x     | Legacy | Android 13–16     | 2027-07 |
| 2.x     | EOL    | Android 13–15     | 2026-07 |
| 1.x     | EOL    | Android 13–14     | 2026-01 |

- **Active**: Full support, new features, bug fixes, security patches.
- **Legacy**: Critical bug fixes and security patches only.
- **EOL (End of Life)**: No further updates.

## Supported Android Versions

| Android | SDK | Toolkit Support | Notes |
|---------|-----|----------------|-------|
| 13      | 33  | Full           | Tested on One UI 5.x, Pixel |
| 14      | 34  | Full           | Tested on One UI 6.x, Pixel |
| 15      | 35  | Full           | Tested on One UI 7.x |
| 16      | 36  | Full           | Tested on One UI 8.x |
| 17      | 37  | Preview        | Capability-limited |

## Deprecation Policy

1. **Notice Period**: Features are deprecated at least 2 minor versions before removal.
2. **Announcement**: Deprecation is announced in CHANGELOG.md and the release notes.
3. **Migration Path**: A migration guide is provided for all deprecated features.
4. **Grace Period**: Deprecated features continue to work for 6 months after the
   deprecation announcement.

## Compatibility Guarantees

### Backward Compatibility

- All commands in v3.x continue to work in v4.x.
- Profiles from v3.x are forward-compatible with v4.x.
- The Plugin SDK v2.0 API remains functional in v3.0 (SDK v3.0 is a superset).
- Configuration files maintain the same format.

### Forward Compatibility

- New features are added as optional modules.
- Existing commands never change behavior without deprecation.
- Plugin API additions are always additive.
- Output formats may gain new fields but never lose existing fields.

## Plugin Compatibility Policy

| Plugin SDK | Status | v4.x Compatibility |
|------------|--------|-------------------|
| v1.0       | EOL    | Not supported     |
| v2.0       | Supported | Full backward compat |
| v2.1       | Supported | Full backward compat |
| v3.0       | Current | Full support       |

Plugins targeting SDK v2.0+ continue to work in v4.x without modification.
Plugin certification (v3.0) is optional but recommended.

## Release Cadence

- **Major releases** (x.0.0): Annual, may include breaking changes after
  deprecation period.
- **Minor releases** (0.x.0): Quarterly, new features, no breaking changes.
- **Patch releases** (0.0.x): As needed, bug fixes and security patches.

## Security Updates

Security vulnerabilities are addressed within:

- **Critical**: 7 days
- **High**: 14 days
- **Medium**: 30 days
- **Low**: Next patch release

## Maintenance Roadmap

| Period | Focus |
|--------|-------|
| H2 2026 | v4.2 stabilization, plugin ecosystem growth, Android 17 support |
| H1 2027 | v4.3 feature release (community-driven), performance optimization |
| H2 2027 | v3.x EOL, v5.0 planning, SDK modernization |
| 2028+ | v5.0 development, Android 18+ support |

### Active Workstreams

1. **Android 17 support** (SDK 37) — Capability-limited preview, planned full support in v4.3.
2. **Plugin ecosystem** — Example plugins, certification tooling, publishing guidelines.
3. **CI pipeline** — Consolidate duplicate jobs, add performance regression detection.
4. **Documentation** — Auto-generate COMPATIBILITY.md, wire `--json` flag.
