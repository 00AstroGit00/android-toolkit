#!/data/data/com.termux/files/usr/bin/bash
#
# benchmark.sh — Device performance benchmark module
#
# Collects:
#   - CPU information (cores, frequency, governor)
#   - Memory (total, available, swap)
#   - Storage (data partition size/usage)
#   - Battery (capacity, temperature, voltage)
#   - Thermal (temperatures from thermalservice)
#   - Frame rendering (dumpsys gfxinfo)
#   - SurfaceFlinger (frame rate, HWC info)
#   - Graphics (GPU renderer, OpenGL version)
#   - Launch latency (cold start time for packages)
#   - Package compile state (dex2oat status)
#
# Output: structured JSON and human-readable Markdown.
#
# Part of the Android Toolkit.

##############################################
# Run all benchmarks.
# Arguments:
#   $1: output format (json|markdown|both) — default: both
##############################################
benchmark_run() {
    local format="${1:-both}"

    log_section "Device Benchmark"

    local results
    results="$(_benchmark_collect_all)"

    case "$format" in
        json|both)
            _benchmark_output_json "$results"
            ;;
    esac

    case "$format" in
        markdown|both)
            _benchmark_output_markdown "$results"
            ;;
    esac

    log_success "Benchmark complete"
}

##############################################
# Collect all benchmark data into a structured string.
##############################################
_benchmark_collect_all() {
    local data=""

    data+="cpu=$(_benchmark_cpu)"$'\n'
    data+="memory=$(_benchmark_memory)"$'\n'
    data+="storage=$(_benchmark_storage)"$'\n'
    data+="battery=$(_benchmark_battery)"$'\n'
    data+="thermal=$(_benchmark_thermal)"$'\n'
    data+="gpu=$(_benchmark_gpu)"$'\n'
    data+="surfaceflinger=$(_benchmark_surfaceflinger)"$'\n'
    data+="packages=$(_benchmark_packages)"$'\n'

    echo "$data"
}

