# Multi-Device Workspace

Manage multiple Android devices simultaneously.

## Features

- **Device Discovery** — Automatically detect all connected ADB devices
- **Toggle Selection** — Select individual or all devices with [Space]
- **Broadcast Commands** — Send adb shell commands to all selected devices at once
- **Group Operations** — Apply toolkit actions (status, battery, benchmark) across devices
- **Visual Status** — Device model, Android version, battery, connection type at a glance

## Usage

| Key | Action |
|-----|--------|
| `↑/↓` | Navigate device list |
| `Space` | Toggle selection |
| `a` | Select all devices |
| `n` | Deselect all |
| `b` | Broadcast command to selected |
| `g` | Group operation menu |
| `F5` | Refresh device list |

## API

```bash
devices_list              # List all connected devices
devices_broadcast <cmd>   # Send command to all selected
devices_group <action>    # Apply action to group
```
