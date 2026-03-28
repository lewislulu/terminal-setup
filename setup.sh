#!/bin/bash
#
# terminal-setup — One-script terminal environment setup
#
# Platforms: macOS, Debian/Ubuntu, Windows (via WSL)
#
# Stack: (Ghostty or cmux) + (Fish or Zsh) + Starship + Nerd Font (MesloLGS)
# Tools: bat, eza, fd, ripgrep, btop, zoxide, jq, tldr, delta, lazygit, fzf
# Node:  fnm (Fast Node Manager) — works with both Fish and Zsh
# Theme: Catppuccin Mocha (Starship)
#
# Usage:
#   ./setup.sh              # interactive shell and terminal choice
#   ./setup.sh --fish       # use Fish
#   ./setup.sh --zsh        # use Zsh (with fish-like plugins)
#   ./setup.sh --ghostty    # use Ghostty terminal
#   ./setup.sh --cmux       # use cmux terminal
#   ./setup.sh --dry-run    # preview what would be done (no changes)
#

set -euo pipefail

# ─── Colors ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Dry-run support ────────────────────────────────────────────────
DRY_RUN=false

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# run_cmd: execute a command, or just print it in dry-run mode
run_cmd() {
    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN]${NC} $*"
    else
        "$@"
    fi
}

# ─── Parse Arguments ────────────────────────────────────────────────
SHELL_CHOICE=""
TERMINAL_CHOICE=""
for arg in "$@"; do
    case "$arg" in
        --fish)    SHELL_CHOICE="fish" ;;
        --zsh)     SHELL_CHOICE="zsh" ;;
        --ghostty) TERMINAL_CHOICE="ghostty" ;;
        --cmux)    TERMINAL_CHOICE="cmux" ;;
        --dry-run) DRY_RUN=true ;;
    esac
done

if $DRY_RUN; then
    echo ""
    echo -e "${YELLOW}${BOLD}  ⚠  DRY-RUN MODE — no changes will be made${NC}"
    echo ""
fi

# ─── OS Detection ───────────────────────────────────────────────────
# Possible values: macos, debian, wsl, unsupported
detect_os() {
    local uname_out
    uname_out="$(uname -s)"

    case "$uname_out" in
        Darwin)
            echo "macos"
            ;;
        Linux)
            # Check if running inside WSL
            if grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; then
                echo "wsl"
            elif [[ -f /etc/debian_version ]] || grep -qi 'debian\|ubuntu' /etc/os-release 2>/dev/null; then
                echo "debian"
            else
                echo "unsupported"
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "windows-native"
            ;;
        *)
            echo "unsupported"
            ;;
    esac
}

OS="$(detect_os)"

case "$OS" in
    macos)
        info "Detected ${BOLD}macOS${NC}"
        ;;
    debian)
        info "Detected ${BOLD}Debian/Ubuntu Linux${NC}"
        ;;
    wsl)
        info "Detected ${BOLD}Windows WSL${NC} (Debian/Ubuntu layer)"
        ;;
    windows-native)
        error "Native Windows (MINGW/MSYS/Cygwin) is not supported.\n  Please install WSL: https://learn.microsoft.com/en-us/windows/wsl/install\n  Then run this script inside WSL."
        ;;
    *)
        error "Unsupported OS: $(uname -s)\n  This script supports macOS, Debian/Ubuntu, and Windows WSL."
        ;;
esac

# ─── Shell Choice ────────────────────────────────────────────────────
if [[ -z "$SHELL_CHOICE" ]]; then
    echo ""
    echo -e "${BOLD}Which shell do you want to use?${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} ${BOLD}Fish${NC}  — Modern shell, amazing defaults, not POSIX"
    echo -e "  ${GREEN}2)${NC} ${BOLD}Zsh${NC}   — POSIX-compatible, fish-like with plugins"
    echo ""
    while true; do
        read -rp "Choose [1/2]: " choice
        case "$choice" in
            1|fish) SHELL_CHOICE="fish"; break ;;
            2|zsh)  SHELL_CHOICE="zsh"; break ;;
            *) echo "Please enter 1 or 2." ;;
        esac
    done
fi

echo ""
info "Setting up with ${BOLD}${SHELL_CHOICE}${NC} on ${BOLD}${OS}${NC}"

# ─── Terminal Emulator Choice ────────────────────────────────────────
if [[ -z "$TERMINAL_CHOICE" ]]; then
    echo ""
    echo -e "${BOLD}Which terminal emulator do you want to use?${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} ${BOLD}Ghostty${NC} — Fast, GPU-accelerated terminal (macOS native)"
    echo -e "  ${GREEN}2)${NC} ${BOLD}cmux${NC}    — Built on Ghostty, vertical tabs, notifications, split panes"
    echo ""
    while true; do
        read -rp "Choose [1/2]: " choice
        case "$choice" in
            1|ghostty) TERMINAL_CHOICE="ghostty"; break ;;
            2|cmux)    TERMINAL_CHOICE="cmux"; break ;;
            *) echo "Please enter 1 or 2." ;;
        esac
    done
fi

