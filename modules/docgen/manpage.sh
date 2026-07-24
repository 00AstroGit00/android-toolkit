#!/data/data/com.termux/files/usr/bin/bash
#
# docgen/manpage.sh — Man page documentation generator
# Part of the Android Toolkit.

docgen_man_page() {
    local output_dir="$1"
    local file="${output_dir}/android-toolkit.1"

    log_info "Generating man page..."

    cat > "$file" << 'MANPAGE'
.TH ANDROID\-TOOLKIT 1 "2026-07-23" "4.0.0" "Android Toolkit Manual"

.SH NAME
android-toolkit \- Android optimization and diagnostics toolkit

.SH SYNOPSIS
.B android-toolkit
[\fI\,OPTIONS\/\fR] [\fI\,COMMAND\/\fR]

.SH DESCRIPTION
The Android Toolkit provides a comprehensive set of commands for
diagnosing, optimizing, and managing Android devices. It supports
multiple backends (ADB, Shizuku/rish) and works across Android 13+.

.SH OPTIONS
.TP
.B \-\-help
Show help message and exit.
.TP
.B \-\-version
Show version information.
.TP
.B \-\-json
Enable machine-readable JSON output.
.TP
.B \-\-watch
Start real-time device monitoring.
.TP
.B \-\-compare <r1> <r2>
Compare two JSON diagnostic reports.
.TP
.B \-\-docgen [dir]
Generate documentation.
.TP
.B \-\-export <format> <type>
Export data in json, csv, or markdown format.
.TP
.B \-\-profile-manager <subcmd>
Manage profiles (list, clone, edit, validate, compare, export, import).

.SH COMMANDS
For a full list of commands, run: \fBandroid-toolkit \-\-help\fR

.SH PROFILES
Profiles are stored in the profiles/ directory and can be managed
via the \-\-profile-manager command.

.SH PLUGINS
Plugins extend the toolkit's functionality. They are loaded from
the plugins/ directory automatically.

.SH FILES
.TP
.I profiles/*.conf
Profile configuration files
.TP
.I plugins/*.sh
Plugin scripts (SDK v2.1)
.TP
.I lib/settings-db.json
Settings database
.TP
.I .benchmarks/
Benchmark history

.SH ENVIRONMENT
.TP
.B ANDROID_TOOLKIT_ROOT_DIR
Root directory of the toolkit.
.TP
.B ANDROID_TOOLKIT_WATCH_INTERVAL
Watch mode refresh interval in seconds (default: 5).

.SH EXIT STATUS
.TP
0
Success
.TP
1
General error
.TP
2
Backend not available

.SH SEE ALSO
adb(1)

.SH AUTHOR
Android Toolkit Team
MANPAGE

    log_success "  android-toolkit.1"
}

##############################################
# Generate architecture overview diagram.
# Arguments:
#   $1: output directory
##############################################
