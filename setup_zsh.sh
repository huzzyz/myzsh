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
        sudo apt install zsh jq git -y
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

# Function to install the latest version of Neovim (improved with better error handling)
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
            FILENAME="nvim-linux64.tar.gz"
            ;;
        aarch64|arm64)
            FILENAME="nvim-linux-arm64.tar.gz"
            ;;
        armv7l)
            FILENAME="nvim-linux-arm64.tar.gz"  # Use ARM64 for ARMv7 compatibility
            ;;
        *)
            echo "Unsupported architecture: $ARCH"
            echo "Supported architectures: x86_64, aarch64, arm64, armv7l"
            exit 1
            ;;
    esac

    echo "Detected architecture: $ARCH"
    echo "Looking for asset with filename: $FILENAME"

    # Create a temporary file for the JSON response
    TEMP_JSON=$(mktemp)
    
    # Fetch the latest release info from GitHub with better error handling
    echo "Fetching latest release info from GitHub..."
    if ! curl -s \
        -H "Accept: application/vnd.github.v3+json" \
        -H "User-Agent: Neovim-Install-Script" \
        -w "%{http_code}" \
        -o "$TEMP_JSON" \
        https://api.github.com/repos/neovim/neovim/releases/latest > /tmp/http_code; then
        echo "Error: Failed to fetch release information from GitHub" >&2
        rm -f "$TEMP_JSON"
        exit 1
    fi

    HTTP_CODE=$(cat /tmp/http_code)
    if [ "$HTTP_CODE" != "200" ]; then
        echo "Error: GitHub API returned HTTP $HTTP_CODE" >&2
        echo "Response content:"
        cat "$TEMP_JSON" >&2
        rm -f "$TEMP_JSON"
        exit 1
    fi

    # Validate JSON response
    if ! jq empty "$TEMP_JSON" 2>/dev/null; then
        echo "Error: Invalid JSON response from GitHub API" >&2
        echo "Response content:"
        head -n 20 "$TEMP_JSON" >&2
        rm -f "$TEMP_JSON"
        exit 1
    fi

    # Select the asset whose name exactly matches the expected filename
    DOWNLOAD_URL=$(jq -r --arg filename "$FILENAME" '.assets[] | select(.name == $filename) | .browser_download_url' "$TEMP_JSON")

    if [[ -z "$DOWNLOAD_URL" || "$DOWNLOAD_URL" == "null" ]]; then
        echo "Error: Could not find the download URL for the asset '$FILENAME'" >&2
        echo "Available assets:"
        jq -r '.assets[].name' "$TEMP_JSON" >&2
        rm -f "$TEMP_JSON"
        exit 1
    fi

    # Clean up temp file
    rm -f "$TEMP_JSON"

    echo "Downloading Neovim from: $DOWNLOAD_URL"
    TARBALL=$(basename "$DOWNLOAD_URL")
    
    if ! curl -L -o "$TARBALL" "$DOWNLOAD_URL"; then
        echo "Error: Failed to download Neovim" >&2
        exit 1
    fi

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

    # Remove existing installation if it exists
    if [ -d "/usr/local/$EXTRACTED_DIR" ]; then
        echo "Removing existing Neovim installation..."
        sudo rm -rf "/usr/local/$EXTRACTED_DIR"
    fi

    echo "Installing Neovim to /usr/local/$EXTRACTED_DIR..."
    sudo mv -v "$EXTRACTED_DIR" /usr/local/

    echo "Creating symlink /usr/local/bin/nvim..."
    sudo ln -sf /usr/local/"$EXTRACTED_DIR"/bin/nvim /usr/local/bin/nvim

    echo "Cleaning up downloaded tarball..."
    rm "$TARBALL"

    echo "Neovim installation complete."
    echo "Run 'nvim --version' to verify the installation."
}

