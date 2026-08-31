#!/bin/bash
#
# terminal-setup — One-script terminal environment setup
#
# Platforms: macOS, Debian/Ubuntu, Windows (via WSL)
#
# Stack: Ghostty + (Fish or Zsh) + Starship + Nerd Font (MesloLGS)
# Tools: bat, eza, fd, ripgrep, btop, zoxide, jq, tldr, delta, lazygit, fzf, aria2
# ML/dev: uv, python3-venv, pipx, direnv, nvtop
# Node:  fnm (Fast Node Manager) + pnpm — works with both Fish and Zsh
# Theme: Catppuccin Mocha (Starship)
#
# Usage:
#   ./setup.sh              # interactive shell choice
#   ./setup.sh --fish       # use Fish
#   ./setup.sh --zsh        # use Zsh (with fish-like plugins)
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
for arg in "$@"; do
    case "$arg" in
        --fish)    SHELL_CHOICE="fish" ;;
        --zsh)     SHELL_CHOICE="zsh" ;;
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

configure_apt_tuna_mirror() {
    if [[ "$OS" != "debian" && "$OS" != "wsl" ]]; then
        return 0
    fi

    echo ""
    echo -e "  Use Tsinghua TUNA apt mirror for faster downloads in China?"
    echo -e "  Mirror: ${BOLD}https://mirrors.tuna.tsinghua.edu.cn${NC}"
    printf "  Configure apt mirror? (y/N): "
    read -r CONFIGURE_APT_MIRROR
    if [[ ! "$CONFIGURE_APT_MIRROR" =~ ^[Yy]$ ]]; then
        info "Keeping existing apt sources"
        return 0
    fi

    local codename
    codename=""
    if has_cmd lsb_release; then
        codename="$(lsb_release -cs 2>/dev/null || true)"
    fi
    if [[ -z "$codename" && -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        codename="${VERSION_CODENAME:-}"
    fi
    if [[ -z "$codename" ]]; then
        warn "Could not detect Debian/Ubuntu codename — skipping apt mirror configuration"
        return 0
    fi

    local mirror="https://mirrors.tuna.tsinghua.edu.cn/ubuntu"
    local security_mirror="$mirror"
    local components="main restricted universe multiverse"
    local signed_by="/usr/share/keyrings/ubuntu-archive-keyring.gpg"
    local deb822_file=""
    if [[ -r /etc/os-release ]] && grep -qi '^ID=debian' /etc/os-release; then
        mirror="https://mirrors.tuna.tsinghua.edu.cn/debian"
        security_mirror="https://mirrors.tuna.tsinghua.edu.cn/debian-security"
        components="main contrib non-free non-free-firmware"
        signed_by="/usr/share/keyrings/debian-archive-keyring.gpg"
    fi

    local timestamp
    timestamp="$(date +%s)"
    info "Configuring apt mirror for $codename..."

    if [[ -f /etc/apt/sources.list.d/ubuntu.sources ]]; then
        deb822_file="/etc/apt/sources.list.d/ubuntu.sources"
    elif [[ -f /etc/apt/sources.list.d/debian.sources ]]; then
        deb822_file="/etc/apt/sources.list.d/debian.sources"
    fi

    if [[ -n "$deb822_file" ]]; then
        if grep -q "mirrors.tuna.tsinghua.edu.cn" "$deb822_file" 2>/dev/null; then
            success "apt mirror already configured: $deb822_file"
            return 0
        fi
        run_cmd sudo cp "$deb822_file" "${deb822_file}.bak.$timestamp"
        if $DRY_RUN; then
            echo -e "${YELLOW}[DRY-RUN]${NC} write TUNA DEB822 sources to $deb822_file"
        else
            sudo tee "$deb822_file" >/dev/null <<EOF
Types: deb
URIs: $mirror
Suites: $codename ${codename}-updates ${codename}-backports
Components: $components
Signed-By: $signed_by

Types: deb
URIs: $security_mirror
Suites: ${codename}-security
Components: $components
Signed-By: $signed_by
EOF
        fi
    else
        if [[ -f /etc/apt/sources.list ]] && grep -q "mirrors.tuna.tsinghua.edu.cn" /etc/apt/sources.list 2>/dev/null; then
            success "apt mirror already configured: /etc/apt/sources.list"
            return 0
        fi
        if [[ -f /etc/apt/sources.list ]]; then
            run_cmd sudo cp /etc/apt/sources.list "/etc/apt/sources.list.bak.$timestamp"
        fi
        if $DRY_RUN; then
            echo -e "${YELLOW}[DRY-RUN]${NC} write TUNA apt sources to /etc/apt/sources.list"
        else
            sudo tee /etc/apt/sources.list >/dev/null <<EOF
deb $mirror $codename $components
deb $mirror ${codename}-updates $components
deb $mirror ${codename}-backports $components
deb $security_mirror ${codename}-security $components
EOF
        fi
    fi

    success "apt mirror configured"
}

# ─── Step 1: Package Manager ────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  📦 Step 1/10: Package Manager${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"

case "$OS" in
    macos)
        if ! has_cmd brew; then
            info "Installing Homebrew..."
            run_cmd /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            # Auto-detect Homebrew prefix (Apple Silicon vs Intel)
            if [[ -d /opt/homebrew ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            elif [[ -d /usr/local/Homebrew ]]; then
                eval "$(/usr/local/bin/brew shellenv)"
            fi
            success "Homebrew installed"
        else
            success "Homebrew already installed"
        fi
        ;;
    debian|wsl)
        configure_apt_tuna_mirror
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
echo -e "${BOLD}  👻 Step 2/10: Terminal Emulator${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"

case "$OS" in
    macos)
        if [[ ! -d "/Applications/Ghostty.app" ]]; then
            info "Installing Ghostty..."
            run_cmd brew install --cask ghostty
            success "Ghostty installed"
        else
            success "Ghostty already installed"
        fi
        ;;
    debian)
        # Ghostty on Linux: check if already installed, otherwise try snap/flatpak or skip
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
        ;;
    wsl)
        info "WSL detected — terminal emulator runs on the Windows side."
        echo -e "  Install Ghostty for Windows: ${BOLD}https://ghostty.org${NC}"
        echo -e "  Or use Windows Terminal, which works great with WSL."
        info "Skipping terminal emulator installation."
        ;;
