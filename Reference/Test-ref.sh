#!/bin/bash

set -e

# Set your target disk here
DISK="/dev/sdX"  # <- Replace with your actual disk, e.g., /dev/sda

# Hostname and user info
HOSTNAME="archlinux"
USERNAME="user"
PASSWORD="password"

# Detect EFI or BIOS
if ls /sys/firmware/efi/efivars >/dev/null 2>&1; then
    BOOT_MODE="UEFI"
else
    BOOT_MODE="BIOS"
fi

echo "Installing in $BOOT_MODE mode on $DISK"

# Wipe disk
sgdisk --zap-all "$DISK" || wipefs -a "$DISK"

# Create partitions
if [ "$BOOT_MODE" == "UEFI" ]; then
    parted -s "$DISK" mklabel gpt
    parted -s "$DISK" mkpart ESP fat32 1MiB 1025MiB
    parted -s "$DISK" set 1 esp on
    BOOT_PART="${DISK}1"
    SWAP_PART="${DISK}2"
    ROOT_PART="${DISK}3"
    HOME_PART="${DISK}4"
    parted -s "$DISK" mkpart primary linux-swap 1025MiB 17409MiB
    parted -s "$DISK" mkpart primary ext4 17409MiB 78849MiB
    parted -s "$DISK" mkpart primary ext4 78849MiB 100%
else
    parted -s "$DISK" mklabel msdos
    parted -s "$DISK" mkpart primary ext4 1MiB 62464MiB
    parted -s "$DISK" mkpart primary linux-swap 62464MiB 78848MiB
    parted -s "$DISK" mkpart primary ext4 78848MiB 100%
    parted -s "$DISK" set 1 boot on
    BOOT_PART="${DISK}1"
    ROOT_PART="${DISK}1"
    SWAP_PART="${DISK}2"
    HOME_PART="${DISK}3"
fi

# Format partitions
if [ "$BOOT_MODE" == "UEFI" ]; then
    mkfs.fat -F32 "$BOOT_PART"
else
    mkfs.ext4 "$BOOT_PART"
fi

mkfs.ext4 "$ROOT_PART"
mkfs.ext4 "$HOME_PART"
mkswap "$SWAP_PART"
swapon "$SWAP_PART"

# Mount partitions
mount "$ROOT_PART" /mnt
mkdir -p /mnt/home
mount "$HOME_PART" /mnt/home

if [ "$BOOT_MODE" == "UEFI" ]; then
    mkdir -p /mnt/boot/efi
    mount "$BOOT_PART" /mnt/boot/efi
else
    mkdir -p /mnt/boot
    mount "$BOOT_PART" /mnt/boot
fi

# Install base system
pacstrap /mnt base linux linux-lts linux-firmware sudo networkmanager \
    grub efibootmgr dosfstools os-prober mtools \
    plasma kde-applications xorg sddm \
    nano vi

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot and configure system
arch-chroot /mnt /bin/bash <<EOF

# Set timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

# Set locale
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1   localhost" >> /etc/hosts
echo "::1         localhost" >> /etc/hosts
echo "127.0.1.1   $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

# Set root password
echo "root:$PASSWORD" | chpasswd

# Create user
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

# Enable services
systemctl enable NetworkManager
systemctl enable sddm

# Install bootloader
if [ "$BOOT_MODE" == "UEFI" ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
else
    grub-install --target=i386-pc "$DISK"
fi

grub-mkconfig -o /boot/grub/grub.cfg

EOF

echo "✅ Installation complete. You can now reboot into your new Arch system."
