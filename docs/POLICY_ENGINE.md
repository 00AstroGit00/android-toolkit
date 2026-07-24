# Policy Engine

Configurable device policies that trigger notifications when violated.

## Configurable Policies

| # | Policy | Default | Description |
|---|--------|---------|-------------|
| 1 | Min Battery | 20% | Warning when battery drops below threshold |
| 2 | Min Patch | 2025-01 | Warning when security patch is outdated |
| 3 | Max Temp | 45°C | Critical alert when device overheats |
| 4 | Required Plugins | — | Comma-separated list of required plugins |
| 5 | Min Android | 13 | Minimum supported Android version |
| 6 | Min One UI | 5 | Minimum Samsung One UI version |
| 7 | Max Storage | 90% | Warning when storage is nearly full |
| 8 | Max Memory | 90% | Warning when memory usage is critical |

## Policy File

Stored in `policies.conf` at toolkit root:

```ini
min_battery=20
min_patch=2025-01
max_temp=45
required_plugins=
min_android=13
min_oneui=5
max_storage=90
max_memory=90
```

## Usage

| Key | Action |
|-----|--------|
| `c` | Check current device against all policies |
| `s` | Save policy configuration to file |
| `1-8` | Edit individual policy values |

## API

```bash
policies_load       # Load policies from config file
policies_save       # Save policies to config file
policies_check      # Check device against all policies — populates POLICY_VIOLATIONS[]
```
