#!/data/data/com.termux/files/usr/bin/bash
#
# automation.sh — Workflow Automation, Builder & Scheduler
#
# Provides reusable workflow automation with:
#   - Predefined workflow templates
#   - Visual workflow builder (block-based)
#   - Scheduler framework for future jobs
#
# Part of the Android Toolkit Dashboard.

# ──────────────────────────────────────────────
# WORKFLOW DEFINITIONS
# ──────────────────────────────────────────────

declare -A AUTOMATION_WORKFLOWS=()
AUTOMATION_WORKFLOW_ORDER=()
AUTOMATION_RESULTS=()
AUTOMATION_RUNNING=false

# ──────────────────────────────────────────────
# SCHEDULER STATE
# ──────────────────────────────────────────────

SCHEDULER_JOBS=()
SCHEDULER_COMPLETED=()
SCHEDULER_FAILED=()
SCHEDULER_PENDING=()
SCHEDULER_ENABLED=false

##############################################
# Initialize built-in workflows.
automation_init() {
    # Format: workflow_id|name|description|steps (colon-separated commands)
    AUTOMATION_WORKFLOWS["new_device"]="New Device Setup|Initial configuration for a new device|doctor_run:maintenance_compile:performance_apply_profile balanced:backup_create_snapshot"
    AUTOMATION_WORKFLOWS["samsung_opt"]="Samsung Optimization|One UI specific optimizations|samsung_apply_light_optimizations:samsung_list_bloatware safe:maintenance_trim_cache"
    AUTOMATION_WORKFLOWS["gaming"]="Gaming Profile|Performance tuning for gaming|performance_apply_profile performance:maintenance_compile:network_refresh"
    AUTOMATION_WORKFLOWS["battery_opt"]="Battery Optimization|Extend battery life|performance_apply_profile powersave:maintenance_trim_cache:doctor_run battery"
    AUTOMATION_WORKFLOWS["package_cleanup"]="Package Cleanup|Remove unnecessary packages|packages_recommend:maintenance_trim_cache:backup_create_packages"
    AUTOMATION_WORKFLOWS["security_audit"]="Security Audit|Full security assessment|audit_run:security_harden_run:settings_verify"
    AUTOMATION_WORKFLOWS["benchmark"]="Benchmark Run|Performance measurement|benchmark_run:benchmark_list_history"
    AUTOMATION_WORKFLOWS["backup"]="Device Backup|Full device backup|backup_create_snapshot:backup_create_packages:reporting_full_report"
    AUTOMATION_WORKFLOWS["report_gen"]="Report Generation|Generate and export reports|reporting_full_report:export_report md:export_report json"

    AUTOMATION_WORKFLOW_ORDER=(new_device samsung_opt gaming battery_opt package_cleanup security_audit benchmark backup report_gen)
}

##############################################
# Get workflow info.
automation_get_info() {
    local id="$1" part="$2"
    local entry="${AUTOMATION_WORKFLOWS[$id]:-}"
    [[ -z "$entry" ]] && echo "?" && return
    case "$part" in
        name) echo "${entry%%|*}" ;;
        desc)
            local rest="${entry#*|}"
            echo "${rest%%|*}"
            ;;
        steps)
            local rest="${entry#*|}"
            rest="${rest#*|}"
            echo "$rest"
            ;;
    esac
}

##############################################
# Execute a workflow.
automation_run() {
    local workflow_id="$1"
    local entry="${AUTOMATION_WORKFLOWS[$workflow_id]:-}"
    [[ -z "$entry" ]] && { notify_push "Workflow not found: $workflow_id" "error"; return 1; }

    local name desc steps
    name="$(automation_get_info "$workflow_id" name)"
    steps="$(automation_get_info "$workflow_id" steps)"

    AUTOMATION_RUNNING=true
    AUTOMATION_RESULTS=()
    menu_msgbox "Workflow" "Running: $name\n\nThis may take several moments..."

    local IFS=':'
    local step_results=()
    local step_count=0
    local failed=false
    for step in $steps; do
        [[ -z "$step" ]] && continue
        ((step_count++))
        notify_push "Step $step_count: $step" "progress"
        local output
        output="$(eval "$step" 2>&1)" || true
        local exitcode=$?
        if [[ "$exitcode" -eq 0 ]]; then
            step_results+=("✓ $step")
        else
            step_results+=("✗ $step (exit: $exitcode)")
            failed=true
        fi
    done

    AUTOMATION_RUNNING=false
    AUTOMATION_RESULTS=("${step_results[@]}")

    local summary="Workflow: $name"$'\n'
    summary+="Completed: $step_count steps"$'\n'
    if [[ "$failed" == "true" ]]; then
        summary+="Status: Some steps failed"$'\n'
    else
        summary+="Status: All steps succeeded"$'\n'
    fi
    summary+=$'\n'"Results:"$'\n'
    local r
    for r in "${step_results[@]}"; do
        summary+="  $r"$'\n'
    done

    menu_textbox "Workflow Results" "$summary"

    # Record in audit trail
    audit_record "Automation" "run" "$workflow_id" "$([[ "$failed" == "true" ]] && echo 'partial' || echo 'success')"
}