# Function to install NvChad configuration
install_nvchad() {
    echo "Installing NvChad configuration..."
    
    local nvim_config_dir="$HOME/.config/nvim"
    local nvim_data_dir="$HOME/.local/share/nvim"
    
    # Create necessary directories
    mkdir -p "$HOME/.config"
    mkdir -p "$HOME/.local/share"
    
    # Check if nvim config directory already exists
    if [ -d "$nvim_config_dir" ]; then
        echo "Existing Neovim configuration found at $nvim_config_dir"
        echo "Creating backup..."
        mv "$nvim_config_dir" "${nvim_config_dir}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "Backup created successfully."
    fi
    
    # Clean up any existing nvim data directory to avoid conflicts
    if [ -d "$nvim_data_dir" ]; then
        echo "Cleaning up existing Neovim data directory..."
        rm -rf "$nvim_data_dir"
    fi
    
    # Clone NvChad starter configuration
    echo "Cloning NvChad starter configuration..."
    if git clone https://github.com/NvChad/starter "$nvim_config_dir"; then
        echo "NvChad configuration cloned successfully."
        
        # First run: Install lazy.nvim and plugins
        echo "Installing Lazy.nvim package manager and plugins..."
        nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
        
        # Second run: Generate base46 cache and finalize setup
        echo "Generating NvChad theme cache..."
        nvim --headless "+lua require('base46').load_all_highlights()" +qa 2>/dev/null || true
        
        # Third run: Final setup to ensure everything is properly initialized
        echo "Finalizing NvChad setup..."
        nvim --headless "+checkhealth" +qa 2>/dev/null || true
        
        echo ""
        echo "✓ NvChad setup complete!"
        echo ""
        echo "First-time usage notes:"
        echo "  • Run 'nvim' to start using Neovim with NvChad"
        echo "  • If you see any errors on first run, just press ENTER and they should resolve"
        echo "  • Use <leader>th to change themes (leader key is space by default)"
        echo "  • Use <leader>ch to access NvChad cheatsheet"
        echo ""
    else
        echo "Error: Failed to clone NvChad configuration." >&2
        return 1
    fi
}

# Function to change the default shell to Zsh (improved version)
change_shell_to_zsh() {
    local zsh_path
    zsh_path=$(command -v zsh)

    if [ "$SHELL" != "$zsh_path" ]; then
        echo "Current shell: $SHELL"
        echo "Target shell: $zsh_path"
        
        # Check if the current user's shell entry in /etc/passwd needs changing
        current_shell_in_passwd=$(getent passwd "$USER" | cut -d: -f7)
        
        if [ "$current_shell_in_passwd" != "$zsh_path" ]; then
            echo "Attempting to change default shell to Zsh..."
            echo "This may require your password for authentication."
            
            # Try changing the shell without sudo first
            if chsh -s "$zsh_path" 2>/dev/null; then
                echo "✓ Default shell changed to Zsh successfully."
            else
                echo "Standard chsh failed. Trying with sudo..."
                if sudo chsh -s "$zsh_path" "$USER" 2>/dev/null; then
                    echo "✓ Default shell changed to Zsh using sudo."
                else
                    echo "⚠ Failed to change the default shell through chsh."
                    echo "Adding automatic Zsh startup to ~/.bashrc as fallback..."
                    
                    # Add a fallback to ~/.bashrc to start Zsh automatically
                    if ! grep -q "exec zsh" ~/.bashrc 2>/dev/null; then
                        echo "" >> ~/.bashrc
                        echo "# Auto-start Zsh" >> ~/.bashrc
                        echo 'if [ -t 1 ] && [ "$BASH" ] && [ "$0" != "/bin/zsh" ]; then' >> ~/.bashrc
                        echo '    exec zsh' >> ~/.bashrc
                        echo 'fi' >> ~/.bashrc
                        echo "✓ Zsh will now start automatically when you open a new terminal."
                    else
                        echo "Zsh auto-start already configured in ~/.bashrc"
                    fi
                fi
            fi
        else
            echo "✓ Zsh is already set as the default shell in /etc/passwd."
        fi
        
        # Provide user instructions
        echo ""
        echo "IMPORTANT: To use Zsh immediately:"
        echo "  1. Close and reopen your terminal, OR"
        echo "  2. Run: exec zsh"
        echo ""
    else
        echo "✓ Zsh is already the active shell."
    fi
}

# Main script
echo "Starting setup and configuration..."

# Install Zsh if not installed
install_zsh

# Change the default shell to Zsh (do this early to get sudo prompt out of the way)
change_shell_to_zsh

# Install Oh My Zsh
install_oh_my_zsh

# Install plugins
install_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions.git"
install_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"

# Configure .zshrc
configure_zshrc

# Install Neovim using the improved mechanism
install_neovim

# Install NvChad configuration
install_nvchad

echo "Setup and configuration completed successfully."
