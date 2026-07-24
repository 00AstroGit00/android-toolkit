# Embedded Terminal Console

Managed command-line console within the dashboard.

## Features

- **Command History** — Last 100 commands, navigable with ↑/↓
- **Safe Mode** — Blocks destructive commands: reboot, format, wipe, rm -rf, dd, mkfs, flash
- **Output Filtering** — Red for errors (E/ FATAL), yellow for warnings (W/), dim for info
- **Session Logging** — Full session saved to timestamped log file
- **Clear Output** — Clear current output buffer with [C]

## Safety

Safe mode (toggled with [T]) blocks these patterns:
- `reboot`, `shutdown`, `poweroff`
- `format`, `wipe`, `mkfs`
- `rm -rf`, `rm -fr`
- `dd`, `flash`
- `fastboot`, `heimdall`

## Usage

| Key | Action |
|-----|--------|
| Type + Enter | Execute command |
| `↑/↓` | Navigate command history |
| `t` | Toggle safe mode |
| `c` | Clear output |
| `F1` | Help |

## Log Files

Session logs are saved to `logs/terminal_*.log` for later review.
