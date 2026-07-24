# GitHub Milestones

Recommended milestones for the Android Toolkit repository.

## Active Maintenance (v4.x)

| Milestone | Due | Description |
|-----------|-----|-------------|
| `v4.2.1` | 2026-08-24 | Bug fix release — address post-stable issues, backport critical fixes |
| `v4.3.0` | 2026-09-24 | Minor release — new non-breaking features, documentation improvements |
| `v4.4.0` | 2026-10-24 | Minor release — continued improvements (if LTS schedule permits) |

## Security

| Milestone | Due | Description |
|-----------|-----|-------------|
| `security` | Rolling | Security vulnerabilities — immediate attention, trigger hotfix release |

## Future Planning

| Milestone | Due | Description |
|-----------|-----|-------------|
| `v5.0 Planning` | 2027-Q1 | Research and design phase for v5.0 (see ROADMAP_V5.md) |

## How to Create Milestones

After creating the repository on GitHub, run the following script (requires
GitHub CLI and repo admin access):

```bash
# Authenticate
gh auth login

# Set repo
REPO="your-org/android-toolkit"

# Create milestones
gh api repos/$REPO/milestones \
  --field title="v4.2.1" \
  --field due_on="2026-08-24T00:00:00Z" \
  --field description="Bug fix release — address post-stable issues, backport critical fixes"

gh api repos/$REPO/milestones \
  --field title="v4.3.0" \
  --field due_on="2026-09-24T00:00:00Z" \
  --field description="Minor release — new non-breaking features, documentation improvements"

gh api repos/$REPO/milestones \
  --field title="v4.4.0" \
  --field due_on="2026-10-24T00:00:00Z" \
  --field description="Minor release — continued improvements (if LTS schedule permits)"

gh api repos/$REPO/milestones \
  --field title="security" \
  --field description="Security vulnerabilities — immediate attention, trigger hotfix release"

gh api repos/$REPO/milestones \
  --field title="v5.0 Planning" \
  --field due_on="2027-01-01T00:00:00Z" \
  --field description="Research and design phase for v5.0 (see ROADMAP_V5.md)"
```

## Milestone Usage Guidelines

1. **v4.2.1**: Issues that must be fixed before the next stable release
2. **v4.3.0**: Feature requests and non-critical enhancements
3. **v4.4.0**: Future improvements deferred from v4.3.0
4. **security**: All security-related issues — highest priority
5. **v5.0 Planning**: Design discussions, RFCs, and proposals for v5
