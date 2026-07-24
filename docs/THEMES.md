# Dashboard Themes

The dashboard ships with 6 built-in color schemes. Each theme defines 16 color slots as 256-color palette indices, supporting both 256-color and truecolor terminals.

## Available Themes

### Dark (default)
The default theme with a near-black background and high-contrast text.
- Background: 16 (near-black)
- Foreground: 255 (near-white)
- Accent: 39 (cyan-blue)
- Sidebar active: 33 (blue)

### Light
Optimized for bright terminals and sunlight readability.
- Background: 231 (white)
- Foreground: 16 (near-black)
- Accent: 27 (blue)

### Classic
Navy-inspired theme reminiscent of old terminal UIs.
- Background: 17 (navy)
- Accent: 46 (green)
- Sidebar active: 34 (green)

### Nord
Based on the popular Nord palette with frost-inspired blues.
- Background: 235 (polar night)
- Accent: 67 (frost blue)
- Success: 150 (aurora green)
- Error: 203 (aurora red)

### Dracula
Dark purple theme with vibrant accents.
- Background: 234 (dracula bg)
- Accent: 141 (purple)
- Success: 84 (green)
- Error: 197 (pink/red)

### Catppuccin
Warm pastel theme with muted, comfortable colors.
- Background: 236 (mantle)
- Accent: 117 (lavender blue)
- Success: 120 (green)
- Error: 210 (red)

## Color Slots

Each theme defines these 16 color slots:

| Slot | Purpose |
|------|---------|
| `bg` | Main background |
| `fg` | Main foreground (text) |
| `header_bg` | Header bar background |
| `header_fg` | Header bar foreground |
| `sidebar_bg` | Sidebar background |
| `sidebar_fg` | Sidebar foreground |
| `sidebar_active_bg` | Active item background |
| `sidebar_active_fg` | Active item foreground |
| `footer_bg` | Footer bar background |
| `footer_fg` | Footer bar foreground |
| `card_bg` | Widget card background |
| `card_fg` | Widget card foreground |
| `card_border` | Widget card border |
| `success` | Success/OK color |
| `warning` | Warning color |
| `error` | Error/danger color |
| `info` | Informational color |
| `muted` | Dimmed/secondary text |
| `accent` | Highlight/accent color |
| `scrollbar` | Scrollbar color |

## Changing Theme

From the dashboard: **Settings > Change Theme** (option 2)

## Adding Custom Themes

Themes are defined in `modules/dashboard/themes.sh`. To add a custom theme:

1. Define a `theme_load_yourname()` function that sets all 20 color arrays
2. Add a case entry in `theme_load()` 
3. Add the name in `theme_list()`

Example:
```bash
theme_load_mytheme() {
    THEME_BG=(16)
    THEME_FG=(255)
    THEME_HEADER_BG=(17)
    THEME_HEADER_FG=(255)
    # ... define all 20 slots
}
```
