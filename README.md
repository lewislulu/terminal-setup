# 🖥️ terminal-setup

One-script macOS terminal environment setup. Run on a fresh Mac, get a fully configured terminal in minutes.

## Stack

| Component | What |
|-----------|------|
| **Ghostty** | Terminal emulator |
| **Fish** | Shell |
| **Starship** | Prompt with Catppuccin Mocha theme |
| **MesloLGS NF** | Nerd Font |
| **bat** | Better `cat` with syntax highlighting |
| **eza** | Better `ls` with icons |
| **fd** | Better `find` |
| **ripgrep** | Better `grep` |
| **btop** | System monitor |
| **zoxide** | Smart `cd` |
| **jq** | JSON processor |
| **tldr** | Simplified man pages |
| **delta** | Better git diffs |
| **lazygit** | Git TUI |
| **nvm.fish** | Node version manager (via Fisher) |

## Quick Start

```bash
# Clone and run
git clone https://github.com/lewislulu/terminal-setup.git
cd terminal-setup
chmod +x setup.sh
./setup.sh
```

Or one-liner:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/lewislulu/terminal-setup/main/setup.sh)
```

## What It Does

1. Installs **Homebrew** (if needed)
2. Installs **Ghostty** terminal
3. Downloads **MesloLGS NF** nerd fonts
4. Installs **Fish** shell and sets it as default
5. Installs all **CLI tools** via brew
6. Installs **Starship** prompt with Catppuccin Mocha config
7. Deploys all config files (with backups of existing ones)
8. Sets up **Fisher** + **nvm.fish**
9. Configures **git-delta** as git pager
10. Sets up Fish **abbreviations** (ls→eza, cat→bat, etc.)

## Post-Setup

1. Open **Ghostty** → set font to `MesloLGS NF`
2. Restart terminal (or `exec fish`)
3. Install Node: `nvm install lts`

## Fish Abbreviations

| Shortcut | Expands To |
|----------|-----------|
| `ls` | `eza --icons --group-directories-first` |
| `ll` | `eza -la --icons --group-directories-first` |
| `lt` | `eza --tree --icons --level=2` |
| `cat` | `bat` |
| `find` | `fd` |
| `grep` | `rg` |
| `top` | `btop` |
| `lg` | `lazygit` |
| `cd` | `z` (zoxide) |

## License

MIT
