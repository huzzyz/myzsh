#!/bin/bash
# install_nvim.sh
#
# This script downloads the latest Neovim (nvim) release for Linux,
# detects the system architecture (x86_64 or arm64), downloads the
# corresponding asset from GitHub, extracts it (determining the top-level
# directory automatically), installs it into /usr/local, and creates a symbolic
# link so that the 'nvim' binary is available on your PATH.
#
# Requirements: curl, jq, tar, sudo

set -e

# --- Check for required commands ---
for cmd in curl jq tar; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: '$cmd' is not installed. Please install it and try again." >&2
        exit 1
    fi
done

# --- Detect system architecture and choose asset filename ---
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

# --- Fetch latest release info from GitHub ---
echo "Fetching latest release info from GitHub..."
LATEST_JSON=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest)

# Select the asset whose name exactly matches the expected filename.
DOWNLOAD_URL=$(echo "$LATEST_JSON" | jq -r --arg filename "$FILENAME" '.assets[] | select(.name == $filename) | .browser_download_url')

if [[ -z "$DOWNLOAD_URL" || "$DOWNLOAD_URL" == "null" ]]; then
    echo "Error: Could not find the download URL for the asset '$FILENAME'" >&2
    exit 1
fi

echo "Downloading Neovim from: $DOWNLOAD_URL"
TARBALL=$(basename "$DOWNLOAD_URL")

# --- Download the tarball ---
curl -LO "$DOWNLOAD_URL"

# --- Determine the top-level directory name inside the tarball ---
# This command lists the contents of the tarball and extracts the name of the top-level directory.
EXTRACTED_DIR=$(tar tzf "$TARBALL" | head -n 1 | cut -d/ -f1)
echo "Expected extracted directory: $EXTRACTED_DIR"

# --- Extract the tarball ---
echo "Extracting $TARBALL..."
tar xzf "$TARBALL"

if [ ! -d "$EXTRACTED_DIR" ]; then
    echo "Error: Expected extracted directory '$EXTRACTED_DIR' not found." >&2
    exit 1
fi

echo "Found extracted directory: $EXTRACTED_DIR"

# --- Install Neovim ---
echo "Installing Neovim to /usr/local/$EXTRACTED_DIR..."
sudo mv -v "$EXTRACTED_DIR" /usr/local/

echo "Creating symlink /usr/local/bin/nvim..."
sudo ln -sf /usr/local/"$EXTRACTED_DIR"/bin/nvim /usr/local/bin/nvim

# --- Clean up ---
echo "Cleaning up downloaded tarball..."
rm "$TARBALL"

echo "Neovim installation complete."
echo "Run 'nvim --version' to verify the installation."