##############################################
# CPU benchmark data.
##############################################
_benchmark_cpu() {
    local cpu_info=""

    # Number of cores
    local cores
    cores="$(nproc 2>/dev/null || backend_exec nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "?")"
    cpu_info+="cores=$cores"$'\n'

    # CPU info
    local cpu_model
    cpu_model="$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d':' -f2 | sed 's/^ *//' || echo "unknown")"
    cpu_info+="model=$cpu_model"$'\n'

    # Max/min frequency (if cpufreq available)
    if [[ -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
        local max_freq min_freq
        max_freq="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null || echo "?")"
        min_freq="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq 2>/dev/null || echo "?")"
        cpu_info+="max_freq=$max_freq"$'\n'
        cpu_info+="min_freq=$min_freq"$'\n'

        local governor
        governor="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "?")"
        cpu_info+="governor=$governor"$'\n'
    else
        cpu_info+="max_freq=?"$'\n'
        cpu_info+="min_freq=?"$'\n'
        cpu_info+="governor=?"$'\n'
    fi

    # SOC
    local soc
    soc="$(cap_get CAP_SOC 2>/dev/null || echo "unknown")"
    cpu_info+="soc=$soc"$'\n'

    echo "$cpu_info"
}

##############################################
# Memory benchmark data.
##############################################
_benchmark_memory() {
    local mem_info=""

    if cap_available CAP_DUMPSYS_MEMINFO 2>/dev/null; then
        local mem_total mem_free mem_avail
        mem_total="$(backend_exec dumpsys meminfo 2>/dev/null | grep "Total RAM:" | awk '{print $3}' || echo "?")"
        mem_free="$(backend_exec dumpsys meminfo 2>/dev/null | grep "Free RAM:" | awk '{print $3}' || echo "?")"
        mem_avail="$(backend_exec dumpsys meminfo 2>/dev/null | grep "Used RAM:" | awk '{print $3}' || echo "?")"
        mem_info+="total=$mem_total"$'\n'
        mem_info+="free=$mem_free"$'\n'
        mem_info+="used=$mem_avail"$'\n'
    elif [[ -f /proc/meminfo ]]; then
        local total_mem free_mem
        total_mem="$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')"
        free_mem="$(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print $2}')"
        mem_info+="total=${total_mem}kB"$'\n'
        mem_info+="free=${free_mem}kB"$'\n'
    else
        mem_info+="total=?"$'\n'
        mem_info+="free=?"$'\n'
    fi

    # Swap
    if command -v free &>/dev/null; then
        local swap_total swap_used
        swap_total="$(free -k 2>/dev/null | awk '/Swap:/{print $2}')"
        swap_used="$(free -k 2>/dev/null | awk '/Swap:/{print $3}')"
        mem_info+="swap_total=${swap_total:-0}"$'\n'
        mem_info+="swap_used=${swap_used:-0}"$'\n'
    else
        mem_info+="swap_total=0"$'\n'
        mem_info+="swap_used=0"$'\n'
    fi

    echo "$mem_info"
}

##############################################
# Storage benchmark data.
##############################################
_benchmark_storage() {
    local storage_info=""

    local data_info
    data_info="$(backend_exec df -h /data 2>/dev/null || df -h /data 2>/dev/null || echo "")"
    if [[ -n "$data_info" ]]; then
        local total used avail use_pct
        total="$(echo "$data_info" | awk 'NR==2 {print $2}')"
        used="$(echo "$data_info" | awk 'NR==2 {print $3}')"
        avail="$(echo "$data_info" | awk 'NR==2 {print $4}')"
        use_pct="$(echo "$data_info" | awk 'NR==2 {print $5}')"
        storage_info+="total=$total"$'\n'
        storage_info+="used=$used"$'\n'
        storage_info+="avail=$avail"$'\n'
        storage_info+="use_pct=$use_pct"$'\n'
    fi

    local system_info
    system_info="$(backend_exec df -h /system 2>/dev/null || echo "")"
    if [[ -n "$system_info" ]]; then
        local sys_total sys_used sys_avail
        sys_total="$(echo "$system_info" | awk 'NR==2 {print $2}')"
        sys_used="$(echo "$system_info" | awk 'NR==2 {print $3}')"
        sys_avail="$(echo "$system_info" | awk 'NR==2 {print $4}')"
        storage_info+="system_total=$sys_total"$'\n'
        storage_info+="system_used=$sys_used"$'\n'
        storage_info+="system_avail=$sys_avail"$'\n'
    fi

    echo "$storage_info"
}

##############################################
# Battery benchmark data.
##############################################
_benchmark_battery() {
    local bat_info=""

    if cap_available CAP_DUMPSYS_BATTERY 2>/dev/null; then
        local bat_dump
        bat_dump="$(backend_exec dumpsys battery 2>/dev/null || echo "")"

        local level scale temp voltage
        level="$(echo "$bat_dump" | grep 'level:' | head -1 | awk '{print $2}')"
        scale="$(echo "$bat_dump" | grep 'scale:' | head -1 | awk '{print $2}')"
        temp="$(echo "$bat_dump" | grep 'temperature:' | head -1 | awk '{print $2}')"
        voltage="$(echo "$bat_dump" | grep 'voltage:' | head -1 | awk '{print $2}')"

        local pct="?"
        if [[ -n "$level" && -n "$scale" ]] && [[ "$scale" -gt 0 ]] 2>/dev/null; then
            pct="$((level * 100 / scale))"
        elif [[ -n "$level" ]]; then
            pct="$level"
        fi

        bat_info+="level=$pct"$'\n'
        bat_info+="temperature=$temp"$'\n'
        bat_info+="voltage=$voltage"$'\n'

        local tech
        tech="$(echo "$bat_dump" | grep 'technology:' | head -1 | awk '{print $2}')"
        bat_info+="technology=$tech"$'\n'
    fi

    echo "$bat_info"
}

##############################################
# Thermal benchmark data.
##############################################
_benchmark_thermal() {
    local thermal_info=""

    if cap_available CAP_DUMPSYS_THERMAL 2>/dev/null; then
        local thermal
        thermal="$(backend_exec dumpsys thermalservice 2>/dev/null | head -30 || echo "")"
        if [[ -n "$thermal" ]]; then
            local temps
            temps="$(echo "$thermal" | grep -i 'temperature' | head -5 || echo "")"
            while IFS= read -r line; do
                if [[ -n "$line" ]]; then
                    thermal_info+="sensor: $line"$'\n'
                fi
            done <<< "$temps"
        fi
    fi

    # Also try sysfs thermal
    if [[ -d /sys/class/thermal ]]; then
        for zone in /sys/class/thermal/thermal_zone*; do
            local type temp
            type="$(cat "$zone/type" 2>/dev/null || echo "unknown")"
            temp="$(cat "$zone/temp" 2>/dev/null || echo "?")"
            if [[ "$temp" =~ ^[0-9]+$ ]]; then
                temp="$((temp / 1000))°C"
            fi
            thermal_info+="${type}=${temp}"$'\n'
        done 2>/dev/null
    fi

    if [[ -z "$thermal_info" ]]; then
        thermal_info+="thermal=unavailable"$'\n'
    fi

    echo "$thermal_info"
}

##############################################
# GPU benchmark data.
##############################################
_benchmark_gpu() {
    local gpu_info=""

    if cap_available CAP_DUMPSYS_SURFACEFLINGER 2>/dev/null; then
        local sf
        sf="$(backend_exec dumpsys SurfaceFlinger 2>/dev/null | head -50 || echo "")"

        local gpu_renderer
        gpu_renderer="$(echo "$sf" | grep -i 'GLES:' | head -1 || echo "")"
        gpu_info+="renderer=$gpu_renderer"$'\n'

        local vsync
        vsync="$(echo "$sf" | grep -i 'vsync' | head -1 || echo "")"
        gpu_info+="vsync=$vsync"$'\n'
    fi

    if cap_available CAP_DUMPSYS_GFXINFO 2>/dev/null; then
        local gfx
        gfx="$(backend_exec dumpsys gfxinfo 2>/dev/null | head -10 || echo "")"
        local gpu_info_line
        gpu_info_line="$(echo "$gfx" | grep -i 'gpu' | head -1 || echo "")"
        if [[ -n "$gpu_info_line" ]]; then
            gpu_info+="gpu_info=$gpu_info_line"$'\n'
        fi
    fi

    echo "$gpu_info"
}

##############################################
# SurfaceFlinger frame data.
##############################################
_benchmark_surfaceflinger() {
    local sf_info=""

    if cap_available CAP_DUMPSYS_SURFACEFLINGER 2>/dev/null; then
        local sf
        sf="$(backend_exec dumpsys SurfaceFlinger --display-id 2>/dev/null || backend_exec dumpsys SurfaceFlinger 2>/dev/null | head -100 || echo "")"

        local hwc
        hwc="$(echo "$sf" | grep -i 'HWC' | head -3 || echo "")"
        sf_info+="hwc=$hwc"$'\n'

        local refresh_rate
        refresh_rate="$(echo "$sf" | grep -i 'refresh' | head -1 || echo "")"
        sf_info+="refresh=$refresh_rate"$'\n'

        local frame_rate
        frame_rate="$(echo "$sf" | grep -i 'frame' | head -1 || echo "")"
        sf_info+="frame_rate=$frame_rate"$'\n'
    fi

    echo "$sf_info"
}

##############################################
# Package compilation state.
##############################################
_benchmark_packages() {
    local pkg_info=""
    local total=0 compiled=0 speed=0 speed_profile=0 verify=0 extract=0

    if cap_available CAP_CMD_PACKAGE 2>/dev/null; then
        local pkg_list
        pkg_list="$(backend_exec pm list packages 2>/dev/null | sed 's/^package://' || echo "")"

        while IFS= read -r pkg; do
            [[ -z "$pkg" ]] && continue
            total=$((total + 1))
            local compile_mode
            compile_mode="$(backend_exec cmd package compile -m verify -f "$pkg" 2>/dev/null | grep -o 'compiler-filter=[a-z-]*' | cut -d= -f2 || echo "unknown")"
            case "$compile_mode" in
                speed) speed=$((speed + 1)); compiled=$((compiled + 1)) ;;
                speed-profile) speed_profile=$((speed_profile + 1)); compiled=$((compiled + 1)) ;;
                verify) verify=$((verify + 1)) ;;
                extract) extract=$((extract + 1)) ;;
                *) ;;
            esac
        done <<< "$(echo "$pkg_list" | head -100)" 2>/dev/null # limit for speed
    fi

    pkg_info+="total=$total"$'\n'
    pkg_info+="compiled=$compiled"$'\n'
    pkg_info+="speed=$speed"$'\n'
    pkg_info+="speed_profile=$speed_profile"$'\n'
    pkg_info+="verify=$verify"$'\n'
    pkg_info+="extract=$extract"$'\n'

    echo "$pkg_info"
}

