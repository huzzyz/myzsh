#!/usr/bin/env bash
# ------------------------------------------------------------
# Universal ZSH + Neovim + NvChad Setup Script
# Works on Debian/Ubuntu and macOS
# ------------------------------------------------------------
set -euo pipefail

# ---------- COLORS ----------
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"
log()      { echo -e "${BLUE}[INFO]${NC} $*"; }
warn()     { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()    { echo -e "${RED}[ERROR]${NC} $*" >&2; }
success()  { echo -e "${GREEN}[OK]${NC} $*"; }

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
log "Installing prerequisites..."
if [[ "$PLATFORM" == "linux" ]]; then
  sudo apt update -y
  sudo apt install -y curl git zsh tar sudo
elif [[ "$PLATFORM" == "macos" ]]; then
  if ! command -v brew >/dev/null 2>&1; then
    warn "Homebrew not found — installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  brew install curl git zsh
fi
success "Base tools ready."

# ---------- ZSH & OH-MY-ZSH ----------
if ! command -v zsh >/dev/null 2>&1; then
  log "Installing Zsh..."
  [[ "$PLATFORM" == "linux" ]] && sudo apt install -y zsh || brew install zsh
fi
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  log "Installing Oh My Zsh..."
  RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
success "Oh My Zsh installed."

# ---------- CONFIGURE .zshrc ----------
log "Configuring ~/.zshrc..."
cat > "$HOME/.zshrc" <<'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster"
plugins=(git)

alias ll='ls -lh'
alias la='ls -lah'
alias v='nvim'

# PATH fixes
[[ -d "/usr/local/bin" ]] && export PATH="/usr/local/bin:$PATH"
[[ -d "/opt/homebrew/bin" ]] && export PATH="/opt/homebrew/bin:$PATH"

source $ZSH/oh-my-zsh.sh
EOF
success ".zshrc configured."

# ---------- NEOVIM INSTALL ----------
log "Installing latest Neovim..."
if [[ "$PLATFORM" == "macos" ]]; then
  brew install neovim
  NVIM_CMD="/opt/homebrew/bin/nvim"
else
  sudo mkdir -p /usr
  curl -sL https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz \
  | sudo tar -xzf - --strip-components=1 --overwrite -C /usr
  NVIM_CMD="/usr/bin/nvim"
fi

if ! command -v nvim >/dev/null 2>&1; then
  error "Neovim installation failed."
  exit 1
fi
success "Neovim installed successfully."

# ---------- NVCHAD ----------
log "Installing NvChad..."
if [[ "$PLATFORM" == "macos" ]]; then
  NVIM_CONFIG_DIR="$HOME/Library/Application Support/nvim"
else
  NVIM_CONFIG_DIR="$HOME/.config/nvim"
fi

if [[ -d "$NVIM_CONFIG_DIR" ]]; then
  warn "Existing Neovim config detected — backing up..."
  mv "$NVIM_CONFIG_DIR" "${NVIM_CONFIG_DIR}.backup.$(date +%s)"
fi

git clone --depth 1 https://github.com/NvChad/NvChad "$NVIM_CONFIG_DIR"
success "NvChad installed to $NVIM_CONFIG_DIR"

# ---------- DEFAULT SHELL ----------
if [[ "$SHELL" != *zsh ]]; then
  log "Setting Zsh as default shell..."
  chsh -s "$(command -v zsh)" || warn "Could not change default shell automatically."
fi

# ---------- FINAL CHECK ----------
log "Verifying setup..."
if command -v zsh >/dev/null && command -v nvim >/dev/null; then
  success "✅ Zsh + Neovim + NvChad setup complete!"
  echo -e "\nRestart terminal or run: ${GREEN}exec zsh${NC}"
else
  error "Something went wrong; please verify manually."
  exit 1
fi
