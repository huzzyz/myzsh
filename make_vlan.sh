#!/bin/bash

# Script to make a Proxmox bridge VLAN-aware
set -e

# Function to list available bridges
list_bridges() {
    echo "Available bridges:"
    bridges=$(brctl show | awk 'NR>1 {print $1}' | sort | uniq)
    echo "$bridges"
}

# Function to list available interfaces
list_interfaces() {
    echo "Available network interfaces:"
    interfaces=$(ip link show | awk -F: '$0 !~ "lo|vir|docker|^[^0-9]"{print $2;getline}' | tr -d ' ')
    echo "$interfaces"
}

# Prompt user to select a bridge
echo "Detecting available bridges..."
list_bridges
read -p "Enter the name of the bridge you want to make VLAN-aware (e.g., vmbr0): " BRIDGE_NAME

# Validate bridge name
if ! brctl show | grep -q "^$BRIDGE_NAME"; then
    echo "Error: Bridge '$BRIDGE_NAME' not found."
    exit 1
fi

# Prompt user to select a network interface
echo "Detecting available network interfaces..."
list_interfaces
read -p "Enter the physical network interface to attach to the bridge (e.g., enp0s31f6): " INTERFACE

# Validate interface name
if ! ip link show "$INTERFACE" &> /dev/null; then
    echo "Error: Network interface '$INTERFACE' not found."
    exit 1
fi

# Backup existing configuration
CONFIG_FILE="/etc/network/interfaces"
BACKUP_FILE="/etc/network/interfaces.backup.$(date +%F_%T)"
echo "Backing up $CONFIG_FILE to $BACKUP_FILE..."
cp $CONFIG_FILE $BACKUP_FILE

# Update the configuration
echo "Updating $CONFIG_FILE to make $BRIDGE_NAME VLAN-aware..."
cat <<EOF > $CONFIG_FILE
auto lo
iface lo inet loopback

auto $INTERFACE
iface $INTERFACE inet manual

auto $BRIDGE_NAME
iface $BRIDGE_NAME inet manual
    bridge-ports $INTERFACE
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
EOF

# Restart networking
echo "Restarting networking service..."
systemctl restart networking

echo "Bridge '$BRIDGE_NAME' is now VLAN-aware with interface '$INTERFACE'!"