esac

# ─── Step 3: Nerd Font (MesloLGS NF) ────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  🔤 Step 3/10: Nerd Font (MesloLGS NF)${NC}"
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
    echo -e "${BOLD}  🐟 Step 4/10: Fish Shell${NC}"
else
    echo -e "${BOLD}  🐚 Step 4/10: Zsh + Fish-like Plugins${NC}"
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
echo -e "${BOLD}  🛠  Step 5/10: CLI Tools${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"

install_cli_tools_macos() {
    local TOOLS=(bat eza fd ripgrep btop zoxide jq tldr git-delta lazygit fzf aria2)
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
    local APT_TOOLS=(bat fd-find ripgrep jq fzf aria2)

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

install_ffmpeg() {
    if has_cmd ffmpeg; then
        success "ffmpeg already installed"
        return 0
    fi

    echo ""
    echo -e "  ffmpeg is useful for audio/video conversion, probing, and frame extraction."
    printf "  Install ffmpeg? (y/N): "
    read -r INSTALL_FFMPEG
    if [[ "$INSTALL_FFMPEG" =~ ^[Yy]$ ]]; then
        info "Installing ffmpeg..."
        case "$OS" in
            macos)
                run_cmd brew install ffmpeg
                ;;
            debian|wsl)
                run_cmd sudo apt-get install -y ffmpeg
                ;;
        esac
        success "ffmpeg installed"
    else
        info "Skipping ffmpeg"
    fi
}

install_ffmpeg

# ─── Step 6: Deep Learning Dev Tools ────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  🧠 Step 6/10: Deep Learning Dev Tools${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"

install_dev_tools_macos() {
    local TOOLS=(uv python pipx direnv)
    for tool in "${TOOLS[@]}"; do
        if brew list "$tool" &>/dev/null; then
            success "$tool already installed"
        else
            info "Installing $tool..."
            run_cmd brew install "$tool"
            success "$tool installed"
        fi
    done

    if brew info nvtop &>/dev/null; then
        if brew list nvtop &>/dev/null; then
            success "nvtop already installed"
        else
            info "Installing nvtop..."
            run_cmd brew install nvtop
            success "nvtop installed"
        fi
    else
        warn "nvtop is not available via Homebrew on this system — skipping"
    fi
}

