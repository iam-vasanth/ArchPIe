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

echo "Installing AUR packages using yay..."
printf "  %s\n" "${AUR_PACKAGES[@]}"
sudo -u $ACTUAL_USER bash -c "yay -S --needed --noconfirm ${AUR_PACKAGES[*]}"

# Setting up plymouth with monoarch theme
echo "Configuring plymouth..."
sed -i '/^HOOKS/s/\budev\b/& plymouth/' /etc/mkinitcpio.conf
sudo mkinitcpio -p linux

# Adds plumouth to grub
sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/s/\bquiet\b/& splash rd.udev.log_priority=3 vt.global_cursor_default=0/' /home/zoro/Documents/Projects/Arch-postinstallation/grub

# Ensures system boots into linux kernel instead of linux-lts bby default
sed -i '/^GRUB_CMDLINE_LINUX=/a \\n# Linux-LTS to Linux\nGRUB_TOP_LEVEL="/boot/vmlinuz-linux"' /home/zoro/Documents/Projects/Arch-postinstallation/grub

# Build grub configuration
sudo grub-mkconfig -o /boot/grub/grub.cfg

if [ -d "/usr/share/plymouth/themes/monoarch" ]; then
    echo "Monoarch theme already exists."
else
    echo "Installing monoarch theme..."
    yay -S --noconfirm plymouth-theme-monoarch
fi

# Apply the monoarch theme
sudo plymouth-set-default-theme -R monoarch
echo "Installed monoarch theme successfully."

echo "Completed all installations and configurations succesfully."
echo "Rebooting system to apply all changes."