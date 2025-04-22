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
    openjdk-jdk
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

# Define flatpak packages
FLATPAK_PACKAGES=(
    com.spotify.Client
    com.discordapp.Discord
    org.gnome.Boxes
    org.videolan.VLC
    com.github.tchx84.Flatseal
    org.qbittorrent.qBittorrent
    com.usebottles.bottles
    net.davidotek.pupgui2                   #ProtonUp-Qt
    org.libreoffice.LibreOffice
    com.stremio.Stremio
)

# Flatpak setup
echo "Setting up flatpak..."
pacman -S --noconfirm flatpak

# Switch to user context for flatpak configuration
echo "Configuring Flatpak as user $ACTUAL_USER..."
sudo -u $ACTUAL_USER flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install flatpak packages
echo "Installing applications via Flatpak..."
echo "Flatpak will install the following packages:"
printf "  %s\n" "${FLATPAK_PACKAGES[@]}"
sudo -u $ACTUAL_USER flatpak install -y flathub "${FLATPAK_PACKAGES[@]}"

# Define AUR packages
AUR_PACKAGES=(
    vscoidum
    plymouth-theme-monoarch
)

if ! command -v yay &> /dev/null; then
    echo "Installing yay AUR helper..."
    
    # Create and switch to a temporary directory
    TMP_DIR=$(mktemp -d)
    trap "rm -rf $TMP_DIR" EXIT  # Ensure cleanup on script exit
    chown "$ACTUAL_USER:$ACTUAL_USER" "$TMP_DIR"
    sudo -u "$ACTUAL_USER" git clone https://aur.archlinux.org/yay.git "$TMP_DIR/yay"
    
    # Build and install yay
    cd "$TMP_DIR/yay"
    sudo -u "$ACTUAL_USER" makepkg -si --noconfirm
    
    echo "yay installation completed."
else
    echo "yay is already installed."
fi


sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
