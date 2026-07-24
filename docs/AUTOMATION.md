# Workflow Automation

Create, run, and schedule device automation workflows.

## Features

### Built-in Templates
| Template | Description |
|----------|-------------|
| `new_device`    | Full new-device setup (optimize + cleanup + audit) |
| `samsung_opt`   | Samsung-specific optimizations |
| `gaming`        | Gaming mode activation |
| `battery_opt`   | Battery optimization profile |
| `package_cleanup`| Bloatware removal workflow |
| `security_audit`| Full security audit + report |
| `benchmark`     | Performance benchmark run |
| `backup`        | Device settings backup |
| `report_gen`    | Generate comprehensive report |

### Automation Builder
Interactive step-by-step workflow construction:
- Device detection check
- Validation step
- Module execution step
- Wait/delay step
- Confirmation prompt step
- Report generation step
- Rollback step
- Notification step

### Scheduler
- View all scheduled jobs
- Track run count, success/failure stats
- Execute jobs on demand
- Remove completed jobs

## Usage

| Key | Action |
|-----|--------|
| `Enter` | Run selected template |
| `b` | Open Automation Builder |
| `s` | Open Scheduler view |
| `d` | Delete selected template |

## API

```bash
automation_list_templates
automation_run <template>
automation_builder
automation_scheduler_list
automation_scheduler_run <id>
```
