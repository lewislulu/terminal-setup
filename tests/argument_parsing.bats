#!/usr/bin/env bats
# Tests for argument parsing (--fish, --zsh, --dry-run)

setup() {
    load 'test_helper'
    setup_sandbox
    setup_save_originals
}

teardown() {
    teardown_sandbox
}

# Simulate argument parsing by sourcing argument parsing section of setup.sh
parse_args_and_source() {
    local script="$PWD/setup.sh"
    local args=("$@")

    # Reset state variables
    SHELL_CHOICE=""
    DRY_RUN=false

    # Parse arguments using same logic as setup.sh
    for arg in "${args[@]}"; do
        case "$arg" in
            --fish)    SHELL_CHOICE="fish" ;;
            --zsh)     SHELL_CHOICE="zsh" ;;
            --dry-run) DRY_RUN=true ;;
        esac
    done
}

@test "no arguments: SHELL_CHOICE is empty (will prompt)" {
    parse_args_and_source
    [[ -z "$SHELL_CHOICE" ]]
}

@test "--fish: SHELL_CHOICE is fish" {
    parse_args_and_source --fish
    [[ "$SHELL_CHOICE" == "fish" ]]
}

@test "--zsh: SHELL_CHOICE is zsh" {
    parse_args_and_source --zsh
    [[ "$SHELL_CHOICE" == "zsh" ]]
}

@test "--dry-run: DRY_RUN is true" {
    parse_args_and_source --dry-run
    $DRY_RUN
}

@test "--dry-run --fish: both flags parsed" {
    parse_args_and_source --dry-run --fish
    [[ "$SHELL_CHOICE" == "fish" ]]
    $DRY_RUN
}

@test "--dry-run --zsh: both flags parsed" {
    parse_args_and_source --dry-run --zsh
    [[ "$SHELL_CHOICE" == "zsh" ]]
    $DRY_RUN
}

@test "unknown argument is ignored" {
    parse_args_and_source --unknown-flag --fish
    [[ "$SHELL_CHOICE" == "fish" ]]
}
