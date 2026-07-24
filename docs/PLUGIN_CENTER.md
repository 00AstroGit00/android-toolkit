# Plugin Development Center

Manage, develop, validate, and certify toolkit plugins.

## Features

- **Plugin Discovery** — Auto-detect installed plugins
- **Validate** — Run plugin certification checks
- **Certify** — Certify individual or all plugins
- **API Documentation** — Built-in SDK reference

## Usage

| Key | Action |
|-----|--------|
| `1` | List installed plugins |
| `2` | Run plugin validation |
| `3` | Certify plugin(s) |
| `4` | View API documentation |

## SDK Reference

Key functions:
- `plugin_load_all()` — Load all available plugins
- `plugin_list()` — List installed plugins
- `plugin_run()` — Execute a plugin by name
- `plugin_certify_run()` — Validate and certify plugins

Full reference: `docs/PLUGIN_API.md`
