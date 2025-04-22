#!/bin/bash

# Arch Linux Application Installation Script
# This script installs common applications using pacman, flatpak, and yay
# It will automatically request sudo privileges if not run with them
# Added confirmation prompts for each package manager's installations

# Check if script is run as root/sudo and re-run with sudo if not
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

echo "===== Starting Arch Linux application installation ====="
echo "Running as root, installing for user: $ACTUAL_USER"

# Function to ask for confirmation
confirm() {
    read -p "$1 [y/N]: " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Update system first
if confirm "Do you want to update the system? /n IT IS MANDATORY $RED"; then
    echo "Updating system..."
    pacman -Syu --noconfirm
else
    echo "Skipping system update."
fi

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
if confirm "Do you want to proceed with pacman installations?"; then
    echo "Installing basic tools with pacman..."
    pacman -S "${PACMAN_PACKAGES[@]}"
else
    echo "Skipping pacman installations."
fi

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

#Virt-manager installation and setup
echo "Installing following packages:"
printf "  %s\n" "${VIRT_MANAGAER[@]}"
if confirm "Do you want to proceed with Virt-manager installation and setup?"; then
    echo "Installing tools needed for virt-manager..."
    pacman -S --needed --noconfirm "${VIRT_MANAGAER[@]}"
else
    echo "Skipping virt-manager installations."
fi

# Define flatpak packages
FLATPAK_PACKAGES=(
    com.vscodium.codium
    com.spotify.Client
    org.ferdium.Ferdium
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

# Install and configure flatpak
if confirm "Do you want to set up Flatpak and install Flatpak applications?"; then
    echo "Setting up Flatpak..."
    pacman -S --needed --noconfirm flatpak
    
    # Switch to user context for flatpak configuration
    echo "Configuring Flatpak as user $ACTUAL_USER..."
    sudo -u $ACTUAL_USER flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    
    # Install applications via Flatpak
    echo "Installing applications via Flatpak..."
    echo "Flatpak will install the following packages:"
    printf "  %s\n" "${FLATPAK_PACKAGES[@]}"
    sudo -u $ACTUAL_USER flatpak install -y flathub "${FLATPAK_PACKAGES[@]}"
else
    echo "Skipping Flatpak setup and installations."
fi

# Define AUR packages
AUR_PACKAGES=(
    google-chrome
    visual-studio-code-bin
    spotify
    teams
    dropbox
    etcher-bin
    zoom
    brave-bin
    bitwarden-bin
    postman-bin
    insomnia
    nodejs-lts-gallium
    docker-compose
    sublime-text-4
)

# Install yay AUR helper if not already installed
if confirm "Do you want to install yay AUR helper (if not already installed) and AUR packages?"; then
    if ! command -v yay &> /dev/null; then
        echo "Installing yay AUR helper..."
        # Create temporary directory
        TMP_DIR=$(mktemp -d)
        chown $ACTUAL_USER:$ACTUAL_USER $TMP_DIR
        
        # Clone and build yay as the regular user
        cd $TMP_DIR
        sudo -u $ACTUAL_USER git clone https://aur.archlinux.org/yay.git
        cd yay
        sudo -u $ACTUAL_USER makepkg -si --noconfirm
        
        # Clean up
        cd /
        rm -rf $TMP_DIR
    fi
    
    # Install packages from AUR using yay (must be run as regular user)
    echo "Installing AUR packages using yay..."
    echo "Yay will install the following packages:"
    printf "  %s\n" "${AUR_PACKAGES[@]}"
    sudo -u $ACTUAL_USER bash -c "yay -S --needed --noconfirm ${AUR_PACKAGES[*]}"
else
    echo "Skipping yay installation and AUR packages."
fi

# Define development packages
DEV_PACKAGES=(
    python
    python-pip
    npm
    docker
    rust
    go
    jdk-openjdk
    maven
)

# Setup development environments
echo "Development packages to install:"
printf "  %s\n" "${DEV_PACKAGES[@]}"
if confirm "Do you want to set up development environments?"; then
    echo "Setting up development environments..."
    pacman -S --needed --noconfirm "${DEV_PACKAGES[@]}"
    
    # Enable and start docker service
    if confirm "Do you want to enable and start the Docker service?"; then
        echo "Enabling Docker service..."
        systemctl enable docker.service
        systemctl start docker.service
        usermod -aG docker $ACTUAL_USER
    else
        echo "Skipping Docker service setup."
    fi
else
    echo "Skipping development environment setup."
fi

# Define font packages
FONT_PACKAGES=(
    ttf-dejavu
    ttf-liberation
    ttf-droid
    ttf-ubuntu-font-family
    noto-fonts
    ttf-roboto
    ttf-fira-code
)

# Install fonts
echo "Font packages to install:"
printf "  %s\n" "${FONT_PACKAGES[@]}"
if confirm "Do you want to install additional fonts?"; then
    echo "Installing fonts..."
    pacman -S --needed --noconfirm "${FONT_PACKAGES[@]}"
else
    echo "Skipping font installation."
fi

# Define gaming packages
GAMING_PACKAGES=(
    steam
    lutris
    wine
    winetricks
)

# Install gaming tools
echo "Gaming packages to install:"
printf "  %s\n" "${GAMING_PACKAGES[@]}"
if confirm "Do you want to install gaming tools?"; then
    echo "Installing gaming tools..."
    pacman -S --needed --noconfirm "${GAMING_PACKAGES[@]}"
else
    echo "Skipping gaming tools installation."
fi

echo "===== Installation complete! ====="
echo "You may need to log out and back in for some changes to take effect."
echo "Note: Some applications might appear in both pacman and AUR lists as alternatives."