#!/data/data/com.termux/files/usr/bin/bash
#
# scheduler.sh — Task scheduler module
#
# Manages recurring tasks using Termux:Boot, cron/crond, and
# termux-job-scheduler. Supports daily maintenance, weekly benchmark,
# monthly report, and automatic backup schedules.
#
# No root required. Uses Termux-native scheduling tools.
#
# Part of the Android Toolkit.

SCHEDULER_DIR="${ANDROID_TOOLKIT_ROOT_DIR}/.scheduler"
SCHEDULER_CRON_FILE="${SCHEDULER_DIR}/crontab"
SCHEDULER_BOOT_DIR="${HOME}/.termux/boot"
SCHEDULER_STATUS_FILE="${SCHEDULER_DIR}/status.json"

SCHEDULER_TASKS=(
    "daily:maintenance:0 3 * * *:${ANDROID_TOOLKIT_ROOT_DIR}/toolkit.sh --trim-cache"
    "weekly:benchmark:0 5 * * 0:${ANDROID_TOOLKIT_ROOT_DIR}/toolkit.sh --benchmark"
    "monthly:report:0 6 1 * *:${ANDROID_TOOLKIT_ROOT_DIR}/toolkit.sh --report"
    "backup:daily:0 4 * * *:${ANDROID_TOOLKIT_ROOT_DIR}/toolkit.sh --backup"
)

##############################################
# Initialize scheduler directory.
##############################################
scheduler_init() {
    mkdir -p "$SCHEDULER_DIR"
    mkdir -p "$SCHEDULER_BOOT_DIR" 2>/dev/null || true
}

##############################################
# Check if crond is available and running.
##############################################
scheduler_crond_available() {
    command -v crond &>/dev/null || command -v cron &>/dev/null
}

##############################################
# Check if termux-job-scheduler is available.
##############################################
scheduler_tjs_available() {
    command -v termux-job-scheduler &>/dev/null
}

##############################################
# Detect available scheduler backend.
# Outputs: cron, tjs, or none
##############################################
scheduler_detect_backend() {
    if scheduler_crond_available; then
        echo "cron"
    elif scheduler_tjs_available; then
        echo "tjs"
    else
        echo "none"
    fi
}

##############################################
# Install or update the crontab with toolkit tasks.
##############################################
_scheduler_install_cron() {
    local temp_cron
    temp_cron="$(mktemp /tmp/toolkit_cron.XXXXXX)"

    # Preserve existing cron jobs
    crontab -l 2>/dev/null > "$temp_cron" || true

    # Add toolkit tasks (avoid duplicates)
    for task_def in "${SCHEDULER_TASKS[@]}"; do
        local name schedule command
        name="$(echo "$task_def" | cut -d: -f1)"
        schedule="$(echo "$task_def" | cut -d: -f3)"
        command="$(echo "$task_def" | cut -d: -f4-)"

        # Remove old entry for this task
        grep -v "# toolkit-scheduler:${name}$" "$temp_cron" > "${temp_cron}.tmp" && mv "${temp_cron}.tmp" "$temp_cron"

        # Add new entry
        echo "${schedule} ${command} # toolkit-scheduler:${name}" >> "$temp_cron"
    done

    # Install crontab
    if crontab "$temp_cron" 2>/dev/null; then
        rm -f "$temp_cron"
        return 0
    else
        rm -f "$temp_cron"
        return 1
    fi
}

##############################################
# Create Termux:Boot script to start crond on device boot.
##############################################
_scheduler_install_boot() {
    local boot_script="${SCHEDULER_BOOT_DIR}/toolkit-scheduler"

    cat > "$boot_script" << 'SCRIPT'
#!/data/data/com.termux/files/usr/bin/bash
# Android Toolkit Scheduler — auto-starts crond on boot
termux-wake-lock
crond
SCRIPT

    chmod +x "$boot_script"
    log_info "Termux:Boot script installed: $boot_script"
}

##############################################
# Enable scheduler with available backend.
##############################################
scheduler_enable() {
    scheduler_init

    local backend
    backend="$(scheduler_detect_backend)"

    case "$backend" in
        cron)
            log_info "Installing cron jobs..."
            if _scheduler_install_cron; then
                log_success "Cron jobs installed"
            else
                log_error "Failed to install cron jobs"
                return 1
            fi

            # Ensure crond is running
            if ! pgrep -x crond &>/dev/null; then
                if command -v sv &>/dev/null; then
                    sv-enable crond 2>/dev/null || true
                    sv up crond 2>/dev/null || true
                fi
                crond 2>/dev/null || true
            fi

            # Install boot script
            _scheduler_install_boot

            log_success "Scheduler enabled (cron backend)"
            ;;

        tjs)
            log_info "Installing termux-job-scheduler tasks..."
            # termux-job-scheduler uses Android's JobScheduler
            for task_def in "${SCHEDULER_TASKS[@]}"; do
                local name period_ms command
                name="$(echo "$task_def" | cut -d: -f1)"
                command="$(echo "$task_def" | cut -d: -f4-)"

                case "$name" in
                    daily)   period_ms=$(( 24 * 3600 * 1000 )) ;;
                    weekly)  period_ms=$(( 7 * 24 * 3600 * 1000 )) ;;
                    monthly) period_ms=$(( 30 * 24 * 3600 * 1000 )) ;;
                    backup)  period_ms=$(( 24 * 3600 * 1000 )) ;;
                    *)       period_ms=$(( 24 * 3600 * 1000 )) ;;
                esac

                termux-job-scheduler -s "$command" --period-ms "$period_ms" --job-name "toolkit-${name}" 2>/dev/null || true
            done
            log_success "Scheduler enabled (termux-job-scheduler backend)"
            ;;

        none)
            log_warning "No scheduler backend found"
            log_info "Install cronie: pkg install cronie"
            log_info "Or termux-job-scheduler: pkg install termux-job-scheduler"
            return 1
            ;;
    esac

    scheduler_save_status "enabled" "$backend"
}

