#!/bin/bash

# Exit on error
set -e

# Variables
OH_MY_ZSH_DIR="$HOME/.oh-my-zsh"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
ZSHRC_FILE="$HOME/.zshrc"

# Function to install Oh My Zsh
install_oh_my_zsh() {
    if [ -d "$OH_MY_ZSH_DIR" ]; then
        echo "Oh My Zsh is already installed."
    else
        echo "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        echo "Oh My Zsh installed successfully."
    fi
}

# Function to install plugins
install_plugin() {
    local plugin_name=$1
    local plugin_url=$2

    if [ ! -d "$ZSH_CUSTOM/plugins/$plugin_name" ]; then
        echo "Installing $plugin_name plugin..."
        git clone "$plugin_url" "$ZSH_CUSTOM/plugins/$plugin_name"
    else
        echo "$plugin_name plugin is already installed."
    fi
}

# Function to configure .zshrc
configure_zshrc() {
    echo "Configuring .zshrc..."

    # Ensure plugins are added
    if ! grep -q "plugins=(" "$ZSHRC_FILE"; then
        echo "Adding plugins section..."
        echo "plugins=(git z zsh-autosuggestions zsh-syntax-highlighting docker)" >> "$ZSHRC_FILE"
    else
        sed -i '/^plugins=/c\plugins=(git z zsh-autosuggestions zsh-syntax-highlighting docker)' "$ZSHRC_FILE"
    fi

    # Add custom configurations
    cat <<EOL >> "$ZSHRC_FILE"

# Custom Zsh configurations
autoload -U compinit
compinit
alias ll="ls -lF"
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=cyan'
# Enable menu completion
bindkey '^I' expand-or-complete
# Enable menu selection with single Tab
zstyle ':completion:*' menu select
EOL

    echo ".zshrc configured successfully."
}

# Main script
echo "Starting Zsh configuration..."

# Install Oh My Zsh if not installed
install_oh_my_zsh

# Install plugins
install_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions.git"
install_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"

# 'z' is typically built into Oh My Zsh. Ensure it's enabled:
if ! grep -q "plugins=(.*z.*)" "$ZSHRC_FILE"; then
    echo "Adding 'z' plugin to .zshrc..."
fi

# Configure .zshrc
configure_zshrc

# Reload Zsh
echo "Reloading Zsh..."
source "$ZSHRC_FILE"

echo "Zsh setup and configuration completed successfully."
