#!/bin/bash

# Exit on error
set -e
set -E 
ERROR_LOG="/var/log/script_errors.txt"

# Trap errors and log them
trap 'echo "Error occurred at line $LINENO. Exit code: $?" | tee -a "$ERROR_LOG"; cleanup' ERR
# Trap normal exit/interrupt for cleanup
trap 'cleanup' EXIT INT TERM
cleanup() {
    echo "Cleaning up..." | tee -a "$ERROR_LOG"
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    log_error "This script should NOT be run as root. Run as normal user."
    exit 1
fi

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    log_error "This script should NOT be run as root. Run as normal user."
    exit 1
fi

# Refresh sudo timestamp and keep it alive
keep_sudo_alive() {
    sudo -v
    while true; do
        sudo -n true
        sleep 50
        kill -0 "$$" || exit
    done 2>/dev/null &
    SUDO_KEEPER_PID=$!
}

# Stop the sudo keeper background process when the script is exited
stop_sudo_keeper() {
    if [[ -n "$SUDO_KEEPER_PID" ]]; then
        kill "$SUDO_KEEPER_PID" 2>/dev/null || true
    fi
}

# Progress bar function
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    
    printf "\r${GREEN}[${NC}"
    printf "%${completed}s" | tr ' ' '█'
    printf "%${remaining}s" | tr ' ' '░'
    printf "${GREEN}]${NC} %3d%% (%d/%d)" "$percentage" "$current" "$total"
}


# # Store the actual username (not root)
# ACTUAL_USER=$(logname || echo $SUDO_USER)
# if [ -z "$ACTUAL_USER" ]; then
#     ACTUAL_USER=$(who | awk '{print $1; exit}')
# fi
# HOME_DIR="/home/$ACTUAL_USER"

# # Create temporary sudoers rule for yay package installation (Optional). 
# # This code block is removable but it will defeat the purpose of entering the sudo password one time and that it's a automatic installation script.
# TEMP_SUDOERS="/etc/sudoers.d/temp-nopasswd-$ACTUAL_USER"
# echo "$ACTUAL_USER ALL=(ALL) NOPASSWD: ALL" > "$TEMP_SUDOERS"
# chmod 440 "$TEMP_SUDOERS"

# # Mounting second drive
# lsblk -o UUID,TYPE,SIZE,MOUNTPOINT
# read -p "Enter the UUID of the second drive: " UUID
# read -p "Enter the mount point (e.g., /mnt/Folder_name): " MOUNT_POINT

