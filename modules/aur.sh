#!/bin/bash

# AUR package installation module

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
        plymouth-theme-monoarch-refined
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