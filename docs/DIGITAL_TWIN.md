# Digital Twin Engine

Maintains a complete virtual representation of every connected Android device, automatically updated after every operation.

## Data Model

JSON structure stored in `twins/{device_id}.json`:

- **device_id** — Unique device identifier
- **last_updated** — ISO timestamp of last update
- **first_seen** — When the device was first discovered
- **hardware** — Model, Android version, One UI, security patch, SELinux
- **state** — Current battery, temperature, storage, memory readings
- **history** — Arrays of optimizations, benchmarks, security scans, package changes, reports, rollbacks
- **toolkit_version** — Version of toolkit that created this twin

## Usage

| Key | Action |
|-----|--------|
| `u` | Update twin with current device state |
| `c` | Compare with another device twin |
| `e` | Export twin data as JSON |
| `r` | Reset twin data |

## API

```bash
twin_init              # Initialize twin storage directory
twin_load [device_id]  # Load twin JSON data
twin_update [device_id] # Capture current state
twin_compare <id1> <id2> # Compare two device twins
twin_add_history <category> <entry> # Append to history array
```
