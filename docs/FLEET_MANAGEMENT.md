# Fleet Management

Enterprise fleet dashboard for managing multiple Android devices.

## Features

- **Auto-discovery** — Detects connected ADB devices and twin data
- **Health Scoring** — Per-device health score based on twin data
- **Status Indicators** — Online (green), offline (red), unauthorized (yellow)
- **Policy Application** — Apply actions across entire fleet
- **Bulk Reporting** — Generate fleet-wide health reports

## Status Legend

| Indicator | Status | Meaning |
|-----------|--------|---------|
| ● Green | Online | Device connected and responsive |
| ■ Red | Offline | Device in twin data but not connected |
| ▲ Yellow | Unauthorized | ADB connection pending authorization |

## Usage

| Key | Action |
|-----|--------|
| `r` | Refresh fleet device list |
| `p` | Apply policy action to fleet |
| `b` | Generate bulk fleet report |

## API

```bash
fleet_discover          # Discover all fleet devices
fleet_stats             # Get fleet online/warning/critical counts
fleet_device_health <id> # Get individual device health score
fleet_apply_policy <action> # Apply action to all online devices
```
