#!/data/data/com.termux/files/usr/bin/bash
#
# docgen/architecture.sh — Architecture documentation generator
# Part of the Android Toolkit.

docgen_architecture() {
    local output_dir="$1"
    local file="${output_dir}/architecture.md"

    log_info "Generating architecture overview..."

    cat > "$file" << 'ARCH'
# Architecture Overview

## Component Diagram

```
┌────────────────────────────────────────────────────────┐
│                     toolkit.sh                          │
│  CLI dispatcher, flag parsing, global init             │
└────────────────────┬───────────────────────────────────┘
                     │
     ┌───────────────┼───────────────────┐
     ▼               ▼                   ▼
┌──────────┐  ┌──────────────┐  ┌──────────────────┐
│ Commands │  │ Capability   │  │ Event System     │
│ Registry │  │ Graph        │  │ (lib/events.sh)  │
│ (lib/    │  │ (lib/        │  │                  │
│ commands │  │ capability   │  │ Sub/pub with     │
│ .sh)     │  │ _graph.sh)   │  │ cycle detection  │
└──────────┘  └──────────────┘  └──────────────────┘
     │               │                   │
     ▼               ▼                   ▼
┌────────────────────────────────────────────────────────┐
│                    Modules                              │
│  ┌─────────┐ ┌──────────┐ ┌──────────┐ ┌───────────┐  │
│  │ adb.sh  │ │ settings │ │ profile  │ │ benchmark │  │
│  │ rish.sh │ │ .sh      │ │ _manager │ │ .sh       │  │
│  │         │ │          │ │ .sh      │ │ (enhanced)│  │
│  └─────────┘ └──────────┘ └──────────┘ └───────────┘  │
│  ┌─────────┐ ┌──────────┐ ┌──────────┐ ┌───────────┐  │
│  │ watch   │ │ compare  │ │ docgen   │ │ export.sh │  │
│  │ .sh     │ │ .sh      │ │ .sh      │ │           │  │
│  └─────────┘ └──────────┘ └──────────┘ └───────────┘  │
│  ┌─────────┐ ┌──────────┐                               │
│  │ tui.sh  │ │ install  │                               │
│  │         │ │ .sh      │                               │
│  └─────────┘ └──────────┘                               │
└────────────────────────────────────────────────────────┘
     │               │
     ▼               ▼
┌────────────────────────────────────────────────────────┐
│                   Libraries                             │
│  ┌──────────┐ ┌──────────┐ ┌────────────┐             │
│  │ utils.sh │ │ plugin   │ │ json_output│             │
│  │ (colors, │ │ .sh      │ │ .sh        │             │
│  │ logging, │ │ (SDK 2.1)│ │ (machine-  │             │
│  │ confirm) │ │          │ │ readable)  │             │
│  └──────────┘ └──────────┘ └────────────┘             │
│  ┌──────────┐ ┌──────────┐ ┌────────────┐             │
│  │ settings │ │ deps     │ │ settings   │             │
│  │ .sh      │ │ endencies│ │ -db.json   │             │
│  │ (registry│ │ .sh      │ │ (data)     │             │
│  │ API)     │ │          │ │            │             │
│  └──────────┘ └──────────┘ └────────────┘             │
└────────────────────────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────┐
│                    Backends                             │
│  ┌──────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ ADB      │  │ Shizuku/     │  │ Termux (native)  │  │
│  │ (USB/TCP)│  │ rish         │  │ commands          │  │
│  └──────────┘  └──────────────┘  └──────────────────┘  │
└────────────────────────────────────────────────────────┘
```

## Data Flow

```
User Input → toolkit.sh → command registry → capability check
  → backend selection → module execution → JSON/TTY output
                              ↓
                   Event System (notifications)
                              ↓
                   Optional: profile save / benchmark history
```

## Key Design Decisions

1. **Modular by design**: Each module is independently loadable
2. **No root required**: ADB or Shizuku/rish for privileged operations
3. **Capability-driven**: Commands check capabilities before execution
4. **Event-driven architecture**: Internal events decouple components
5. **JSON output everywhere**: `--json` flag for scripting/automation
6. **Plugin-first**: New features can be added as plugins without core changes
7. **Backward compatible**: All v3.x profiles and commands continue to work
ARCH

    log_success "  architecture.md"
}

##############################################
# Generate migration guide.
# Arguments:
#   $1: output directory
##############################################
