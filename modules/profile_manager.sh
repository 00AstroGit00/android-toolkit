#!/data/data/com.termux/files/usr/bin/bash
#
# profile_manager.sh — Profile Manager Module
#
# Allows users to:
#   - list available profiles
#   - clone profiles
#   - edit profiles
#   - validate profiles
#   - compare profiles
#   - export/import profiles (JSON)
#
# Profiles inherit from base profiles where possible.
#
# Part of the Android Toolkit.

PROFILE_DIR="${ANDROID_TOOLKIT_ROOT_DIR}/profiles"
PROFILE_BASE="base"

##############################################
# List all available profiles.
##############################################
profile_manager_list() {
    log_section "Available Profiles"

    echo ""
    printf "  %-25s %-12s %s\n" "Profile" "Type" "Description"
    printf "  %-25s %-12s %s\n" "─────────────────────" "──────────" "──────────────────────────"

    local file
    for file in "$PROFILE_DIR"/*.conf; do
        [[ -f "$file" ]] || continue
        local name
        name="$(basename "$file" .conf)"
        local desc
        desc="$(grep -m1 '^# ' "$file" 2>/dev/null | sed 's/^# //' || echo "")"
        local type="user"
        [[ "$name" == "$PROFILE_BASE" ]] && type="base"
        [[ "$name" =~ ^(balanced|performance|powersave|light)$ ]] && type="built-in"
        printf "  %-25s %-12s %s\n" "$name" "$type" "$desc"
    done
}

##############################################
# Clone a profile.
# Arguments:
#   $1: source profile name
#   $2: target profile name
##############################################
profile_manager_clone() {
    local source="$1" target="$2"

    if [[ -z "$source" || -z "$target" ]]; then
        log_error "Usage: --profile-manager clone <source> <target>"
        return 1
    fi

    local src_file="${PROFILE_DIR}/${source}.conf"
    local tgt_file="${PROFILE_DIR}/${target}.conf"

    if [[ ! -f "$src_file" ]]; then
        log_error "Source profile not found: $source"
        return 1
    fi

    if [[ -f "$tgt_file" ]]; then
        if ! utils_confirm "Target profile '$target' exists. Overwrite?"; then
            log_info "Clone cancelled"
            return 0
        fi
    fi

    cp "$src_file" "$tgt_file"
    log_success "Profile cloned: $source → $target"
}

##############################################
# Edit a profile (opens in editor).
# Arguments:
#   $1: profile name
##############################################
profile_manager_edit() {
    local name="$1"

    if [[ -z "$name" ]]; then
        log_error "Usage: --profile-manager edit <name>"
        return 1
    fi

    local file="${PROFILE_DIR}/${name}.conf"

    if [[ ! -f "$file" ]]; then
        log_error "Profile not found: $name"
        return 1
    fi

    local editor="${EDITOR:-vi}"
    log_info "Opening $file with $editor..."
    $editor "$file"
    log_success "Profile edited: $name"
}

##############################################
# Validate a profile file.
# Arguments:
#   $1: profile name or file path
# Returns: 0 if valid
##############################################
profile_manager_validate() {
    local target="$1"
    local file=""

    if [[ -z "$target" ]]; then
        # Validate all profiles
        log_section "Validating All Profiles"
        local all_valid=true
        local f
        for f in "$PROFILE_DIR"/*.conf; do
            profile_manager_validate "$(basename "$f" .conf)" || all_valid=false
        done
        $all_valid && log_success "All profiles valid" || log_warning "Some profiles have issues"
        return
    fi

    # Check if it's a name or path
    if [[ -f "$target" ]]; then
        file="$target"
    else
        file="${PROFILE_DIR}/${target}.conf"
    fi

    if [[ ! -f "$file" ]]; then
        log_error "Profile not found: $target"
        return 1
    fi

    local name
    name="$(basename "$file" .conf)"
    log_info "Validating: $name"

    local errors=0

    # Check bash syntax
    if ! bash -n "$file" 2>/dev/null; then
        log_error "  Syntax error in $name"
        errors=$((errors + 1))
    fi

    # Check for required variables
    local required_vars=(
        "PROFILE_ANIMATION_SCALE"
        "PROFILE_DEXOPT"
        "PROFILE_BATTERY_SAVER"
    )

    local var
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" "$file" 2>/dev/null; then
            log_warning "  Missing recommended variable: $var"
        fi
    done

    if [[ "$errors" -eq 0 ]]; then
        log_success "Profile '$name' is valid"
        return 0
    else
        log_error "Profile '$name' has $errors error(s)"
        return 1
    fi
}

##############################################
# Compare two profiles.
# Arguments:
#   $1: first profile name
#   $2: second profile name
##############################################
profile_manager_compare() {
    local p1="$1" p2="$2"

    if [[ -z "$p1" || -z "$p2" ]]; then
        log_error "Usage: --profile-manager compare <profile1> <profile2>"
        return 1
    fi

    local f1="${PROFILE_DIR}/${p1}.conf"
    local f2="${PROFILE_DIR}/${p2}.conf"

    if [[ ! -f "$f1" ]]; then
        log_error "Profile not found: $p1"
        return 1
    fi
    if [[ ! -f "$f2" ]]; then
        log_error "Profile not found: $p2"
        return 1
    fi

    log_section "Profile Comparison: $p1 vs $p2"

    # Extract all key=value pairs from both
    local keys
    keys="$( (grep -oP '^[A-Z_]+=' "$f1" | sed 's/=//'; grep -oP '^[A-Z_]+=' "$f2" | sed 's/=//') | sort -u)"

    echo ""
    printf "  %-35s %-20s %-20s\n" "Key" "$p1" "$p2"
    printf "  %-35s %-20s %-20s\n" "───────────────────────────────────" "──────────────────" "──────────────────"

    local key
    for key in $keys; do
        local v1 v2
        v1="$(grep "^${key}=" "$f1" 2>/dev/null | head -1 | cut -d= -f2-)"
        v2="$(grep "^${key}=" "$f2" 2>/dev/null | head -1 | cut -d= -f2-)"

        if [[ "$v1" != "$v2" ]]; then
            printf "  \033[33m%-35s %-20s %-20s\033[0m\n" "$key" "${v1:-unset}" "${v2:-unset}"
        else
            printf "  \033[32m%-35s %-20s %-20s\033[0m\n" "$key" "${v1:-unset}" "${v2:-unset}"
        fi
    done
}

##############################################
# Export a profile as JSON.
# Arguments:
#   $1: profile name
#   $2: output file (optional)
##############################################
profile_manager_export() {
    local name="$1" output="${2:-}"
    local file="${PROFILE_DIR}/${name}.conf"

    if [[ ! -f "$file" ]]; then
        log_error "Profile not found: $name"
        return 1
    fi

    if [[ -z "$output" ]]; then
        output="${PROFILE_DIR}/${name}.json"
    fi

    # Convert INI-style to JSON
    if command -v jq &>/dev/null; then
        local json="{}"
        while IFS='=' read -r key value; do
            key="$(echo "$key" | tr -d '[:space:]')"
            value="$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            [[ -z "$key" || "$key" =~ ^# ]] && continue
            json="$(echo "$json" | jq --arg k "$key" --arg v "$value" '. + {($k): $v}' 2>/dev/null)"
        done < "$file"

        echo "$json" > "$output"
        log_success "Profile exported: $output"
    else
        # Fallback: copy as-is
        cp "$file" "$output"
        log_success "Profile exported (INI): $output"
    fi
}

##############################################
# Import a profile from JSON.
# Arguments:
#   $1: source file
#   $2: profile name (optional, derived from filename if omitted)
##############################################
profile_manager_import() {
    local source="$1" name="${2:-}"

    if [[ ! -f "$source" ]]; then
        log_error "File not found: $source"
        return 1
    fi

    if [[ -z "$name" ]]; then
        name="$(basename "$source" | sed 's/\.[^.]*$//')"
    fi

    local target="${PROFILE_DIR}/${name}.conf"

    if [[ -f "$target" ]]; then
        if ! utils_confirm "Profile '$name' exists. Overwrite?"; then
            log_info "Import cancelled"
            return 0
        fi
    fi

    # If JSON, convert to INI
    if [[ "$source" == *.json ]] && command -v jq &>/dev/null; then
        jq -r 'to_entries[] | "\(.key)=\(.value)"' "$source" > "$target"
    else
        cp "$source" "$target"
    fi

    # Validate the imported profile
    if profile_manager_validate "$name"; then
        log_success "Profile imported: $source → $name"
    else
        log_warning "Profile imported but has validation issues"
    fi
}

##############################################
# Main entry point.
# Arguments:
#   $1: subcommand (list|clone|edit|validate|compare|export|import)
#   $@: subcommand arguments
##############################################
profile_manager_run() {
    local cmd="${1:-list}"
    shift 2>/dev/null || true

    case "$cmd" in
        list|ls)
            profile_manager_list
            ;;
        clone|copy)
            profile_manager_clone "$1" "$2"
            ;;
        edit|modify)
            profile_manager_edit "$1"
            ;;
        validate|check)
            profile_manager_validate "$1"
            ;;
        compare|diff)
            profile_manager_compare "$1" "$2"
            ;;
        export)
            profile_manager_export "$1" "$2"
            ;;
        import)
            profile_manager_import "$1" "$2"
            ;;
        *)
            log_error "Unknown subcommand: $cmd"
            echo "  Usage: --profile-manager <list|clone|edit|validate|compare|export|import> [args]"
            return 1
            ;;
    esac
}
