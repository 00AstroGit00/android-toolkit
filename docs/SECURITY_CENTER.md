# Security Center

Comprehensive device security assessment and hardening center.

## Assessment Categories

| # | Check | Risk if Enabled |
|---|-------|-----------------|
| 1 | **Root Access** | Full device compromise via malicious apps |
| 2 | **USB Debugging** | Physical access attacks via ADB |
| 3 | **Developer Options** | Surface for social engineering attacks |
| 4 | **Unknown Sources** | Sideloaded malware installation risk |
| 5 | **Lock Screen** | No screen lock = no data protection |
| 6 | **Encryption** | Unencrypted = full data access if stolen |
| 7 | **Verified Boot** | Tampered system partitions undetected |
| 8 | **Security Patch** | Outdated = known CVE vulnerabilities |
| 9 | **SELinux** | Disabled = no mandatory access control |
| 10 | **OEM Unlock** | Bootloader unlocked = persistent compromise |

## Scoring

- **0–40**: Critical — Immediate action recommended
- **41–70**: Warning — Several issues to address
- **71–90**: Good — Minor improvements available
- **91–100**: Excellent — Strong security posture

## Quick Actions

| Key | Action |
|-----|--------|
| `a` | Run full security audit |
| `h` | Launch security hardening |
| `F5` | Refresh assessment |
| `1-0` | View individual category details |

## API

```bash
security_center_assess          # Run full assessment
security_center_score           # Get overall score
security_center_recommendations # Get improvement list
audit_run                       # Security audit module
security_harden_scan            # Hardening module
```