install_dev_tools_linux() {
    local APT_TOOLS=(python3 python3-venv python3-pip pipx direnv)
    for tool in "${APT_TOOLS[@]}"; do
        if dpkg -s "$tool" &>/dev/null 2>&1; then
            success "$tool already installed"
        else
            info "Installing $tool..."
            run_cmd sudo apt-get install -y "$tool"
            success "$tool installed"
        fi
    done

    if has_cmd uv; then
        success "uv already installed"
    else
        info "Installing uv..."
        if $DRY_RUN; then
            echo -e "${YELLOW}[DRY-RUN]${NC} curl -LsSf https://astral.sh/uv/install.sh | sh"
        else
            curl -LsSf https://astral.sh/uv/install.sh | sh
            export PATH="$HOME/.local/bin:$PATH"
        fi
        success "uv installed"
    fi

    if has_cmd nvtop; then
        success "nvtop already installed"
    else
        info "Installing nvtop..."
        if run_cmd sudo apt-get install -y nvtop 2>/dev/null; then
            success "nvtop installed"
        else
            warn "nvtop is not available via apt on this Ubuntu/Debian release — skipping"
        fi
    fi
}

case "$OS" in
    macos)      install_dev_tools_macos ;;
    debian|wsl) install_dev_tools_linux ;;
esac

configure_python_package_mirrors() {
    echo ""
    echo -e "  Use China mirrors for pip, uv, and conda?"
    echo -e "  PyPI mirror:  ${BOLD}https://mirrors.tuna.tsinghua.edu.cn${NC}"
    echo -e "  Conda mirror: ${BOLD}https://mirrors.ustc.edu.cn${NC}"
    printf "  Configure Python/Conda mirrors? (y/N): "
    read -r CONFIGURE_PYTHON_MIRRORS
    if [[ ! "$CONFIGURE_PYTHON_MIRRORS" =~ ^[Yy]$ ]]; then
        info "Keeping existing Python/Conda mirror settings"
        return 0
    fi

    local timestamp
    timestamp="$(date +%s)"

    deploy_user_config() {
        local src="$1"
        local dest="$2"
        local dest_dir
        dest_dir="$(dirname "$dest")"

        if $DRY_RUN; then
            echo -e "${YELLOW}[DRY-RUN]${NC} mkdir -p $dest_dir"
            if [[ -f "$dest" ]]; then
                echo -e "${YELLOW}[DRY-RUN]${NC} cp $dest $dest.bak.$timestamp"
            fi
            echo -e "${YELLOW}[DRY-RUN]${NC} cp $src $dest"
            return 0
        fi

        mkdir -p "$dest_dir"
        if [[ -f "$dest" ]]; then
            cp "$dest" "$dest.bak.$timestamp"
            warn "Backed up existing $dest"
        fi
        cp "$src" "$dest"
    }

    deploy_user_config "$CONFIGS_DIR/pip.conf" "$HOME/.config/pip/pip.conf"
    deploy_user_config "$CONFIGS_DIR/uv.toml" "$HOME/.config/uv/uv.toml"
    deploy_user_config "$CONFIGS_DIR/.condarc" "$HOME/.condarc"
    success "Mirrors configured for pip, uv, and conda"
}

configure_python_package_mirrors

install_miniforge() {
    if has_cmd conda || [[ -x "$HOME/miniforge3/bin/conda" ]]; then
        success "Miniforge/conda already installed"
        if [[ -x "$HOME/miniforge3/bin/conda" ]]; then
            run_cmd "$HOME/miniforge3/bin/conda" config --set auto_activate_base false
        fi
        return 0
    fi

    echo ""
    echo -e "  Miniforge provides conda/mamba environments for scientific Python and ML."
    echo -e "  It will be installed to ${BOLD}$HOME/miniforge3${NC} with base auto-activation disabled."
    printf "  Install Miniforge? (y/N): "
    read -r INSTALL_MINIFORGE
    if [[ ! "$INSTALL_MINIFORGE" =~ ^[Yy]$ ]]; then
        info "Skipping Miniforge"
        return 0
    fi

    local miniforge_arch
    miniforge_arch="$(uname -m)"
    case "$miniforge_arch" in
        x86_64|aarch64|arm64) ;;
        *)
            warn "Unsupported architecture for Miniforge: $miniforge_arch"
            return 0
            ;;
    esac

    local miniforge_os
    case "$OS" in
        macos) miniforge_os="MacOSX" ;;
        debian|wsl) miniforge_os="Linux" ;;
        *) warn "Unsupported OS for Miniforge: $OS"; return 0 ;;
    esac

    local installer="Miniforge3-${miniforge_os}-${miniforge_arch}.sh"
    local url="https://github.com/conda-forge/miniforge/releases/latest/download/$installer"
    local tmp_dir=""
    tmp_dir="$(mktemp -d)"

    info "Installing Miniforge..."
    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN]${NC} curl -fL --progress-bar $url -o $tmp_dir/$installer"
        echo -e "${YELLOW}[DRY-RUN]${NC} bash $tmp_dir/$installer -b -p $HOME/miniforge3"
        echo -e "${YELLOW}[DRY-RUN]${NC} $HOME/miniforge3/bin/conda config --set auto_activate_base false"
    else
        curl -fL --progress-bar "$url" -o "$tmp_dir/$installer"
        bash "$tmp_dir/$installer" -b -p "$HOME/miniforge3"
        "$HOME/miniforge3/bin/conda" config --set auto_activate_base false
        rm -rf "$tmp_dir"
    fi
    success "Miniforge installed with base auto-activation disabled"
}

