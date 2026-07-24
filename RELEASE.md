> **DEPRECATED** — This document has been superseded by  
> [`docs/RELEASE_PROCESS.md`](docs/RELEASE_PROCESS.md).  
>  
> The authoritative release process covers branch strategy, semantic versioning,
> release cadence (stable/beta/nightly), full release checklists, backport
> policy, support windows, deprecation policy, and security releases.
>
> This file is retained for historical reference and will be removed in v5.0.

# Release Process (Archived)

## Versioning

This project follows [Semantic Versioning 2.0](https://semver.org/):

- **MAJOR**: Breaking changes to the CLI, module API, or plugin API.
- **MINOR**: New features, new modules, new commands (backward-compatible).
- **PATCH**: Bug fixes, performance improvements, documentation.

The current version is in `VERSION` (single line, no newline after the version number).

## Channels

| Channel   | Frequency   | Stability | Description                     |
|-----------|-------------|-----------|---------------------------------|
| `stable`  | Monthly     | High      | Production-ready releases       |
| `beta`    | Weekly      | Medium    | Feature-complete, may have bugs |
| `nightly` | Daily       | Low       | Latest commits, may be unstable |

## Release Steps

### 1. Prepare

```bash
# Update VERSION file
echo "2.1.0" > VERSION

# Update CHANGELOG.md with release date and notes
# Commit version bump
git add VERSION CHANGELOG.md
git commit -m "chore: bump version to 2.1.0"
```

### 2. Tag

```bash
git tag -a v2.1.0 -m "Release v2.1.0"
git push origin v2.1.0
```

### 3. Build

```bash
./toolkit.sh build
```

This produces:
- `android-toolkit-v2.1.0.zip` — release artifact
- `android-toolkit-v2.1.0.zip.sha256` — checksum
- `manifest.json` — version metadata
- `release-notes.md` — auto-generated release notes

### 4. Publish

1. Create a GitHub Release from the tag.
2. Upload the ZIP, SHA256, and manifest files.
3. Add the changelog entry as release notes.

### 5. Verify

```bash
# Verify checksum
sha256sum -c android-toolkit-v2.1.0.zip.sha256

# Test update
./toolkit.sh update --channel stable
```

## Hotfix Process

For critical bugs in a stable release:

1. Branch from the release tag: `git checkout -b hotfix/v2.0.1 v2.0.0`
2. Apply the fix.
3. Bump PATCH version.
4. Tag and release following the same steps.
5. Merge the hotfix branch back to main.

## Artifact Verification

All release ZIPs include:
- SHA256 checksum file
- Signed manifest (when GPG key is configured)
- Test results from the CI run

Verify with:

```bash
sha256sum -c android-toolkit-*.zip.sha256
```