echo ""
info "Using terminal: ${BOLD}${TERMINAL_CHOICE}${NC}"

# ─── Config Directory ───────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS_DIR="$SCRIPT_DIR/configs"

# If running via curl pipe (no local configs dir), clone the repo first
if [[ ! -d "$CONFIGS_DIR" ]]; then
    info "Config files not found locally, cloning repo..."
    TMPDIR_CLONE="$(mktemp -d)"
    git clone --depth 1 https://github.com/lewislulu/terminal-setup.git "$TMPDIR_CLONE/terminal-setup"
    SCRIPT_DIR="$TMPDIR_CLONE/terminal-setup"
    CONFIGS_DIR="$SCRIPT_DIR/configs"
fi

# ═══════════════════════════════════════════════════════════════════════
# Helper Functions (cross-platform)
# ═══════════════════════════════════════════════════════════════════════

# Install a package using the appropriate package manager
pkg_install() {
    local pkg="$1"
    case "$OS" in
        macos)
            if brew list "$pkg" &>/dev/null; then
                success "$pkg already installed"
                return 0
            fi
            info "Installing $pkg..."
            run_cmd brew install "$pkg"
            ;;
        debian|wsl)
            if dpkg -s "$pkg" &>/dev/null 2>&1; then
                success "$pkg already installed"
                return 0
            fi
            info "Installing $pkg..."
            run_cmd sudo apt-get install -y "$pkg"
            ;;
    esac
    success "$pkg installed"
}

# Install a cask (macOS only, no-op on Linux)
cask_install() {
    local cask="$1"
    if [[ "$OS" != "macos" ]]; then
        warn "Cask install is macOS-only, skipping $cask on $OS"
        return 0
    fi
    if brew list --cask "$cask" &>/dev/null; then
        success "$cask already installed"
        return 0
    fi
    info "Installing $cask..."
    run_cmd brew install --cask "$cask"
    success "$cask installed"
}

# Check if a command exists
has_cmd() {
    command -v "$1" &>/dev/null
}

# ─── Step 1: Package Manager ────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  📦 Step 1/8: Package Manager${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"

case "$OS" in
    macos)
        if ! has_cmd brew; then
            info "Installing Homebrew..."
            run_cmd /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            eval "$(/opt/homebrew/bin/brew shellenv)"
            success "Homebrew installed"
        else
            success "Homebrew already installed"
        fi
        ;;
    debian|wsl)
        info "Updating apt package index..."
        run_cmd sudo apt-get update
        # Ensure basic build tools are available
        pkg_install "curl"
        pkg_install "git"
        pkg_install "wget"
        pkg_install "unzip"
        pkg_install "build-essential"
        success "apt package manager ready"
        ;;
esac

# ─── Step 2: Terminal Emulator ───────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  👻 Step 2/8: Terminal Emulator${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"

case "$OS" in
    macos)
        if [[ "$TERMINAL_CHOICE" == "ghostty" ]]; then
            if [[ ! -d "/Applications/Ghostty.app" ]]; then
                info "Installing Ghostty..."
                run_cmd brew install --cask ghostty
                success "Ghostty installed"
            else
                success "Ghostty already installed"
            fi
        elif [[ "$TERMINAL_CHOICE" == "cmux" ]]; then
            if [[ ! -d "/Applications/cmux.app" ]]; then
                info "Installing cmux..."
                run_cmd brew install --cask cmux
                success "cmux installed"
            else
                success "cmux already installed"
            fi
        fi
        ;;
    debian)
        if [[ "$TERMINAL_CHOICE" == "ghostty" ]]; then
            if has_cmd ghostty; then
                success "Ghostty already installed"
            else
                warn "Ghostty is not easily available on Linux via apt."
                echo -e "  Options to install Ghostty on Linux:"
                echo -e "    • Snap:    ${BOLD}sudo snap install ghostty${NC}"
                echo -e "    • Build:   ${BOLD}https://ghostty.org/docs/install/build${NC}"
                echo -e "    • Or use any other terminal (kitty, alacritty, etc.)"
                echo ""
                info "Skipping Ghostty installation — install it manually if desired."
            fi
        elif [[ "$TERMINAL_CHOICE" == "cmux" ]]; then
            warn "cmux is macOS-only at this time."
            echo -e "  For Linux, please use Ghostty or another terminal."
            info "Skipping cmux installation."
        fi
        ;;
    wsl)
        info "WSL detected — terminal emulator runs on the Windows side."
        if [[ "$TERMINAL_CHOICE" == "cmux" ]]; then
            echo -e "  cmux is macOS-only. For WSL, please use Windows Terminal or Ghostty for Windows."
        else
            echo -e "  Install Ghostty for Windows: ${BOLD}https://ghostty.org${NC}"
            echo -e "  Or use Windows Terminal, which works great with WSL."
        fi
        info "Skipping terminal emulator installation."
        ;;
esac

# ─── Step 3: Nerd Font (MesloLGS NF) ────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  🔤 Step 3/8: Nerd Font (MesloLGS NF)${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"

# Determine font directory based on OS
case "$OS" in
    macos)
        FONT_DIR="$HOME/Library/Fonts"
        ;;
    debian|wsl)
        FONT_DIR="$HOME/.local/share/fonts"
        ;;
