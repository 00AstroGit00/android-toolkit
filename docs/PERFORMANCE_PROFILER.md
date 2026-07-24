# Performance Profiler

Profiles toolkit execution for optimization. Measures module execution time, identifies slow commands, and generates performance suggestions.

## Metrics

| Metric | Description |
|--------|-------------|
| Execution Time | Wall-clock time for function/module execution (ms) |
| Slow Count | Number of operations exceeding threshold (default: 500ms) |
| Total Time | Cumulative time across all profiled operations |
| Functions | Total number of functions profiled |

## Profiling Process

1. Press `s` to start profiling
2. The profiler automatically measures key dashboard operations (status refresh, health score calculation, twin load)
3. Results displayed with color-coded timing (red if exceeds threshold)
4. View detailed log with `v`
5. Get optimization suggestions with `g`

## Optimization Targets

| Operation | Target | Current Threshold |
|-----------|--------|-------------------|
| Startup | <100 ms | — |
| Dashboard refresh | <25 ms | 500ms alert |
| Device switching | <40 ms | 500ms alert |

## Usage

| Key | Action |
|-----|--------|
| `s` | Start profiling dashboard operations |
| `u` | Refresh profiler data |
| `v` | View detailed profiler log |
| `g` | Generate optimization suggestions |

## API

```bash
perf_profiler_start            # Begin profiling session
perf_profiler_mark <label>     # Record timing point
perf_profiler_elapsed <from> [to]  # Measure elapsed time (ms)
perf_profiler_profile_func <func> [label]  # Profile a function
perf_profiler_summary          # Get profiling summary
perf_profiler_suggestions      # Get optimization suggestions
```
