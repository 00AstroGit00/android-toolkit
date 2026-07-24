# Audit Trail

Records every significant dashboard action with timestamps.

## Features

- **Automatic Recording** — Page navigation, snapshots, workflows, settings changes
- **Category Filtering** — Filter log entries by text
- **Multiple Export Formats** — TXT, CSV, JSON
- **Log Rotation** — Auto-rotated at 1MB to prevent disk bloat
- **Live Summary** — Success/warning/error/info counts in header

## Export Formats

| Format | File Extension | Use Case |
|--------|---------------|----------|
| TXT | `.txt` | Human-readable log |
| CSV | `.csv` | Spreadsheet import |
| JSON | `.json` | Programmatic analysis |

## Usage

| Key | Action |
|-----|--------|
| `e` | Export as TXT |
| `c` | Export as CSV |
| `j` | Export as JSON |
| `f` | Clear current filter |
| `/` | Search/filter entries |

## Storage

Log files stored in: `audit/` directory
Max in-memory entries: 500 (FIFO)
Max file size: 1MB before rotation
