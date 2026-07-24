<p align="center">
  <img src="docs/assets/logo.svg" alt="Android Toolkit" width="128" height="128"/>
</p>

<h1 align="center">Android Toolkit</h1>

<p align="center">
  <strong>A modular, non-root Android optimization and diagnostics toolkit</strong>
</p>

<p align="center">
  <a href="#"><img src="https://img.shields.io/badge/version-4.2.0--stable-blue?style=flat-square" alt="Version 4.2.0 Stable"/></a>
  <a href="#"><img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="MIT License"/></a>
  <a href="#"><img src="https://img.shields.io/badge/Android-13--16-3DDC84?style=flat-square&logo=android" alt="Android 13-16"/></a>
  <a href="#"><img src="https://img.shields.io/badge/Samsung_One_UI-5--8-1428A0?style=flat-square" alt="One UI 5-8"/></a>
  <a href="#"><img src="https://img.shields.io/badge/adb-✓-brightgreen?style=flat-square" alt="ADB"/></a>
  <a href="#"><img src="https://img.shields.io/badge/Shizuku-✓-brightgreen?style=flat-square" alt="Shizuku"/></a>
  <a href="#"><img src="https://img.shields.io/badge/bash_4.4+-✓-brightgreen?style=flat-square" alt="Bash 4.4+"/></a>
  <a href="#"><img src="https://img.shields.io/badge/PRs-welcome-orange?style=flat-square" alt="PRs Welcome"/></a>
  <a href="#"><img src="https://img.shields.io/badge/LTS-H2_2026--2028+-important?style=flat-square" alt="LTS H2 2026-2028+"/></a>
</p>

<p align="center">
  Works with <strong>ADB</strong> (USB/wireless) or <strong>Shizuku/rish</strong> backends.<br/>
  Targets <strong>Android 13–16</strong> and <strong>Samsung One UI 5–8</strong>, with special attention to the <strong>Galaxy S23 Ultra</strong>.
</p>

<blockquote align="center">
  <strong>Philosophy:</strong> Safe, reversible, device-aware operations.<br/>
  Prefer verified actions over aggressive or speculative tweaks.<br/>
  <strong>No root required. No bootloader unlock. No warranty void.</strong>
</blockquote>

