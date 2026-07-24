# Enterprise Settings

Central configuration hub for the Android Toolkit Dashboard.

## Configuration Options

| # | Setting | Description | Default |
|---|---------|-------------|---------|
| 1 | **ADB Port** | ADB connection port | `5555` |
| 2 | **Theme** | Dashboard color scheme | `default` |
| 3 | **Auto-refresh** | Data refresh interval (seconds) | `3` |
| 4 | **Session Auto-save** | Periodic state saving | `false` |
| 5 | **Backend Mode** | Connection backend | `auto` |
| 6 | **Audit Trail** | Action logging toggle | `true` |
| 7 | **Log Level** | Logging verbosity | `info` |

## Usage

| Key | Action |
|-----|--------|
| `1-7` | Edit corresponding setting |
| `s` | Save configuration to file |
| `r` | Reload from disk |
| `q` | Save, apply and return |

## Config File

Location: `enterprise.conf` (root of toolkit directory)

Format:
```ini
# Android Toolkit Enterprise Configuration
adb_port=5555
theme_name=default
audit_enabled=true
auto_refresh=3
session_autosave=false
backend_mode=auto
log_level=info
```

## API

```bash
enterprise_load_config   # Load from enterprise.conf
enterprise_save_config   # Save to enterprise.conf
enterprise_get <key>     # Get config value
enterprise_set <key> <val>  # Set config value
```
