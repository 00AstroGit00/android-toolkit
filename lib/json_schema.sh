#!/data/data/com.termux/files/usr/bin/bash
#
# json_schema.sh — JSON Schema Validation Module
#
# Provides schema definitions and validation for:
#   - settings-db.json
#   - diagnostic reports
#   - telemetry data
#   - benchmark results
#   - plugin manifests
#   - profiles
#   - release manifests
#
# Schemas are embedded as JSON Schema (draft-07) strings.
# Validation requires jq.
#
# Part of the Android Toolkit.

SCHEMA_DIR="${ANDROID_TOOLKIT_ROOT_DIR}/configs/schemas"

##############################################
# Initialize schema directory.
##############################################
schema_init() {
    mkdir -p "$SCHEMA_DIR"
}

##############################################
# Get embedded schema by name.
# Arguments:
#   $1: schema name (settings|report|telemetry|benchmark|plugin|profile|manifest)
# Outputs: JSON Schema string
##############################################
schema_get() {
    local name="$1"
    case "$name" in
        settings)
            cat << 'EOS'
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Settings Database",
  "type": "object",
  "required": ["settings"],
  "properties": {
    "settings": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["key", "namespace"],
        "properties": {
          "key": {"type": "string"},
          "namespace": {"type": "string", "enum": ["global", "secure", "system"]},
          "type": {"type": "string", "enum": ["integer", "string", "boolean", "float"]},
          "default": {"type": "string"},
          "recommended": {"type": "string"},
          "risk": {"type": "string", "enum": ["low", "medium", "high"]},
          "reboot": {"type": "boolean"},
          "min_android": {"type": "integer"},
          "max_android": {"type": "integer"},
          "oem": {"type": "string"},
          "description": {"type": "string"},
          "doc": {"type": "string"}
        }
      }
    }
  }
}
EOS
            ;;
        report)
            cat << 'EOS'
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Device Report",
  "type": "object",
  "required": ["toolkit_version", "date", "device"],
  "properties": {
    "toolkit_version": {"type": "string"},
    "date": {"type": "string"},
    "device": {
      "type": "object",
      "required": ["manufacturer", "model", "android_version", "android_sdk"],
      "properties": {
        "manufacturer": {"type": "string"},
        "model": {"type": "string"},
        "android_version": {"type": "string"},
        "android_sdk": {"type": "integer"},
        "kernel": {"type": "string"},
        "one_ui_version": {"type": "string"},
        "abi": {"type": "string"},
        "security_patch": {"type": "string"}
      }
    },
    "settings": {"type": "object"},
    "packages": {"type": "object"},
    "scores": {"type": "object"},
    "battery": {"type": "object"},
    "storage": {"type": "object"},
    "network": {"type": "object"}
  }
}
EOS
            ;;
        telemetry)
            cat << 'EOS'
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Telemetry Data",
  "type": "object",
  "required": ["runs", "first_run", "last_run"],
  "properties": {
    "runs": {"type": "integer", "minimum": 0},
    "first_run": {"type": "string"},
    "last_run": {"type": "string"},
    "profiles": {"type": "object"},
    "backends": {"type": "object"},
    "failures": {"type": "integer"},
    "total_duration": {"type": "number"},
    "oems": {"type": "object"}
  }
}
EOS
            ;;
        benchmark)
            cat << 'EOS'
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Benchmark Results",
  "type": "object",
  "required": ["name", "date", "runs", "scores"],
  "properties": {
    "name": {"type": "string"},
    "date": {"type": "string"},
    "runs": {"type": "integer", "minimum": 1},
    "scores": {
      "type": "array",
      "items": {"type": "integer"}
    },
    "median": {"type": "integer"},
    "variance": {"type": "integer"},
    "overall": {"type": "integer"},
    "device": {
      "type": "object",
      "properties": {
        "manufacturer": {"type": "string"},
        "model": {"type": "string"},
        "android_sdk": {"type": "integer"}
      }
    }
  }
}
EOS
            ;;
        plugin)
            cat << 'EOS'
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Plugin Manifest",
  "type": "object",
  "required": ["name", "version", "api_version", "min_toolkit_version"],
  "properties": {
    "name": {"type": "string"},
    "version": {"type": "string"},
    "api_version": {"type": "string"},
    "description": {"type": "string"},
    "author": {"type": "string"},
    "min_toolkit_version": {"type": "string"},
    "supported_android": {
      "type": "array",
      "items": {"type": "integer"}
    },
    "supported_oems": {
      "type": "array",
      "items": {"type": "string"}
    },
    "permissions": {
      "type": "array",
      "items": {"type": "string"}
    },
    "dependencies": {
      "type": "array",
      "items": {"type": "string"}
    },
    "commands": {
      "type": "array",
      "items": {"type": "string"}
    },
    "events": {
      "type": "array",
      "items": {"type": "string"}
    }
  }
}
EOS
            ;;
        profile)
            cat << 'EOS'
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Profile",
  "type": "object",
  "properties": {
    "name": {"type": "string"},
    "description": {"type": "string"},
    "settings": {
      "type": "object",
      "additionalProperties": {"type": "string"}
    }
  }
}
EOS
            ;;
        manifest)
            cat << 'EOS'
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Release Manifest",
  "type": "object",
  "required": ["version", "date"],
  "properties": {
    "version": {"type": "string"},
    "date": {"type": "string"},
    "files": {
      "type": "object",
      "patternProperties": {
        "^.*$": {"type": "string"}
      }
    },
    "checksums": {
      "type": "object",
      "patternProperties": {
        "^.*$": {"type": "string"}
      }
    },
    "requirements": {
      "type": "object",
      "properties": {
        "bash": {"type": "string"},
        "android": {"type": "string"},
        "backends": {
          "type": "array",
          "items": {"type": "string"}
        }
      }
    },
    "changes": {
      "type": "array",
      "items": {"type": "string"}
    }
  }
}
EOS
            ;;
        android-db)
            cat << 'EOS'
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Android Version Database",
  "type": "object",
  "required": ["versions"],
  "properties": {
    "versions": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["version", "sdk", "name", "release_date"],
        "properties": {
          "version": {"type": "string"},
          "sdk": {"type": "integer"},
          "name": {"type": "string"},
          "release_date": {"type": "string"},
          "api_level": {"type": "integer"},
          "supported_commands": {
            "type": "array",
            "items": {"type": "string"}
          },
          "deprecated_apis": {
            "type": "array",
            "items": {"type": "string"}
          },
          "replacement_apis": {
            "type": "object",
            "additionalProperties": {"type": "string"}
          },
          "oem_notes": {
            "type": "object",
            "additionalProperties": {"type": "string"}
          }
        }
      }
    }
  }
}
EOS
            ;;
        *)
            log_error "Unknown schema: $name"
            return 1
            ;;
    esac
}