---

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Requirements](#requirements)
- [Installation](#installation)
- [Backend Setup](#backend-setup)
- [Usage](#usage)
- [Profiles](#profiles)
- [Plugin System](#plugin-system)
- [Backup and Restore](#backup-and-restore)
- [Dry Run Mode](#dry-run-mode)
- [Safety](#safety)
- [Supported Platforms](#supported-platforms)
- [Compatibility Matrix](#compatibility-matrix)
- [Documentation](#documentation)
- [Screenshots](#screenshots)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [Security](#security)
- [License](#license)
- [Acknowledgements](#acknowledgements)

---

## Features

| Area | Capabilities |
|------|-------------|
| **Device Detection** | Android version, SDK, model, manufacturer, One UI version, build fingerprint, ABI |
| **Backend** | Auto-detects ADB, Shizuku/rish, or local shell. Selectable via `--backend` |
| **Performance** | Animation scales, GPU/HWUI rendering, cached app freezer, ART dexopt profiles |
| **Battery** | Battery stats reporting, power saver toggle, automatic/dynamic power savings |
| **Display** | Resolution/density reading, refresh rate display, override with rollback |
| **Network** | Mobile data always-on toggle, BLE/WiFi scanning, DNS flush, connectivity check |
| **Packages** | Disable/enable packages with protected list, backup before disable |
| **Maintenance** | ART bytecode compilation (`bg-dexopt-job`), cache clearing, fstrim |
| **Reporting** | Quick status overview, comprehensive device report |
| **Samsung** | One UI version detection, GOS disable/uninstall, refresh rate control, multi-core scheduler, Light Performance Profile, RAM Plus management, touch optimization, battery/display/network optimizations, comprehensive bloatware listing (100+ packages, 6 categories), Samsung Customization Service management, app background restriction/whitelist |
| **Safety** | Probe-before-write settings, backups before destructive actions, protection list for critical packages, dry-run mode, configurable timeouts |
| **Capability Detection** | Comprehensive probe of device properties, runtime environment, and feature support; results cached for downstream use |
| **Settings Database** | Canonical JSON reference of 38 settings with Android/OEM constraints, defaults, recommendations, risk levels |
| **Automatic Validation** | 7-step write protocol: probe namespace → read current → compare → record rollback → dry-run check → apply → verify |
| **Rollback Engine** | Journal-based rollback with `--rollback latest`, `--rollback <timestamp>`, `--rollback list`; auto-restore on validation failure |
| **Doctor Command** | Comprehensive system diagnostics with PASS/WARNING/FAIL; checks backend, storage, modules, profiles, capabilities, permissions |
| **Benchmark** | CPU (cores, frequency, governor), memory, storage, battery, thermal, GPU rendering, package compilation state — output as JSON + Markdown |
| **Plugin System** | Pluggable architecture — third-party scripts auto-loaded from `plugins/` with registration, execution, and cleanup lifecycle |
| **OEM Framework** | Device-aware OEM modules for Samsung, Google, OnePlus, Nothing, Xiaomi, Motorola, Oppo, Vivo with per-OEM settings validation |

---

## Architecture

```
                    ┌─────────────────────────────────┐
                    │         toolkit.sh               │
                    │    CLI Parser + Dispatcher        │
                    └──────────┬──────────────────────┘
                               │
            ┌──────────────────┼──────────────────────┐
            ▼                  ▼                       ▼
    ┌──────────────┐   ┌──────────────┐   ┌──────────────────┐
    │  lib/        │   │  modules/    │   │  plugins/         │
    │  Core Libs   │──▶│  Features    │──▶│  Third-party      │
    │  ──────────  │   │  ──────────  │   │  Extensions       │
    │  backend.sh  │   │  perf.sh     │   └──────────────────┘
    │  detection.sh│   │  battery.sh  │
    │  config.sh   │   │  network.sh  │   ┌──────────────────┐
    │  plugin.sh   │   │  samsung.sh  │   │  configs/        │
    │  rollback.sh │   │  doctor.sh   │   │  settings-db.json│
    │  ...         │   │  ...         │   │  default.conf    │
    └──────┬───────┘   └──────┬───────┘   └──────────────────┘
           │                  │
           ▼                  ▼
    ┌─────────────────────────────────────┐
    │        Backend Abstraction           │
    │  ADB (USB/Wireless) │ rish │ Local   │
    └─────────────────────────────────────┘
```

**Key design choices:**

- **Backend-agnostic**: All device operations go through `backend_exec()`, which translates to ADB shell, rish shell, or direct local execution.
- **Journaled writes**: Every `settings put` is recorded in a rollback journal before execution. Failed writes auto-revert.
- **Capability probing**: No assumptions about device capabilities. Everything is probed at runtime and cached.
- **OEM framework**: Per-OEM modules extend the core with device-specific settings and validation rules.

---

## Requirements

- **Termux** from [F-Droid](https://f-droid.org/en/packages/com.termux/) (not Google Play — Play version is outdated)
- **Bash** (default in Termux)
- Optional: `adb` (`pkg install android-tools`)
- Optional: Shizuku app + `rish` for on-device elevated access

---

## Installation

```bash
# Clone or copy the toolkit to your Termux home
cp -r android-toolkit ~/
cd ~/android-toolkit

# Make scripts executable
chmod +x toolkit.sh lib/*.sh modules/*.sh

# (Optional) Install ADB for USB/wireless backend support
pkg install android-tools

# Run a quick status check
./toolkit.sh --status
```

---

## Backend Setup

### ADB (USB or Wireless)

The ADB backend requires `adb` installed (`pkg install android-tools`) and a device
connected with USB debugging or wireless debugging enabled.

**USB:**
1. Enable **Developer options** (tap Build Number 7 times in Settings → About phone)
2. Enable **USB debugging** in Developer options
3. Connect your phone to your computer with a USB cable
4. Run `adb devices` to verify the connection
5. Run the toolkit with `./toolkit.sh --backend adb --status`

**Wireless (Android 11+):**
1. Enable **Wireless debugging** in Developer options
2. Use **Pairing code** to connect: `adb pair <ip>:<port>`
3. Connect: `adb connect <ip>:<port>`
4. Run the toolkit

> **Note:** ADB authorization resets after reboot. You'll need to reconnect.

### Shizuku / rish

[Shizuku](https://shizuku.rikka.app/) allows apps to use system APIs without root.

1. Install **Shizuku** from [Google Play](https://play.google.com/store/apps/details?id=moe.shizuku.privileged.api)
2. Start the Shizuku service (via Wireless debugging or ADB)
3. In Shizuku, go to **Terminal** → follow instructions to download `rish`
4. Copy `rish` to Termux: `cp /storage/emulated/0/Android/data/moe.shizuku.privileged.api/files/rish $PREFIX/bin/`
5. Verify: `rish -c 'echo ok'`
6. Run the toolkit: `./toolkit.sh --backend rish --status`

> **Note:** Shizuku service stops after reboot. Restart it from the Shizuku app.

---

## Usage

```
toolkit.sh [OPTIONS] <ACTION>
```

### Options

| Flag | Description |
|------|-------------|
| `-b, --backend <type>` | Backend: `adb`, `rish`, or `auto` (default) |
| `-s, --serial <id>` | ADB device serial (only with `--backend adb`) |
| `-v, --verbose` | Enable debug-level logging |
| `-n, --dry-run` | Preview changes without executing them |
| `-h, --help` | Show help message |

### Actions

| Action | Description |
|--------|-------------|
| `--status` | Quick device status overview |
| `--report` | Full device report (battery, display, network, packages, properties) |
| `--backup` | Create full settings + packages backup |
| `--restore <file>` | Restore settings from a backup file |
| `--apply <profile>` | Apply a performance profile (balanced\|performance\|powersave\|light) |
| `--compile` | Force ART bytecode optimization (`cmd package bg-dexopt-job`) |
| `--trim-cache` | Clear app caches and trim filesystem |
| `--refresh-network` | Tune network settings and flush DNS |
| `--disable-package <pkg>` | Disable a system package (opt-in) |
| `--enable-package <pkg>` | Re-enable a disabled package |
| `--list-bloatware [level]` | List Samsung bloatware (safe\|moderate\|aggressive\|all) |
| `--samsung-light` | Apply Samsung light optimizations (battery-focused) |
| `--doctor [filter]` | Run system diagnostics (filter: backend\|storage\|modules\|profiles\|capabilities\|permissions) |
| `--rollback [target]` | Rollback changes — `latest` (default), `<timestamp>`, or `list` |
| `--benchmark` | Run device benchmark (CPU, memory, storage, battery, thermal, GPU) |
| `--plugin <name> [args]` | Execute a plugin by name, passing optional arguments |

### Examples

```bash
# Quick status
./toolkit.sh --status

# Full report via Shizuku
./toolkit.sh --backend rish --report

# Backup settings via ADB
./toolkit.sh --backend adb --backup

# Preview profile changes without applying
./toolkit.sh --dry-run --apply performance

# Apply balanced profile
./toolkit.sh --apply balanced

# Optimize app bytecode
./toolkit.sh --compile

# Disable a package (with confirmation)
./toolkit.sh --disable-package com.facebook.appmanager

# Re-enable a package
./toolkit.sh --enable-package com.facebook.appmanager

# List Samsung bloatware (safe only)
./toolkit.sh --list-bloatware safe

# List all Samsung bloatware candidates
./toolkit.sh --list-bloatware all

# Apply Samsung light optimizations (battery-focused)
./toolkit.sh --samsung-light

# Run diagnostics
./toolkit.sh --doctor

# Check backend connectivity only
./toolkit.sh --doctor backend

# List rollback entries
./toolkit.sh --rollback list

# Rollback latest change
./toolkit.sh --rollback latest

# Run device benchmark
./toolkit.sh --benchmark

# Execute a plugin
./toolkit.sh --plugin my-plugin --arg1 val1

# Verbose logging for debugging
./toolkit.sh --verbose --status
```

---

## Profiles

Profiles are preset configurations stored in the `profiles/` directory. Each profile
sets animation scale, GPU rendering, app freezer, dexopt mode, battery saver, and
Samsung-specific settings (GOS, RAM Plus, refresh rate, performance profile).

| Profile | Animation | Dexopt | GPU Render | Battery Saver | Samsung Refresh | GOS | RAM Plus | Light Perf |
|---------|-----------|--------|------------|---------------|-----------------|-----|----------|------------|
| **balanced** | 0.75x | speed-profile | Default | Off | Keep current | Keep | Keep | Off |
| **performance** | Off (0x) | speed | Forced 2D + MSAA | Off | 120Hz peak | Keep | 0 | Off |
| **powersave** | Off (0x) | verify | Default | On | 60Hz capped | Disable | 0 | On |
| **light** | 0.5x | speed-profile | Default | Off | 60Hz | Disable | 0 | On |

Apply a profile:
```bash
./toolkit.sh --apply balanced
```

A backup is automatically created before applying any profile.

---

## Plugin System

The toolkit supports third-party plugins that extend its functionality without
modifying core code. Plugins are auto-loaded from `plugins/`.

```bash
# List available plugins
./toolkit.sh --plugin list

# Run a plugin
./toolkit.sh --plugin my-plugin --arg1 val1
```

**Example plugins** are available in `plugins/examples/`:

| Example | Demonstrates |
|---------|-------------|
| `10-command-extension.sh` | Custom CLI commands via `plugin_commands()` |
| `20-reporting.sh` | Device data collection using `api_*` safe APIs |
| `30-validation.sh` | Config schema, dependencies, pre-run validation |
| `40-configuration.sh` | Persistent config via `plugin_config_get/set` |

Plugin SDK reference: [PLUGIN_API.md](PLUGIN_API.md)  
Plugin examples: [`plugins/examples/`](plugins/examples/)  
Plugin security: [docs/PLUGIN_SECURITY.md](docs/PLUGIN_SECURITY.md)  
Plugin development guide: [CONTRIBUTING.md](CONTRIBUTING.md#plugin-development)

---

## Backup and Restore

The toolkit creates timestamped backups in `backups/`.

**Manual backup:**
```bash
./toolkit.sh --backup
```
Creates two files:
- `snapshot_<timestamp>.txt` — all system, secure, and global settings
- `packages_<timestamp>.txt` — enabled, disabled, and third-party packages

**Restore:**
```bash
./toolkit.sh --restore backups/snapshot_20260724_120000.txt
```
Protected keys like `adb_enabled` and `development_settings_enabled` are skipped
during restore to prevent locking the device.

**Automatic backups** are created before applying profiles and before disabling
packages.

---

## Dry Run Mode

Use `--dry-run` (or `-n`) to preview what would change without executing anything:

```bash
./toolkit.sh --dry-run --apply performance
./toolkit.sh --dry-run --trim-cache
./toolkit.sh --dry-run --disable-package com.example.app
```

Dry-run works across:
- All `backend_exec` calls (prints the command that would run)
- All `backend_settings_put` calls (prints the setting change)
- Package disable/enable operations
- Profile application
- Cache trimming and ART compilation
- Display resolution changes
- Backup restoration

Read-only commands (status, report, settings reads) still execute in dry-run mode
so the preview can show current values alongside planned changes.

---

## Safety

1. **No root required.** The toolkit never attempts to gain root access.
2. **Probe before write.** Every settings change reads the current value first.
   If the value is already what's requested, no write occurs.
3. **Protected packages.** Critical system packages cannot be disabled via
   `--disable-package`. The protected list is in `modules/packages.sh` and
   includes phone, system UI, settings, launcher, keyboard, and Google Play
   Services.
4. **Backups.** Automatic backups are created before profile application and
   package disabling. Manual backup via `--backup` is recommended before
   major changes.
5. **Confirmation.** Package disabling requires interactive confirmation.
6. **Samsung settings are guarded.** Settings like `peak_refresh_rate` and
   `multicore_packet_scheduler` are only written if they already exist on
   the device.
7. **Timeout protection.** Long-running operations (ART compilation, cache
   clearing) have configurable timeouts (default: 300 seconds).
8. **Dry-run available.** Preview changes before applying them.
9. **Rollback journal.** Every write is recorded in a journal. Use `--rollback list`
   to see history and `--rollback latest` to undo the most recent change.
10. **Settings database constraints.** The `settings-db.json` maps each key to
    its minimum/maximum Android version, applicable OEM, and recommended value.
    Writes outside documented constraints are rejected.
11. **Capability probing.** All device/runtime features are probed before use.
    Capabilities are cached and never assumed.
12. **Write verification.** Every `settings put` is followed by a read-back and
    compared. If the value doesn't match, the change is automatically
    rolled back and the user is warned.

---

## Supported Platforms

| Platform | Support Level |
|----------|--------------|
| **Android 13** (API 33) | ✅ Full |
| **Android 14** (API 34) | ✅ Full |
| **Android 15** (API 35) | ✅ Full |
| **Android 16** (API 36) | ⚠️ Experimental |
| **Samsung One UI 5.x** | ✅ Full |
| **Samsung One UI 6.x** | ✅ Full |
| **Samsung One UI 7.x** | ✅ Full |
| **Samsung One UI 8.x** | ⚠️ Experimental |
| **Google Pixel (7-9)** | ✅ Full |
| **OnePlus / OxygenOS** | ✅ Partial |
| **Nothing OS** | ✅ Partial |
| **Xiaomi HyperOS/MIUI** | ✅ Partial |
| **Motorola My UX** | ✅ Partial |
| **Oppo ColorOS** | ✅ Partial |
| **Vivo Funtouch OS** | ✅ Partial |

---

## Compatibility Matrix

| Backend | Read Settings | Write Settings | Package Ops | ART Compile | fstrim |
|---------|:------------:|:-------------:|:-----------:|:-----------:|:------:|
| `local` | ✅ | ❌ | ❌ | ❌ | ❌ |
| `adb` (USB) | ✅ | ✅ | ✅ | ✅ | ✅ |
| `adb` (Wireless) | ✅ | ✅ | ✅ | ✅ | ✅ |
| `rish` | ✅ | ✅ | ✅ | ✅ | ⚠️ |

| Feature | ADB | rish | Local |
|---------|:---:|:----:|:-----:|
| Device detection | ✅ | ✅ | ✅ |
| Performance profiles | ✅ | ✅ | ❌ |
| Battery optimization | ✅ | ✅ | ❌ |
| Network tuning | ✅ | ✅ | ❌ |
| Package management | ✅ | ✅ | ❌ |
| Backup & restore | ✅ | ✅ | ✅ |
| Rollback engine | ✅ | ✅ | ❌ |
| Doctor diagnostics | ✅ | ✅ | ✅ |
| Benchmark | ✅ | ✅ | ✅ |
| Plugins | ✅ | ✅ | ✅ |

---

## Documentation

| Document | Description |
|----------|-------------|
| [README.md](README.md) | This file — overview, installation, usage |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Coding standards, PR process, testing |
| [SECURITY.md](SECURITY.md) | Vulnerability reporting and disclosure |
| [CHANGELOG.md](CHANGELOG.md) | Version history |
| [LTS-POLICY.md](LTS-POLICY.md) | Long-term support schedule |
| [PLUGIN_API.md](PLUGIN_API.md) | Plugin SDK v3.0 reference |
| [docs/RELEASE_PROCESS.md](docs/RELEASE_PROCESS.md) | Release cadence, backport policy |
| [ROADMAP_V5.md](ROADMAP_V5.md) | Future development plans |
| [docs/PLUGIN_SECURITY.md](docs/PLUGIN_SECURITY.md) | Plugin security considerations |
| [DEVELOPER.md](DEVELOPER.md) | Internal architecture overview |

---

## Screenshots

> Screenshots will be added in a future release.  
> The toolkit is a CLI-only tool. Example terminal output from key commands
> (`--status`, `--doctor`, `--benchmark`, `--report`) will be provided here.

---

## Roadmap

**Current release:** v4.2.0 Stable — maintenance-only updates.

**v5.0 Planning** is documented in [ROADMAP_V5.md](ROADMAP_V5.md), including:
- Plugin namespace isolation
- JSON output wiring
- Android 17+ support
- ShellCheck zero-warnings
- Performance baselining
- Generated documentation sync
- Plugin SDK v4.0
- CI consolidation

---

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for:

- Coding standards (indentation, naming, quoting, error handling)
- Commit message format (Conventional Commits)
- PR checklist and review process
- Testing requirements (BATS, ShellCheck, JSON validation)
- Plugin development guide

**Quick start:**
```bash
# Fork and clone
git clone https://github.com/YOUR_USERNAME/android-toolkit.git
cd android-toolkit

# Run syntax checks
bash -n toolkit.sh lib/*.sh modules/*.sh

# Run ShellCheck
shellcheck -x *.sh lib/*.sh modules/*.sh

# Run BATS tests
bats tests/bats/
```

---

## Security

See [SECURITY.md](SECURITY.md) for:

- Supported versions and LTS schedule
- How to report a vulnerability
- Disclosure process and timeline
- GPG key information (if configured)

**Do not open public issues for security vulnerabilities.**  
Report via the security issue template or contact maintainers directly.

---

## License

MIT License — see [LICENSE](LICENSE) for details.

Copyright (c) 2026 Android Toolkit Contributors

---

## Acknowledgements

- [Shizuku](https://shizuku.rikka.app/) — System API access without root
- [Termux](https://termux.dev/) — Android terminal emulator
- [BATS](https://github.com/bats-core/bats-core) — Bash testing framework
- [ShellCheck](https://www.shellcheck.net/) — Shell script analysis
- [mvdan/sh](https://github.com/mvdan/sh) — Shell formatter (shfmt)
- All [contributors](https://github.com/YOUR_USERNAME/android-toolkit/graphs/contributors) who have helped improve the toolkit

---

<p align="center">
  <sub>Made with ❤️ for the Android community. No root required.</sub>
</p>
