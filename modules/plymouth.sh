#!/bin/bash

# Plymouth boot splash configuration module

# Configure Plymouth
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
    
    if echo "$available_themes" | grep -q "monoarch-refined"; then
        sudo plymouth-set-default-theme monoarch-refined > /dev/null 2>&1
        log_info "Theme set to: monoarch-refined"
    else
        sudo plymouth-set-default-theme bgrt > /dev/null 2>&1 || \
        sudo plymouth-set-default-theme spinner > /dev/null 2>&1
        log_warn "monoarch-refined theme not found, using default"
    fi
    
    # Rebuild initramfs
    log_info "Rebuilding initramfs..."
    sudo mkinitcpio -P > /dev/null 2>&1
    
    # Rebuild GRUB configuration
    log_info "Rebuilding GRUB configuration..."
    sudo grub-mkconfig -o /boot/grub/grub.cfg > /dev/null 2>&1
    
    log_info "✓ Plymouth configured successfully"
}