##############################################
# Save a schema to the schemas directory.
# Arguments:
#   $1: schema name
##############################################
schema_save() {
    local name="$1"
    schema_init
    local file="${SCHEMA_DIR}/${name}.json"
    schema_get "$name" > "$file" 2>/dev/null || return 1
    log_debug "Schema saved: $file"
}

##############################################
# Save all schemas.
##############################################
schema_save_all() {
    log_section "Saving JSON Schemas"
    schema_init
    local schemas=(settings report telemetry benchmark plugin profile manifest android-db)
    local s
    for s in "${schemas[@]}"; do
        if schema_save "$s"; then
            log_info "  Schema: $s"
        fi
    done
    log_success "Schemas saved to $SCHEMA_DIR"
}

##############################################
# Validate a JSON file against a schema.
# Arguments:
#   $1: JSON file path
#   $2: schema name (or path to schema file)
# Returns: 0 if valid, 1 if invalid
##############################################
schema_validate() {
    local json_file="$1" schema_ref="$2"

    if [[ ! -f "$json_file" ]]; then
        log_error "File not found: $json_file"
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        log_warning "jq not available — cannot validate schema"
        return 0
    fi

    local schema_content=""
    if [[ -f "$schema_ref" ]]; then
        schema_content="$(cat "$schema_ref")"
    else
        schema_content="$(schema_get "$schema_ref" 2>/dev/null)" || {
            log_error "Unknown schema: $schema_ref"
            return 1
        }
    fi

    # Validate using ajv if available, otherwise basic jq validation
    if command -v ajv &>/dev/null; then
        ajv validate -s <(echo "$schema_content") -d "$json_file" 2>/dev/null
        return $?
    fi

    # Basic validation: check that the JSON parses and required fields exist
    if ! jq empty "$json_file" 2>/dev/null; then
        log_error "Invalid JSON: $json_file"
        return 1
    fi

    # Check required top-level fields by extracting them from the schema
    local required
    required="$(echo "$schema_content" | jq -r '.required // [] | .[]' 2>/dev/null)"
    if [[ -n "$required" ]]; then
        local field
        for field in $required; do
            if ! jq -e "has(\"$field\")" "$json_file" &>/dev/null; then
                log_error "Schema validation: missing required field '$field' in $json_file"
                return 1
            fi
        done
    fi

    log_debug "Schema validation passed (basic): $json_file"
    return 0
}

