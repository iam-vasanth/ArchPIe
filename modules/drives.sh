#!/bin/bash

# Additional drive configuration module

# Declare global associative array for drive info
declare -g -A DRIVE_INFO

# Collect drive information from user
collect_drive_info() {
    echo ""
    echo -e "${BLUE}=== Additional Drive Configuration ===${NC}"
    
    local drive_count=0
    
    while true; do
        read -p "Do you want to add a drive to fstab? (y/n): " add_drive
        
        if [[ "$add_drive" != "y" ]]; then
            break
        fi
        
        echo ""
        echo "Available drives:"
        lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT | grep -E "disk|part" | grep -v "loop"
        echo ""
        
        read -p "Enter device name (e.g., sdb1): " device
        
        if [[ ! -b "/dev/$device" ]]; then
            log_error "Device /dev/$device not found"
            continue
        fi
        
        # Get UUID
        local uuid
        uuid=$(sudo blkid -s UUID -o value "/dev/$device" 2>/dev/null)
        
        if [[ -z "$uuid" ]]; then
            log_error "Could not get UUID for /dev/$device. Drive might not be formatted."
            continue
        fi
        
        # Get filesystem type
        local fstype
        fstype=$(sudo blkid -s TYPE -o value "/dev/$device" 2>/dev/null)
        
        if [[ -z "$fstype" ]]; then
            log_error "Could not determine filesystem type for /dev/$device"
            continue
        fi
        
        # Ask for mount point
        read -p "Enter mount point (e.g., /mnt/data): " mountpoint
        
        # Validate mount point
        if [[ ! "$mountpoint" =~ ^/mnt/ ]] && [[ ! "$mountpoint" =~ ^/media/ ]]; then
            log_warn "Mount point should typically be under /mnt/ or /media/"
            read -p "Continue anyway? (y/n): " continue_anyway
            if [[ "$continue_anyway" != "y" ]]; then
                continue
            fi
        fi
        
        # Use defaults for mount options
        local mount_opts="defaults"
        
        # Store drive info
        DRIVE_INFO["${drive_count}_device"]="$device"
        DRIVE_INFO["${drive_count}_uuid"]="$uuid"
        DRIVE_INFO["${drive_count}_fstype"]="$fstype"
        DRIVE_INFO["${drive_count}_mountpoint"]="$mountpoint"
        DRIVE_INFO["${drive_count}_options"]="$mount_opts"
        
        ((drive_count++))
        
        log_info "✓ Drive $device configured (UUID: $uuid)"
        echo ""
    done
    
    DRIVE_INFO["count"]=$drive_count
    
    if [[ $drive_count -eq 0 ]]; then
        log_info "No additional drives to configure"
    else
        log_info "Collected information for $drive_count drive(s)"
    fi
}

# Configure all collected drives
configure_additional_drives() {
    local count=${DRIVE_INFO["count"]:-0}
    
    if [[ $count -eq 0 ]]; then
        log_info "Skipping additional drive configuration"
        return 0
    fi
    
    log_info "Configuring $count additional drive(s)..."
    
    # Backup fstab
    sudo cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)
    log_info "Backed up /etc/fstab"
    
    local configured=0
    
    for ((i=0; i<count; i++)); do
        local device="${DRIVE_INFO["${i}_device"]}"
        local uuid="${DRIVE_INFO["${i}_uuid"]}"
        local fstype="${DRIVE_INFO["${i}_fstype"]}"
        local mountpoint="${DRIVE_INFO["${i}_mountpoint"]}"
        local options="${DRIVE_INFO["${i}_options"]}"
        
        log_info "Configuring /dev/$device..."
        
        # Check if already in fstab
        if grep -q "$uuid" /etc/fstab; then
            log_warn "UUID $uuid already in fstab, skipping"
            continue
        fi
        
        # Create mount point
        if [[ ! -d "$mountpoint" ]]; then
            sudo mkdir -p "$mountpoint"
            log_info "Created mount point: $mountpoint"
        fi
        
        # Determine fsck pass number
        local fsck_pass=2
        if [[ "$mountpoint" == "/" ]]; then
            fsck_pass=1
        elif [[ "$fstype" == "vfat" ]] || [[ "$fstype" == "exfat" ]] || [[ "$fstype" == "ntfs" ]]; then
            fsck_pass=0
        fi
        
        # Add to fstab
        echo "UUID=$uuid  $mountpoint  $fstype  $options  0  $fsck_pass" | sudo tee -a /etc/fstab > /dev/null
        
        ((configured++))
        log_info "✓ Added /dev/$device to fstab"
    done
    
    # Test fstab
    log_info "Testing fstab configuration..."
    if sudo mount -a 2>/dev/null; then
        log_info "✓ Successfully configured $configured drive(s)"
        
        # Show mounted drives
        echo ""
        log_info "Mounted drives:"
        for ((i=0; i<count; i++)); do
            local mountpoint="${DRIVE_INFO["${i}_mountpoint"]}"
            if mountpoint -q "$mountpoint" 2>/dev/null; then
                echo "  ✓ $mountpoint"
            fi
        done
    else
        log_error "✗ Failed to mount drives. Restoring backup..."
        sudo cp /etc/fstab.backup.$(date +%Y%m%d_%H%M%S) /etc/fstab
        log_error "Please check drive configuration manually"
        return 1
    fi
}