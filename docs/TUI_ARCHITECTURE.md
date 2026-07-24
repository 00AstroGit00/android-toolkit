# Dashboard Architecture

## Overview

The interactive dashboard is a full-screen terminal UI that runs alongside the existing CLI. It is implemented as a set of shell scripts under `modules/dashboard/` that use direct ANSI escape sequences for rendering. There is no external dependency on ncurses, terminfo, or any compiled binary for the core rendering.

## Design Principles

1. **Presentation layer only** — The dashboard never implements business logic. It calls the same public API functions that the CLI uses (`devices_list`, `benchmark_run`, `audit_run`, etc.).
2. **100% backward compatibility** — All existing CLI flags, plugins, scripts, and API consumers work unchanged.
3. **No runtime dependencies** — Core rendering uses only ANSI escape sequences. `dialog`/`whiptail` are optional fallbacks for confirmation/input popups.
4. **Graceful degradation** — Falls back from truecolor → 256-color → 16-color → monochrome based on terminal capability.
5. **Unicode with ASCII fallback** — Box-drawing and icon characters degrade to ASCII when Unicode is unavailable.

## Module Layering

```
┌─────────────────────────────────────────────────────────┐
│                    dashboard.sh                          │
│  Main controller: event loop, page routing, key dispatch│
├─────────────────────────────────────────────────────────┤
│                     pages.sh                             │
│  19 page renderers + key handlers for all sidebar items │
├──────────┬──────────┬──────────┬──────────┬──────────────┤
│widgets.sh│ header.sh│ sidebar.sh│ footer.sh│notifications│
│Dashboard │ Top bar  │ Left nav  │ Bottom   │ Toast msgs  │
│cards     │          │           │ bar      │             │
├──────────┴──────────┴──────────┴──────────┴──────────────┤
│                  renderer.sh                              │
│  ANSI primitives: cursor, color, box-drawing, fills       │
├───────────────────────────────────────────────────────────┤
│  status.sh    │  themes.sh   │  shortcuts.sh  │ menus.sh  │
│  Data cache   │  6 themes    │  Key reader    │ popups    │
│  TTL 5s       │  20 slots    │  Multi-byte    │ dialog/   │
│               │              │  sequences     │ whiptail  │
├───────────────┴──────────────┴────────────────┴───────────┤
│                   loader.sh                                │
│  Dependency-ordered module loader                          │
└───────────────────────────────────────────────────────────┘
```

## Data Flow

```
┌──────────┐    ┌──────────┐    ┌──────────┐
│ toolkit  │───▶│ status.sh│───▶│ widgets  │───▶ Terminal
│  APIs    │    │ (cache)  │    │ header   │
│          │    │ TTL: 5s  │    │ footer   │
│ devices  │    │          │    │ pages    │
│ battery  │    │          │    │          │
│ meminfo  │    │          │    │          │
│ ...      │    │          │    │          │
└──────────┘    └──────────┘    └──────────┘
                      │
                      ▼
               ┌──────────────┐
               │ Event Loop   │
               │ 3s auto-     │
               │ refresh      │
               │ key dispatch │
               └──────────────┘
```

1. `toolkit.sh` initializes all subsystems (backend, logging, device detection)
2. Dashboard modules are loaded by `loader.sh`
3. `dashboard_run()` enters the alternate screen buffer and starts the event loop
4. Every 3 seconds, `status_refresh()` pulls fresh data from toolkit APIs
5. On keypress, `_dashboard_handle_key()` dispatches to page-specific or global handlers
6. Page renderers use `renderer.sh` primitives to draw content
7. On quit, the alternate screen is exited and terminal state is restored

## Rendering Pipeline

The renderer uses direct ANSI escape sequences:

| Feature | ANSI Code | Example |
|---------|-----------|---------|
| Cursor goto | `\033[row;colH` | Move cursor to position |
| Clear screen | `\033[2J` | Full clear |
| Hide cursor | `\033[?25l` | During dashboard |
| Show cursor | `\033[?25h` | On exit |
| Enter alt screen | `\033[?1049h` | Full-screen mode |
| Exit alt screen | `\033[?1049l` | Return to shell |
| 256-color fg | `\033[38;5;Nm` | N = 0-255 |
| 256-color bg | `\033[48;5;Nm` | N = 0-255 |
| Truecolor fg | `\033[38;2;R;G;Bm` | RGB values |
| Truecolor bg | `\033[48;2;R;G;Bm` | RGB values |

## Color Detection

The renderer detects terminal capabilities in order:
1. `COLORTERM=truecolor` or `COLORTERM=24bit` → truecolor (16.7M colors)
2. `TERM=*256color*` → 256 colors
3. `tput colors` → detected value
4. Default → 16 colors (safe)

## Keyboard Input

The shortcut reader (`shortcuts.sh`) puts the terminal in raw mode with `stty raw -echo` and reads bytes individually. It handles multi-byte escape sequences for:
- Arrow keys (3-4 bytes)
- Function keys F1-F12 (4-5 bytes)
- Ctrl+letter combinations (1 byte)
- Home/End/PgUp/PgDn (3-4 bytes)

## Thread Safety

Single-threaded by design. The event loop alternates between:
1. Reading keyboard input (with timeout via `dd` blocking read)
2. Auto-refreshing data on 3-second intervals
3. Redrawing the screen when dirty

## Error Recovery

- `trap` handlers restore cursor, exit alternate screen on EXIT/INT/TERM/HUP
- The dashboard wraps dangerous operations with `menu_confirm()` dialogs
- If `dialog`/`whiptail` are unavailable, `menu_*` functions fall back to text prompts

## Performance

- Rendering is direct-to-terminal (no double-buffer in most cases)
- Status data is cached with 5-second TTL
- Redraws only happen when `DASHBOARD_REDRAW_NEEDED=true` (set by data refresh or navigation)
- Widget content is computed on-demand during render