##############################################
# Output benchmark data as JSON.
##############################################
_benchmark_output_json() {
    local data="$1"
    local bench_file="${ANDROID_TOOLKIT_ROOT_DIR}/logs/benchmark_$(date '+%Y%m%d_%H%M%S').json"

    {
        echo "{"
        echo '  "timestamp": "'$(date '+%Y-%m-%d %H:%M:%S')'",'
        echo '  "device": "'$(detect_device_summary 2>/dev/null)'",'
        echo '  "results": {'

        local first=true
        while IFS='=' read -r section rest; do
            if [[ -z "$section" ]]; then
                continue
            fi
            if $first; then first=false; else echo ","; fi
            echo "    \"$section\": {"

            local inner_first=true
            while IFS='=' read -r key val; do
                [[ -z "$key" ]] && continue
                if $inner_first; then inner_first=false; else echo ","; fi
                echo -n "      \"$key\": \"$val\""
            done <<< "$rest"

            echo ""
            echo -n "    }"
        done <<< "$data"
        echo ""
        echo "  }"
        echo "}"
    } > "$bench_file"

    if command -v jq &>/dev/null; then
        jq . "$bench_file" > "${bench_file}.tmp" 2>/dev/null && mv "${bench_file}.tmp" "$bench_file"
    fi

    log_success "Benchmark JSON: $bench_file"
    echo "$bench_file"
}