# Detect GPU and install appropriate drivers
detect_and_install_gpu_drivers() {
    log_info "Detecting GPU..."
    local GPU_PACKAGES=()
    local gpu_detected=false
    
    # Detect NVIDIA
    if lspci | grep -i nvidia > /dev/null; then
        log_info "NVIDIA GPU detected"
        GPU_PACKAGES+=(
            nvidia-utils
            lib32-nvidia-utils
            nvidia-settings
        )
        gpu_detected=true
    fi
    
    # Detect AMD
    if lspci | grep -iE "vga|3d|display" | grep -iE "amd|ati|radeon" > /dev/null; then
        log_info "AMD GPU detected"
        GPU_PACKAGES+=(
            mesa
            lib32-mesa
            vulkan-radeon
            lib32-vulkan-radeon
            libva-mesa-driver
            lib32-libva-mesa-driver
            mesa-vdpau
            lib32-mesa-vdpau
        )
        gpu_detected=true
    fi
    
    # Detect Intel
    if lspci | grep -iE "vga|3d|display" | grep -i "intel" > /dev/null; then
        log_info "Intel GPU detected"
        GPU_PACKAGES+=(
            mesa
            lib32-mesa
            vulkan-intel
            lib32-vulkan-intel
            intel-media-driver
            libva-intel-driver
        )
        gpu_detected=true
    fi
    
    if [[ "$gpu_detected" = false ]]; then
        log_warn "No specific GPU detected, installing generic drivers"
        GPU_PACKAGES+=(
            mesa
            lib32-mesa
        )
    fi
    
    # Install GPU packages
    if [[ ${#GPU_PACKAGES[@]} -gt 0 ]]; then
        log_info "Installing GPU drivers and 32-bit libraries for gaming..."
        if sudo pacman -S --needed --noconfirm "${GPU_PACKAGES[@]}" > /tmp/gpu_install.log 2>&1; then
            log_info "✓ GPU drivers installed successfully"
        else
            log_error "✗ Failed to install GPU drivers"
            log_error "Check /tmp/gpu_install.log for details"
            return 1
        fi
    fi
}

# Install pacman packages
install_pacman_packages() {
    log_info "Installing pacman packages..."
    local PACMAN_PACKAGES=(
        firewalld
        git
        jdk-openjdk
        neovim
        plymouth
        fuse
        steam
        wine
        winetricks
        wine-mono
        wine-gecko
        lutris
        discord
    )
    
    local total=${#PACMAN_PACKAGES[@]}
    echo -e "${YELLOW}Installing $total pacman packages...${NC}"
    
    if sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}" > /tmp/pacman_install.log 2>&1; then
        show_progress "$total" "$total"
        echo ""
        log_info "✓ Pacman packages installed successfully"
    else
        echo ""
        log_error "✗ Failed to install pacman packages"
        log_error "Check /tmp/pacman_install.log for details"
        return 1
    fi
}

# Install and configure virt-manager
install_virt_manager() {
    log_info "Installing virt-manager and dependencies..."
    local VIRT_PACKAGES=(
        virt-manager
        qemu-full
        virt-viewer
        libvirt
        edk2-ovmf
        dnsmasq
        bridge-utils
        libguestfs
        dmidecode
        vde2
        swtpm
    )
    local total=${#VIRT_PACKAGES[@]}
    echo -e "${YELLOW}Installing $total virtualization packages...${NC}"
    
    if sudo pacman -S --needed --noconfirm "${VIRT_PACKAGES[@]}" > /tmp/virt_install.log 2>&1; then
        show_progress "$total" "$total"
        echo ""
        log_info "✓ Virtualization packages installed successfully"
        
        # Enable and start libvirtd service
        log_info "Configuring libvirt service..."
        sudo systemctl enable --now libvirtd > /dev/null 2>&1
        
        # Add user to libvirt group
        log_info "Adding user to libvirt group..."
        sudo usermod -aG libvirt "$USER"
        
        # Start default network
        sudo virsh net-autostart default > /dev/null 2>&1
        sudo virsh net-start default > /dev/null 2>&1 || true
        
        log_info "✓ virt-manager configured successfully"
        log_warn "You need to log out and back in for group changes to take effect"
    else
        echo ""
        log_error "✗ Failed to install virtualization packages"
        log_error "Check /tmp/virt_install.log for details"
        return 1
    fi
}

# Install Flatpak packages
install_flatpak_packages() {
    log_info "Installing Flatpak packages..."
    
    # Ensure flatpak is installed
    if ! command -v flatpak &> /dev/null; then
        log_warn "Flatpak not found, installing..."
        sudo pacman -S --needed --noconfirm flatpak > /dev/null 2>&1
    fi
    
    # Add Flathub repository (system) - for actual installations
    if ! flatpak remote-list --system | grep -q flathub 2>/dev/null; then
        log_info "Adding Flathub repository (system)..."
        sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo > /dev/null 2>&1
    fi
    
    # Add Flathub repository (user) - for GNOME Software options
    log_info "Adding Flathub repository (user - for GNOME Software)..."
    flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo > /dev/null 2>&1
    
    local FLATPAK_PACKAGES=(
        com.spotify.Client
        com.mattjakeman.ExtensionManager
        com.github.tchx84.Flatseal
        org.videolan.VLC
        ode.haeckerfelix.Fragments
        com.usebottles.bottles
        org.libreoffice.LibreOffice
        org.localsend.localsend_app
    )
    
    local total=${#FLATPAK_PACKAGES[@]}
    local current=0
    
    echo -e "${YELLOW}Installing $total Flatpak packages (system-wide)...${NC}"
    
    for pkg in "${FLATPAK_PACKAGES[@]}"; do
        if flatpak list --system | grep -q "$pkg" 2>/dev/null; then
            ((current++))
            show_progress "$current" "$total"
        else
            if sudo flatpak install -y --system flathub "$pkg" > /tmp/flatpak_install.log 2>&1; then
                ((current++))
                show_progress "$current" "$total"
            else
                echo ""
                log_error "✗ Failed to install $pkg"
                log_error "Check /tmp/flatpak_install.log for details"
            fi
        fi
    done
    
    echo ""
    log_info "✓ Flatpak packages installation completed (system-wide for Btrfs compatibility)"
}

# Install AUR helper (yay) if not present
install_yay() {
    if command -v yay &> /dev/null; then
        log_info "yay is already installed"
        return 0
    fi
    log_info "Installing yay AUR helper..."

    local YAY_DIR="/tmp/yay-install"
    rm -rf "$YAY_DIR"
    
    git clone https://aur.archlinux.org/yay.git "$YAY_DIR" > /tmp/yay_install.log 2>&1
    cd "$YAY_DIR"
    
    if makepkg -si --noconfirm > /tmp/yay_install.log 2>&1; then
        log_info "✓ yay installed successfully"
        cd - > /dev/null
        rm -rf "$YAY_DIR"
    else
        log_error "✗ Failed to install yay"
        log_error "Check /tmp/yay_install.log for details"
        cd - > /dev/null
        return 1
    fi
}

# Install AUR packages
install_aur_packages() {
    log_info "Installing AUR packages..."
    
    local AUR_PACKAGES=(
        plymouth-theme-monoarch
        visual-studio-code-bin
        an-anime-game-launcher-bin
    )
    
    if [[ ${#AUR_PACKAGES[@]} -eq 0 ]]; then
        log_warn "No AUR packages to install"
        return 0
    fi
    
    local total=${#AUR_PACKAGES[@]}
    echo -e "${YELLOW}Installing $total AUR packages...${NC}"
    
    if yay -S --needed --noconfirm "${AUR_PACKAGES[@]}" > /tmp/aur_install.log 2>&1; then
        show_progress "$total" "$total"
        echo ""
        log_info "✓ AUR packages installed successfully"
    else
        echo ""
        log_error "✗ Failed to install AUR packages"
        log_error "Check /tmp/aur_install.log for details"
        return 1
    fi
}

# System configurations
configure_plymouth() {
    log_info "Configuring Plymouth boot splash..."
    
    # Check if plymouth is installed
    if ! command -v plymouth-set-default-theme &> /dev/null; then
        log_error "Plymouth not installed"
        return 1
    fi
    
    # Add plymouth hook if not already present in mkinitcpio
    if ! grep -q "plymouth" /etc/mkinitcpio.conf; then
        log_info "Adding plymouth hook to mkinitcpio..."
        sudo sed -i 's/^HOOKS=(\(.*\)udev\(.*\))/HOOKS=(\1udev plymouth\2)/' /etc/mkinitcpio.conf
    else
        log_info "Plymouth hook already present in mkinitcpio"
    fi
    
    # Add plymouth parameters to GRUB if not already present
    if ! grep -q "splash" /etc/default/grub; then
        log_info "Adding plymouth parameters to GRUB..."
        sudo sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/s/quiet/quiet splash rd.udev.log_priority=3 vt.global_cursor_default=0/' /etc/default/grub
    else
        log_info "Plymouth parameters already present in GRUB"
    fi
    
    # Set plymouth theme
    log_info "Setting Plymouth theme..."
    local available_themes
    available_themes=$(sudo plymouth-set-default-theme -l 2>/dev/null)
    
    if echo "$available_themes" | grep -q "connect"; then
        sudo plymouth-set-default-theme connect > /dev/null 2>&1
        log_info "Theme set to: Connect"
    else
        sudo plymouth-set-default-theme bgrt > /dev/null 2>&1 || \
        sudo plymouth-set-default-theme spinner > /dev/null 2>&1
        log_warn "monoarch theme not found, using default"
    fi
    
    # Rebuild initramfs
    log_info "Rebuilding initramfs..."
    sudo mkinitcpio -P > /dev/null 2>&1
    
    # Rebuild GRUB configuration
    log_info "Rebuilding GRUB configuration..."
    sudo grub-mkconfig -o /boot/grub/grub.cfg > /dev/null 2>&1
    
    log_info "✓ Plymouth configured successfully"
}

# Main execution
main() {
    log_info "Starting system setup script..."
    log_info "Error log: $ERROR_LOG"
    
    # Ask for sudo password once and keep it alive
    log_info "This script requires sudo privileges"
    keep_sudo_alive
    
    # Detect and install GPU drivers first
    detect_and_install_gpu_drivers
    
    # Run installations
    install_pacman_packages
    install_flatpak_packages
    install_yay
    install_aur_packages
    
    # Run configurations
    configure_plymouth
    
    # Stop sudo keeper
    stop_sudo_keeper
    
    log_info "Setup completed successfully!"
    log_info "Please reboot your system for all changes to take effect."
}

# Run main function
main "$@"

# Setting up plymouth with monoarch theme
echo "Configuring plymouth..."
sed -i "/^HOOKS/s/\budev\b/& plymouth/" /etc/mkinitcpio.conf
echo "Regenerating initramfs..."
sudo mkinitcpio -p linux

# Adds plumouth to grub
sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT=/s/\bquiet\b/& splash rd.udev.log_priority=3 vt.global_cursor_default=0/" /etc/default/grub

# Build grub configuration
echo "Building grub configuration..."
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Apply the monoarch theme
echo "Applying monoarch theme..."
sudo plymouth-set-default-theme -R monoarch
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
