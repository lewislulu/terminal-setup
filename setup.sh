#!/bin/bash
#
# terminal-setup — One-script Mac terminal environment setup
#
# Stack: Ghostty + Fish + Starship + Nerd Font (MesloLGS)
# Tools: bat, eza, fd, ripgrep, btop, zoxide, jq, tldr, delta, lazygit
# Node:  nvm.fish (via Fisher)
# Theme: Catppuccin Mocha (Starship)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/lewislulu/terminal-setup/main/setup.sh | bash
#   — or —
#   git clone https://github.com/lewislulu/terminal-setup.git && cd terminal-setup && ./setup.sh
#

set -euo pipefail

# ─── Colors ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ─── Pre-flight ──────────────────────────────────────────────────────
[[ "$(uname)" != "Darwin" ]] && error "This script is for macOS only."

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

# ─── Step 1: Homebrew ───────────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  🍺 Step 1/7: Homebrew${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"

if ! command -v brew &>/dev/null; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
    success "Homebrew installed"
else
    success "Homebrew already installed"
fi

# ─── Step 2: Ghostty ────────────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  👻 Step 2/7: Ghostty Terminal${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"

if [[ ! -d "/Applications/Ghostty.app" ]]; then
    info "Installing Ghostty..."
    brew install --cask ghostty
    success "Ghostty installed"
else
    success "Ghostty already installed"
fi

# ─── Step 3: Nerd Font (MesloLGS NF) ────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  🔤 Step 3/7: Nerd Font (MesloLGS NF)${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"

FONT_DIR="$HOME/Library/Fonts"
MESLO_BASE_URL="https://github.com/romkatv/powerlevel10k-media/raw/master"
MESLO_FONTS=(
    "MesloLGS NF Regular.ttf"
    "MesloLGS NF Bold.ttf"
    "MesloLGS NF Italic.ttf"
    "MesloLGS NF Bold Italic.ttf"
)

FONT_INSTALLED=true
for font in "${MESLO_FONTS[@]}"; do
    [[ ! -f "$FONT_DIR/$font" ]] && FONT_INSTALLED=false && break
done

if $FONT_INSTALLED; then
    success "MesloLGS NF fonts already installed"
else
    info "Downloading MesloLGS NF fonts..."
    mkdir -p "$FONT_DIR"
    for font in "${MESLO_FONTS[@]}"; do
        encoded=$(echo "$font" | sed 's/ /%20/g')
        curl -fsSL "$MESLO_BASE_URL/$encoded" -o "$FONT_DIR/$font"
    done
    success "MesloLGS NF fonts installed"
fi

# ─── Step 4: Fish Shell ─────────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  🐟 Step 4/7: Fish Shell${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"

if ! command -v fish &>/dev/null; then
    info "Installing Fish..."
    brew install fish
    success "Fish installed"
else
    success "Fish already installed"
fi

# Add fish to allowed shells & set as default
FISH_PATH="$(which fish)"
if ! grep -qxF "$FISH_PATH" /etc/shells 2>/dev/null; then
    info "Adding Fish to /etc/shells (may need sudo)..."
    echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null
fi

if [[ "$SHELL" != "$FISH_PATH" ]]; then
    info "Setting Fish as default shell..."
    chsh -s "$FISH_PATH"
    success "Default shell changed to Fish"
else
    success "Fish is already the default shell"
fi

# ─── Step 5: CLI Tools ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  🛠  Step 5/7: CLI Tools${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"

TOOLS=(bat eza fd ripgrep btop zoxide jq tldr git-delta lazygit)

for tool in "${TOOLS[@]}"; do
    if brew list "$tool" &>/dev/null; then
        success "$tool already installed"
    else
        info "Installing $tool..."
        brew install "$tool"
        success "$tool installed"
    fi
done

# ─── Step 6: Starship Prompt ────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  🚀 Step 6/7: Starship Prompt${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"

if ! command -v starship &>/dev/null; then
    info "Installing Starship..."
    brew install starship
    success "Starship installed"
else
    success "Starship already installed"
fi

