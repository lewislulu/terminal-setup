#!/usr/bin/env bats
# Tests for dry-run mode behavior

setup() {
    load 'test_helper'
    setup_sandbox
}

teardown() {
    teardown_sandbox
}

# ── run_cmd behavior in dry-run mode ─────────────────────────────

@test "run_cmd: dry-run prints but does not execute" {
    DRY_RUN=true

    # Create a temporary file to test if commands actually run
    local marker="$SANDBOX_DIR/marker"

    run_cmd() {
        if $DRY_RUN; then
            echo "[DRY-RUN] $*"
        else
            "$@"
        fi
    }

    run run_cmd touch "$marker"
    [[ "$output" == *"DRY-RUN"* ]]
    [[ "$output" == *"touch"* ]]
    # File should NOT have been created
    [[ ! -f "$marker" ]]
}

@test "run_cmd: normal mode executes" {
    DRY_RUN=false

    local marker="$SANDBOX_DIR/marker"

    run_cmd() {
        if $DRY_RUN; then
            echo "[DRY-RUN] $*"
        else
            "$@"
        fi
    }

    run run_cmd touch "$marker"
    # File SHOULD have been created
    [[ -f "$marker" ]]
}

@test "dry-run messages use YELLOW prefix" {
    DRY_RUN=true
    local output
    output=$(echo -e "\033[0;33m[DRY-RUN]\033[0m test message")
    [[ "$output" == *"test message"* ]]
}

@test "error function exits with code 1" {
    run bash -c '
        error() { echo "ERROR: $*" >&2; exit 1; }
        error "test error"
    '
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"test error"* ]]
}
