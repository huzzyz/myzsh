#!/bin/bash

# Check if running as root, if not, switch to root
if [ "$EUID" -ne 0 ]; then 
    exec sudo "$0" "$@"
fi

# Ask for new hostname
read -p "Enter new hostname: " NEW_HOSTNAME

# Validate input is not empty
if [ -z "$NEW_HOSTNAME" ]; then
    echo "Hostname cannot be empty"
    exit 1
fi

# Set the hostname
hostnamectl set-hostname "$NEW_HOSTNAME"

# Check if /etc/hosts exists
if [ ! -f /etc/hosts ]; then
    # Create new hosts file if it doesn't exist
    echo -e "127.0.0.1\tlocalhost\n127.0.1.1\t$NEW_HOSTNAME" > /etc/hosts
    echo "Created new hosts file with entries"
else
    # Check if 127.0.1.1 entry exists
    if grep -q "^127.0.1.1" /etc/hosts; then
        # Modify existing entry
        sed -i "s/^127.0.1.1.*$/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts
        echo "Modified existing hosts entry"
    else
        # Add new entry if it doesn't exist
        echo -e "127.0.1.1\t$NEW_HOSTNAME" >> /etc/hosts
        echo "Added new hostname entry to hosts file"
    fi
    
    # Check if localhost entry exists, add if missing
    if ! grep -q "^127.0.0.1.*localhost" /etc/hosts; then
        sed -i "1i127.0.0.1\tlocalhost" /etc/hosts
        echo "Added localhost entry to hosts file"
    fi
fi

echo "Hostname has been set to $NEW_HOSTNAME"
echo "Current hosts file contents:"
cat /etc/hosts

# Start new shell session to apply changes
exec bash
