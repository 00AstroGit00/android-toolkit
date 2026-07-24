#!/data/data/com.termux/files/usr/bin/bash
#
# dependencies.sh — Dependency Manager
#
# Detects required and optional tools, explains missing dependencies,
# and optionally installs supported Termux packages on request.
#
# Part of the Android Toolkit.

DEPS_TOOLS_REQUIRED=(
    "bash:bash:Bourne Again SHell"
)

DEPS_TOOLS_OPTIONAL=(
    "adb:android-tools:Android Debug Bridge (USB/wireless backend)"
    "rish:shizuku:Shizuku rish (on-device elevated access)"
    "dialog:dialog:Terminal UI dialogs (TUI backend)"
    "whiptail:whiptail:Terminal UI menus (fallback TUI)"
    "jq:jq:JSON processor (settings DB, telemetry, reports)"
    "curl:curl:HTTP client (update checks, downloads)"
    "wget:wget:HTTP client (update fallback)"
    "zip:zip:Archive creation (builds, exports)"
    "sha256sum:coreutils:SHA256 checksums"
    "pandoc:pandoc:PDF report generation"
    "cronie:cronie:Cron daemon (scheduler)"
    "termux-job-scheduler:termux-job-scheduler:Android JobScheduler tasks"
    "git:git:Version control (development)"
    "shellcheck:shellcheck:Bash script linting (development)"
    "shfmt:shfmt:Shell script formatting (development)"
)

DEPS_INSTALLED=()
DEPS_MISSING=()
DEPS_INSTALLABLE=()

##############################################
# Detect all tools, categorizing as installed, missing, or installable.
##############################################
deps_init() {
    DEPS_INSTALLED=()
    DEPS_MISSING=()
    DEPS_INSTALLABLE=()

    local entry bin pkg desc
    for entry in "${DEPS_TOOLS_REQUIRED[@]}" "${DEPS_TOOLS_OPTIONAL[@]}"; do
        bin="$(echo "$entry" | cut -d: -f1)"
        pkg="$(echo "$entry" | cut -d: -f2)"
        desc="$(echo "$entry" | cut -d: -f3-)"

        if command -v "$bin" &>/dev/null; then
            DEPS_INSTALLED+=("$entry")
        else
            DEPS_MISSING+=("$entry")
            # Check if it's a Termux-installable package
            if [[ -n "$pkg" ]] && deps_is_installable "$pkg"; then
                DEPS_INSTALLABLE+=("$entry")
            fi
        fi
    done
}

##############################################
# Check if a package can be installed via Termux.
# Arguments:
#   $1: package name
# Returns: 0 if installable
##############################################
deps_is_installable() {
    local pkg="$1"
    # Termux packages are installable via pkg
    command -v pkg &>/dev/null
}

##############################################
# Check if a required tool is available.
# Arguments:
#   $1: binary name
# Returns: 0 if installed
##############################################
deps_has() {
    local bin="$1"
    command -v "$bin" &>/dev/null
}

##############################################
# Check if ALL required tools are present.
# Returns: 0 if all present
##############################################
deps_check_required() {
    local entry bin
    for entry in "${DEPS_TOOLS_REQUIRED[@]}"; do
        bin="$(echo "$entry" | cut -d: -f1)"
        if ! command -v "$bin" &>/dev/null; then
            return 1
        fi
    done
    return 0
}

##############################################
# Install a Termux package with confirmation.
# Arguments:
#   $1: package name
# Returns: 0 on success
##############################################
deps_install() {
    local pkg="$1"

    if ! command -v pkg &>/dev/null; then
        log_error "Termux pkg command not available"
        return 1
    fi

    if ! utils_confirm "Install '${pkg}' via pkg?"; then
        log_info "Installation cancelled"
        return 1
    fi

    log_info "Installing: $pkg"
    pkg install -y "$pkg" 2>&1 | tail -5 || {
        log_error "Failed to install: $pkg"
        return 1
    }

    log_success "Installed: $pkg"
    return 0
}

##############################################
# Install all missing optional tools (with confirmation each).
# Returns: number installed
##############################################
deps_install_all() {
    local count=0
    local entry pkg desc

    for entry in "${DEPS_INSTALLABLE[@]}"; do
        pkg="$(echo "$entry" | cut -d: -f2)"
        desc="$(echo "$entry" | cut -d: -f3-)"

        echo ""
        log_info "Missing: $pkg — $desc"
        if deps_install "$pkg"; then
            count=$((count + 1))
        fi
    done

    echo ""
    log_info "Installed $count package(s)"
    return $count
}

##############################################
# Print dependency status table.
##############################################
deps_status() {
    log_section "Dependency Status"

    echo ""
    echo "  Required:"
    local entry bin desc
    for entry in "${DEPS_TOOLS_REQUIRED[@]}"; do
        bin="$(echo "$entry" | cut -d: -f1)"
        desc="$(echo "$entry" | cut -d: -f3-)"
        if command -v "$bin" &>/dev/null; then
            printf "  \033[32m✓\033[0m  %-20s %s\n" "$bin" "$desc"
        else
            printf "  \033[31m✗\033[0m  %-20s %s\n" "$bin" "$desc"
        fi
    done

    echo ""
    echo "  Optional:"
    for entry in "${DEPS_TOOLS_OPTIONAL[@]}"; do
        bin="$(echo "$entry" | cut -d: -f1)"
        desc="$(echo "$entry" | cut -d: -f3-)"
        if command -v "$bin" &>/dev/null; then
            printf "  \033[32m✓\033[0m  %-20s %s\n" "$bin" "$desc"
        else
            printf "  \033[33m⚡\033[0m  %-20s %s (pkg install %s)\n" "$bin" "$desc" "$(echo "$entry" | cut -d: -f2)"
        fi
    done

    # Summary
    local installed=0 missing=0
    for entry in "${DEPS_TOOLS_REQUIRED[@]}" "${DEPS_TOOLS_OPTIONAL[@]}"; do
        bin="$(echo "$entry" | cut -d: -f1)"
        if command -v "$bin" &>/dev/null; then
            installed=$((installed + 1))
        else
            missing=$((missing + 1))
        fi
    done

    echo ""
    echo "  ${installed} installed, ${missing} missing"
}

##############################################
# Explain what a missing dependency is needed for.
# Arguments:
#   $1: binary name
##############################################
deps_explain() {
    local bin="$1"
    local entry

    for entry in "${DEPS_TOOLS_REQUIRED[@]}" "${DEPS_TOOLS_OPTIONAL[@]}"; do
        local e_bin e_pkg e_desc
        e_bin="$(echo "$entry" | cut -d: -f1)"
        e_pkg="$(echo "$entry" | cut -d: -f2)"
        e_desc="$(echo "$entry" | cut -d: -f3-)"

        if [[ "$e_bin" == "$bin" ]]; then
            echo "  $bin: $e_desc"
            echo "  Package: $e_pkg"
            if command -v "$bin" &>/dev/null; then
                echo "  Status: installed"
            elif command -v pkg &>/dev/null; then
                echo "  Status: installable via 'pkg install $e_pkg'"
            else
                echo "  Status: not available (pkg not found)"
            fi
            return 0
        fi
    done

    log_error "Unknown dependency: $bin"
    return 1
}

# Auto-init
deps_init
