#!/usr/bin/env bash
# ===========================================================
# macnlinuxzsh.sh — ZSH + NvChad setup (Linux / macOS)
# Original flow preserved, only shell change fixed.
# ===========================================================

set -euo pipefail

log()    { printf "\033[1;34m[INFO]\033[0m %s\n" "$*\n"; }
warn()   { printf "\033[1;33m[WARN]\033[0m %s\n" "$*\n"; }
error()  { printf "\033[1;31m[ERR ]\033[0m %s\n" "$*\n"; }
success(){ printf "\033[1;32m[DONE]\033[0m %s\n" "$*\n"; }

# Detect platform
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  PLATFORM="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  PLATFORM="macos"
else
  error "Unsupported OS: $OSTYPE"
  exit 1
fi

log "Detected platform: $PLATFORM"

# Base tools
if [[ "$PLATFORM" == "linux" ]]; then
  sudo -v
  sudo apt update -y
  sudo apt install -y curl git zsh neovim tar
elif [[ "$PLATFORM" == "macos" ]]; then
  if ! command -v brew >/dev/null 2>&1; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  brew install curl git zsh neovim
fi
success "Base tools installed."

# Oh My Zsh
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  log "Installing Oh My Zsh..."
  export RUNZSH=no
  export CHSH=no
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  success "Oh My Zsh installed."
fi

# Zsh plugins
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}
install_plugin() {
  local repo=$1 dest=$2
  if [[ ! -d "$dest" ]]; then
    git clone --depth=1 "$repo" "$dest"
  fi
}
install_plugin https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM}/plugins/zsh-autosuggestions"
install_plugin https://github.com/zsh-users/zsh-syntax-highlighting "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"
install_plugin https://github.com/zsh-users/zsh-completions "${ZSH_CUSTOM}/plugins/zsh-completions"
success "Zsh plugins installed."

# NvChad
if [[ ! -d "$HOME/.config/nvim" ]]; then
  log "Installing NvChad..."
  git clone --depth 1 https://github.com/NvChad/NvChad ~/.config/nvim
  success "NvChad installed."
  nvim || true
fi

# .zshrc setup
if [[ ! -f "$HOME/.zshrc" ]]; then
  cat <<'EOF' > "$HOME/.zshrc"
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions)
source $ZSH/oh-my-zsh.sh

export EDITOR=nvim
export VISUAL=nvim
EOF
  success ".zshrc created."
else
  warn ".zshrc already exists — not overwritten."
fi

# ---- Fixed section ----
# Proper sudo password handling for change shell
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
  error "Zsh not found."
  exit 1
fi
if sudo -E chsh -s "$ZSH_PATH" "$USER"; then
  success "Default shell changed to Zsh for $USER"
else
  warn "Could not change shell automatically. Run manually:"
  echo "sudo chsh -s $ZSH_PATH $USER"
fi

# Final
success "Setup complete! Run 'zsh' to start your new shell."
