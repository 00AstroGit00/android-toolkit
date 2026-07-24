# Release Process

> **Version:** 1.0 — Applies to v4.x and later  
> **Reference implementation:** v4.2.0

---

## 1. Branch Strategy

```
main
  │
  ├── stable                (always points to latest stable tag)
  │
  ├── release/v4.1.x        (LTS backport branch for v4.1)
  ├── release/v4.2.x        (LTS backport branch for v4.2) ← current
  │
  ├── hotfix/cve-YYYY-XXXX  (security hotfix branches)
  └── hotfix/crash-regression
```

| Branch | Purpose | Source | Target |
|--------|---------|--------|--------|
| `main` | Next development | — | Tagged releases |
| `stable` | Latest stable release | `main` after tag | README points here |
| `release/vMAJOR.MINOR.x` | LTS backports | Tag `vMAJOR.MINOR.0` | Patch tags |
| `hotfix/*` | Emergency fixes | `stable` or `release/*` | Merge to `main` + `stable` |

### Branch Lifecycle

1. **On tag**: After tagging `v4.2.0`, create `release/v4.2.x` from the tag.
2. **Patches**: Merge fixes to `main`, cherry-pick to `release/v4.2.x`.
3. **EOL**: Archive the branch when LTS ends (see LTS-POLICY.md).

---

## 2. Semantic Versioning

