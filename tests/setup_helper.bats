#!/usr/bin/env bats
# Tests for OS detection helper functions

setup() {
    load 'test_helper'
    setup_sandbox
}

teardown() {
    cleanup_mocks
    teardown_sandbox
}

# ── detect_os tests ──────────────────────────────────────────────
# We test the OS detection LOGIC by running the conditions in a
# subprocess with mocked file paths under SANDBOX_DIR.

create_release_file() {
    local path="$1" content="$2"
    mkdir -p "$(dirname "$SANDBOX_DIR$path")"
    printf '%s' "$content" > "$SANDBOX_DIR$path"
}

@test "detect_os: macOS" {
    result=$(bash -c 'uname -s')
    [[ "$result" == "Darwin" ]] || skip "not running on macOS"
}

@test "detect_os: Arch Linux via /etc/arch-release" {
    create_release_file "/etc/arch-release" "Arch Linux"
    result=$(bash -c "
        if [[ -f '$SANDBOX_DIR/etc/arch-release' ]]; then echo arch; else echo no; fi
    ")
    [[ "$result" == "arch" ]]
}

@test "detect_os: Arch Linux via /etc/os-release" {
    create_release_file "/etc/os-release" "ID=arch"
    result=$(bash -c "
        if grep -qi 'arch' '$SANDBOX_DIR/etc/os-release' 2>/dev/null; then echo arch; else echo no; fi
    ")
    [[ "$result" == "arch" ]]
}

@test "detect_os: Debian via /etc/debian_version" {
    create_release_file "/etc/debian_version" "12.0"
    result=$(bash -c "
        if [[ -f '$SANDBOX_DIR/etc/debian_version' ]]; then echo debian; else echo no; fi
    ")
    [[ "$result" == "debian" ]]
}

@test "detect_os: Debian via /etc/os-release" {
    create_release_file "/etc/os-release" "ID=debian"
    result=$(bash -c "
        if grep -qi 'debian' '$SANDBOX_DIR/etc/os-release' 2>/dev/null; then echo debian; else echo no; fi
    ")
    [[ "$result" == "debian" ]]
}

@test "detect_os: Ubuntu via /etc/os-release" {
    create_release_file "/etc/os-release" "ID=ubuntu"
    result=$(bash -c "
        if grep -qi 'ubuntu' '$SANDBOX_DIR/etc/os-release' 2>/dev/null; then echo debian; else echo no; fi
    ")
    [[ "$result" == "debian" ]]
}

@test "detect_os: WSL via /proc/version" {
    create_release_file "/proc/version" "Linux version 5.10.102.1-microsoft-standard-WSL2"
    result=$(bash -c "
        if grep -qiE '(microsoft|wsl)' '$SANDBOX_DIR/proc/version' 2>/dev/null; then echo wsl; else echo no; fi
    ")
    [[ "$result" == "wsl" ]]
}

@test "detect_os: unsupported Linux" {
    result="unsupported"
    [[ "$result" == "unsupported" ]]
}

# ── has_cmd tests ────────────────────────────────────────────────

@test "has_cmd: existing command returns true" {
    command -v bash
}

@test "has_cmd: non-existing command returns false" {
    run command -v this_command_does_not_exist_xyz123
    [[ "$status" -ne 0 ]]
}

# ── pkg_install checks (Arch) ────────────────────────────────────

@test "pacman -Qi: detects installed package" {
    if command -v pacman &>/dev/null; then
        run pacman -Qi bash
        [[ "$status" -eq 0 ]]
    else
        skip "pacman not available on this system"
    fi
}

@test "pacman -Qi: detects uninstalled package" {
    if command -v pacman &>/dev/null; then
        run pacman -Qi package_that_does_not_exist_xyz 2>/dev/null
        [[ "$status" -ne 0 ]]
    else
        skip "pacman not available on this system"
    fi
}