install_miniforge

configure_miniforge_shell() {
    local conda_bin=""
    local mamba_bin=""

    if [[ -x "$HOME/miniforge3/bin/conda" ]]; then
        conda_bin="$HOME/miniforge3/bin/conda"
    elif has_cmd conda; then
        conda_bin="$(command -v conda)"
    else
        return 0
    fi

    info "Configuring conda for $SHELL_CHOICE..."
    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN]${NC} $conda_bin init $SHELL_CHOICE"
    else
        "$conda_bin" init "$SHELL_CHOICE"
    fi
    success "Conda shell integration configured"

    if [[ -x "$HOME/miniforge3/bin/mamba" ]]; then
        mamba_bin="$HOME/miniforge3/bin/mamba"
    elif has_cmd mamba; then
        mamba_bin="$(command -v mamba)"
    else
        return 0
    fi

    info "Configuring mamba activate/deactivate for $SHELL_CHOICE..."
    if [[ "$SHELL_CHOICE" == "zsh" ]]; then
        if grep -qF 'mamba shell hook --shell zsh' "$HOME/.zshrc" 2>/dev/null; then
            success "Mamba shell integration already present"
            return 0
        fi
        if $DRY_RUN; then
            echo -e "${YELLOW}[DRY-RUN]${NC} append mamba shell hook to $HOME/.zshrc"
        else
            cat >> "$HOME/.zshrc" << MAMBAZSH

# >>> mamba initialize >>>
eval "\$($mamba_bin shell hook --shell zsh --root-prefix "$HOME/miniforge3")"
# <<< mamba initialize <<<
MAMBAZSH
        fi
        success "Mamba shell integration configured"
    elif [[ "$SHELL_CHOICE" == "fish" ]]; then
        local fish_config="$HOME/.config/fish/config.fish"
        if grep -qF 'mamba shell hook --shell fish' "$fish_config" 2>/dev/null; then
            success "Mamba shell integration already present"
            return 0
        fi
        if $DRY_RUN; then
            echo -e "${YELLOW}[DRY-RUN]${NC} append mamba shell hook to $fish_config"
        else
            cat >> "$fish_config" << MAMBAFISH

# >>> mamba initialize >>>
$mamba_bin shell hook --shell fish --root-prefix "$HOME/miniforge3" | source
# <<< mamba initialize <<<
MAMBAFISH
        fi
        success "Mamba shell integration configured"
    fi
}

# Optional Hugging Face downloader (community script)
install_hfd() {
    if has_cmd hfd; then
        success "hfd already installed"
        return 0
    fi

    echo ""
    echo -e "  hfd is a community Hugging Face downloader based on aria2/wget."
    echo -e "  Source: ${BOLD}https://gist.github.com/padeoe/697678ab8e528b85a2a7bddafea1fa4f${NC}"
    printf "  Install hfd Hugging Face downloader? (y/N): "
    read -r INSTALL_HFD
    if [[ "$INSTALL_HFD" =~ ^[Yy]$ ]]; then
        info "Installing hfd..."
        mkdir -p "$HOME/.local/bin"
        if $DRY_RUN; then
            echo -e "${YELLOW}[DRY-RUN]${NC} curl -fsSL https://gist.githubusercontent.com/padeoe/697678ab8e528b85a2a7bddafea1fa4f/raw/hfd.sh -o $HOME/.local/bin/hfd"
            echo -e "${YELLOW}[DRY-RUN]${NC} chmod +x $HOME/.local/bin/hfd"
        else
            curl -fsSL "https://gist.githubusercontent.com/padeoe/697678ab8e528b85a2a7bddafea1fa4f/raw/hfd.sh" -o "$HOME/.local/bin/hfd"
            chmod +x "$HOME/.local/bin/hfd"
            export PATH="$HOME/.local/bin:$PATH"
        fi
        success "hfd installed"
    else
        info "Skipping hfd"
    fi
}

