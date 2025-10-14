#!/bin/bash

# Flatpak package installation module

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
        de.haeckerfelix.Fragments
        com.usebottles.bottles
        org.libreoffice.LibreOffice
        org.localsend.localsend_app
        app.zen_browser.zen
        org.gnome.Firmware
        md.obsidian.Obsidian
        com.protonvpn.www
    )
    
    local total=${#FLATPAK_PACKAGES[@]}
    local current=0
    
    echo -e "${YELLOW}Installing $total Flatpak packages (system-wide)...${NC}"
    
    for pkg in "${FLATPAK_PACKAGES[@]}"; do
        if flatpak list --system | grep -q "$pkg" 2>/dev/null; then
            ((current++))
            show_progress "$current" "$total"
        else
            if sudo flatpak install -y --system flathub "$pkg" > $LOG_DIR/flatpak_install.log 2>&1; then
                ((current++))
                show_progress "$current" "$total"
            else
                echo ""
                log_error "✗ Failed to install $pkg"
                log_error "Check $LOG_DIR/flatpak_install.log for details"
            fi
        fi
    done
    
    echo ""
    log_info "✓ Flatpak packages installation completed"
}