esac

MESLO_FONTS=(
    "MesloLGS NF Regular.ttf"
    "MesloLGS NF Bold.ttf"
    "MesloLGS NF Italic.ttf"
    "MesloLGS NF Bold Italic.ttf"
)

# Font source: bundled in repo (fonts/) — no download needed
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FONT_SRC_DIR="$SCRIPT_DIR/fonts"

FONT_INSTALLED=true
for font in "${MESLO_FONTS[@]}"; do
    [[ ! -f "$FONT_DIR/$font" ]] && FONT_INSTALLED=false && break
done

if $FONT_INSTALLED; then
    success "MesloLGS NF fonts already installed"
else
    info "Installing MesloLGS NF fonts from repo..."
    mkdir -p "$FONT_DIR"
    for font in "${MESLO_FONTS[@]}"; do
        if [[ -f "$FONT_SRC_DIR/$font" ]]; then
            run_cmd cp "$FONT_SRC_DIR/$font" "$FONT_DIR/$font"
        else
            warn "Font not found in repo: $font — skipping"
        fi
    done
    # Rebuild font cache on Linux
    if [[ "$OS" == "debian" || "$OS" == "wsl" ]]; then
        if has_cmd fc-cache; then
            run_cmd fc-cache -fv "$FONT_DIR"
        fi
    fi
    success "MesloLGS NF fonts installed"
fi

# ─── Step 4: Shell ──────────────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
if [[ "$SHELL_CHOICE" == "fish" ]]; then
    echo -e "${BOLD}  🐟 Step 4/8: Fish Shell${NC}"
else
    echo -e "${BOLD}  🐚 Step 4/8: Zsh + Fish-like Plugins${NC}"
fi
echo -e "${BOLD}══════════════════════════════════════════${NC}"

install_shell_macos() {
    if [[ "$SHELL_CHOICE" == "fish" ]]; then
        if ! has_cmd fish; then
            info "Installing Fish..."
            run_cmd brew install fish
            success "Fish installed"
        else
            success "Fish already installed"
        fi

        FISH_PATH="$(which fish)"
        if ! grep -qxF "$FISH_PATH" /etc/shells 2>/dev/null; then
            info "Adding Fish to /etc/shells (may need sudo)..."
            echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null
        fi

        if [[ "$SHELL" != "$FISH_PATH" ]]; then
            info "Setting Fish as default shell..."
            run_cmd chsh -s "$FISH_PATH"
            success "Default shell changed to Fish"
        else
            success "Fish is already the default shell"
        fi
    else
        # Zsh is pre-installed on macOS, just install the plugins
        local plugins=(zsh-autosuggestions zsh-syntax-highlighting zsh-completions)
        for plugin in "${plugins[@]}"; do
            if brew list "$plugin" &>/dev/null; then
                success "$plugin already installed"
            else
                info "Installing $plugin..."
                run_cmd brew install "$plugin"
                success "$plugin installed"
            fi
        done

        ZSH_PATH="$(which zsh)"
        if [[ "$SHELL" != "$ZSH_PATH" ]]; then
            info "Setting Zsh as default shell..."
            run_cmd chsh -s "$ZSH_PATH"
            success "Default shell changed to Zsh"
        else
            success "Zsh is already the default shell"
        fi
    fi
}

