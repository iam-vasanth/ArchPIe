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
sudo -v &> /dev/null
while true; do sudo -n true &> /dev/null ; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Store the actual username (not root)
ACTUAL_USER=$(logname || echo $SUDO_USER)
if [ -z "$ACTUAL_USER" ]; then
    ACTUAL_USER=$(who | awk '{print $1; exit}')
fi
HOME_DIR="/home/$ACTUAL_USER"

# Create temporary sudoers rule for yay package installation (Optional). 
# This code block is removable but it will defeat the purpose of entering the sudo password one time and that it's a automatic installation script.
TEMP_SUDOERS="/etc/sudoers.d/temp-nopasswd-$ACTUAL_USER"
echo "$ACTUAL_USER ALL=(ALL) NOPASSWD: ALL" > "$TEMP_SUDOERS"
chmod 440 "$TEMP_SUDOERS"

# Revert back the sudoers rule after the script execution
trap 'echo "Cleaning up..."; rm -f "$TEMP_SUDOERS"' EXIT INT TERM

# Extracting the network device name for firewalld configuration (Virt-manager)
NetDevice=$(ip route | awk '/default/ {print $5}')

# Progress bar function
progress_bar() {
    local duration=2
    local interval=0.1
    local completed=0
    local total=$((duration / interval))
    local bar_width=50

    while ((completed <= total)); do
        local percent=$((completed * 100 / total))
        local filled=$((completed * bar_width / total))
        local empty=$((bar_width - filled))

        printf "\r[%-${filled}s%${empty}s] %3d%%" "#" "" "$percent"

        sleep $interval
        completed=$((completed + 1))
    done
    echo ""  # New line at the end
}

pacman() {
    # Defining the pacman packages to be installed
    PACMAN_PACKAGES=(
        lib32-nvidia-utils
        firewalld
        git
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
    sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"
}

virtmanager() {
    # Define packages needed for virt-manager
    VIRT_MANAGAER=(
        qemu-full
        virt-manager
        virt-viewer
        bridge-utils
        dnsmasq
        ebtables
        iptables
        libguestfs
        swtpm
    )
    sudo pacman -S --needed --noconfirm "${VIRT_MANAGAER[@]}"
}

flatpak() {
    # Define flatpak packages
    FLATPAK_PACKAGES=(
        com.spotify.Client
        com.discordapp.Discord
        org.videolan.VLC
        com.github.tchx84.Flatseal
        org.qbittorrent.qBittorrent
        com.usebottles.bottles
        net.davidotek.pupgui2                   #ProtonUp-Qt
        org.libreoffice.LibreOffice
        com.stremio.Stremio
    )
    # Flatpak setup
    sudo pacman -S --needed --noconfirm flatpak

    #Configuring Flatpak as user
    sudo -u $ACTUAL_USER flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    # Install flatpak packages
    sudo -u $ACTUAL_USER flatpak install -y flathub "${FLATPAK_PACKAGES[@]}"
}

aur() {
    # Define AUR packages
    AUR_PACKAGES=(
        visual-studio-code-bin
        plymouth-theme-monoarch
    )

    # Cheking if yay is installed. if not, install yay
    if ! command -v yay &> /dev/null; then
        echo "yay is not installed. Installing yay..."
        # Create and switch to a temporary directory
        TMP_DIR=$(mktemp -d) &> /dev/null
        trap "rm -rf $TMP_DIR" EXIT  # Ensure cleanup on script exit
        chown "$ACTUAL_USER:$ACTUAL_USER" "$TMP_DIR" &> /dev/null
        sudo -u "$ACTUAL_USER" git clone https://aur.archlinux.org/yay.git "$TMP_DIR/yay"
        # Build and install yay
        cd "$TMP_DIR/yay" &> /dev/null
        sudo -u "$ACTUAL_USER" makepkg -si --noconfirm &> /dev/null
        echo "yay installation completed."
    else
        echo "yay is already installed."
    fi
    # Install AUR packages using yay
    sudo -u $ACTUAL_USER bash -c "yay -S --needed --noconfirm ${AUR_PACKAGES[*]}" &> /dev/null
}

# Updating the system
echo " Updating system.... "
progress_bar 2
echo "System update completed."

# Install pacman packages
echo "Installing basic tools with pacman..."
pacman &> /dev/null
progress_bar 2
echo "Installing pacman packages completed."

# Install virt-manager and configure firewalld
echo "Installing virt-manager and dependencies..."
virtmanager &> /dev/null
progress_bar 2
echo "Installing virt-manager packages completed."

# Install flatpak packages
echo "Installing flatpak and packages..."
flatpak &> /dev/null
progress_bar 2
echo "Installing flatpak packages completed."

# Install AUR packages
echo "Installing AUR packages..."
aur
progress_bar 2
echo "Installing AUR packages completed."

# Setting up plymouth with monoarch theme
echo "Configuring plymouth..."
sed -i "/^HOOKS/s/\budev\b/& plymouth/" /etc/mkinitcpio.conf
echo "Regenerating initramfs..."
sudo mkinitcpio -p linux &> /dev/null
progress_bar 2

# Adds plumouth to grub
sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT=/s/\bquiet\b/& splash rd.udev.log_priority=3 vt.global_cursor_default=0/" /etc/default/grub

# Ensures system boots into linux kernel instead of linux-lts by default
sed -i '/^GRUB_CMDLINE_LINUX=/a \\n# Linux-LTS to Linux\nGRUB_TOP_LEVEL="/boot/vmlinuz-linux"' /etc/default/grub

# Build grub configuration
echo "Building grub configuration..."
sudo grub-mkconfig -o /boot/grub/grub.cfg &> /dev/null

# Apply the monoarch theme
echo "Applying monoarch theme..."
sudo plymouth-set-default-theme -R monoarch &> /dev/null
progress_bar 2
echo "Installed monoarch theme successfully."

# WIP
# # Mount the 2nd drive
# read -p "Do you want to mount the 2nd drive(If you have). Then enter device name (e.g. /dev/nvme1n1) or press Enter to skip:" 2nddrive
# if [ -z "$2nddrive" ]; then
#     echo "No device name entered. Skipping drive mounting."
# else
#     echo "You entered: $2nddrive"
# fi
# echo "Mounting the 2nd drive..."
# sudo mkdir -p /mnt/BigPP &> /dev/null
# UUID=$(blkid /dev/nvme1n1 | grep -oP 'UUID="\K[^"]+')
# if grep -q "$UUID" /etc/fstab; then
#   echo "UUID already exists in /etc/fstab. Skipping entry."
# else
#   echo "Adding entry to /etc/fstab"
#   echo "UUID=$UUID $MOUNT_POINT ext4 defaults 0 2" >> /etc/fstab
# fi

# # Connecting to hypervisor
# connect qemu:///system &> /dev/null

# virt-install \
#   --name win11-vm \
#   --memory 8192 \
#   --vcpus 6 \
#   --os-variant Win11 \
#   --disk size=150,path=/mnt/BigPP/win11-vm.qcow2,format=qcow2,bus=virtio \
#   --cdrom /path/to/windows11.iso \
#   --disk /mnt/BigPP/ISO/virtio-win-0.1.229.iso,device=cdrom \
#   --network network=default \
#   --graphics spice \
#   --video qxl \
#   --boot uefi \


echo "Completed all installations and configurations succesfully."
echo "Rebooting system to apply all changes."