# Session Manager

Save and restore complete dashboard state across sessions.

## Saved State

- Active page and scroll position
- Multi-device selections
- Terminal command history
- AI conversation history
- Performance monitor data points
- Dashboard theme and configuration

## Usage

| Key | Action |
|-----|--------|
| `n` | Create new session (with optional name) |
| `s` | Save current session (overwrites active) |
| `r` | Restore — select from saved sessions |
| `d` | Delete — remove a saved session |

## File Format

Sessions are stored in `sessions/*.session` as plaintext key-value files:

```
SESSION_VERSION=1
SESSION_NAME=my_workspace
SESSION_TIMESTAMP=1712345678
PAGE_NAME=dashboard
MULTI_DEVICES=(dev1 dev2)
TERMINAL_HISTORY_ENTRY=adb devices
```

## Auto-Save

Enable in Enterprise Settings: `session_autosave=true`
Auto-save runs every 120 seconds when enabled.
