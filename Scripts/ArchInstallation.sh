#!/bin/bash

set -e

echo "==> Welcome to the Arch Auto-Reinstall Script"

# Checking if ethernet is connected
echo "Checking the internet connection..."

# Function to check internet connection
check_internet() {
    if ping -q -c 1 -W archlinux.org >/dev/null; then
        echo "Internet connection is active."
        return 0
    else
        echo "No internet connection detected."
        return 1
    fi
}

# Initial internet check
check_internet
internet_status=$?

# Loop until the user resolves the issue or exits
while [ $internet_status -ne 0 ]; do
    echo "Would you like to:"
    echo "1) Check again for an internet connection"
    echo "2) Connect to Wi-Fi manually"
    echo "3) Exit the script"
    read -p "Enter 1, 2, or 3: " choice

    case $choice in
        1)
            echo "Rechecking internet connection..."
            check_internet
            internet_status=$?
            ;;
        2)
            echo "You can connect to Wi-Fi using nmtui (NetworkManager TUI)."
            echo "Starting nmtui..."
            nmtui
            check_internet
            internet_status=$?
            ;;
        3)
            echo "Exiting the script."
            exit 0
            ;;
        *)
            echo "Invalid option. Please choose 1, 2, or 3."
            ;;
    esac
done

clear

# Sync date and time
timedatectl set-ntp true

# Display the disk layout
echo "==> Available partitions:"
lsblk -p -o NAME,SIZE,FSTYPE,MOUNTPOINT

# Partition the disk
read -rp "Enter the disk to partition (e.g., /dev/sda): " Main_Disk
read -rp "Enter the size of the boot partition (e.g., 1-2G): " BOOT_SIZE
read -rp "Enter the size of the swap partition (e.g., 20G): " SWAP_SIZE
read -rp "Enter the size of the root partition (e.g., 20G): " ROOT_SIZE

# Check if bios is UEFI(32bit or 64bit) or BIOS
UEFI_check() {
    if cat /sys/firmware/efi/fw_platform_size >/dev/null; then
        echo "UEFI detected."
        return 0
    else
        echo "BIOS detected."
        return 1
    fi
}

UEFI_check
UEFI=$?
# Create partitions
echo "==> Creating partitions..."
if [ $UEFI -eq 0 ]; then
    gdisk -Z $Main_Disk
    gdisk -n 1:0:+$BOOT_SIZE -t 1:ef00 -c 1:boot -l $Main_Disk
    gdisk -n 2:0:+$SWAP_SIZE -t 2:8200 -c 2:Swap -l $Main_Disk
    gdisk -n 3:0:+$ROOT_SIZE -t 3:8300 -c 3:Root -l $Main_Disk
    gdisk -n 4:0:0 -t 4:2300 -c 4:Home -l $Main_Disk
    gdisk -w $Main_Disk
    else
    fdisk $Main_Disk <<EOF
g
n
+${BOOT_SIZE}
n
+${SWAP_SIZE}
n
+${ROOT_SIZE}
n
w
EOF
fi