install_shell_linux() {
    if [[ "$SHELL_CHOICE" == "fish" ]]; then
        if ! has_cmd fish; then
            # Fish PPA for latest version on Ubuntu/Debian
            if [[ -f /etc/lsb-release ]] && grep -qi ubuntu /etc/lsb-release 2>/dev/null; then
                info "Adding Fish PPA for latest version..."
                run_cmd sudo apt-add-repository -y ppa:fish-shell/release-3
                run_cmd sudo apt-get update
            fi
            info "Installing Fish..."
            run_cmd sudo apt-get install -y fish
            success "Fish installed"
        else
            success "Fish already installed"
        fi

        FISH_PATH="$(which fish)"
        if ! grep -qxF "$FISH_PATH" /etc/shells 2>/dev/null; then
            info "Adding Fish to /etc/shells..."
            echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null
        fi

        if [[ "$SHELL" != "$FISH_PATH" ]]; then
            info "Setting Fish as default shell..."
            run_cmd chsh -s "$FISH_PATH"
            success "Default shell changed to Fish"
        else
            success "Fish is already the default shell"
        fi
    else
        # Install Zsh if not present
        if ! has_cmd zsh; then
            info "Installing Zsh..."
            run_cmd sudo apt-get install -y zsh
            success "Zsh installed"
        else
            success "Zsh already installed"
        fi

        # Install Zsh plugins from apt or git clone
        local ZSH_PLUGINS_DIR="/usr/share"
        local need_clone=false

        # zsh-autosuggestions
        if [[ -f "$ZSH_PLUGINS_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
            success "zsh-autosuggestions already installed"
        elif dpkg -s zsh-autosuggestions &>/dev/null 2>&1; then
            success "zsh-autosuggestions already installed"
        else
            info "Installing zsh-autosuggestions..."
            run_cmd sudo apt-get install -y zsh-autosuggestions 2>/dev/null || {
                info "apt package not available, cloning from git..."
                run_cmd sudo git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_PLUGINS_DIR/zsh-autosuggestions"
            }
            success "zsh-autosuggestions installed"
        fi

        # zsh-syntax-highlighting
        if [[ -f "$ZSH_PLUGINS_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
            success "zsh-syntax-highlighting already installed"
        elif dpkg -s zsh-syntax-highlighting &>/dev/null 2>&1; then
            success "zsh-syntax-highlighting already installed"
        else
            info "Installing zsh-syntax-highlighting..."
            run_cmd sudo apt-get install -y zsh-syntax-highlighting 2>/dev/null || {
                info "apt package not available, cloning from git..."
                run_cmd sudo git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_PLUGINS_DIR/zsh-syntax-highlighting"
            }
            success "zsh-syntax-highlighting installed"
        fi

        ZSH_PATH="$(which zsh)"
        if [[ "$SHELL" != "$ZSH_PATH" ]]; then
            info "Setting Zsh as default shell..."
            run_cmd chsh -s "$ZSH_PATH"
            success "Default shell changed to Zsh"
        else
            success "Zsh is already the default shell"
        fi
    fi
}

case "$OS" in
    macos)  install_shell_macos ;;
    debian|wsl) install_shell_linux ;;
esac

# ─── Step 5: CLI Tools ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  🛠  Step 5/8: CLI Tools${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"

install_cli_tools_macos() {
    local TOOLS=(bat eza fd ripgrep btop zoxide jq tldr git-delta lazygit fzf)
    for tool in "${TOOLS[@]}"; do
        if brew list "$tool" &>/dev/null; then
            success "$tool already installed"
        else
            info "Installing $tool..."
            run_cmd brew install "$tool"
            success "$tool installed"
        fi
    done
}

install_cli_tools_linux() {
    # Tools available directly from apt (on modern Debian/Ubuntu)
    local APT_TOOLS=(bat fd-find ripgrep jq fzf)

    for tool in "${APT_TOOLS[@]}"; do
        if dpkg -s "$tool" &>/dev/null 2>&1; then
            success "$tool already installed"
        else
            info "Installing $tool..."
            run_cmd sudo apt-get install -y "$tool"
            success "$tool installed"
        fi
    done

    # btop — not in apt on older Debian/Ubuntu, use snap as fallback
    if has_cmd btop; then
        success "btop already installed"
    else
        info "Installing btop..."
        if run_cmd sudo apt-get install -y btop 2>/dev/null; then
            success "btop installed via apt"
        elif has_cmd snap; then
            info "btop not in apt, trying snap..."
            run_cmd sudo snap install btop
            success "btop installed via snap"
        else
            warn "btop not available via apt or snap — skipping (install manually: https://github.com/aristocratos/btop)"
        fi
    fi

    # zoxide — not in apt on older Debian/Ubuntu, use bundled installer as fallback
    if has_cmd zoxide; then
        success "zoxide already installed"
    else
        info "Installing zoxide..."
        if run_cmd sudo apt-get install -y zoxide 2>/dev/null; then
            success "zoxide installed via apt"
        elif has_cmd snap && run_cmd sudo snap install zoxide 2>/dev/null; then
            success "zoxide installed via snap"
        else
            info "zoxide not in apt/snap, using bundled installer..."
            run_cmd bash "$SCRIPT_DIR/scripts/install-zoxide.sh"
            success "zoxide installed via bundled script"
        fi
    fi

    # bat is installed as 'batcat' on Debian/Ubuntu — create symlink
    if has_cmd batcat && ! has_cmd bat; then
        info "Creating symlink: batcat → bat"
        mkdir -p "$HOME/.local/bin"
        run_cmd ln -sf "$(which batcat)" "$HOME/.local/bin/bat"
        success "bat symlink created"
    fi

    # fd is installed as 'fdfind' on Debian/Ubuntu — create symlink
    if has_cmd fdfind && ! has_cmd fd; then
        info "Creating symlink: fdfind → fd"
        mkdir -p "$HOME/.local/bin"
        run_cmd ln -sf "$(which fdfind)" "$HOME/.local/bin/fd"
        success "fd symlink created"
    fi

    # Helper: install bundled binary from bin/linux-x86_64/
    install_bundled_bin() {
        local name="$1"
        if [[ -f "$SCRIPT_DIR/bin/linux-x86_64/$name" ]]; then
            run_cmd sudo cp "$SCRIPT_DIR/bin/linux-x86_64/$name" "/usr/local/bin/$name"
            run_cmd sudo chmod +x "/usr/local/bin/$name"
            success "$name installed from bundled binary"
            return 0
        fi
        return 1
    }

    # eza — try apt first, then bundled binary
    if has_cmd eza; then
        success "eza already installed"
    else
        info "Installing eza..."
        if run_cmd sudo apt-get install -y eza 2>/dev/null; then
            success "eza installed via apt"
        else
            install_bundled_bin eza || warn "Could not install eza — skipping"
        fi
    fi

    # tldr (tealdeer) — try apt first, then bundled binary
    if has_cmd tldr; then
        success "tldr already installed"
    else
        info "Installing tldr..."
        if run_cmd sudo apt-get install -y tealdeer 2>/dev/null; then
            success "tldr installed via apt"
        else
            install_bundled_bin tldr || warn "Could not install tldr — skipping"
        fi
    fi

    # git-delta — try apt first, then bundled binary
    if has_cmd delta; then
        success "git-delta already installed"
    else
        info "Installing git-delta..."
        if run_cmd sudo apt-get install -y git-delta 2>/dev/null; then
            success "git-delta installed via apt"
        else
            install_bundled_bin delta || warn "Could not install git-delta — skipping"
        fi
    fi

    # lazygit — try apt first, then bundled binary
    if has_cmd lazygit; then
        success "lazygit already installed"
    else
        info "Installing lazygit..."
        if run_cmd sudo apt-get install -y lazygit 2>/dev/null; then
            success "lazygit installed via apt"
        else
            install_bundled_bin lazygit || warn "Could not install lazygit — skipping"
        fi
    fi

    # Ensure ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        export PATH="$HOME/.local/bin:$PATH"
    fi
}

case "$OS" in
    macos)      install_cli_tools_macos ;;
    debian|wsl) install_cli_tools_linux ;;
