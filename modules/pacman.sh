#!/bin/bash

# Pacman package installation module

# Install pacman packages
install_pacman_packages() {
    log_info "Installing pacman packages..."
    local PACMAN_PACKAGES=(
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
        base-devel
    )
    
    # Add firewall package based on user choice
    if [[ "$FIREWALL_CHOICE" == "1" ]]; then
        PACMAN_PACKAGES+=(firewalld)
    elif [[ "$FIREWALL_CHOICE" == "2" ]]; then
        PACMAN_PACKAGES+=(ufw)
    fi
    
    local total=${#PACMAN_PACKAGES[@]}
    echo -e "${YELLOW}Installing $total pacman packages...${NC}"
    
    if sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}" >> $LOG_DIR/pacman_install.log 2>&1; then
        show_progress "$total" "$total"
        echo ""
        log_info "✓ Pacman packages installed successfully"
    else
        echo ""
        log_error "✗ Failed to install pacman packages"
        log_error "Check $LOG_DIR/pacman_install.log for details"
        return 1
    fi
}