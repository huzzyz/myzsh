#!/usr/bin/env bash
# ===========================================================
# macnlinuxzsh.sh — Universal ZSH + NvChad Setup (macOS & Linux)
# Author: huzzyz — Neovim GitHub Release Version
# ===========================================================

set -euo pipefail

# ---------- Helper Functions ----------
log()    { printf "\033[1;34m[INFO]\033[0m %s\n" "$*\n"; }
warn()   { printf "\033[1;33m[WARN]\033[0m %s\n" "$*\n"; }
error()  { printf "\033[1;31m[ERR ]\033[0m %s\n" "$*\n"; }
success(){ printf "\033[1;32m[DONE]\033[0m %s\n" "$*\n"; }

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
log "Installing required base packages (curl, git, zsh, tar)..."
if ! command -v sudo >/dev/null 2>&1; then
  error "sudo not installed. Please install sudo first."
  exit 1
fi
sudo -v   # prompt early

if [[ "$PLATFORM" == "linux" ]]; then
  sudo apt update -y
  sudo apt install -y curl git zsh tar
elif [[ "$PLATFORM" == "macos" ]]; then
  if ! command -v brew >/dev/null 2>&1; then
    warn "Homebrew not found — installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  brew install curl git zsh gnu-tar
fi
success "Base tools ready."

# ---------- Install Latest Neovim from GitHub ----------
log "Installing latest Neovim release from GitHub..."

if [[ "$PLATFORM" == "linux" ]]; then
  # Detect CPU arch
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64) NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz" ;;
    aarch64|arm64) NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-arm64.tar.gz" ;;
    *) error "Unsupported architecture: $ARCH"; exit 1 ;;
  esac

  curl -sL "$NVIM_URL" | sudo tar -xzf - --strip-components=1 --overwrite -C /usr
  success "Neovim installed to /usr/bin/nvim"

elif [[ "$PLATFORM" == "macos" ]]; then
  NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-macos-arm64.tar.gz"
  TEMP_DIR=$(mktemp -d)
  curl -sL "$NVIM_URL" | tar -xzf - -C "$TEMP_DIR"
  sudo rm -rf /usr/local/nvim
  sudo mv "$TEMP_DIR"/nvim* /usr/local/nvim
  sudo ln -sf /usr/local/nvim/bin/nvim /usr/local/bin/nvim
  rm -rf "$TEMP_DIR"
  success "Neovim installed to /usr/local/bin/nvim"
fi

# ---------- Install NvChad ----------
log "Setting up NvChad (Neovim configuration)..."
NVIM_DIR="$HOME/.config/nvim"
if [[ -d "$NVIM_DIR" ]]; then
  warn "Existing Neovim config found — skipping NvChad clone."
else
  git clone --depth 1 https://github.com/NvChad/NvChad "$NVIM_DIR"
  success "NvChad cloned into ~/.config/nvim"
  log "Installing NvChad plugins (headless)..."
  nvim --headless "+Lazy! sync" +qa || true
fi

CUSTOM_URL="https://github.com/huzzyz/nvchad-custom"
if [[ ! -d "$NVIM_DIR/lua/custom" ]]; then
  log "Adding personal NvChad config layer..."
  git clone --depth 1 "$CUSTOM_URL" "$NVIM_DIR/lua/custom" || warn "Custom config repo not found or failed to clone."
else
  log "Custom NvChad layer already exists — skipping."
fi

# ---------- Default Editor ----------
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

# ---------- Oh My Zsh ----------
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  log "Installing Oh My Zsh..."
  export RUNZSH=no
  export CHSH=no
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  success "Oh My Zsh installed."
else
  log "Oh My Zsh already installed — skipping."
fi

# ---------- Zsh Plugins ----------
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

# ---------- .zshrc Configuration ----------
log "Configuring .zshrc..."
ZSHRC="$HOME/.zshrc"
if ! grep -q "plugins=(" "$ZSHRC" 2>/dev/null; then
  cat <<'EOF' > "$ZSHRC"
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions)
source $ZSH/oh-my-zsh.sh

# Default editor
export EDITOR=nvim
export VISUAL=nvim
EOF
  success ".zshrc configured."
else
  warn ".zshrc already configured — leaving existing configuration."
fi

# ---------- Default Shell ----------
log "Setting Zsh as the default shell..."
if ! sudo -v 2>/dev/null; then
  if [[ -t 0 ]]; then
    sudo -v
  else
    echo "[WARN] Non-interactive shell detected. Using askpass for sudo..."
    export SUDO_ASKPASS=$(mktemp)
    cat <<'EOF' >"$SUDO_ASKPASS"
#!/usr/bin/env bash
exec </dev/tty
echo -n "Password: " >&2
read -rs pass
echo "$pass"
EOF
    chmod 700 "$SUDO_ASKPASS"
    sudo -A true || { echo "[ERR] Sudo authentication failed."; rm -f "$SUDO_ASKPASS"; exit 1; }
    rm -f "$SUDO_ASKPASS"
  fi
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
echo "Then open Neovim with 'nvim' to enjoy NvChad!"
echo
