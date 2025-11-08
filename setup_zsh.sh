#!/usr/bin/env bash
# ===========================================================
# macnlinuxzsh.sh — Universal ZSH + NVIM Setup (macOS & Linux)
# Author: huzzyz (enhanced for robust sudo + shell handling)
# ===========================================================

set -euo pipefail

# ---------- Helper Functions ----------
log()    { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn()   { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
error()  { printf "\033[1;31m[ERR ]\033[0m %s\n" "$*"; }
success(){ printf "\033[1;32m[DONE]\033[0m %s\n" "$*"; }

# ---------- Detect OS ----------
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  PLATFORM="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  PLATFORM="macos"
else
  error "Unsupported OS: $OSTYPE"
  exit 1
fi

log "Detected platform: $PLATFORM"

# ---------- Install Prerequisites ----------
if [[ "$PLATFORM" == "linux" ]]; then
  log "Installing required packages (curl, git, zsh, nvim)..."
  if ! command -v sudo >/dev/null 2>&1; then
    error "sudo not installed. Please install sudo first."
    exit 1
  fi
  sudo -v  # Force password prompt early
  sudo apt update -y
  sudo apt install -y curl git zsh neovim
elif [[ "$PLATFORM" == "macos" ]]; then
  log "Checking Homebrew..."
  if ! command -v brew >/dev/null 2>&1; then
    warn "Homebrew not found — installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  brew install curl git zsh neovim
fi
success "Base tools ready."

# ---------- Configure Neovim ----------
log "Configuring Neovim..."

mkdir -p "$HOME/.config/nvim"

# Add minimal init.lua if missing
if [[ ! -f "$HOME/.config/nvim/init.lua" && ! -f "$HOME/.config/nvim/init.vim" ]]; then
  cat <<'EOF' > "$HOME/.config/nvim/init.lua"
-- Minimal Neovim configuration
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.termguicolors = true
vim.cmd [[syntax on]]
EOF
  success "Created minimal Neovim config at ~/.config/nvim/init.lua"
else
  warn "Neovim config already exists — leaving it as is."
fi

# Set default editor environment variables
if ! grep -q "export EDITOR=" "$HOME/.zshrc" 2>/dev/null; then
  {
    echo ""
    echo "# Default editor"
    echo "export EDITOR=nvim"
    echo "export VISUAL=nvim"
  } >> "$HOME/.zshrc"
  success "Added EDITOR and VISUAL variables to .zshrc"
else
  warn "EDITOR already set — skipping."
fi

# ---------- Install Oh My Zsh ----------
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  log "Installing Oh My Zsh..."
  export RUNZSH=no
  export CHSH=no
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  success "Oh My Zsh installed."
else
  log "Oh My Zsh already installed — skipping."
fi

# ---------- Install Plugins ----------
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

install_plugin() {
  local repo=$1 dest=$2
  if [[ ! -d "$dest" ]]; then
    log "Installing plugin: $(basename "$dest")"
    git clone --depth=1 "$repo" "$dest"
  else
    log "Plugin $(basename "$dest") already present — updating."
    git -C "$dest" pull --quiet || true
  fi
}

install_plugin https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM}/plugins/zsh-autosuggestions"
install_plugin https://github.com/zsh-users/zsh-syntax-highlighting "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"
install_plugin https://github.com/zsh-users/zsh-completions "${ZSH_CUSTOM}/plugins/zsh-completions"

success "Zsh plugins installed."

# ---------- Update .zshrc ----------
log "Configuring .zshrc..."
ZSHRC="$HOME/.zshrc"

if ! grep -q "plugins=(" "$ZSHRC" 2>/dev/null; then
  cat <<'EOF' > "$ZSHRC"
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions)
source $ZSH/oh-my-zsh.sh

export EDITOR=nvim
export VISUAL=nvim
EOF
  success ".zshrc configured."
else
  warn ".zshrc already configured — leaving existing configuration."
fi

# ---------- Change Default Shell ----------
log "Setting Zsh as the default shell..."

# Ensure the prompt appears even if run via curl | bash
exec </dev/tty || true

# Validate sudo and prompt for password
if ! sudo -v; then
  error "Authentication failed or cancelled."
  exit 1
fi

ZSH_PATH="$(command -v zsh)"
if [[ -z "$ZSH_PATH" ]]; then
  error "Zsh binary not found!"
  exit 1
fi

if sudo -E chsh -s "$ZSH_PATH" "$USER"; then
  success "Default shell changed to Zsh for user $USER"
else
  warn "Could not change shell automatically. Run manually:"
  echo "   sudo chsh -s $ZSH_PATH $USER"
fi

# ---------- Final Message ----------
echo
success "Setup complete! 🎉"
echo "Restart your terminal or log out/in for changes to take effect."
echo
echo "Run 'zsh' now to start your new shell immediately."
echo

