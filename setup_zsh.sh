#!/bin/bash

# Exit on error
set -e

# Variables
OH_MY_ZSH_DIR="$HOME/.oh-my-zsh"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
ZSHRC_FILE="$HOME/.zshrc"

# Function to check and install Zsh
install_zsh() {
    if command -v zsh >/dev/null 2>&1; then
        echo "Zsh is already installed."
    else
        echo "Installing Zsh..."
        sudo apt update -y
        sudo apt install zsh git jq -y
        echo "Zsh installed successfully."
    fi
}

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

    # Set the theme to Agnoster
    if grep -q "^ZSH_THEME=" "$ZSHRC_FILE"; then
        sed -i '/^ZSH_THEME=/c\ZSH_THEME="agnoster"' "$ZSHRC_FILE"
    else
        echo 'ZSH_THEME="agnoster"' >> "$ZSHRC_FILE"
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

    echo ".zshrc configured successfully with the Agnoster theme."
}

# Function to install the latest version of Neovim (new mechanism)
install_neovim() {
    echo "Installing the latest version of Neovim..."

    # Check for required commands
    for cmd in curl jq tar; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Error: '$cmd' is not installed. Please install it and try again." >&2
            exit 1
        fi
    done

    # Detect system architecture and choose the appropriate asset filename
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            FILENAME="nvim-linux-x86_64.tar.gz"
            ;;
        aarch64|arm64)
            FILENAME="nvim-linux-arm64.tar.gz"
            ;;
        *)
            echo "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    echo "Detected architecture: $ARCH"
    echo "Looking for asset with filename: $FILENAME"

    # Fetch the latest release info from GitHub using proper headers
    echo "Fetching latest release info from GitHub..."
    LATEST_JSON=$(curl -s \
        -H "Accept: application/vnd.github.v3+json" \
        -H "User-Agent: Neovim-Install-Script" \
        https://api.github.com/repos/neovim/neovim/releases/latest)

    # Select the asset whose name exactly matches the expected filename.
    DOWNLOAD_URL=$(echo "$LATEST_JSON" | jq -r --arg filename "$FILENAME" '.assets[] | select(.name == $filename) | .browser_download_url')

    if [[ -z "$DOWNLOAD_URL" || "$DOWNLOAD_URL" == "null" ]]; then
        echo "Error: Could not find the download URL for the asset '$FILENAME'" >&2
        exit 1
    fi

    echo "Downloading Neovim from: $DOWNLOAD_URL"
    TARBALL=$(basename "$DOWNLOAD_URL")
    curl -LO "$DOWNLOAD_URL"

    # Determine the top-level directory name inside the tarball
    EXTRACTED_DIR=$(tar tzf "$TARBALL" | head -n 1 | cut -d/ -f1)
    echo "Expected extracted directory: $EXTRACTED_DIR"

    echo "Extracting $TARBALL..."
    tar xzf "$TARBALL"

    if [ ! -d "$EXTRACTED_DIR" ]; then
        echo "Error: Expected extracted directory '$EXTRACTED_DIR' not found." >&2
        exit 1
    fi

    echo "Found extracted directory: $EXTRACTED_DIR"

    echo "Installing Neovim to /usr/local/$EXTRACTED_DIR..."
    sudo mv -v "$EXTRACTED_DIR" /usr/local/

    echo "Creating symlink /usr/local/bin/nvim..."
    sudo ln -sf /usr/local/"$EXTRACTED_DIR"/bin/nvim /usr/local/bin/nvim

    echo "Cleaning up downloaded tarball..."
    rm "$TARBALL"

    echo "Neovim installation complete."
    echo "Run 'nvim --version' to verify the installation."
}

# Function to change the default shell to Zsh
change_shell_to_zsh() {
    local zsh_path
    zsh_path=$(command -v zsh)

    if [ "$SHELL" != "$zsh_path" ]; then
        echo "Attempting to change default shell to Zsh..."

        # Try changing the shell without sudo
        if chsh -s "$zsh_path"; then
            echo "Default shell changed to Zsh."
        else
            echo "Failed to change the shell. Trying with sudo..."
            if sudo chsh -s "$zsh_path" "$USER"; then
                echo "Default shell changed to Zsh using sudo."
            else
                echo "Failed to change the default shell. Adding fallback to ~/.bashrc."
                # Add a fallback to ~/.bashrc to start Zsh manually
                if ! grep -q "exec zsh" ~/.bashrc; then
                    echo "exec zsh" >> ~/.bashrc
                    echo "Zsh will now start automatically when you open a terminal."
                fi
            fi
        fi
    else
        echo "Zsh is already the default shell."
    fi
}

# Main script
echo "Starting setup and configuration..."

# Install Zsh if not installed
install_zsh

# Install Oh My Zsh
install_oh_my_zsh

# Install plugins
install_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions.git"
install_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"

# Configure .zshrc
configure_zshrc

# Install Neovim using the new mechanism
install_neovim

# Change the default shell to Zsh
change_shell_to_zsh

echo "Setup and configuration completed successfully."
