#!/bin/bash
# run_tests.sh — Run all BATS tests with proper setup
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check for bats
if ! command -v bats &>/dev/null; then
    echo "Error: 'bats' is not installed." >&2
    echo "" >&2
    echo "  Install it:" >&2
    echo "    macOS:  brew install bats-core" >&2
    echo "    Arch:   sudo pacman -S bats" >&2
    echo "    Debian: sudo apt install bats" >&2
    exit 1
fi

echo ""
echo "=== terminal-setup test suite ==="
echo "Project: $PROJECT_DIR"
echo ""

# Run all .bats files in the tests directory
cd "$PROJECT_DIR"
bats "$SCRIPT_DIR"/*.bats

echo ""
echo "=== done ==="
