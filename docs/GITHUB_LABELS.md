# GitHub Issue Labels

Recommended labels for the Android Toolkit repository.

## Bug & Quality

| Label | Color | Description |
|-------|-------|-------------|
| `bug` | `#d73a4a` | Something isn't working |
| `regression` | `#e99695` | Behavior that worked previously has stopped working |
| `security` | `#000000` | Security vulnerability or related concern |

## Enhancements

| Label | Color | Description |
|-------|-------|-------------|
| `enhancement` | `#a2eeef` | New feature or improvement request |
| `performance` | `#fef2c0` | Performance optimization or benchmark concern |
| `ci` | `#0052cc` | CI/CD pipeline, workflow, or automation changes |

## Documentation

| Label | Color | Description |
|-------|-------|-------------|
| `documentation` | `#0075ca` | Improvements or additions to documentation |

## Plugin System

| Label | Color | Description |
|-------|-------|-------------|
| `plugin` | `#5319e7` | Plugin SDK, plugin API, or plugin ecosystem |

## Process

| Label | Color | Description |
|-------|-------|-------------|
| `question` | `#d876e3` | Further information is requested |
| `duplicate` | `#cfd3d7` | This issue or PR already exists |
| `invalid` | `#cfd3d7` | Doesn't seem right or doesn't reproduce |
| `wontfix` | `#ffffff` | This will not be worked on |

## Community

| Label | Color | Description |
|-------|-------|-------------|
| `good first issue` | `#7057ff` | Good for newcomers |
| `help wanted` | `#008672` | Extra attention is needed |

## How to Apply

After creating the repository on GitHub, run the following script (requires
GitHub CLI and repo admin access):

```bash
# Authenticate
gh auth login

# Set repo
REPO="your-org/android-toolkit"

# Create labels
gh label create bug --repo "$REPO" --color d73a4a --description "Something isn't working"
gh label create enhancement --repo "$REPO" --color a2eeef --description "New feature or improvement request"
gh label create documentation --repo "$REPO" --color 0075ca --description "Improvements or additions to documentation"
gh label create security --repo "$REPO" --color 000000 --description "Security vulnerability or related concern"
gh label create regression --repo "$REPO" --color e99695 --description "Behavior that worked previously has stopped working"
gh label create plugin --repo "$REPO" --color 5319e7 --description "Plugin SDK, plugin API, or plugin ecosystem"
gh label create ci --repo "$REPO" --color 0052cc --description "CI/CD pipeline, workflow, or automation changes"
gh label create performance --repo "$REPO" --color fef2c0 --description "Performance optimization or benchmark concern"
gh label create question --repo "$REPO" --color d876e3 --description "Further information is requested"
gh label create duplicate --repo "$REPO" --color cfd3d7 --description "This issue or PR already exists"
gh label create invalid --repo "$REPO" --color cfd3d7 --description "Doesn't seem right or doesn't reproduce"
gh label create wontfix --repo "$REPO" --color ffffff --description "This will not be worked on"
gh label create "good first issue" --repo "$REPO" --color 7057ff --description "Good for newcomers"
gh label create "help wanted" --repo "$REPO" --color 008672 --description "Extra attention is needed"
```
