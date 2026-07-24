# Enterprise Dashboard Profiles

Role-based dashboard layouts that expose relevant pages and tools based on user role.

## Available Profiles

| # | Profile | Access | Best For |
|---|---------|--------|----------|
| 1 | **Administrator** | All pages | Full system management |
| 2 | **Technician** | Devices, diagnostics, recovery | Device repair & diagnostics |
| 3 | **Developer** | Plugins, profiler, system map | Module & plugin development |
| 4 | **Power User** | Optimization, health, monitoring | Daily device optimization |
| 5 | **Security Analyst** | Security, audit, policies, fleet | Security assessment & compliance |
| 6 | **Plugin Developer** | Plugin center, sandbox, SDK | Plugin development & testing |

## Page Access by Profile

| Page | Admin | Tech | Dev | Power | Sec | PluginDev |
|------|-------|------|-----|-------|-----|-----------|
| All Pages | ✓ | — | — | — | — | — |
| Diagnostics | ✓ | ✓ | — | — | — | — |
| Performance | ✓ | — | — | ✓ | — | — |
| Security Center | ✓ | — | — | — | ✓ | — |
| Plugin Center | ✓ | — | ✓ | — | — | ✓ |
| Fleet | ✓ | — | — | — | ✓ | — |
| Audit Trail | ✓ | — | — | — | ✓ | ✓ |
| Policies | ✓ | — | — | ✓ | ✓ | — |

## Usage

| Key | Action |
|-----|--------|
| `1-6` | Switch to corresponding profile |
| Active indicator | Current profile shown with ← indicator |

## Profile Descriptions

- **Administrator**: Full system access — all pages and tools available
- **Technician**: Device repair & diagnostics — hardware/software operations
- **Developer**: Module & plugin development — SDK, profiler, automation
- **Power User**: Device optimization & health monitoring — daily operations
- **Security Analyst**: Security assessment & compliance — audits, policies, fleet
- **Plugin Developer**: Plugin development & testing — sandbox, profiler, SDK docs
