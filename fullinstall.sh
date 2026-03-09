#!/bin/bash
######################################
### Secure Void Linux Installation ###
### by: Liz Boudreau		   ###
### License: GPL-2.0		   ###
######################################

### This script will do a fully guided installation of void linux from the command line
### it is meant to be run from a live installation image of void linux
### this script was designed and tested with the void linux image released in 2025 and assumes Linux 6.12

### This script is a work in progress, use at your own risk. It is not supported. Issues will be ignored.
### Sources used for creating this script: man-pages, void linux manual, and https://github.com/dylanbegin/void-install.git

### The target system will have the following installation features and qualities
### Root, home and swap (partition) in an LVM on a LUKS2 partition
### An EFI partition containing a UKI
### Target system is assumed to have capabilities for EFI stub, Secure boot and a TPM2 chip and use will be made of these features

### to run this script, run the following manually:
### # mkdir /install
### # cd /install
### # xbps-install -Sfu xbps
### # xbps-install -Sfy parted git
### # git clone https://github.com/jerod256/voidinstall_secure.git
### # cd voidinstall_secure
### # chmod +x fullinstall.sh
### # ./fullinstall.sh

### set global variables
arch=x86_64
mirror="https://repo-default.voidlinux.org/current"
mirror_nonfree="https://repo-default.voidlinux.org/current/nonfree"

### variables to be set (with defaults)
default_disk="vda"
default_efi_size="1024MiB"
LANG="en_US.UTF-8"
default_host="laptop"
default_USER="lizluv"
default_PASSWD="1234"
default_CRYPTPASS="56789"

### packages to be loaded into the live session for installation (seems to be required manually before this script is run)
#pkg_preinst="parted git"
#package list for basic system setup
pkg_base="base-system cryptsetup efibootmgr nftables networkmanager sbctl vim git lvm2 refind sbsigntool efitools tpm2-tools"
### package list for system utilities, daemons, drivers, etc
pkg_sysutils="tlp base-devel bluez git wget curl git btop udisksctl"
### package list for graphical desktop environment
pkg_gui="seatd pipewire wireplumber xdg_desktop_portal_wlroots polkit dbus fuzzel wl-clipboard swaybg waybar swaylock swayidle grim slurp wiremix bluetui nwg-look nwg-drawer kitty foot ffmpeg firefox"

### gathers information
### 1. target disk label
lsblk
echo -n "Enter the name of the target disk as shown above [leave blank for default]"
read temp_disk
disk="${temp_disk:-$default_disk}"
echo
echo

### 2. EFI partition size
echo -n "Enter the size of the partition [leave blank for default]"
read temp_efisize
efi_size="${temp_efisize:-$default_efi_size}"
echo
echo

### 3. User name
echo -n "Enter the username [leave blank for default]"
read temp_username
USER="${temp_username:-$default_USER}"
echo
echo

### 4. user password (also will be used for root)
while true; do
	echo -n "Enter password"
	read -s PASS1

	echo -n "Verify password"
	read -s PASS2

	if [ "$PASS1" = "$PASS2" ]; then
		echo "Password successfully set."
		break
	else
		echo "Match failed. Try again."
	fi
done

### 5. cryptsetup passphrase, will be used to decrypt root drive
while true; do
	echo -n "Enter encryption passphrase"
	read -s CRYPTPASS1

	echo -n "Verify passphrase"
	read -s CRYPTPASS2

	if [ "$PASS1" = "$PASS2" ]; then
		echo "Passphrase successfully set."
		break
	else
		echo "Match failed. Try again."
	fi
done


### Enters into disk preparation:
echo "Formatting the disk $disk..."
dd if=/dev/zero of=/dev/${disk} bs=1M count=100

### Create a new gpt partition table
echo "Creating GPT partition table on $disk..."
parted -s /dev/${disk} mklabel gpt

### Create efi partition
echo "Creating $disk EFI partition..."
parted -s -a optimal /dev/${disk} mkpart primary fat32 2048s $efi_size

### Create root partition
echo "Creating linux partition on rest of free space..."
parted -s -a optimal /dev/${disk} mkpart primary ext4 $efi_size 100%

### Set esp flag on efi partition
echo "Setting esp flag on EFI partition..."
parted -s /dev/${disk} set 1 esp on

### Encrypt root partition
echo "Encrypt root partition with LUKS2 aes-512..."
echo "$CRYPTPASS1" | cryptsetup --label crypt --type luks2 --cipher aes-xts-plain64 --key-size 512 --hash sha512 --iter-time 1000 --use-random luksFormat /dev/${disk}2

### Open encrypted partition
echo "Opening crypt partition..."
echo "$CRYPTPASS1" | cryptsetup open --allow-discards --type luks /dev/${disk}2 cryptroot


### LVM Setup
### Make root partition into an LV group
echo "creating logical volume group on root partition..."
vgcreate cryptgroup /dev/mapper/cryptroot 
echo "creating root logical volume..."
lvcreate --name root -L 10G cryptgroup
echo "creating swap logical volume..."
lvcreate --name swap -L 4G cryptgroup
echo "creating home logical volume..."
lvcreate --name home -l 80%FREE cryptgroup

echo "Creating EFI filesystem FAT32..."
mkfs.fat -F 32 -n EFI /dev/${disk}1
#mkfs.ext4 -L ROOT /dev/mapper/cryptroot

echo "creating root filesystem ext4..."
mkfs.ext4 -L root /dev/cryptgroup/root
echo "creating swap filesystem..."
mkswap /dev/cryptgroup/swap
echo "mounting swap volume..."
swapon /dev/cryptgroup/swap
echo "creating home filesystem ext4..."
mkfs.ext4 -L home /dev/cryptgroup/home

### mount root and home
echo "mounting root to target filesystem..."
mount /dev/cryptgroup/root /mnt

echo "mounting home to target filesystem..."
mkdir -p /mnt/home
mount /dev/cryptgroup/home /mnt/home

# since the intention is to use an EFI stub for boot, only create a /mnt/boot folder and mount to EFI partition
echo "mounting EFI stub directory..."
mkdir -p /mnt/boot/efi
mount /dev/${disk}1 /mnt/boot/efi