##############################################
# Output benchmark data as Markdown.
##############################################
_benchmark_output_markdown() {
    local data="$1"
    local md_file="${ANDROID_TOOLKIT_ROOT_DIR}/logs/benchmark_$(date '+%Y%m%d_%H%M%S').md"

    {
        echo "# Device Benchmark Report"
        echo ""
        echo "**Generated:** $(date '+%Y-%m-%d %H:%M:%S')"
        echo "**Device:** $(detect_device_summary 2>/dev/null || echo 'unknown')"
        echo ""
        echo "## CPU"
        echo "| Metric | Value |"
        echo "|--------|-------|"

        local cpu_data
        cpu_data="$(echo "$data" | grep '^cpu=' | cut -d'=' -f2-)"
        while IFS='=' read -r key val; do
            [[ -n "$key" ]] && echo "| $key | $val |"
        done <<< "$cpu_data"

        echo ""
        echo "## Memory"
        echo "| Metric | Value |"
        echo "|--------|-------|"
        local mem_data
        mem_data="$(echo "$data" | grep '^memory=' | cut -d'=' -f2-)"
        while IFS='=' read -r key val; do
            [[ -n "$key" ]] && echo "| $key | $val |"
        done <<< "$mem_data"

        echo ""
        echo "## Storage"
        echo "| Metric | Value |"
        echo "|--------|-------|"
        local sto_data
        sto_data="$(echo "$data" | grep '^storage=' | cut -d'=' -f2-)"
        while IFS='=' read -r key val; do
            [[ -n "$key" ]] && echo "| $key | $val |"
        done <<< "$sto_data"

        echo ""
        echo "## Battery"
        echo "| Metric | Value |"
        echo "|--------|-------|"
        local bat_data
        bat_data="$(echo "$data" | grep '^battery=' | cut -d'=' -f2-)"
        while IFS='=' read -r key val; do
            [[ -n "$key" ]] && echo "| $key | $val |"
        done <<< "$bat_data"

        echo ""
        echo "## Thermal"
        echo "| Metric | Value |"
        echo "|--------|-------|"
        local therm_data
        therm_data="$(echo "$data" | grep '^thermal=' | cut -d'=' -f2-)"
        while IFS='=' read -r key val; do
            [[ -n "$key" ]] && echo "| $key | $val |"
        done <<< "$therm_data"

        echo ""
        echo "## GPU"
        echo "| Metric | Value |"
        echo "|--------|-------|"
        local gpu_data
        gpu_data="$(echo "$data" | grep '^gpu=' | cut -d'=' -f2-)"
        while IFS='=' read -r key val; do
            [[ -n "$key" ]] && echo "| $key | $val |"
        done <<< "$gpu_data"

        echo ""
        echo "## SurfaceFlinger"
        echo "| Metric | Value |"
        echo "|--------|-------|"
        local sf_data
        sf_data="$(echo "$data" | grep '^surfaceflinger=' | cut -d'=' -f2-)"
        while IFS='=' read -r key val; do
            [[ -n "$key" ]] && echo "| $key | $val |"
        done <<< "$sf_data"

        echo ""
        echo "## Package Compilation"
        echo "| Metric | Value |"
        echo "|--------|-------|"
        local pkg_data
        pkg_data="$(echo "$data" | grep '^packages=' | cut -d'=' -f2-)"
        while IFS='=' read -r key val; do
            [[ -n "$key" ]] && echo "| $key | $val |"
        done <<< "$pkg_data"
    } > "$md_file"

    log_success "Benchmark Markdown: $md_file"
    echo "$md_file"
}