esac

# ─── Step 6: Starship Prompt ────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  🚀 Step 6/8: Starship Prompt${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"

if has_cmd starship; then
    success "Starship already installed"
else
    case "$OS" in
        macos)
            info "Installing Starship..."
            run_cmd brew install starship
            ;;
        debian|wsl)
            info "Installing Starship..."
            if [[ -f "$SCRIPT_DIR/bin/linux-x86_64/starship" ]]; then
                run_cmd sudo cp "$SCRIPT_DIR/bin/linux-x86_64/starship" /usr/local/bin/starship
                run_cmd sudo chmod +x /usr/local/bin/starship
            else
                run_cmd sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- --yes
            fi
            ;;
    esac
    success "Starship installed"
fi

# ─── Step 7: fnm + Node.js (optional) ───────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  🟢 Step 7/8: fnm + Node.js (optional)${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"

if has_cmd fnm; then
    success "fnm already installed"
    # Load fnm in current shell so we can install Node
    eval "$(fnm env --use-on-cd --shell bash)"
    if ! fnm list 2>/dev/null | grep -q lts; then
        info "Installing Node LTS..."
        run_cmd fnm install --lts
        run_cmd fnm default lts-latest
        run_cmd fnm use lts-latest
        success "Node LTS installed and set as default"
    else
        success "Node LTS already installed"
    fi
else
    echo ""
    printf "  Install fnm + Node.js? (y/N): "
    read -r INSTALL_FNM
    if [[ "$INSTALL_FNM" =~ ^[Yy]$ ]]; then
        case "$OS" in
            macos)
                info "Installing fnm (Fast Node Manager)..."
                run_cmd brew install fnm
                ;;
            debian|wsl)
                info "Installing fnm via official installer..."
                run_cmd bash -c "$(curl -fsSL https://fnm.vercel.app/install)" -- --skip-shell
                export PATH="$HOME/.local/share/fnm:$PATH"
                ;;
        esac
        success "fnm installed"

        # Load fnm in current shell so we can install Node
        if has_cmd fnm; then
            eval "$(fnm env --use-on-cd --shell bash)"
            info "Installing Node LTS..."
            run_cmd fnm install --lts
            run_cmd fnm default lts-latest
            run_cmd fnm use lts-latest
            success "Node LTS installed and set as default"
        fi
    else
        info "Skipping fnm + Node.js"
    fi
fi

# ─── Step 8: Config Files ───────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  📦 Step 8/8: Deploying Configs${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"

# --- Ghostty config ---
deploy_ghostty_config() {
    local ghostty_config_dir
    case "$OS" in
        macos)
            ghostty_config_dir="$HOME/Library/Application Support/com.mitchellh.ghostty"
            ;;
        debian)
            ghostty_config_dir="$HOME/.config/ghostty"
            ;;
        wsl)
            info "Ghostty config: configure on the Windows side if using Ghostty for Windows."
            info "Deploying Linux-side config to ~/.config/ghostty/ for reference."
            ghostty_config_dir="$HOME/.config/ghostty"
            ;;
    esac

    mkdir -p "$ghostty_config_dir"
    if [[ -f "$ghostty_config_dir/config" ]] || [[ -f "$ghostty_config_dir/config.ghostty" ]]; then
        local existing
        existing="$(ls "$ghostty_config_dir"/config* 2>/dev/null | head -1)"
        run_cmd cp "$existing" "${existing}.bak.$(date +%s)"
        warn "Backed up existing Ghostty config"
    fi

    # macOS uses config.ghostty, Linux uses config
    case "$OS" in
        macos)
            run_cmd cp "$CONFIGS_DIR/ghostty.config" "$ghostty_config_dir/config.ghostty"
            ;;
        debian|wsl)
            run_cmd cp "$CONFIGS_DIR/ghostty.config" "$ghostty_config_dir/config"
            ;;
    esac
    success "Ghostty config deployed"
}