# ─── Step 7: Config Files ───────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  📦 Step 7/7: Deploying Configs${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"

# Fish config
FISH_CONFIG_DIR="$HOME/.config/fish"
mkdir -p "$FISH_CONFIG_DIR"

if [[ -f "$FISH_CONFIG_DIR/config.fish" ]]; then
    cp "$FISH_CONFIG_DIR/config.fish" "$FISH_CONFIG_DIR/config.fish.bak.$(date +%s)"
    warn "Backed up existing config.fish"
fi
cp "$CONFIGS_DIR/config.fish" "$FISH_CONFIG_DIR/config.fish"
success "Fish config deployed"

# Starship config
mkdir -p "$HOME/.config"
if [[ -f "$HOME/.config/starship.toml" ]]; then
    cp "$HOME/.config/starship.toml" "$HOME/.config/starship.toml.bak.$(date +%s)"
    warn "Backed up existing starship.toml"
fi
cp "$CONFIGS_DIR/starship.toml" "$HOME/.config/starship.toml"
success "Starship config deployed"

# Fisher + fish plugins
info "Installing Fisher and plugins..."
fish -c '
    if not functions -q fisher
        curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
        fisher install jorgebucaran/fisher
    end
    fisher install jorgebucaran/nvm.fish
' 2>/dev/null
success "Fisher + nvm.fish installed"

# fish_plugins file
cp "$CONFIGS_DIR/fish_plugins" "$FISH_CONFIG_DIR/fish_plugins"
success "Fish plugins list deployed"

# ─── Git config for delta ────────────────────────────────────────────
info "Configuring git-delta as git pager..."
git config --global core.pager delta
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global delta.dark true
git config --global delta.line-numbers true
git config --global delta.side-by-side true
git config --global merge.conflictstyle diff3
git config --global diff.colorMoved default
success "git-delta configured"

# ─── Shell aliases (fish abbreviations) ─────────────────────────────
info "Setting up Fish abbreviations..."
fish -c '
    abbr -a --global ls "eza --icons --group-directories-first"
    abbr -a --global ll "eza -la --icons --group-directories-first"
    abbr -a --global lt "eza --tree --icons --level=2"
    abbr -a --global cat "bat"
    abbr -a --global find "fd"
    abbr -a --global grep "rg"
    abbr -a --global top "btop"
    abbr -a --global lg "lazygit"
    abbr -a --global cd "z"
'
success "Fish abbreviations set"

# ─── Zoxide init ─────────────────────────────────────────────────────
ZOXIDE_INIT='zoxide init fish | source'
if ! grep -qF "zoxide" "$FISH_CONFIG_DIR/config.fish" 2>/dev/null; then
    info "Adding zoxide init to fish config..."
    echo "" >> "$FISH_CONFIG_DIR/config.fish"
    echo "# zoxide" >> "$FISH_CONFIG_DIR/config.fish"
    echo "$ZOXIDE_INIT" >> "$FISH_CONFIG_DIR/config.fish"
    success "Zoxide init added"
else
    success "Zoxide init already present"
fi

# ─── Done! ───────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ✅ All done!${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BOLD}Your terminal stack:${NC}"
echo -e "    👻 Ghostty          — terminal emulator"
echo -e "    🐟 Fish             — shell"
echo -e "    🚀 Starship         — prompt (Catppuccin Mocha)"
echo -e "    🔤 MesloLGS NF      — nerd font"
echo -e "    📦 bat eza fd rg    — modern coreutils"
echo -e "    📊 btop             — system monitor"
echo -e "    🔀 lazygit + delta  — git tools"
echo -e "    📁 zoxide           — smart cd"
echo -e "    🟢 nvm.fish         — Node version manager"
echo ""
echo -e "  ${YELLOW}Next steps:${NC}"
echo -e "    1. Open ${BOLD}Ghostty${NC} and set font to ${BOLD}MesloLGS NF${NC}"
echo -e "    2. Restart your terminal (or run: ${BOLD}exec fish${NC})"
echo -e "    3. Install Node: ${BOLD}nvm install lts${NC}"
echo ""
