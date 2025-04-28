#!/bin/bash

set -e

echo "==> Welcome to the Arch Auto-Reinstall Script"

HOSTNAME="Enma"
USERNAME="zoro"
PASSWORD="vasu"
read -p "Enter the disk to install Arch Linux (e.g., /dev/sda): " Main_Disk

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

# Sync date and time
timedatectl set-ntp true

# Create partitions
echo "==> Creating partitions..."
    parted -s "$DISK" mklabel gpt
    parted -s "$DISK" mkpart ESP fat32 1MiB 1025MiB
    parted -s "$DISK" set 1 esp on
    parted -s "$DISK" mkpart primary linux-swap 1025MiB 17409MiB
    parted -s "$DISK" mkpart primary ext4 17409MiB 78849MiB
    parted -s "$DISK" mkpart primary ext4 78849MiB 100%

# Format partitions
echo "==> Formatting partitions..."

# Format partitions

# Boot partition
BOOT_PART="${Main_Disk}p1"
echo "Formatting boot partition ($BOOT_PART)..."
mkfs.fat -F32 "$BOOT_PART"
mount --mkdir /dev/$BOOT_PART /mnt/boot/efi

# Swap partition
SWAP_PART="${Main_Disk}p2"
echo "Setting up swap partition ($SWAP_PART)..."
mkswap $SWAP_PART
swapon $SWAP_PART

# Root partition
ROOT_PART="${Main_Disk}p3"
echo "Formatting root partition ($ROOT_PART) as ext4..."
mkfs.ext4 $ROOT_PART
mount /dev/$ROOT_PART /mnt

# Home partition
HOME_PART="${Main_Disk}p4"
echo "Formatting home partition ($HOME_PART) as ext4..."
mkfs.ext4 $HOME_PART
mount --mkdir /dev/$HOME_PART /mnt/home

reflector -latest 20 -p https --sort rate --save /etc/pacman.d/mirrorlist

echo "==> Partitions formatted and mounted successfully!"
pacstrap /mnt base base-devel linux linux-headers linux-lts linux-lts-headers linux-firmware efibootmgr \
    grub os-prober amd-ucode reflector networkmanager plasma sddm konsole dolphin ark kwrite kcalc \
    spectacle krunner partitionmanager packagekit-qt5

# Generate fstab
echo "==> Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the new system
echo "==> Chrooting into the new system..."
arch-chroot /mnt /bin/bash <<EOF
# Set the timezone
ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
hwclock --systohc

# Set the locale
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set the hostname
echo $HOSTNAME > /etc/hostname

# Set hosts
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1   localhost" >> /etc/hosts
echo "::1         localhost" >> /etc/hosts
echo "127.0.1.1   $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

# Set root password
echo "root:$PASSWORD" | chpasswd

# Enable services
systemctl enable NetworkManager
systemctl enable sddm

# Install grub
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Create a new user
useradd -mG wheel $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Enable multilib repository
sed -i 's/^#\[multilib\]/\[multilib\]/' /etc/pacman.conf
sudo pacman -Syu

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB