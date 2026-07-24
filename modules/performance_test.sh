#!/data/data/com.termux/files/usr/bin/bash
#
# performance.sh — Performance Regression Framework
#
# Tracks:
#   - startup time
#   - command latency
#   - report generation time
#   - benchmark execution time
#   - memory usage
#   - shell process count
#
# Results are stored in tests/performance/results/
# and compared against baselines.
#
# Part of the Android Toolkit.

PERF_RESULTS_DIR="${ANDROID_TOOLKIT_ROOT_DIR}/tests/performance/results"
PERF_BASELINE_DIR="${ANDROID_TOOLKIT_ROOT_DIR}/tests/performance/baselines"
PERF_THRESHOLD=20  # Maximum allowed regression percentage

##############################################
# Initialize performance directories.
##############################################
perf_init() {
    mkdir -p "$PERF_RESULTS_DIR" "$PERF_BASELINE_DIR"
}

##############################################
# Measure execution time of a command.
# Arguments:
#   $1: measurement name
#   $@: command to measure
# Outputs: JSON with timing info
##############################################
perf_measure() {
    local name="$1"
    shift

    local start end duration mem_before mem_after proc_before proc_after

    # Memory before (KB)
    mem_before="$(perf_get_memory)"
    proc_before="$(perf_get_process_count)"

    start="$(date +%s%N)"
    "$@" >/dev/null 2>&1 || true
    end="$(date +%s%N)"

    mem_after="$(perf_get_memory)"
    proc_after="$(perf_get_process_count)"

    duration=$(( (end - start) / 1000000 ))  # ms

    local mem_delta=$(( mem_after - mem_before ))
    local proc_delta=$(( proc_after - proc_before ))

    jq -n \
        --arg name "$name" \
        --argjson duration "$duration" \
        --argjson mem_before "$mem_before" \
        --argjson mem_after "$mem_after" \
        --argjson mem_delta "$mem_delta" \
        --argjson proc_before "$proc_before" \
        --argjson proc_after "$proc_after" \
        --argjson proc_delta "$proc_delta" \
        '{
            name: $name,
            duration_ms: $duration,
            memory_kb_before: $mem_before,
            memory_kb_after: $mem_after,
            memory_delta_kb: $mem_delta,
            processes_before: $proc_before,
            processes_after: $proc_after,
            processes_delta: $proc_delta,
            timestamp: now | strftime("%Y-%m-%dT%H:%M:%SZ")
        }' 2>/dev/null
}

##############################################
# Get current memory usage in KB.
##############################################
perf_get_memory() {
    if [[ -f /proc/self/status ]]; then
        grep -i 'VmRSS' /proc/self/status 2>/dev/null | awk '{print $2}' || echo "0"
    elif command -v free &>/dev/null; then
        free | grep 'Mem:' | awk '{print $3}'
    else
        echo "0"
    fi
}

##############################################
# Get current shell process count.
##############################################
perf_get_process_count() {
    ps --no-headers -o pid 2>/dev/null | wc -l || echo "1"
}