deploy_ghostty_config

# --- Starship config ---
mkdir -p "$HOME/.config"
if [[ -f "$HOME/.config/starship.toml" ]]; then
    run_cmd cp "$HOME/.config/starship.toml" "$HOME/.config/starship.toml.bak.$(date +%s)"
    warn "Backed up existing starship.toml"
fi
run_cmd cp "$CONFIGS_DIR/starship.toml" "$HOME/.config/starship.toml"
success "Starship config deployed"

# --- Shell-specific config ---
if [[ "$SHELL_CHOICE" == "fish" ]]; then
    FISH_CONFIG_DIR="$HOME/.config/fish"
    mkdir -p "$FISH_CONFIG_DIR"
    FISH_CONFIG="$FISH_CONFIG_DIR/config.fish"

    if [[ -f "$FISH_CONFIG" ]]; then
        info "Smart merging: preserving existing config.fish..."
        run_cmd cp "$FISH_CONFIG" "$FISH_CONFIG_DIR/config.fish.bak.$(date +%s)"
        warn "Backed up existing config.fish"
    fi

    if [[ ! -f "$FISH_CONFIG" ]] || [[ ! -s "$FISH_CONFIG" ]]; then
        if [[ "$OS" == "macos" ]]; then
            run_cmd cp "$CONFIGS_DIR/config.fish" "$FISH_CONFIG"
        else
            run_cmd cp "$CONFIGS_DIR/config.fish" "$FISH_CONFIG"
            sed -i 's|/opt/homebrew/bin/starship|starship|g' "$FISH_CONFIG"
            sed -i 's|fish_add_path /opt/homebrew/bin|# PATH: system paths are used on Linux|g' "$FISH_CONFIG"
            sed -i 's|\$HOME/Library/pnpm|\$HOME/.local/share/pnpm|g' "$FISH_CONFIG"
        fi
        success "Fish config deployed"
    else
        if ! grep -qF "starship init fish" "$FISH_CONFIG" 2>/dev/null; then
            info "Adding Starship init to fish config..."
            echo '' >> "$FISH_CONFIG"
            echo '# Starship prompt' >> "$FISH_CONFIG"
            if [[ "$OS" == "macos" ]]; then
                echo 'source (/opt/homebrew/bin/starship init fish --print-full-init | psub)' >> "$FISH_CONFIG"
            else
                echo 'source (starship init fish --print-full-init | psub)' >> "$FISH_CONFIG"
            fi
        fi

        if ! grep -qF "fnm env" "$FISH_CONFIG" 2>/dev/null; then
            info "Adding fnm init to fish config..."
            echo '' >> "$FISH_CONFIG"
            echo '# fnm (Node version manager)' >> "$FISH_CONFIG"
            echo 'fnm env --use-on-cd --shell fish | source' >> "$FISH_CONFIG"
        fi

        if ! grep -qF "zoxide init fish" "$FISH_CONFIG" 2>/dev/null; then
            info "Adding zoxide init to fish config..."
            echo '' >> "$FISH_CONFIG"
            echo '# zoxide' >> "$FISH_CONFIG"
            echo 'zoxide init fish | source' >> "$FISH_CONFIG"
        fi

        if ! grep -qF "fzf --fish" "$FISH_CONFIG" 2>/dev/null; then
            info "Adding fzf init to fish config..."
            echo '' >> "$FISH_CONFIG"
            echo '# fzf' >> "$FISH_CONFIG"
            echo 'fzf --fish | source' >> "$FISH_CONFIG"
            echo "set -gx FZF_DEFAULT_OPTS '--height 40% --layout=reverse --border'" >> "$FISH_CONFIG"
            echo 'if command -q fd' >> "$FISH_CONFIG"
            echo '    set -gx FZF_DEFAULT_COMMAND '\''fd --type f --hidden --follow --exclude .git'\''' >> "$FISH_CONFIG"
            echo '    set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND' >> "$FISH_CONFIG"
            echo '    set -gx FZF_ALT_C_COMMAND '\''fd --type d --hidden --follow --exclude .git'\''' >> "$FISH_CONFIG"
            echo 'end' >> "$FISH_CONFIG"
        fi

        if [[ "$OS" == "debian" || "$OS" == "wsl" ]]; then
            if ! grep -qF '.local/bin' "$FISH_CONFIG" 2>/dev/null; then
                echo '' >> "$FISH_CONFIG"
                echo '# Local bin (Linux)' >> "$FISH_CONFIG"
                echo 'fish_add_path $HOME/.local/bin' >> "$FISH_CONFIG"
            fi
        fi

        success "Fish config merged"
    fi

    if ! $DRY_RUN; then
        info "Setting up Fish abbreviations (appending only)..."
        fish -c '
            abbr -a --global ls "eza --icons --group-directories-first" 2>/dev/null || true
            abbr -a --global ll "eza -la --icons --group-directories-first" 2>/dev/null || true
            abbr -a --global lt "eza --tree --icons --level=2" 2>/dev/null || true
            abbr -a --global cat "bat" 2>/dev/null || true
            abbr -a --global find "fd" 2>/dev/null || true
            abbr -a --global grep "rg" 2>/dev/null || true
            abbr -a --global top "btop" 2>/dev/null || true
            abbr -a --global lg "lazygit" 2>/dev/null || true
            abbr -a --global cd "z" 2>/dev/null || true
        ' 2>/dev/null || true
        success "Fish abbreviations set"
    else
        info "[DRY-RUN] Would set Fish abbreviations"
    fi
