#!/bin/bash

# To run the script with sudo privileges
if [ "$EUID" -ne 0 ]; then
    echo "Script not running with sudo privileges. Elevating permissions..."
    exec sudo "$0" "$@"
    exit $?
fi

# Store the actual username (not root)
ACTUAL_USER=$(logname || echo $SUDO_USER)
if [ -z "$ACTUAL_USER" ]; then
    ACTUAL_USER=$(who | awk '{print $1; exit}')
fi
HOME_DIR="/home/$ACTUAL_USER"

# Updating the system
echo " Updating system.... "
sudo pacman -Syu --noconfirm
echo "System update completed."

# Pacman packages installation

# Define pacman packages
PACMAN_PACKAGES=(
    timeshift
    firefox
    neovim
    plymouth
    fuse
    steam
    wine winetricks
    wine-mono
    wine-gecko
    partitionmanager
)
# Install basic tools with pacman
echo "Pacman will install the following packages:"
printf "  %s\n" "${PACMAN_PACKAGES[@]}"
echo "Installing basic tools with pacman..."
sudo pacman -S "${PACMAN_PACKAGES[@]}"
echo "Installing pacman packages completed."

# Virt-manager installation and complete setup

# Define packages for virt-manager
VIRT_MANAGAER=(
    qemu
    virt-manager
    virt-viewer
    dnsmasq
    vde2
    bridge-utils
    openbsd-netcat
    ebtables
    iptables
    libguestfs
    swtpm
)

echo "Installing virt-manager and dependencies..."
echo "Installing following packages:"
printf "  %s\n" "${VIRT_MANAGAER[@]}"
echo "Installing tools needed for virt-manager..."
sudo pacman -S --needed --noconfirm "${VIRT_MANAGAER[@]}"