# ══════════════════════════════════════════════════════════════
# Enhanced Benchmarking (Phase 4)
# ══════════════════════════════════════════════════════════════

BENCHMARK_HISTORY_DIR="${ANDROID_TOOLKIT_ROOT_DIR}/.benchmarks"

##############################################
# Initialize benchmark history storage.
##############################################
benchmark_history_init() {
    mkdir -p "$BENCHMARK_HISTORY_DIR"
}

##############################################
# Run a benchmark measurement N times and return values.
# Arguments:
#   $1: metric name (e.g., "memory_score")
#   $2: measurement function name
#   $3: number of runs (default: 3)
# Outputs: space-separated values
##############################################
benchmark_repeated_measure() {
    local metric="$1" func="$2" count="${3:-3}"
    local values=()

    for ((i=1; i<=count; i++)); do
        local val
        val="$($func 2>/dev/null || echo 0)"
        values+=("$val")
        log_debug "Benchmark $metric run $i/$count: $val"
    done

    echo "${values[@]}"
}

##############################################
# Calculate median from space-separated values.
# Arguments:
#   $1: space-separated numeric values
# Outputs: median
##############################################
benchmark_median() {
    local values=($1)
    local sorted
    sorted="$(printf '%s\n' "${values[@]}" | sort -n)"
    local count="${#values[@]}"
    local mid=$(( count / 2 ))

    if [[ $(( count % 2 )) -eq 0 ]]; then
        echo "$sorted" | sed -n "${mid}p"
    else
        echo "$sorted" | sed -n "$(( mid + 1 ))p"
    fi
}

##############################################
# Calculate variance from space-separated values.
# Arguments:
#   $1: space-separated numeric values
# Outputs: variance
##############################################
benchmark_variance() {
    local values=($1)
    local sum=0 count=0 mean=0 var_sum=0

    for v in "${values[@]}"; do
        sum=$(( sum + v ))
        count=$(( count + 1 ))
    done
    [[ "$count" -eq 0 ]] && { echo "0"; return 0; }

    mean=$(( sum / count ))

    for v in "${values[@]}"; do
        local diff=$(( v - mean ))
        var_sum=$(( var_sum + diff * diff ))
    done

    echo $(( var_sum / count ))
}

##############################################
# Save benchmark results to history.
# Arguments:
#   $1: JSON result string
##############################################
benchmark_save_history() {
    benchmark_history_init
    local timestamp
    timestamp="$(date '+%Y%m%d_%H%M%S')"
    local history_file="${BENCHMARK_HISTORY_DIR}/${timestamp}.json"

    echo "$1" > "$history_file"
    log_debug "Benchmark saved: $history_file"
    echo "$history_file"
}

##############################################
# Load a previous benchmark result.
# Arguments:
#   $1: timestamp or "latest"
# Outputs: JSON content
##############################################
benchmark_load_history() {
    local target="$1"
    local file=""

    if [[ "$target" == "latest" ]]; then
        file="$(ls -t "$BENCHMARK_HISTORY_DIR"/*.json 2>/dev/null | head -1)"
    else
        file="${BENCHMARK_HISTORY_DIR}/${target}.json"
    fi

    if [[ -f "$file" ]]; then
        cat "$file"
    fi
}