else
    ZSHRC="$HOME/.zshrc"

    if [[ -f "$ZSHRC" ]]; then
        info "Smart merging: preserving existing .zshrc..."
        run_cmd cp "$ZSHRC" "$ZSHRC.bak.$(date +%s)"
        warn "Backed up existing .zshrc"
    fi

    if [[ ! -f "$ZSHRC" ]] || [[ ! -s "$ZSHRC" ]]; then
        if [[ "$OS" == "macos" ]]; then
            run_cmd cp "$CONFIGS_DIR/.zshrc" "$ZSHRC"
        else
            run_cmd cp "$CONFIGS_DIR/.zshrc" "$ZSHRC"
            sed -i 's|export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:\$PATH"|# PATH — system paths on Linux\nexport PATH="$HOME/.local/bin:$PATH"|' "$ZSHRC"
            sed -i 's|/opt/homebrew/share/zsh-syntax-highlighting/|/usr/share/zsh-syntax-highlighting/|g' "$ZSHRC"
            sed -i 's|/opt/homebrew/share/zsh-autosuggestions/|/usr/share/zsh-autosuggestions/|g' "$ZSHRC"
            sed -i 's|/opt/homebrew/share/zsh-completions|/usr/share/zsh-completions|g' "$ZSHRC"
            sed -i 's|\$HOME/Library/pnpm|\$HOME/.local/share/pnpm|g' "$ZSHRC"
            if ! grep -qF '.local/share/fnm' "$ZSHRC" 2>/dev/null; then
                sed -i '/# ─── fnm/i # fnm binary path (Linux)\nexport PATH="$HOME/.local/share/fnm:$PATH"\n' "$ZSHRC"
            fi
        fi
        success "Zsh config deployed"
    else
        if ! grep -qF "starship init zsh" "$ZSHRC" 2>/dev/null; then
            info "Adding Starship init to zsh config..."
            echo '' >> "$ZSHRC"
            echo '# Starship prompt' >> "$ZSHRC"
            echo 'eval "$(starship init zsh)"' >> "$ZSHRC"
        fi

        if ! grep -qF "zsh-syntax-highlighting.zsh" "$ZSHRC" 2>/dev/null; then
            info "Adding zsh-syntax-highlighting to zsh config..."
            echo '' >> "$ZSHRC"
            echo '# Zsh plugins - Syntax highlighting' >> "$ZSHRC"
            if [[ "$OS" == "macos" ]]; then
                echo 'if [[ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then' >> "$ZSHRC"
                echo '    source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' >> "$ZSHRC"
                echo 'fi' >> "$ZSHRC"
            else
                echo 'if [[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then' >> "$ZSHRC"
                echo '    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' >> "$ZSHRC"
                echo 'fi' >> "$ZSHRC"
            fi
        fi

        if ! grep -qF "zsh-autosuggestions.zsh" "$ZSHRC" 2>/dev/null; then
            info "Adding zsh-autosuggestions to zsh config..."
            echo '' >> "$ZSHRC"
            echo '# Zsh plugins - Autosuggestions' >> "$ZSHRC"
            if [[ "$OS" == "macos" ]]; then
                echo 'if [[ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then' >> "$ZSHRC"
                echo '    source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh' >> "$ZSHRC"
                echo '    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='\''fg=8'\''' >> "$ZSHRC"
                echo '    ZSH_AUTOSUGGEST_STRATEGY=(history completion)' >> "$ZSHRC"
                echo 'fi' >> "$ZSHRC"
            else
                echo 'if [[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then' >> "$ZSHRC"
                echo '    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh' >> "$ZSHRC"
                echo '    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='\''fg=8'\''' >> "$ZSHRC"
                echo '    ZSH_AUTOSUGGEST_STRATEGY=(history completion)' >> "$ZSHRC"
                echo 'fi' >> "$ZSHRC"
            fi
        fi

        if ! grep -qF "zoxide init zsh" "$ZSHRC" 2>/dev/null; then
            info "Adding zoxide init to zsh config..."
            echo '' >> "$ZSHRC"
            echo '# zoxide (smart cd)' >> "$ZSHRC"
            echo 'eval "$(zoxide init zsh)"' >> "$ZSHRC"
        fi

        if ! grep -qF "fnm env" "$ZSHRC" 2>/dev/null; then
            info "Adding fnm init to zsh config..."
            echo '' >> "$ZSHRC"
            echo '# fnm (Node version manager)' >> "$ZSHRC"
            echo 'eval "$(fnm env --use-on-cd --shell zsh)"' >> "$ZSHRC"
        fi

        if ! grep -qF "fzf --zsh" "$ZSHRC" 2>/dev/null && ! grep -qF "~/.fzf.zsh" "$ZSHRC" 2>/dev/null; then
            info "Adding fzf init to zsh config..."
            echo '' >> "$ZSHRC"
            echo '# fzf' >> "$ZSHRC"
            echo "export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'" >> "$ZSHRC"
            echo 'if command -v fd &>/dev/null; then' >> "$ZSHRC"
            echo '    export FZF_DEFAULT_COMMAND='\''fd --type f --hidden --follow --exclude .git'\''' >> "$ZSHRC"
            echo '    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"' >> "$ZSHRC"
            echo '    export FZF_ALT_C_COMMAND='\''fd --type d --hidden --follow --exclude .git'\''' >> "$ZSHRC"
            echo 'fi' >> "$ZSHRC"
            echo 'if [[ -f ~/.fzf.zsh ]]; then' >> "$ZSHRC"
            echo '    source ~/.fzf.zsh' >> "$ZSHRC"
            echo 'elif command -v fzf &>/dev/null; then' >> "$ZSHRC"
            echo '    eval "$(fzf --zsh 2>/dev/null)"' >> "$ZSHRC"
            echo 'fi' >> "$ZSHRC"
        fi

        if [[ "$OS" == "debian" || "$OS" == "wsl" ]]; then
            if ! grep -qF '.local/bin' "$ZSHRC" 2>/dev/null; then
                echo '' >> "$ZSHRC"
                echo '# Local bin (Linux)' >> "$ZSHRC"
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$ZSHRC"
            fi
            if ! grep -qF '.local/share/fnm' "$ZSHRC" 2>/dev/null; then
                echo '' >> "$ZSHRC"
                echo '# fnm binary path (Linux)' >> "$ZSHRC"
                echo 'export PATH="$HOME/.local/share/fnm:$PATH"' >> "$ZSHRC"
            fi
        fi

        success "Zsh config merged"
    fi