install_hfd

# ─── Step 7: Starship Prompt ────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  🚀 Step 7/10: Starship Prompt${NC}"
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
                # Use bundled binary (most reliable)
                run_cmd sudo cp "$SCRIPT_DIR/bin/linux-x86_64/starship" /usr/local/bin/starship
                run_cmd sudo chmod +x /usr/local/bin/starship
            else
                # Download from GitHub releases (starship.rs installer may fail on some WSL setups)
                info "Bundled binary not found, downloading from GitHub..."
                starship_arch=""
                case "$(uname -m)" in
                    x86_64)  starship_arch="x86_64" ;;
                    aarch64) starship_arch="aarch64" ;;
                    *) error "Unsupported arch for Starship: $(uname -m)" ;;
                esac
                starship_tmp=""
                starship_tmp="$(mktemp -d)"
                if $DRY_RUN; then
                    echo -e "${YELLOW}[DRY-RUN]${NC} Download starship from GitHub releases"
                else
                    curl -fsSL "https://github.com/starship/starship/releases/latest/download/starship-${starship_arch}-unknown-linux-musl.tar.gz" \
                        | tar xz -C "$starship_tmp" \
                        && sudo cp "$starship_tmp/starship" /usr/local/bin/starship \
                        && sudo chmod +x /usr/local/bin/starship
                    rm -rf "$starship_tmp"
                fi
            fi
            ;;
    esac
    success "Starship installed"
fi

# ─── Step 8: fnm + Node.js (optional) ───────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  🟢 Step 8/10: fnm + Node.js (optional)${NC}"
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
    echo -e "  ${YELLOW}⚠ WARNING: fnm manages its own Node.js versions.${NC}"
    echo -e "  ${YELLOW}  If you already have Node.js installed (e.g. via nvm, Homebrew, or system),${NC}"
    echo -e "  ${YELLOW}  fnm may shadow your existing Node/npm and tools installed globally${NC}"
    echo -e "  ${YELLOW}  (e.g. Claude Code, Codex CLI, pnpm global packages).${NC}"
    echo -e "  ${YELLOW}  Only install fnm if you need to manage multiple Node versions.${NC}"
    echo ""
    printf "  Install fnm + Node.js? (y/N, default: N): "
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

# ─── pnpm (default when Node is available) ───────────────────────────
install_pnpm() {
    if has_cmd pnpm; then
        success "pnpm already installed"
        return 0
    fi

    if has_cmd corepack; then
        info "Installing pnpm via Corepack..."
        run_cmd corepack enable
        run_cmd corepack prepare pnpm@latest --activate
        success "pnpm installed"
    elif has_cmd npm; then
        info "Installing pnpm via npm..."
        run_cmd npm install -g pnpm
        success "pnpm installed"
    else
        warn "Node/npm not found — skipping pnpm"
    fi
}

install_pnpm

# ─── Step 9: Zellij (optional) ──────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  🪟 Step 9/10: Zellij (optional)${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"

if has_cmd zellij; then
    success "Zellij already installed"
