#!/bin/bash

set -e

echo "==> Welcome to the Arch Auto-Reinstall Script (Safe for /home)"
echo

# Show available partitions
lsblk -p -o NAME,SIZE,FSTYPE,MOUNTPOINT

# Prompt for partitions
read -rp "Enter ROOT partition (will be formatted): " ROOT_PART
read -rp "Enter HOME partition (will NOT be formatted): " HOME_PART
read -rp "Enter EFI partition (usually /dev/sdX1 or /dev/nvmeXn1p1): " EFI_PART

# Confirm before proceeding
echo
echo "⚠️  About to format $ROOT_PART and reinstall Arch Linux."
read -rp "Are you sure? [y/N]: " CONFIRM
[[ $CONFIRM != "y" && $CONFIRM != "Y" ]] && { echo "Aborted."; exit 1; }

# Prompt for system settings
read -rp "Enter hostname: " HOSTNAME
read -rp "Enter username: " USERNAME
read -rsp "Enter password for root and user: " PASSWORD
echo

# Set up mount point
MNT="/mnt"
echo "==> Formatting $ROOT_PART..."
mkfs.ext4 -F "$ROOT_PART"

echo "==> Mounting partitions..."
mount "$ROOT_PART" "$MNT"
mkdir -p "$MNT/home"
mount "$HOME_PART" "$MNT/home"
mkdir -p "$MNT/boot/efi"
mount "$EFI_PART" "$MNT/boot/efi"

echo "==> Installing base system..."
pacstrap "$MNT" base linux linux-firmware sudo networkmanager grub efibootmgr

echo "==> Generating fstab..."
genfstab -U "$MNT" >> "$MNT/etc/fstab"

echo "==> Chrooting and configuring system..."
arch-chroot "$MNT" /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME" > /etc/hosts

echo "root:$PASSWORD" | chpasswd

useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

systemctl enable NetworkManager

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
EOF

echo "✅ Done! Arch reinstalled with your /home untouched!"