##############################################
# List benchmark history.
##############################################
benchmark_list_history() {
    benchmark_history_init
    log_section "Benchmark History"

    local files
    files="$(ls -t "$BENCHMARK_HISTORY_DIR"/*.json 2>/dev/null)"

    if [[ -z "$files" ]]; then
        log_info "No benchmark history found"
        return 0
    fi

    echo ""
    printf "  %-25s %s\n" "Timestamp" "Scores"
    printf "  %-25s %s\n" "─────────────────────" "──────────────────────────────"
    local file
    for file in $files; do
        local ts name score
        ts="$(basename "$file" .json)"
        name="$(jq -r '.name // "benchmark"' "$file" 2>/dev/null || echo "unknown")"
        score="$(jq -r '.scores.overall // "N/A"' "$file" 2>/dev/null || echo "N/A")"
        printf "  %-25s %s (score: %s)\n" "$ts" "$name" "$score"
    done
}

##############################################
# Compare current benchmark against a previous one.
# Arguments:
#   $1: previous benchmark timestamp or "latest"
# Outputs: comparison text
##############################################
benchmark_compare_previous() {
    local prev_file="${1:-latest}"
    local prev_data

    prev_data="$(benchmark_load_history "$prev_file")"
    if [[ -z "$prev_data" ]]; then
        log_warning "No previous benchmark to compare against"
        return 1
    fi

    log_section "Benchmark Comparison"

    local prev_overall cur_overall
    prev_overall="$(echo "$prev_data" | jq -r '.scores.overall // 0' 2>/dev/null || echo 0)"
    cur_overall="${BENCHMARK_OVERALL_SCORE:-0}"

    if [[ "$cur_overall" -gt 0 && "$prev_overall" -gt 0 ]]; then
        local diff=$(( cur_overall - prev_overall ))
        if [[ "$diff" -gt 0 ]]; then
            log_success "Improved by ${diff} points (${prev_overall} → ${cur_overall})"
        elif [[ "$diff" -lt 0 ]]; then
            log_warning "Declined by $(( -diff )) points (${prev_overall} → ${cur_overall})"
        else
            log_info "Unchanged (${prev_overall} → ${cur_overall})"
        fi
    fi

    echo ""
    echo "  Previous: $(basename "$prev_file" .json)"
    if command -v jq &>/dev/null; then
        echo "$prev_data" | jq '.scores' 2>/dev/null
    fi
}

# Enhanced benchmark entry point with history
benchmark_run_enhanced() {
    local runs="${1:-3}"

    log_section "Enhanced Benchmark (${runs}x runs)"
    log_info "Running benchmark ${runs} times for median values..."

    local scores=()
    local i
    for ((i=1; i<=runs; i++)); do
        log_info "Run $i/$runs..."
        benchmark_run 2>/dev/null | tail -1
        scores+=("${BENCHMARK_OVERALL_SCORE:-0}")
    done

    local score_list="${scores[*]}"
    local median variance
    median="$(benchmark_median "$score_list")"
    variance="$(benchmark_variance "$score_list")"

    echo ""
    echo "  ── Repeated Benchmark Results ──"
    printf "  Runs:    %s\n" "$score_list"
    printf "  Median:  %s\n" "$median"
    printf "  Variance: %s\n" "$variance"

    local json_data
    json_data="$(jq -n \
        --arg date "$(date -Iseconds)" \
        --argjson runs "$runs" \
        --argjson median "$median" \
        --argjson variance "$variance" \
        --argjson scores "$(printf '%s\n' "${scores[@]}" | jq -R -s -c 'split("\n") | map(select(length > 0) | tonumber)')" \
        '{
            name: "benchmark",
            date: $date,
            runs: $runs,
            scores: $scores,
            median: $median,
            variance: $variance,
            overall: $median
        }' 2>/dev/null || echo "{\"date\":\"$(date -Iseconds)\",\"runs\":$runs,\"median\":$median}")"

    benchmark_save_history "$json_data"
    benchmark_compare_previous "latest"
}