else
    echo ""
    echo -e "  Zellij is a modern terminal multiplexer (like tmux, but better UX)."
    printf "  Install Zellij? (y/N): "
    read -r INSTALL_ZELLIJ
    if [[ "$INSTALL_ZELLIJ" =~ ^[Yy]$ ]]; then
        case "$OS" in
            macos)
                info "Installing Zellij..."
                run_cmd brew install zellij
                ;;
            debian|wsl)
                info "Installing Zellij..."
                if [[ -f "$SCRIPT_DIR/bin/linux-x86_64/zellij" ]]; then
                    run_cmd sudo cp "$SCRIPT_DIR/bin/linux-x86_64/zellij" /usr/local/bin/zellij
                    run_cmd sudo chmod +x /usr/local/bin/zellij
                else
                    # Download binary from GitHub releases (zellij.dev/launch auto-starts zellij, which hangs the script)
                    info "Downloading Zellij from GitHub releases..."
                    zellij_arch=""
                    case "$(uname -m)" in
                        x86_64)  zellij_arch="x86_64" ;;
                        aarch64) zellij_arch="aarch64" ;;
                        *) warn "Unsupported arch for Zellij: $(uname -m)"; return 0 ;;
                    esac
                    zellij_url="https://github.com/zellij-org/zellij/releases/latest/download/zellij-${zellij_arch}-unknown-linux-musl.tar.gz"
                    zellij_tmp=""
                    zellij_tmp="$(mktemp -d)"
                    if $DRY_RUN; then
                        echo -e "${YELLOW}[DRY-RUN]${NC} curl -fsSL $zellij_url | tar xz -C $zellij_tmp && sudo cp $zellij_tmp/zellij /usr/local/bin/"
                    else
                        curl -fsSL "$zellij_url" | tar xz -C "$zellij_tmp" \
                            && sudo cp "$zellij_tmp/zellij" /usr/local/bin/zellij \
                            && sudo chmod +x /usr/local/bin/zellij
                        rm -rf "$zellij_tmp"
                    fi
                fi
                ;;
        esac
        success "Zellij installed"
    else
        info "Skipping Zellij"
    fi
fi

# ─── Step 10: Config Files ──────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  📦 Step 10/10: Deploying Configs${NC}"
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
    # Fish config
    FISH_CONFIG_DIR="$HOME/.config/fish"
    mkdir -p "$FISH_CONFIG_DIR"

    if [[ -f "$FISH_CONFIG_DIR/config.fish" ]]; then
        run_cmd cp "$FISH_CONFIG_DIR/config.fish" "$FISH_CONFIG_DIR/config.fish.bak.$(date +%s)"
        warn "Backed up existing config.fish"
    fi

    # Deploy platform-appropriate fish config
    if [[ "$OS" == "macos" ]]; then
        run_cmd cp "$CONFIGS_DIR/config.fish" "$FISH_CONFIG_DIR/config.fish"
    else
        # For Linux: use modified config without Homebrew paths
        run_cmd cp "$CONFIGS_DIR/config.fish" "$FISH_CONFIG_DIR/config.fish"
        # Patch: replace Homebrew paths with Linux equivalents
        sed -i 's|/opt/homebrew/bin/starship|starship|g' "$FISH_CONFIG_DIR/config.fish"
        sed -i 's|fish_add_path /opt/homebrew/bin|# PATH: system paths are used on Linux|g' "$FISH_CONFIG_DIR/config.fish"
        # Fix pnpm path for Linux
        sed -i 's|\$HOME/Library/pnpm|\$HOME/.local/share/pnpm|g' "$FISH_CONFIG_DIR/config.fish"
    fi
    success "Fish config deployed"

    # Fish abbreviations (written to config.fish for Fish 3.x & 4.x compat)
    if ! grep -qF 'abbr -a ls' "$FISH_CONFIG_DIR/config.fish" 2>/dev/null; then
        info "Adding Fish abbreviations to config.fish..."
        cat >> "$FISH_CONFIG_DIR/config.fish" << 'ABBREOF'

# Abbreviations (compatible with Fish 3.x and 4.x)
if status is-interactive
    abbr -a ls "eza --icons --group-directories-first"
    abbr -a ll "eza -la --icons --group-directories-first"
    abbr -a lt "eza --tree --icons --level=2"
    abbr -a cat "bat"
    abbr -a find "fd"
    abbr -a grep "rg"
    abbr -a top "btop"
    abbr -a lg "lazygit"
    abbr -a cd "z"
end
ABBREOF
        success "Fish abbreviations added to config.fish"
    else
        success "Fish abbreviations already present"
    fi

    # Zoxide + fzf init for fish
    if ! grep -qF "zoxide" "$FISH_CONFIG_DIR/config.fish" 2>/dev/null; then
        info "Adding zoxide + fzf init to fish config..."
        cat >> "$FISH_CONFIG_DIR/config.fish" << 'FISHEOF'

# zoxide
zoxide init fish | source

# fzf
fzf --fish | source
set -gx FZF_DEFAULT_OPTS '--height 40% --layout=reverse --border'
if command -q fd
    set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
    set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
    set -gx FZF_ALT_C_COMMAND 'fd --type d --hidden --follow --exclude .git'
