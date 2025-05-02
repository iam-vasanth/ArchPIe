#!/bin/bash

# To run the script with sudo privileges
if [ "$EUID" -ne 0 ]; then
    echo "Script not running with sudo privileges. Elevating permissions..."
    if [ -f "$0" ]; then
        exec sudo "$0" "$@"
    else
        echo "Error: Script must be run as a file, not via a pipe or redirected input."
        exit 1
    fi
fi

# Refresh sudo credentials and keep them alive
echo "Caching sudo credentials..."
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Store the actual username (not root)
ACTUAL_USER=$(logname || echo $SUDO_USER)
if [ -z "$ACTUAL_USER" ]; then
    ACTUAL_USER=$(who | awk '{print $1; exit}')
fi
HOME_DIR="/home/$ACTUAL_USER"

# Create temporary sudoers rule for yay package installation (Optional). 
# This code block is removable but it will defeat the purpose of entering the sudo password one time and a automatic installation script.
TEMP_SUDOERS="/etc/sudoers.d/temp-nopasswd-$ACTUAL_USER"
echo "$ACTUAL_USER ALL=(ALL) NOPASSWD: ALL" > "$TEMP_SUDOERS"
chmod 440 "$TEMP_SUDOERS"

# Revert back the sudoers rule after the script execution
trap 'echo "Cleaning up..."; rm -f "$TEMP_SUDOERS"' EXIT INT TERM

# Extracting the network device name for ufw configuration (Virt-manager)
NetDevice=$(ip route | awk '/default/ {print $5}')

# Updating the system
echo " Updating system.... "
sudo pacman -Syu --noconfirm
echo "System update completed."

# Pacman packages installation

# Define pacman packages
PACMAN_PACKAGES=(
    lib32-nvidia-utils
    steam
    ufw
    git
    plymouth
)
# Install basic tools with pacman
echo "Installing basic tools with pacman..."
sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"
echo "Installing pacman packages completed."

# Virt-manager installation and complete setup

# Define packages for virt-manager
VIRT_MANAGAER=(
    qemu-full
    virt-manager
    virt-viewer
    bridge-utils
    libguestfs
    swtpm
)

echo "Installing virt-manager and dependencies..."
sudo pacman -S --needed --noconfirm "${VIRT_MANAGAER[@]}"

# Configuring UFW for virt-manager
echo "configuring UFW for virt-manager..."
sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
sed "$a \\n# Allow forwarding for libvirt\n*nat\n:POSTROUTING ACCEPT [0:0]\n-A POSTROUTING -s 192.168.122.0/24 -o '$NetDevice' -j MASQUERADE\nCOMMIT" /home/zoro/Documents/Projects/Arch-postinstallation/before.rules
sudo ufw enable
sudo systemctl enable --now ufw
echo "Virt-manager installation completed."

# Define flatpak packages
FLATPAK_PACKAGES=(
    com.spotify.Client
    com.discordapp.Discord
)

# Flatpak setup
echo "Setting up flatpak..."
sudo pacman -S --needed --noconfirm flatpak

# Switch to user context for flatpak configuration
echo "Configuring Flatpak as user $ACTUAL_USER..."
sudo -u $ACTUAL_USER flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install flatpak packages
echo "Installing applications via Flatpak..."
sudo -u $ACTUAL_USER flatpak install -y flathub "${FLATPAK_PACKAGES[@]}"

# Define AUR packages
AUR_PACKAGES=(
    visual-studio-code-bin
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
sudo -u $ACTUAL_USER bash -c "yay -S --needed --noconfirm ${AUR_PACKAGES[*]}"

# Setting up plymouth with monoarch theme
echo "Configuring plymouth..."
sed -i "/^HOOKS/s/\budev\b/& plymouth/" /etc/mkinitcpio.conf
sudo mkinitcpio -p linux

# Adds plumouth to grub
sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT=/s/\bquiet\b/& splash rd.udev.log_priority=3 vt.global_cursor_default=0/" /etc/default/grub

# Ensures system boots into linux kernel instead of linux-lts bby default
sed -i '/^GRUB_CMDLINE_LINUX=/a \\n# Linux-LTS to Linux\nGRUB_TOP_LEVEL="/boot/vmlinuz-linux"' /etc/default/grub

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