This project follows [Semantic Versioning 2.0](https://semver.org/).

| Component | Change | Example |
|-----------|--------|---------|
| **MAJOR** (x.0.0) | Breaking CLI/API/Plugin SDK changes | v4→v5 |
| **MINOR** (0.x.0) | New features, modules, commands (backward-compatible) | v4.2→v4.3 |
| **PATCH** (0.0.x) | Bug fixes, performance, docs (no new functionality) | v4.2.0→v4.2.1 |

### Pre-release Identifiers

| Suffix | Meaning | Lifetime |
|--------|---------|----------|
| `-rc1`, `-rc2` | Release candidate | Superseded by stable or next RC |
| `-beta1` | Beta feature release | Merged to main |
| `-nightly.YYYYMMDD` | Daily build | Auto-deleted after 90 days |

### Version Location

- Single file: `VERSION` (root of repository, no trailing newline).
- Also exposed at runtime via `--version` and `ANDROID_TOOLKIT_VERSION`.

---

## 3. Release Cadence

| Channel | Frequency | Audience | Quality Bar |
|---------|-----------|----------|-------------|
| `stable` | Monthly | All users | CI → RC review → Stable |
| `beta` | Weekly | Early adopters | CI passes, feature-complete |
| `nightly` | Daily | Developers | Automated build |

### Release Checklist

Every stable release must pass these checks before tagging:

```
[ ] VERSION file updated
[ ] CHANGELOG.md updated with all changes
[ ] All 78+ .sh files pass bash -n (0 errors)
[ ] All .json files validate (0 failures)
[ ] ShellCheck: 0 errors, warnings reviewed
[ ] BATS test suite passes (90+ tests)
[ ] --release-ready exits with PASS
[ ] --static-analysis completes with 0 failures
[ ] Platform validation on reference device
[ ] Plugin SDK compatibility verified
[ ] Release artifacts build correctly
[ ] SHA256 checksums generated
[ ] SBOM generated
[ ] Release notes generated
[ ] Tag signed with GPG (when available)
```

---

## 4. Release Steps

### 4.1 Prepare Release Candidate

```bash
# Create RC branch from main
git checkout -b release/v4.3.0-rc1 main

# Update VERSION
echo "4.3.0-rc1" > VERSION

# Update CHANGELOG.md with RC entry
# Run validation
bash -n toolkit.sh && shellcheck -s bash toolkit.sh
bash tests/run_tests.sh

# Commit
git add VERSION CHANGELOG.md
git commit -m "chore: v4.3.0-rc1"
git tag -a v4.3.0-rc1 -m "v4.3.0-rc1"
git push origin v4.3.0-rc1
```

### 4.2 Validate RC

- CI runs automatically on tag push.
- Generate `FINAL_RELEASE_REVIEW.md` (independent review).
- Platform validation on at least one reference device.
- Plugin ecosystem validation.

### 4.3 Promote to Stable

```bash
# Update VERSION to stable
echo "4.3.0" > VERSION

# Mark RC as superseded in CHANGELOG.md
# Commit
git add VERSION CHANGELOG.md
git commit -m "chore: v4.3.0 promote to stable"

# Tag
git tag -a v4.3.0 -m "v4.3.0 Stable Release"
git push origin v4.3.0

# Create release branch
git checkout -b release/v4.3.x v4.3.0
git push origin release/v4.3.x

# Update stable branch
git checkout stable
git merge v4.3.0
git push origin stable
```

### 4.4 CI Builds and Publishes

On tag push, CI automatically:
1. Runs all validation jobs (syntax, ShellCheck, JSON, BATS)
2. Builds release artifacts:
   - `android-toolkit-v4.3.0.zip`
   - `android-toolkit-v4.3.0.tar.gz`
   - `android-toolkit-v4.3.0.zip.sha256`
   - `android-toolkit-v4.3.0.tar.gz.sha512`
   - `sbom-v4.3.0.json` (SPDX)
   - `manifest-v4.3.0.json`
   - `release-notes-v4.3.0.md`
3. Uploads to GitHub Release
4. Marks previous RC as superseded

---

## 5. Backport Policy

| Change Type | Backport Target | Criteria |
|-------------|----------------|----------|
| Security fix (Critical/High) | All active LTS branches | CVE or verified exploit |
| Security fix (Medium) | Latest LTS branch | Patch release |
| Bug fix (functional regression) | Latest LTS branch | Reproduced by reporter |
| Bug fix (cosmetic) | Main only | — |
| New feature | Main only | — |
| Documentation | Latest LTS branch + main | Trivial merge |

### Backport Process

```bash
# Cherry-pick to release branch
git checkout release/v4.2.x
git cherry-pick -x <commit-hash>
# Resolve conflicts if any
git push origin release/v4.2.x

# Tag patch
echo "4.2.1" > VERSION
git add VERSION CHANGELOG.md
git commit -m "chore: v4.2.1"
git tag -a v4.2.1 -m "v4.2.1"
git push origin v4.2.1
```

---

## 6. Support Windows

| Version | Status | Android Support | End of Life |
|---------|--------|-----------------|-------------|
| 4.x | Active | 13–17 | TBD |
| 3.x | Legacy | 13–16 | 2027-07 |
| 2.x | EOL | 13–15 | 2026-07 |
| 1.x | EOL | 13–14 | 2026-01 |

See `LTS-POLICY.md` for detailed support timelines.

---

## 7. Deprecation Policy

1. **Notice**: Features are deprecated at least 2 MINOR versions before removal.
2. **Announcement**: Deprecation is recorded in CHANGELOG.md and the release notes.
3. **Grace period**: Deprecated features continue to work for 6 months after announcement.
4. **Migration path**: A migration guide is provided for all deprecated features.
5. **Removal**: Removal happens at the next MAJOR version.

### Deprecation State Transitions

```
Active → Deprecated (changelog warning + docs notice)
Deprecated → Removed (next major version)
```

### Current Deprecations (v4.2.0)

None. All APIs are Active.

---

## 8. Artifact Verification

Every release includes:

```
android-toolkit-v4.2.0.zip          — Source archive
android-toolkit-v4.2.0.tar.gz       — Source archive (tar)
android-toolkit-v4.2.0.zip.sha256   — SHA256 checksum
android-toolkit-v4.2.0.zip.sha512   — SHA512 checksum
sbom-v4.2.0.json                    — SPDX Software Bill of Materials
manifest-v4.2.0.json                — Release metadata
release-notes-v4.2.0.md             — Auto-generated release notes
```

### Verification Commands

```bash
# Verify archive integrity
sha256sum -c android-toolkit-*.zip.sha256
sha512sum -c android-toolkit-*.tar.gz.sha512

# Verify SBOM
jq '.spdxVersion' sbom-*.json

# Verify manifest
jq '.version' manifest-*.json
```

---

## 9. Security Releases

Security fixes follow an accelerated process:

1. **Private report** via GitHub Security Advisories or email.
2. **Triage** within 48 hours (CVSS scoring).
3. **Fix branch**: `hotfix/cve-YYYY-XXXX` from `stable`.
4. **Patch tag**: `v4.2.1` (bump only PATCH).
5. **Public disclosure** after patch is available (typically 14 days).

See `SECURITY.md` for vulnerability reporting details.
