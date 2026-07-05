# test_helper.bash — Test utilities for terminal-setup
#
# Provides mock functions and helpers to test setup.sh in isolation.
# Designed for use with BATS (Bash Automated Testing System).

# Save original commands so we can restore them
setup_save_originals() {
    : "${ORIGINAL_UNAME:=$(command -v uname)}"
    : "${ORIGINAL_GREP:=$(command -v grep)}"
    : "${ORIGINAL_DPKG:=$(command -v dpkg)}"
    : "${ORIGINAL_PACMAN:=$(command -v pacman)}"
    : "${ORIGINAL_BREW:=$(command -v brew)}"
    : "${ORIGINAL_COMMAND:=$(command -v command)}"
    export ORIGINAL_UNAME ORIGINAL_GREP ORIGINAL_DPKG ORIGINAL_PACMAN ORIGINAL_BREW ORIGINAL_COMMAND
}

# Create a temporary sandbox home directory
setup_sandbox() {
    SANDBOX_DIR="$(mktemp -d)"
    HOME="$SANDBOX_DIR"
    export HOME
}

# Remove the sandbox
teardown_sandbox() {
    if [[ -n "${SANDBOX_DIR-}" ]]; then
        rm -rf "$SANDBOX_DIR"
    fi
}

# Mock `uname -s` by temporarily placing a fake uname in PATH
mock_uname() {
    local wanted="$1"
    local bindir="$SANDBOX_DIR/bin"
    mkdir -p "$bindir"
    cat > "$bindir/uname" <<'SCRIPT'
#!/bin/bash
if [[ "$1" == "-s" ]]; then
    echo "__MOCK_UNAME__"
else
    exec __REAL_UNAME__ "$@"
fi
SCRIPT
    sed -i "s/__MOCK_UNAME__/$wanted/" "$bindir/uname"
    sed -i "s|__REAL_UNAME__|$ORIGINAL_UNAME|" "$bindir/uname"
    chmod +x "$bindir/uname"
    PATH="$bindir:$PATH"
}

# Create a fake OS release file
mock_os_release() {
    local file="$1"
    local content="$2"
    mkdir -p "$(dirname "$file")"
    echo "$content" > "$file"
}

# Remove mocked files
cleanup_mocks() {
    rm -rf "$SANDBOX_DIR/bin" 2>/dev/null || true
    rm -f /tmp/__test_* 2>/dev/null || true
}

# Source the setup.sh script in a safe way (extract functions only)
source_setup_helpers() {
    local script="$1"
    # Source only the helper functions and color definitions
    source <(sed -n \
        -e '/^# ─── Colors/,/^esac$/p' \
        -e '/^has_cmd/,/^}$/p' \
        -e '/^detect_os/,/^}$/p' \
        -e '/^info()\|success()\|warn()\|error()/,/^}$/p' \
        "$script" 2>/dev/null) || true
}

# Assert that a command was run (dry-run log check)
assert_dry_run_log_contains() {
    local log="$1"
    local expected="$2"
    grep -qF "$expected" <<< "$log"
}

# Run a snippet of setup.sh with dry-run to inspect behavior
run_dry_snippet() {
    local snippet="$1"
    local tmpfile
    tmpfile="$(mktemp /tmp/__test_dry.XXXXXX)"
    echo 'DRY_RUN=true' > "$tmpfile"
    echo "$snippet" >> "$tmpfile"
    bash "$tmpfile" 2>&1 || true
    rm -f "$tmpfile"
}
