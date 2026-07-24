# Performance Monitor

Live device performance monitoring with visual history.

## Features

- **CPU Info** — Core count, max frequency
- **Memory Bar** — Real-time usage visualization with total/available
- **Storage Bar** — Storage capacity usage
- **Battery Bar** — Battery level indicator
- **Temperature** — Device and battery temperature with color coding
- **Memory Trend** — ASCII sparkline showing memory usage over last 60 samples
- **Snapshot Export** — Save performance data to timestamped text file

## Color Coding

| Metric | Green | Yellow | Red |
|--------|-------|--------|-----|
| Memory | < 60% | 60–80% | > 80% |
| Temperature | < 35°C | 35–45°C | > 45°C |

## Usage

| Key | Action |
|-----|--------|
| `s` | Save snapshot to file |
| `r` | Reset history |
| Auto | Records data point every 2 seconds |

## Snapshot File

Saved as `perf_snapshot_YYYYMMDD_HHMMSS.txt` in the toolkit root.
Contains current metrics and full history of all recorded samples.
