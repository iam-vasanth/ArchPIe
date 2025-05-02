#!/bin/bash

set -e

echo "==> Welcome to the Arch Auto-Reinstall Script"

HOSTNAME="Enma"
USERNAME="zoro"
PASSWORD="vasu"

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
        BOOT_MODE=UEFI
    else
        BOOT_MODE=BIOS
    fi
}

UEFI_check
UEFI=$?
# Create partitions
echo "==> Creating partitions..."
if [ $BOOT_MODE == "UEFI" ]; then
    parted -s "$DISK" mklabel gpt
    parted -s "$DISK" mkpart ESP fat32 1MiB 1025MiB
    parted -s "$DISK" set 1 esp on
    parted -s "$DISK" mkpart primary linux-swap 1025MiB 17409MiB
    parted -s "$DISK" mkpart primary ext4 17409MiB 78849MiB
    parted -s "$DISK" mkpart primary ext4 78849MiB 100%
else
    parted -s "$DISK" mklabel msdos
    parted -s "$DISK" mkpart primary ext4 1MiB 62464MiB
    parted -s "$DISK" mkpart primary linux-swap 62464MiB 78848MiB
    parted -s "$DISK" mkpart primary ext4 78848MiB 100%
    parted -s "$DISK" set 1 boot on
fi

# Determine partition naming scheme
if [ $Main_Disk == *"nvme"* ]; then
    PART_SUFFIX="p"
else
    PART_SUFFIX=""
fi

# Format partitions
echo "==> Formatting partitions..."

# Format partitions

# Boot partition
BOOT_PART="${Main_Disk}${PART_SUFFIX}1"
echo "Formatting boot partition ($BOOT_PART)..."
if [ "$BOOT_MODE" == "UEFI" ]; then
    mkfs.fat -F32 "$BOOT_PART"
    mount --mkdir /dev/$BOOT_PART /mnt/boot/efi
else
    mkfs.ext4 "$BOOT_PART"
    mount --mkdir /dev/$BOOT_PART /mnt/boot
fi

# Swap partition
SWAP_PART="${Main_Disk}${PART_SUFFIX}2"
echo "Setting up swap partition ($SWAP_PART)..."
mkswap $SWAP_PART
swapon $SWAP_PART

# Root partition
ROOT_PART="${Main_Disk}${PART_SUFFIX}3"
echo "Formatting root partition ($ROOT_PART) as ext4..."
mkfs.ext4 $ROOT_PART
# Mount root partition
mount /dev/$ROOT_PART /mnt

# Home partition (optional)
HOME_PART="${Main_Disk}${PART_SUFFIX}4"
echo "Formatting home partition ($HOME_PART) as ext4..."
mkfs.ext4 $HOME_PART
# Mount home partition
mount --mkdir /dev/$HOME_PART /mnt/home

echo "==> Partitions formatted and mounted successfully!"
pacstrap /mnt base base-devel linux linux-headers linux-lts linux-lts-headers linux-firmware neovim amd-ucode