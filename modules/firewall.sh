#!/bin/bash

# Firewall configuration module

# Collect firewall choice
collect_firewall_choice() {
    echo ""
    echo -e "${BLUE}=== Firewall Configuration ===${NC}"
    echo "Which firewall do you want to use?"
    echo "1) firewalld (recommended for virt-manager)"
    echo "2) UFW (simpler, user-friendly)"
    echo "3) None (skip firewall setup)"
    read -p "Enter choice [1-3]: " FIREWALL_CHOICE
    
    while [[ "$FIREWALL_CHOICE" != "1" && "$FIREWALL_CHOICE" != "2" && "$FIREWALL_CHOICE" != "3" ]]; do
        log_error "Invalid choice. Please enter 1, 2, or 3."
        read -p "Enter choice [1-3]: " FIREWALL_CHOICE
    done
    
    if [[ "$FIREWALL_CHOICE" == "1" ]]; then
        log_info "Selected: firewalld"
    elif [[ "$FIREWALL_CHOICE" == "2" ]]; then
        log_info "Selected: UFW"
    else
        log_info "Selected: No firewall"
    fi
}

# Configure firewall based on user choice
configure_firewall() {
    if [[ "$FIREWALL_CHOICE" == "1" ]]; then
        configure_firewalld
    elif [[ "$FIREWALL_CHOICE" == "2" ]]; then
        configure_ufw
    else
        log_info "Skipping firewall configuration"
    fi
}

# Configure firewalld
configure_firewalld() {
    log_info "Configuring firewalld..."
    
    # Get network device
    local NetDevice
    NetDevice=$(ip route | awk '/default/ {print $5; exit}')
    
    if [[ -z "$NetDevice" ]]; then
        log_warn "No default network device found"
        return 1
    fi
    
    # Enable and configure
    sudo systemctl enable --now firewalld > /dev/null 2>&1
    sudo firewall-cmd --set-default-zone=home > /dev/null 2>&1
    sudo firewall-cmd --zone=home --change-interface="$NetDevice" --permanent > /dev/null 2>&1
    
    # Allow SSH
    sudo firewall-cmd --zone=home --add-service=ssh --permanent > /dev/null 2>&1
    
    # Allow LocalSend (port 53317)
    sudo firewall-cmd --zone=home --add-port=53317/tcp --permanent > /dev/null 2>&1
    sudo firewall-cmd --zone=home --add-port=53317/udp --permanent > /dev/null 2>&1
    
    # Reload firewall
    sudo firewall-cmd --reload > /dev/null 2>&1
    
    log_info "✓ firewalld configured with SSH and LocalSend access"
}

# Configure UFW
configure_ufw() {
    log_info "Configuring UFW..."
    
    # Enable UFW
    sudo systemctl enable --now ufw > /dev/null 2>&1
    
    # Default policies
    sudo ufw default deny incoming > /dev/null 2>&1
    sudo ufw default allow outgoing > /dev/null 2>&1
    
    # Allow SSH
    sudo ufw allow ssh > /dev/null 2>&1
    
    # Allow LocalSend (port 53317)
    sudo ufw allow 53317/tcp > /dev/null 2>&1
    sudo ufw allow 53317/udp > /dev/null 2>&1
    
    # Enable firewall
    sudo ufw --force enable > /dev/null 2>&1
    
    log_info "✓ UFW configured with SSH and LocalSend access"
}

# Configure firewall for libvirt
configure_firewall_for_libvirt() {
    if [[ "$INSTALL_VIRT_MANAGER" != "y" ]]; then
        return 0
    fi
    
    # Check which firewall is active
    if systemctl is-active --quiet firewalld 2>/dev/null; then
        log_info "Configuring firewalld for libvirt..."
        # firewalld automatically handles libvirt zone
        log_info "✓ firewalld libvirt zone configured automatically"
        
    elif systemctl is-active --quiet ufw 2>/dev/null; then
        log_info "Configuring UFW for libvirt..."
        
        # Allow traffic on virbr0 interface
        sudo ufw allow in on virbr0 > /dev/null 2>&1
        sudo ufw allow out on virbr0 > /dev/null 2>&1
        
        # Reload UFW
        sudo ufw reload > /dev/null 2>&1
        
        log_info "✓ UFW configured for libvirt networking"
    fi
}