##############################################
# Validate all JSON files in a directory against a schema.
# Arguments:
#   $1: directory path
#   $2: schema name (glob pattern for files, e.g., *.json)
##############################################
schema_validate_dir() {
    local dir="$1" schema_name="$2"

    if [[ ! -d "$dir" ]]; then
        log_warning "Directory not found: $dir"
        return 0
    fi

    local exit_code=0
    local file
    for file in "$dir"/*.json; do
        [[ -f "$file" ]] || continue
        if ! schema_validate "$file" "$schema_name"; then
            exit_code=1
        fi
    done

    return $exit_code
}

##############################################
# Validate all known JSON artifacts in the project.
##############################################
schema_validate_all() {
    log_section "JSON Schema Validation"
    local exit_code=0

    # settings-db.json
    if [[ -f "${ANDROID_TOOLKIT_ROOT_DIR}/lib/settings-db.json" ]]; then
        if schema_validate "${ANDROID_TOOLKIT_ROOT_DIR}/lib/settings-db.json" "settings"; then
            log_success "  settings-db.json: OK"
        else
            log_error "  settings-db.json: INVALID"
            exit_code=1
        fi
    fi

    # android-db.json (if exists)
    if [[ -f "${ANDROID_TOOLKIT_ROOT_DIR}/configs/android-db.json" ]]; then
        if schema_validate "${ANDROID_TOOLKIT_ROOT_DIR}/configs/android-db.json" "android-db"; then
            log_success "  android-db.json: OK"
        else
            log_error "  android-db.json: INVALID"
            exit_code=1
        fi
    fi

    # Benchmark history
    if [[ -d "${ANDROID_TOOLKIT_ROOT_DIR}/.benchmarks" ]]; then
        if ! schema_validate_dir "${ANDROID_TOOLKIT_ROOT_DIR}/.benchmarks" "benchmark"; then
            exit_code=1
        fi
    fi

    # Exports
    if [[ -d "${ANDROID_TOOLKIT_ROOT_DIR}/exports" ]]; then
        local file
        for file in "${ANDROID_TOOLKIT_ROOT_DIR}/exports"/*.json; do
            [[ -f "$file" ]] || continue
            if echo "$file" | grep -q 'diff_'; then
                schema_validate "$file" "report" 2>/dev/null || true
            else
                schema_validate "$file" "report" 2>/dev/null || log_warning "  $file: could not validate"
            fi
        done
    fi

    if [[ "$exit_code" -eq 0 ]]; then
        log_success "All JSON schemas valid"
    else
        log_warning "Some JSON schemas failed validation"
    fi

    return $exit_code
}