##############################################
# Run the standard performance benchmark suite.
##############################################
perf_run_suite() {
    perf_init
    log_section "Performance Benchmark Suite"

    local results_file="${PERF_RESULTS_DIR}/perf_$(date +%Y%m%d_%H%M%S).json"
    local results_arr="[]"

    local test_cmds=(
        "help:toolkit.sh --help"
        "version:toolkit.sh --version"
        "about:toolkit.sh --about"
        "status:toolkit.sh --status"
    )

    local test
    for test in "${test_cmds[@]}"; do
        local name cmd
        name="$(echo "$test" | cut -d: -f1)"
        cmd="$(echo "$test" | cut -d: -f2-)"

        echo -n "  Measuring $name... "
        local result
        result="$(perf_measure "$name" bash "${ANDROID_TOOLKIT_ROOT_DIR}/${cmd}" 2>/dev/null)"
        local duration
        duration="$(echo "$result" | jq -r '.duration_ms' 2>/dev/null || echo "0")"
        echo "${duration}ms"

        results_arr="$(echo "$results_arr" | jq --argjson r "$result" '. + [$r]' 2>/dev/null)"
    done

    # Add report generation (extended)
    echo -n "  Measuring report generation... "
    local report_result
    report_result="$(perf_measure "report" bash "${ANDROID_TOOLKIT_ROOT_DIR}/toolkit.sh" --report 2>/dev/null)"
    local report_duration
    report_duration="$(echo "$report_result" | jq -r '.duration_ms' 2>/dev/null || echo "0")"
    echo "${report_duration}ms"
    results_arr="$(echo "$results_arr" | jq --argjson r "$report_result" '. + [$r]' 2>/dev/null)"

    # Write results
    local full_result
    full_result="$(jq -n \
        --arg date "$(date -Iseconds)" \
        --arg version "${ANDROID_TOOLKIT_VERSION:-0.0.0}" \
        --argjson results "$results_arr" \
        '{
            suite: "standard",
            date: $date,
            toolkit_version: $version,
            results: $results,
            summary: {
                total_tests: ($results | length),
                total_duration_ms: ([$results[].duration_ms] | add)
            }
        }' 2>/dev/null || echo "{\"date\":\"$(date -Iseconds)\",\"results\":$results_arr}")"

    echo "$full_result" > "$results_file"
    log_success "Performance results saved: $results_file"
}

##############################################
# Compare results against baselines.
# Arguments:
#   $1: results file (optional, uses latest if omitted)
##############################################
perf_compare_baseline() {
    local results_file="${1:-$(ls -t "$PERF_RESULTS_DIR"/*.json 2>/dev/null | head -1)}"
    local baseline_file="${PERF_BASELINE_DIR}/baseline.json"

    if [[ ! -f "$results_file" ]]; then
        log_error "No results found. Run performance suite first."
        return 1
    fi

    if [[ ! -f "$baseline_file" ]]; then
        log_warning "No baseline found. Creating baseline from current results."
        cp "$results_file" "$baseline_file"
        log_success "Baseline created: $baseline_file"
        return 0
    fi

    log_section "Performance Regression Check"

    local has_regression=false
    local test_names
    test_names="$(jq -r '.results[].name' "$results_file" 2>/dev/null)"

    local name
    for name in $test_names; do
        local current baseline
        current="$(jq -r ".results[] | select(.name==\"$name\") | .duration_ms" "$results_file" 2>/dev/null || echo "0")"
        baseline="$(jq -r ".results[] | select(.name==\"$name\") | .duration_ms" "$baseline_file" 2>/dev/null || echo "0")"

        if [[ "$baseline" -gt 0 ]]; then
            local diff=$(( current - baseline ))
            local pct=$(( diff * 100 / baseline ))

            if [[ "$pct" -gt "$PERF_THRESHOLD" ]]; then
                log_error "  REGRESSION: $name ${pct}% slower (${baseline}ms → ${current}ms)"
                has_regression=true
            elif [[ "$pct" -lt "-$PERF_THRESHOLD" ]]; then
                log_success "  IMPROVEMENT: $name $(( -pct ))% faster (${baseline}ms → ${current}ms)"
            else
                log_info "  OK: $name (${baseline}ms → ${current}ms, ${pct}%)"
            fi
        fi
    done

    if $has_regression; then
        log_warning "Performance regressions detected!"
        return 1
    fi

    log_success "No regressions detected"
}

##############################################
# Main entry point.
##############################################
perf_run() {
    local cmd="${1:-suite}"

    case "$cmd" in
        suite)
            perf_run_suite
            ;;
        compare|check)
            perf_compare_baseline "${2:-}"
            ;;
        baseline)
            perf_compare_baseline "${2:-}"  # Creates baseline if none exists
            ;;
        *)
            echo "Usage: --performance <suite|compare|baseline>"
            return 1
            ;;
    esac
}
