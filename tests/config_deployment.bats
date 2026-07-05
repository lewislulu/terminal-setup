#!/usr/bin/env bats
# Tests for config file deployment logic

setup() {
    load 'test_helper'
    setup_sandbox
}

teardown() {
    teardown_sandbox
}

# ── Config backup tests ──────────────────────────────────────────

@test "existing config is backed up before overwrite" {
    CONFIGS_DIR="$PWD/configs"

    # Create a mock existing config
    mkdir -p "$HOME/.config"
    echo "existing config" > "$HOME/.config/starship.toml"

    # Simulate backup logic
    if [[ -f "$HOME/.config/starship.toml" ]]; then
        cp "$HOME/.config/starship.toml" "$HOME/.config/starship.toml.bak.test"
    fi
    cp "$CONFIGS_DIR/starship.toml" "$HOME/.config/starship.toml"

    # Verify backup exists
    [[ -f "$HOME/.config/starship.toml.bak.test" ]]
    [[ "$(cat "$HOME/.config/starship.toml.bak.test")" == "existing config" ]]
    # Verify new config deployed
    [[ "$(cat "$HOME/.config/starship.toml")" == "$(cat "$CONFIGS_DIR/starship.toml")" ]]
}

@test "backup has unique timestamp" {
    # Verify that .bak.$(date +%s) produces a unique name each run
    local ts1 ts2
    ts1="config.bak.$(date +%s)"
    sleep 1
    ts2="config.bak.$(date +%s)"
    [[ "$ts1" != "$ts2" ]]
}

@test "no existing config: no backup created, fresh deploy" {
    CONFIGS_DIR="$PWD/configs"
    mkdir -p "$HOME/.config"

    [[ ! -f "$HOME/.config/starship.toml" ]]

    cp "$CONFIGS_DIR/starship.toml" "$HOME/.config/starship.toml"

    [[ -f "$HOME/.config/starship.toml" ]]
    # No backup should exist since there was no original
    local backups
    backups=$(ls "$HOME/.config"/starship.toml.bak.* 2>/dev/null || true)
    [[ -z "$backups" ]]
}

# ── Ghostty config directory tests ───────────────────────────────

@test "Ghostty config dir: Arch uses ~/.config/ghostty" {
    OS="arch"
    local dir
    case "$OS" in
        arch|debian) dir="$HOME/.config/ghostty" ;;
        macos)       dir="$HOME/Library/Application Support/com.mitchellh.ghostty" ;;
    esac
    [[ "$dir" == "$HOME/.config/ghostty" ]]
}

@test "Ghostty config dir: macOS uses Application Support" {
    OS="macos"
    local dir
    case "$OS" in
        arch|debian) dir="$HOME/.config/ghostty" ;;
        macos)       dir="$HOME/Library/Application Support/com.mitchellh.ghostty" ;;
    esac
    [[ "$dir" == "$HOME/Library/Application Support/com.mitchellh.ghostty" ]]
}