fi

# ─── Git config for delta ────────────────────────────────────────────
if has_cmd delta || $DRY_RUN; then
    info "Configuring git-delta as git pager..."
    run_cmd git config --global core.pager delta
    run_cmd git config --global interactive.diffFilter "delta --color-only"
    run_cmd git config --global delta.navigate true
    run_cmd git config --global delta.dark true
    run_cmd git config --global delta.line-numbers true
    run_cmd git config --global delta.side-by-side true
    run_cmd git config --global merge.conflictstyle diff3
    run_cmd git config --global diff.colorMoved default
    success "git-delta configured"
fi

# ─── Done! ───────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
if $DRY_RUN; then
    echo -e "${YELLOW}${BOLD}  ⚠  DRY-RUN complete — no changes were made${NC}"
else
    echo -e "${GREEN}${BOLD}  ✅ All done!${NC}"
fi
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BOLD}Platform:${NC} $OS"
echo -e ""
echo -e "  ${BOLD}Your terminal stack:${NC}"
case "$OS" in
    macos)
        if [[ "$TERMINAL_CHOICE" == "cmux" ]]; then
            echo -e "    🔧 cmux                 — terminal emulator (built on Ghostty)"
        else
            echo -e "    👻 Ghostty              — terminal emulator"
        fi
        ;;
    debian)
        if [[ "$TERMINAL_CHOICE" == "cmux" ]]; then
            echo -e "    🔧 cmux                 — terminal (macOS only, install manually on Linux)"
        else
            echo -e "    👻 Ghostty              — terminal (install separately on Linux)"
        fi
        ;;
    wsl)
        echo -e "    💻 Windows Terminal      — recommended for WSL"
        ;;
esac
if [[ "$SHELL_CHOICE" == "fish" ]]; then
    echo -e "    🐟 Fish                 — shell"
else
    echo -e "    🐚 Zsh                  — shell (POSIX-compatible)"
    echo -e "    ✨ zsh-autosuggestions   — fish-like suggestions"
    echo -e "    🎨 zsh-syntax-highlight — fish-like highlighting"
fi
echo -e "    🚀 Starship             — prompt (Catppuccin Mocha)"
echo -e "    🔤 MesloLGS NF          — nerd font"
echo -e "    🟢 fnm                  — Node version manager (fast!)"
echo -e "    📦 bat eza fd rg        — modern coreutils"
echo -e "    📊 btop                 — system monitor"
echo -e "    🔀 lazygit + delta      — git tools"
echo -e "    📁 zoxide               — smart cd"
echo -e "    🔍 fzf                  — fuzzy finder"
echo ""
echo -e "  ${YELLOW}Next steps:${NC}"
echo -e "    1. Restart your terminal (or open ${BOLD}Ghostty${NC})"
echo -e "    2. Node is ready: ${BOLD}node --version${NC}"
echo -e "    3. Pin a project: ${BOLD}echo 22 > .node-version${NC} (fnm auto-switches)"
echo -e "    4. Try: ${BOLD}Ctrl+R${NC} (fzf history) / ${BOLD}Ctrl+T${NC} (fzf files)"
echo ""
