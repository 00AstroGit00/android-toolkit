# Android Toolkit Dashboard

The interactive dashboard provides a full-screen terminal UI for the Android Toolkit, inspired by tools like LazyGit, k9s, and btop. It uses ANSI escape sequences for rendering (not curses/ncurses), making it portable across any terminal that supports 256-color or truecolor.

## Usage

```bash
# Launch the dashboard (default when no arguments given)
./toolkit.sh

# Launch explicitly with --tui flag
./toolkit.sh --tui
```

All existing CLI flags (`--status`, `--doctor`, `--report`, etc.) continue to work exactly as before.

## Architecture

The dashboard is a presentation layer only — it calls the same underlying toolkit APIs that the CLI uses. No module, plugin, or script needs modification.

```
toolkit.sh
  └─ modules/dashboard/loader.sh     Module loader (dependency-ordered)
       ├─ renderer.sh                ANSI terminal rendering engine
       ├─ themes.sh                  Color scheme system (6 themes)
       ├─ shortcuts.sh               Keyboard input reader
       ├─ status.sh                  Device data collection with caching
       ├─ menus.sh                   Dialog/whiptail wrapper for popups
       ├─ header.sh                  Top status bar
       ├─ sidebar.sh                 Left navigation sidebar
       ├─ footer.sh                  Bottom shortcut bar
       ├─ notifications.sh           Toast notification system
       ├─ widgets.sh                 Home dashboard widgets
       ├─ pages.sh                   19 page renderers and key handlers
       └─ dashboard.sh               Main controller and event loop
```

## Dashboard Layout

```
┌──────────────────────────────────────────────────────────────┐
│  ◆ Android Toolkit v4.2.0    Device Model    ● Online [adb] │  ← Header
│  Battery: 85% 35°C  |  Mem: 62%  |  Storage: 45%           │
├────────┬─────────────────────────────────────────────────────┤
│        │                                                     │
│ Dash   │  Dashboard — Live Device Overview                   │  ← Content
│ Devs   │  ┌──────────┐ ┌──────────┐ ┌──────────┐            │     area
│ Perf   │  │ DEVICE   │ │ BATTERY  │ │ MEMORY   │            │
│ Opti   │  │ Pixel 7  │ │ 85%      │ │ 62%      │            │
│ Pack   │  └──────────┘ └──────────┘ └──────────┘            │
│ Bloat  │  ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│ Batt   │  │ STORAGE  │ │ CPU      │ │ NETWORK  │            │
│ ...    │  │ 45%      │ │ 8 cores  │ │ WiFi     │            │
│        │  └──────────┘ └──────────┘ └──────────┘            │
│        │                                                     │
├────────┴─────────────────────────────────────────────────────┤
│  Welcome to Android Toolkit!                                 │  ← Footer
│  ↑↓ Navigate  |  Enter  |  F1 Help  |  F5 Refresh  |  Q Q  │
└──────────────────────────────────────────────────────────────┘
```

## Navigation

| Key | Action |
|-----|--------|
| `↑` / `↓` | Navigate sidebar or list items |
| `→` / `Enter` | Select current item |
| `←` / `Esc` | Go back to previous page |
| `Tab` | Cycle to next sidebar page |
| `F1` | Help screen |
| `F5` / `Ctrl+R` | Refresh all data |
| `Ctrl+L` | Redraw screen |
| `Q` / `Ctrl+C` | Quit dashboard |

## Pages

| Page | Description |
|------|-------------|
| Dashboard | Live device overview with widgets |
| Devices | Connected device management |
| Performance | Profiles, benchmarks, analysis |
| Optimization | Battery, display, memory, network |
| Packages | Package browser and management |
| Bloatware | Samsung bloatware removal |
| Battery | Battery status and optimization |
| Display | Resolution, density, refresh rate |
| Network | Connectivity, DNS, WiFi |
| Security | Audit, hardening, review |
| Plugins | Plugin manager |
| Reports | View and export reports |
| Benchmarks | Performance testing |
| Validation | Release readiness checks |
| Compatibility | Device compatibility matrix |
| Logs | Toolkit activity logs |
| Settings | Configuration and themes |
| Help | Keyboard shortcuts reference |
| About | Version and project info |

## Themes

The dashboard ships with 6 color schemes:
- **Dark** (default) — Near-black background
- **Light** — White background for bright terminals
- **Classic** — Navy blue theme
- **Nord** — Polar-inspired frost palette
- **Dracula** — Dark purple theme
- **Catppuccin** — Warm pastel theme

Change themes in **Settings > Change Theme**.

## Auto-Refresh

The dashboard refreshes device data every 3 seconds. Press `F5` or `Ctrl+R` to force an immediate refresh.

## Requirements

- Terminal with 256-color or truecolor support (`TERM=xterm-256color`)
- `dialog` or `whiptail` (optional, for popup menus)
- No external dependencies beyond what the toolkit already requires
