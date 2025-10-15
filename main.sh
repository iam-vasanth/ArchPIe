#!/bin/bash

#!/bin/bash

cat << "EOF"                                                                                                                     
        
   █████████                      █████      ███████████  █████         
  ███▒▒▒▒▒███                    ▒▒███      ▒▒███▒▒▒▒▒███▒▒███          
 ▒███    ▒███  ████████   ██████  ▒███████   ▒███    ▒███ ▒███   ██████ 
 ▒███████████ ▒▒███▒▒███ ███▒▒███ ▒███▒▒███  ▒██████████  ▒███  ███▒▒███
 ▒███▒▒▒▒▒███  ▒███ ▒▒▒ ▒███ ▒▒▒  ▒███ ▒███  ▒███▒▒▒▒▒▒   ▒███ ▒███████ 
 ▒███    ▒███  ▒███     ▒███  ███ ▒███ ▒███  ▒███         ▒███ ▒███▒▒▒  
 █████   █████ █████    ▒▒██████  ████ █████ █████        █████▒▒██████ 
▒▒▒▒▒   ▒▒▒▒▒ ▒▒▒▒▒      ▒▒▒▒▒▒  ▒▒▒▒ ▒▒▒▒▒ ▒▒▒▒▒        ▒▒▒▒▒  ▒▒▒▒▒▒  
                                                                          
EOF

echo ""
echo "A modular and automated setup script for Arch Linux fresh installations"
echo "=========================================="

# Main orchestrator for Arch Linux post-installation setup
# This script sources modules and coordinates the installation process

# Exit on error
set -e
set -E

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common library
source "$SCRIPT_DIR/lib/common.sh"

# Source all modules
source "$SCRIPT_DIR/modules/gpu.sh"
source "$SCRIPT_DIR/modules/pacman.sh"
source "$SCRIPT_DIR/modules/flatpak.sh"
source "$SCRIPT_DIR/modules/aur.sh"
source "$SCRIPT_DIR/modules/virt.sh"
source "$SCRIPT_DIR/modules/firewall.sh"
source "$SCRIPT_DIR/modules/drives.sh"
source "$SCRIPT_DIR/modules/plymouth.sh"

# Have to add a if to check if the user is using gnome or KDE and save it

# Main execution
main() {
    echo ""
    echo "=========================================="
    echo "  Arch Linux Post-Installation Setup"
    echo "=========================================="
    echo ""
    
    log_info "Starting system setup script..."
    log_info "Error log: $ERROR_LOG"
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should NOT be run as root. Run as normal user."
        exit 1
    fi
    
    # Sudo password once and keep it alive
    log_info "This script requires sudo privileges"
    keep_sudo_alive
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  COLLECTING CONFIGURATION OPTIONS${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    # Collecting user choices
    collect_firewall_choice
    collect_virt_manager_choice
    collect_drive_info
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  CONFIGURATION COMPLETE${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    log_info "All configuration collected. Starting automated installation..."
    log_warn "You can now leave the script to run unattended."
    echo ""
    sleep 3
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  INSTALLING PACKAGES${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    # Detect and install GPU drivers
    detect_and_install_gpu_drivers
    
    # Run installations
    install_pacman_packages
    install_flatpak_packages
    install_yay
    install_aur_packages
    install_virt_manager
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  APPLYING CONFIGURATIONS${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    # Run configurations
    configure_firewall
    configure_firewall_for_libvirt
    configure_additional_drives
    configure_plymouth
    
    # Stop sudo keeper
    stop_sudo_keeper
    
    echo ""
    echo "=========================================="
    log_info "Setup completed successfully!"
    echo "=========================================="
    echo ""
    log_warn "IMPORTANT: Please reboot your system for all changes to take effect."
    echo ""
    read -p "Do you want to reboot now? (y/n): " reboot_choice
    
    if [[ "$reboot_choice" == "y" ]]; then
        log_info "Rebooting system..."
        sudo reboot
    else
        log_info "Please remember to reboot manually."
    fi
}

main "$@"