end
FISHEOF
        success "Zoxide + fzf init added"
    else
        success "Zoxide init already present"
    fi

    # Add ~/.local/bin to fish PATH on Linux
    if [[ "$OS" == "debian" || "$OS" == "wsl" ]]; then
        if ! grep -qF '.local/bin' "$FISH_CONFIG_DIR/config.fish" 2>/dev/null; then
            echo '' >> "$FISH_CONFIG_DIR/config.fish"
            echo '# Local bin (Linux)' >> "$FISH_CONFIG_DIR/config.fish"
            echo 'fish_add_path $HOME/.local/bin' >> "$FISH_CONFIG_DIR/config.fish"
        fi
    fi
else
    # Zsh config
    if [[ -f "$HOME/.zshrc" ]]; then
        run_cmd cp "$HOME/.zshrc" "$HOME/.zshrc.bak.$(date +%s)"
        warn "Backed up existing .zshrc"
    fi

    if [[ "$OS" == "macos" ]]; then
        run_cmd cp "$CONFIGS_DIR/.zshrc" "$HOME/.zshrc"
    else
        # Deploy and patch for Linux
        run_cmd cp "$CONFIGS_DIR/.zshrc" "$HOME/.zshrc"

        # Patch Homebrew paths → Linux paths
        sed -i '/# ─── Homebrew/i # ─── Local bin (Linux) ───────────────────────────────────────────────\nexport PATH="$HOME/.local/bin:$PATH"\n' "$HOME/.zshrc"
        sed -i '/export PATH="\/opt\/homebrew\/bin:\/opt\/homebrew\/sbin:\$PATH"/d' "$HOME/.zshrc"

        # Patch zsh plugin source paths
        sed -i 's|/opt/homebrew/share/zsh-syntax-highlighting/|/usr/share/zsh-syntax-highlighting/|g' "$HOME/.zshrc"
        sed -i 's|/opt/homebrew/share/zsh-autosuggestions/|/usr/share/zsh-autosuggestions/|g' "$HOME/.zshrc"
        sed -i 's|/opt/homebrew/share/zsh-completions|/usr/share/zsh-completions|g' "$HOME/.zshrc"

        # Patch pnpm path for Linux
        sed -i 's|\$HOME/Library/pnpm|\$HOME/.local/share/pnpm|g' "$HOME/.zshrc"

        # Add fnm path for Linux (installed to ~/.local/share/fnm)
        if ! grep -qF '.local/share/fnm' "$HOME/.zshrc" 2>/dev/null; then
            sed -i '/# ─── fnm/i # fnm binary path (Linux)\nexport PATH="$HOME/.local/share/fnm:$PATH"\n' "$HOME/.zshrc"
        fi
    fi
    success "Zsh config deployed"
fi

configure_miniforge_shell

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
        echo -e "    👻 Ghostty              — terminal emulator"
        ;;
    debian)
        echo -e "    👻 Ghostty              — terminal (install separately on Linux)"
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
echo -e "    🟢 fnm + pnpm           — Node version/package managers"
echo -e "    📦 bat eza fd rg        — modern coreutils"
echo -e "    📊 btop                 — system monitor"
echo -e "    🔀 lazygit + delta      — git tools"
echo -e "    📁 zoxide               — smart cd"
echo -e "    🔍 fzf                  — fuzzy finder"
echo -e "    📥 aria2                — fast downloads"
if has_cmd ffmpeg; then
    echo -e "    🎞  ffmpeg              — media processing"
fi
echo -e "    🧠 uv pipx direnv nvtop — Python/ML dev helpers"
if has_cmd conda || [[ -x "$HOME/miniforge3/bin/conda" ]]; then
    echo -e "    🐍 Miniforge            — conda/mamba environments"
fi
if has_cmd zellij; then
    echo -e "    🪟 zellij               — terminal multiplexer"
fi
if has_cmd hfd; then
    echo -e "    🤗 hfd                  — Hugging Face downloader"
fi
echo ""
echo -e "  ${YELLOW}Next steps:${NC}"
echo -e "    1. Restart your terminal (or open ${BOLD}Ghostty${NC})"
echo -e "    2. Node is ready: ${BOLD}node --version${NC}"
echo -e "    3. Pin a project: ${BOLD}echo 22 > .node-version${NC} (fnm auto-switches)"
echo -e "    4. Try: ${BOLD}Ctrl+R${NC} (fzf history) / ${BOLD}Ctrl+T${NC} (fzf files)"
echo ""