##############################################
# Build a custom workflow interactively.
automation_builder() {
    local steps=()
    local done=false

    while ! $done; do
        local action
        action="$(menu_select "Automation Builder" "Add workflow step:" \
            "detect"    "Detect Device" \
            "validate"  "Validate State" \
            "module"    "Execute Module" \
            "wait"      "Wait (seconds)" \
            "confirm"   "Ask Confirmation" \
            "report"    "Generate Report" \
            "rollback"  "Rollback on Failure" \
            "notify"    "Send Notification" \
            "save"      "Save Workflow" \
            "cancel"    "Cancel")" || { done=true; continue; }

        case "$action" in
            detect)   steps+=("Detect Device: devices_list") ;;
            validate) steps+=("Validate: doctor_run") ;;
            module)
                local mod
                mod="$(menu_input "Module" "Function to call (e.g., benchmark_run):")" || continue
                [[ -n "$mod" ]] && steps+=("Execute: $mod")
                ;;
            wait)
                local secs
                secs="$(menu_input "Wait" "Seconds to wait:")" || continue
                [[ -n "$secs" ]] && steps+=("Wait: ${secs}s")
                ;;
            confirm)  steps+=("Confirm Action") ;;
            report)   steps+=("Report: reporting_full_report") ;;
            rollback) steps+=("Rollback: rollback_perform latest") ;;
            notify)   steps+=("Notify User") ;;
            save)
                if [[ "${#steps[@]}" -gt 0 ]]; then
                    local name
                    name="$(menu_input "Save" "Workflow name:")" || continue
                    if [[ -n "$name" ]]; then
                        local id="custom_$(date +%s)"
                        local steps_str=""
                        local s
                        for s in "${steps[@]}"; do
                            local step_cmd
                            step_cmd="$(echo "$s" | sed 's/^[^:]*: //')"
                            [[ -z "$steps_str" ]] && steps_str="$step_cmd" || steps_str+=":$step_cmd"
                        done
                        AUTOMATION_WORKFLOWS["$id"]="${name}|Custom workflow|${steps_str}"
                        AUTOMATION_WORKFLOW_ORDER+=("$id")
                        notify_push "Workflow '$name' saved" "success"
                        done=true
                    fi
                else
                    notify_push "No steps added yet" "warning"
                fi
                ;;
            cancel)   done=true ;;
        esac
    done
}

##############################################
# Render automation page.
_page_render_automation() {
    local top="$1" left="$2" width="$3" height="$4"
    renderer_cursor_goto "$top" "$left"
    renderer_bold
    renderer_fg_256 "$(theme_get accent)"
    printf 'Automation Center'
    renderer_reset
    renderer_fg_256 "$(theme_get muted)"
    printf ' — Workflows, builder, and scheduler'
    renderer_reset

    local row=$(( top + 2 ))
    local col="$left"

    # Workflows section
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    renderer_cursor_goto "$row" "$col"
    printf 'WORKFLOWS  [B: Build]  [R: Run]'
    renderer_reset
    ((row++))

    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get card_border)"
    printf '%*s' "$width" "" | tr ' ' '─'
    renderer_reset
    ((row++))

    local wf_id
    for wf_id in "${AUTOMATION_WORKFLOW_ORDER[@]}"; do
        [[ "$row" -ge $(( top + height - 4 )) ]] && break
        local name
        name="$(automation_get_info "$wf_id" name)"
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get accent)"
        printf '  ▶'
        renderer_reset
        renderer_fg_256 "$(theme_get fg)"
        printf ' %s' "$name"
        renderer_reset
        ((row++))
    done

    # Scheduler section
    ((row++))
    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get muted)"
    renderer_dim
    printf 'SCHEDULER  [S: Status]'
    renderer_reset
    ((row++))

    renderer_cursor_goto "$row" "$col"
    renderer_fg_256 "$(theme_get card_border)"
    printf '%*s' "$width" "" | tr ' ' '─'
    renderer_reset
    ((row++))

    if [[ "$SCHEDULER_ENABLED" == "true" ]]; then
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get fg)"
        printf '  Jobs: %d pending, %d completed, %d failed' \
            "${#SCHEDULER_PENDING[@]}" "${#SCHEDULER_COMPLETED[@]}" "${#SCHEDULER_FAILED[@]}"
        renderer_reset
    else
        renderer_cursor_goto "$row" "$col"
        renderer_fg_256 "$(theme_get muted)"
        printf '  Scheduler is available (requires cron/at for backend)'
        renderer_reset
    fi
}

_page_key_automation() {
    local key="$1"
    case "$key" in
        "r"|"R")
            local wf_ids=()
            local wf_id
            for wf_id in "${AUTOMATION_WORKFLOW_ORDER[@]}"; do
                wf_ids+=("$wf_id" "$(automation_get_info "$wf_id" name)")
            done
            local selected
            selected="$(menu_select "Run Workflow" "Choose:" "${wf_ids[@]}")" || return 0
            [[ -n "$selected" ]] && automation_run "$selected"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "b"|"B")
            automation_builder
            DASHBOARD_REDRAW_NEEDED=true
            ;;
        "s"|"S")
            local status="Scheduler Status"
            status+=$'\n'"Enabled: $SCHEDULER_ENABLED"
            status+=$'\n'"Pending: ${#SCHEDULER_PENDING[@]}"
            status+=$'\n'"Completed: ${#SCHEDULER_COMPLETED[@]}"
            status+=$'\n'"Failed: ${#SCHEDULER_FAILED[@]}"
            if [[ "$SCHEDULER_ENABLED" != "true" ]]; then
                status+=$'\n\n'"Scheduling requires cron or at daemon."
                status+=$'\n'"Install: pkg install cronie termux-services"
            fi
            menu_textbox "Scheduler" "$status"
            DASHBOARD_REDRAW_NEEDED=true
            ;;
    esac
}

# Initialize on load
automation_init
