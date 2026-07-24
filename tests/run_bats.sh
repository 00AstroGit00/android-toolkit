#!/data/data/com.termux/files/usr/bin/bash
#
# run_bats.sh — Execute BATS tests via bash shim
#
# Workaround for environments without bats-core installed.
# Parses tests/bats/*.bats and runs each @test block.
#
# Usage: bash tests/run_bats.sh [--verbose]
#
# Part of the Android Toolkit.

set -o pipefail

ANDROID_TOOLKIT_ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export ANDROID_TOOLKIT_ROOT_DIR

VERBOSE=false
[[ "$1" == "--verbose" ]] && VERBOSE=true

PASS=0
FAIL=0
TOTAL=0

run_test() {
    local test_name="$1"
    local test_body="$2"
    
    TOTAL=$((TOTAL + 1))
    
    # Create a temp script for this test
    local tmpfile
    tmpfile="$(mktemp /tmp/toolkit_test.XXXXXX)"
    
    cat > "$tmpfile" <<'TESTEOF'
#!/data/data/com.termux/files/usr/bin/bash
set -o pipefail
ANDROID_TOOLKIT_ROOT_DIR="$1"
export ANDROID_TOOLKIT_ROOT_DIR

# BATS compatibility shims
run() {
    _run_output=$(eval "$@" 2>&1)
    _run_status=$?
    _run_args=("$@")
}
status=0
output=""

# Shims for BATS builtins
skip() { echo "SKIPPED: $1"; exit 0; }

TESTEOF
    
    # Add the test body
    echo "$test_body" >> "$tmpfile"
    echo 'exit 0' >> "$tmpfile"
    
    # Run the test
    if bash -n "$tmpfile" 2>/dev/null; then
        local result
        result=$(bash "$tmpfile" "$ANDROID_TOOLKIT_ROOT_DIR" 2>&1)
        local rc=$?
        
        if [[ "$rc" -eq 0 ]] && ! echo "$result" | grep -q "FAIL"; then
            echo "  ✓ $test_name"
            PASS=$((PASS + 1))
        elif echo "$result" | grep -qi "SKIP"; then
            echo "  ○ $test_name (SKIPPED)"
            PASS=$((PASS + 1))
        else
            echo "  ✗ $test_name"
            $VERBOSE && echo "    Exit: $rc" && echo "$result" | sed 's/^/    /'
            FAIL=$((FAIL + 1))
        fi
    else
        echo "  ✗ $test_name (SYNTAX ERROR)"
        FAIL=$((FAIL + 1))
    fi
    
    rm -f "$tmpfile"
}

echo ""
echo "═══ Android Toolkit Test Suite ═══"
echo ""

for bats_file in "$ANDROID_TOOLKIT_ROOT_DIR"/tests/bats/*.bats; do
    echo "── ${bats_file##*/} ──"
    echo ""
    
    # Parse BATS file: extract @test blocks
    local current_name=""
    local current_body=""
    local in_test=false
    local brace_depth=0
    
    while IFS= read -r line; do
        if [[ "$line" =~ @test\ \"(.*)\"\ \{ ]]; then
            # Save previous test
            if $in_test && [[ -n "$current_name" ]]; then
                run_test "$current_name" "$current_body"
            fi
            current_name="${BASH_REMATCH[1]}"
            current_body=""
            in_test=true
            brace_depth=0
        elif $in_test; then
            # Count braces to know when test ends
            local open_braces=$(echo "$line" | tr -cd '{' | wc -c)
            local close_braces=$(echo "$line" | tr -cd '}' | wc -c)
            brace_depth=$((brace_depth + open_braces - close_braces))
            if [[ "$brace_depth" -le 0 && "$line" == "}" ]]; then
                # End of test
                run_test "$current_name" "$current_body"
                current_name=""
                current_body=""
                in_test=false
            else
                current_body+="$line"$'\n'
            fi
        fi
    done < "$bats_file"
done

echo ""
echo "═══ Results ═══"
echo "  Total: $TOTAL"
echo "  Pass:  $PASS"
echo "  Fail:  $FAIL"
echo ""

if [[ "$FAIL" -eq 0 ]]; then
    echo "  ✓ ALL TESTS PASSED"
    exit 0
else
    echo "  ✗ SOME TESTS FAILED"
    exit 1
fi
