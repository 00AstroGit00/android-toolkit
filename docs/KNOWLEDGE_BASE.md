# Knowledge Base

Integrated searchable knowledge system with cross-referenced topics.

## Categories

| # | Category | Topics |
|---|----------|--------|
| 1 | CLI & Shortcuts | Command reference, dashboard keyboard shortcuts |
| 2 | API Reference | Public API functions, status_get, backend_exec |
| 3 | Modules Guide | Dashboard modules, digital twin, health scoring |
| 4 | Plugin SDK | Plugin development lifecycle, certification |
| 5 | Troubleshooting | Common issues: no device, permissions, rendering |
| 6 | Release Notes | v5.0 and v4.0 feature summaries |
| 7 | Architecture | System architecture, event bus, data model |

## Features

- **Full-text search** — Searches all entries by keyword
- **Category browsing** — Filter by topic area
- **Cross-references** — Related topics linked within entries
- **Live updates** — Entries built from current docs/

## Usage

| Key | Action |
|-----|--------|
| `/` | Search all entries |
| `c` | Clear search filter |
| `1-7` | Browse specific category |

## Entry Format

```
[id|title|category|summary|details]
```

Example:
```
commands|CLI Commands|reference|How to use toolkit.sh CLI|
  toolkit.sh [--version|--help|--status|--doctor]
```