##############################################
# Disable scheduler and remove tasks.
##############################################
scheduler_disable() {
    scheduler_init

    local backend
    backend="$(scheduler_detect_backend)"

    case "$backend" in
        cron)
            # Remove toolkit tasks from crontab
            local temp_cron
            temp_cron="$(mktemp /tmp/toolkit_cron.XXXXXX)"
            crontab -l 2>/dev/null | grep -v "toolkit-scheduler:" > "$temp_cron" || true
            crontab "$temp_cron" 2>/dev/null || true
            rm -f "$temp_cron"

            # Remove boot script
            rm -f "${SCHEDULER_BOOT_DIR}/toolkit-scheduler"
            log_success "Scheduler disabled (cron jobs removed)"
            ;;

        tjs)
            for task_def in "${SCHEDULER_TASKS[@]}"; do
                local name
                name="$(echo "$task_def" | cut -d: -f1)"
                termux-job-scheduler --cancel "toolkit-${name}" 2>/dev/null || true
            done
            log_success "Scheduler disabled (TJS tasks removed)"
            ;;
    esac

    scheduler_save_status "disabled" ""
}

##############################################
# Save scheduler status to JSON.
##############################################
scheduler_save_status() {
    local status="$1" backend="$2"
    if command -v jq &>/dev/null; then
        local data
        data="$(cat "$SCHEDULER_STATUS_FILE" 2>/dev/null || echo '{"enabled":false,"backend":"","tasks":[],"last_run":""}')"
        data="$(echo "$data" | jq --arg s "$status" --arg b "$backend" \
            '.enabled = ($s == "enabled") | .backend = $b')"
        echo "$data" > "$SCHEDULER_STATUS_FILE"
    fi
}

##############################################
# List scheduled tasks.
##############################################
scheduler_list() {
    scheduler_init

    log_section "Scheduled Tasks"

    local backend
    backend="$(scheduler_detect_backend)"
    log_info "Backend: $backend"

    echo ""
    if [[ "$backend" == "cron" ]]; then
        echo "  Cron jobs:"
        crontab -l 2>/dev/null | grep "toolkit-scheduler:" | while IFS= read -r line; do
            local task_name
            task_name="$(echo "$line" | sed 's/.*# toolkit-scheduler://')"
            local schedule
            schedule="$(echo "$line" | awk '{print $1, $2, $3, $4, $5}')"
            printf "    %-15s %s\n" "$task_name" "$schedule"
        done || echo "    No toolkit tasks scheduled"
    else
        echo "  Available tasks:"
        for task_def in "${SCHEDULER_TASKS[@]}"; do
            local name desc schedule
            name="$(echo "$task_def" | cut -d: -f1)"
            desc="$(echo "$task_def" | cut -d: -f2)"
            schedule="$(echo "$task_def" | cut -d: -f3)"
            printf "    %-15s %-20s %s\n" "$name" "$schedule" "$desc"
        done
    fi
}

##############################################
# Run a specific scheduled task immediately.
# Arguments:
#   $1: task name (daily, weekly, monthly, backup)
##############################################
scheduler_run_task() {
    local task_name="$1"

    for task_def in "${SCHEDULER_TASKS[@]}"; do
        local name command
        name="$(echo "$task_def" | cut -d: -f1)"
        command="$(echo "$task_def" | cut -d: -f4-)"

        if [[ "$name" == "$task_name" ]]; then
            log_info "Running scheduled task: $task_name"
            eval "$command"
            scheduler_save_status "enabled" "$(scheduler_detect_backend)"
            return $?
        fi
    done

    log_error "Unknown task: $task_name"
    log_info "Available tasks: daily, weekly, monthly, backup"
    return 1
}

##############################################
# Main scheduler entry point.
# Arguments:
#   $@: list|add|remove|run|enable|disable
##############################################
scheduler_run() {
    local action="${1:-list}"

    case "$action" in
        list|status)
            scheduler_list
            ;;
        enable|start)
            scheduler_enable
            ;;
        disable|stop)
            scheduler_disable
            ;;
        run)
            scheduler_run_task "${2:-daily}"
            ;;
        add)
            log_warning "Custom task addition not yet implemented via CLI"
            log_info "Edit the SCHEDULER_TASKS array in modules/scheduler.sh"
            ;;
        remove)
            log_warning "Use 'disable' to remove all toolkit tasks"
            ;;
        *)
            log_error "Unknown scheduler action: $action"
            echo "  Usage: --schedule [list|enable|disable|run <task>]"
            return 1
            ;;
    esac
}
