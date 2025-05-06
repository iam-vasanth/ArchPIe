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

# # Mounting second drive
# lsblk -o UUID,TYPE,SIZE,MOUNTPOINT
# read -p "Enter the UUID of the second drive: " UUID
# read -p "Enter the mount point (e.g., /mnt/Folder_name): " MOUNT_POINT

# WIP
# Extrating the KVM virtual network device name for virt-manager
# KVM_NetDevice=$

pacman() {
    # Defining the pacman packages to be installed
    PACMAN_PACKAGES=(
        lib32-nvidia-utils
        firewalld
        git
        jdk-openjdk
        firefox
        discord
        neovim
        plymouth
        fuse
        steam
        wine
        winetricks
        wine-mono
        wine-gecko
        partitionmanager
    )
    sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}" &> /dev/null
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
    sudo pacman -S --needed --noconfirm "${VIRT_MANAGAER[@]}" &> /dev/null
    # WIP
    # Configure firewalld for virt-manager
    # sudo systemctl enable --now firewalld &> /dev/null
    # # Have to add a SED - sudo systemctl net.ipv4.ip_forward=1
    # # Have to add a SED - sudo systemctl net.ipv6.conf.all.forwarding=1
    # sudo firewall-cmd --zone=external --change-interface=$NetDevice --permanent
    # sudo firewall-cmd --zone=internal --change-interface=virbr0 --permanent
    # sudo firewall-cmd --reload
    # sudo firewall-cmd --permanent --new-policy int2ext
    # sudo firewall-cmd --permanent --policy  int2ext --add-ingress-zone internal
    # sudo firewall-cmd --permanent --policy  int2ext --add-egress-zone external
    # sudo firewall-cmd --permanent --policy int2ext --set-target ACCEPT
    # sudo firewall-cmd --reload
    # sudo systemctl restart firewalld
    # sudo systemctl restart libvirtd
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
    sudo pacman -S --needed --noconfirm flatpak &> /dev/null

    #Configuring Flatpak as user
    sudo -u $ACTUAL_USER flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo &> /dev/null

    # Install flatpak packages
    sudo -u $ACTUAL_USER flatpak install -y flathub "${FLATPAK_PACKAGES[@]}" &> /dev/null
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
sudo pacman -Syu --noconfirm
echo "System update completed."

# Install pacman packages
echo "Installing basic tools with pacman..."
pacman
echo "Installing pacman packages completed."

# Install virt-manager and configure firewalld
echo "Installing virt-manager and dependencies..."
virtmanager
echo "Installing virt-manager packages completed."

# Install flatpak packages
echo "Installing flatpak and packages..."
flatpak
echo "Installing flatpak packages completed."

# Install AUR packages
echo "Installing AUR packages..."
aur
echo "Installing AUR packages completed."

# Setting up plymouth with monoarch theme
echo "Configuring plymouth..."
sed -i "/^HOOKS/s/\budev\b/& plymouth/" /etc/mkinitcpio.conf
echo "Regenerating initramfs..."
sudo mkinitcpio -p linux &> /dev/null

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
echo "Installed monoarch theme successfully."

# # Mounting the second drive
# sudo mkdir -p $MOUNT_POINT &> /dev/null
# if grep -q "UUID=$UUID" /etc/fstab; then
#     echo "The UUID $UUID already exists in /etc/fstab. Skipping entry."
# else
#     echo "Adding entry to /etc/fstab..."
#     echo "UUID=$UUID $MOUNT_POINT ext4 nofail 0 0" >> /etc/fstab
#     echo "Entry added successfully."
#     sudo mount -a &> /dev/null
#     echo "Mounted $MOUNT_POINT successfully."
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
#   --tpm backend.type=emulator,model=tpm-crb

# virt-instll \
#     --name arch-vm \
#     --memory 4096 \

echo "Completed all installations and configurations succesfully."
echo "Rebooting system to apply all changes."
