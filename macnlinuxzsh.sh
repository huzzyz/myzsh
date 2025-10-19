#!/usr/bin/env bash
#
# Universal ZSH + Neovim setup script for Linux & macOS
# Author: Ismail Kalimi (huzzyz)
# -------------------------------------------------------

set -euo pipefail

# ---------- COLORS ----------
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

# ---------- UTILITIES ----------
log() { echo -e "${BLUE}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }

# ---------- DETECT OS ----------
OS_TYPE="$(uname -s)"
ARCH="$(uname -m)"

if [[ "$OS_TYPE" == "Darwin" ]]; then
  PLATFORM="macos"
elif [[ "$OS_TYPE" == "Linux" ]]; then
  PLATFORM="linux"
else
  error "Unsupported OS: $OS_TYPE"
  exit 1
fi

log "Detected platform: $PLATFORM ($ARCH)"

# ---------- PREREQUISITES ----------
log "Ensuring required tools are available..."
if ! command -v curl >/dev/null 2>&1; then
  error "curl not found — please install curl and rerun this script."
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  error "git not found — please install git and rerun this script."
  exit 1
fi

# ---------- INSTALL ZSH ----------
if ! command -v zsh >/dev/null 2>&1; then
  log "ZSH not found. Installing..."
  if [[ "$PLATFORM" == "linux" ]]; then
    sudo apt update && sudo apt install -y zsh
  else
    brew install zsh
  fi
  success "ZSH installed."
else
  success "ZSH already installed."
fi

# ---------- CONFIGURE .zshrc ----------
ZSHRC="$HOME/.zshrc"
log "Configuring .zshrc..."

cat > "$ZSHRC" <<'EOF'
# --- Default ZSH Configuration ---
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster"
plugins=(git)

# Custom aliases
alias ll='ls -lh'
alias la='ls -lah'
alias gs='git status'
alias v='nvim'

# PATH adjustments for Homebrew (macOS)
if [[ -d "/opt/homebrew/bin" ]]; then
  export PATH="/opt/homebrew/bin:$PATH"
fi

# PATH adjustments for Linux
if [[ -d "/usr/local/bin" ]]; then
  export PATH="/usr/local/bin:$PATH"
fi

source $ZSH/oh-my-zsh.sh
EOF

success ".zshrc configured successfully with the Agnoster theme."

# ---------- INSTALL OH-MY-ZSH ----------
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  log "Installing Oh My Zsh..."
  RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  success "Oh My Zsh installed."
else
  success "Oh My Zsh already installed."
fi

# ---------- INSTALL NEOVIM ----------
log "Installing the latest version of Neovim..."

if [[ "$PLATFORM" == "macos" ]]; then
  if ! command -v brew >/dev/null 2>&1; then
    warn "Homebrew not found — installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  brew install neovim
  success "Neovim installed via Homebrew."

elif [[ "$PLATFORM" == "linux" ]]; then
  TMP_DIR=$(mktemp -d)
  NEOVIM_URL=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest \
    | grep browser_download_url \
    | grep "nvim-linux64.tar.gz" \
    | cut -d '"' -f 4 | head -n 1)

  if [[ -z "$NEOVIM_URL" ]]; then
    error "Failed to fetch Neovim download URL. Installing via apt instead."
    sudo apt update && sudo apt install -y neovim
  else
    log "Downloading Neovim from: $NEOVIM_URL"
    curl -L "$NEOVIM_URL" -o "$TMP_DIR/nvim-linux64.tar.gz"
    tar xzf "$TMP_DIR/nvim-linux64.tar.gz" -C "$TMP_DIR"
    sudo rm -rf /usr/local/nvim-linux64
    sudo mv "$TMP_DIR/nvim-linux64" /usr/local/
    sudo ln -sf /usr/local/nvim-linux64/bin/nvim /usr/local/bin/nvim
    success "Neovim installed successfully."
  fi
  rm -rf "$TMP_DIR"
fi

# ---------- DEFAULT SHELL ----------
if [[ "$SHELL" != *zsh ]]; then
  log "Setting ZSH as default shell..."
  chsh -s "$(command -v zsh)" || warn "Could not change default shell automatically. Please run manually."
else
  success "ZSH is already your default shell."
fi

# ---------- FINAL CHECK ----------
log "Verifying installations..."
if command -v zsh >/dev/null && command -v nvim >/dev/null; then
  success "ZSH and Neovim successfully installed and configured!"
else
  error "Something went wrong — please review the log above."
  exit 1
fi

log "Setup complete. Restart your terminal or run 'exec zsh' to start using it."
