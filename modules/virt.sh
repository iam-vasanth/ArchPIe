#!/bin/bash

# Virtualization (virt-manager) setup module

# Collect virt-manager installation choice
collect_virt_manager_choice() {
    echo ""
    echo -e "${BLUE}=== Virtualization Setup ===${NC}"
    read -p "Do you want to install virt-manager (QEMU/KVM)? (y/n): " INSTALL_VIRT_MANAGER
    
    if [[ "$INSTALL_VIRT_MANAGER" == "y" ]]; then
        log_info "virt-manager will be installed"
    else
        log_info "Skipping virt-manager installation"
    fi
}

# Install and configure virt-manager
install_virt_manager() {
    if [[ "$INSTALL_VIRT_MANAGER" != "y" ]]; then
        log_info "Skipping virt-manager installation"
        return 0
    fi
    
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
        
        # Enable IP forwarding
        log_info "Enabling IP forwarding..."
        sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1
        sudo sysctl -w net.ipv6.conf.all.forwarding=1 > /dev/null 2>&1
        
        # Make IP forwarding persistent
        sudo mkdir -p /etc/sysctl.d
        echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-libvirt.conf > /dev/null
        echo "net.ipv6.conf.all.forwarding=1" | sudo tee -a /etc/sysctl.d/99-libvirt.conf > /dev/null
        
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