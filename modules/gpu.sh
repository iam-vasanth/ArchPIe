#!/bin/bash

# GPU detection and driver installation module

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
        if sudo pacman -S --needed --noconfirm "${GPU_PACKAGES[@]}" >> $LOG_DIR/gpu_install.log 2>&1; then
            log_info "✓ GPU drivers installed successfully"
        else
            log_error "✗ Failed to install GPU drivers"
            log_error "Check $LOG_DIR/gpu_install.log for details"
            return 1
        fi
    fi
}