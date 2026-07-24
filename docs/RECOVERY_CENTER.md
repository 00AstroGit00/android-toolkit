# Recovery Center

Centralized recovery interface for rollback and system restoration.

## Features

- **Rollback Points** — Create named snapshots of device state
- **State Capture** — Records battery, storage, memory, thermal, active profile, and toolkit config
- **Validation** — Verify integrity of recovery points before restoring
- **Failed Task Tracking** — Automatic logging of failed operations
- **Profile Restoration** — Applies saved profile configuration on restore
- **Timeline Integration** — All recovery actions recorded in Timeline

## Recovery Point Data

```json
{
  "name": "rollback_20250101_120000",
  "created": "2025-01-01T12:00:00Z",
  "type": "rollback_point",
  "state": {
    "battery": "85",
    "storage": "62",
    "memory": "45",
    "thermal": "32",
    "profile": "balanced"
  }
}
```

## Usage

| Key | Action |
|-----|--------|
| `n` | Create new recovery point |
| `r` | Restore from recovery point |
| `v` | Validate recovery point integrity |
| `f` | View failed task log |

## API

```bash
recovery_init           # Initialize and scan for points
recovery_create_point [name]  # Create recovery point
recovery_validate <file>      # Validate recovery point
recovery_restore <file>       # Restore from recovery point
recovery_track_failure <task> <error>  # Log a failure
```
