#######################
## Disk partitioning ##
#######################
# pass as first parameter the dev designation such as /dev/vda
# passed disk should be a minimum of 30GB
# the second parameter should be the dev designation of the open cryptroot
# such as /dev/mapper/cryptroot
#
# to do on script
# 1. test in VM for parameter passing
# 2. go through crypt setup script and add script for LVM

# Format the boot disk - destroys the first 1MB of disk
#echo "Formating the disk $1..."
#dd if=/dev/zero of=$1 bs=1M count=100

# Create a new gpt partition table
#echo "Creating GPT partition table on $1..."
#parted -s $1 mklabel gpt

# Create efi partition
#echo "Creating $1 EFI partition..."
#parted -s -a optimal $1 mkpart primary fat32 2048s 1G

# Create root partition
#echo "Creating linux partition on rest of free space..."
#parted -s -a optimal $1 mkpart primary ext4 1G 95%

# Set esp on efi partition
#echo "Setting esp flag on EFI partition..."
#parted -s $1 set 1 esp on

#####################
## Disk encryption ##
#####################

# Encrypt root partition
#echo "Encrypt root partition with LUKS2 aes-512..."
#cryptsetup --label crypt --type luks2 --cipher aes-xts-plain64 --key-size 512 --hash sha512 --iter-time 1000 --use-random luksFormat $12

# Open encrypted partition
#echo "Opening crypt partition..."
#cryptsetup open --allow-discards --type luks $12 cryptroot

##########################
## Setup Main Volume LVM##
##########################

# Make root partition into an LV group
echo "creating logical volume group on root partition..."
vgcreate cryptgroup $2 
echo "creating root logical volume..."
lvcreate --name root -L 10G cryptgroup
echo "creating swap logical volume..."
lvcreate --name swap -L 4G cryptgroup
echo "creating home logical volume..."
lvcreate --name home -l 80%FREE cryptgroup

echo "Creating EFI filesystem FAT32..."
mkfs.fat -F 32 -n EFI $1
#mkfs.ext4 -L ROOT /dev/mapper/cryptroot

echo "creating root filesystem ext4..."
mkfs.ext4 -L root /dev/cryptgroup/root
echo "creating swap filesystem..."
mkswap /dev/cryptgroup/swap
echo "mounting swap volume..."
swapon /dev/cryptgroup/swap
echo "creating home filesystem ext4..."
mkfs.ext4 -L home /dev/cryptgroup/home

########################################
## Mount Volumes to Target Filesystem ##
########################################

# Swap is already mounted, but EFI, root and home still need to be mounted

# mount root and home
echo "mounting root to target filesystem..."
mount /dev/cryptgroup/root /mnt

echo "mounting home to target filesystem..."
mkdir -p /mnt/home
mount /dev/cryptgroup/home /mnt/home

# since the intention is to use an EFI stub for boot, only create a /mnt/boot folder and mount to EFI partition
echo "mounting EFI stub directory..."
mkdir -p /mnt/boot
mount $1 /mnt/boot

# make the folder for the xbps keys and copy them over
mkdir -p /mnt/var/db/xbps/keys
cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/

# install base system and required utilities into the target system
XBPS_ARCH=x86_64 xbps-install -Sfy -R https://repo-default.voidlinux.org/current -R https://repo-default.voidlinux.org/current/nonfree -r /mnt base-system lvm2 cryptsetup refind efibootmgr sbctl sbsigntool efitools seatd bluez dbus pipewire wireplumber sbsigntool tlp tpm2-tools Vulkan-Tools
# installing refind just in case the EFI stub is not recognized by the BIOS
# it can be bypassed if the BIOS sees the EFI stub

# generate the filesystem table
xgenfstab /mnt > /mnt/etc/fstab

# Checklist for installation setup
# - setup dracut to:
#  - make a UKI - and place in the unencrypted boot partition
#  - the UKI will be seen by the BIOS, set by the efibootmgr
#  - the UKI will unlock the encrypted root drive
#  - the UKI will find the filesystem and boot
#  - update the UKI to the rolling release kernel
# - secure boot tools signs the UKI
#  - put hooks into dracut to resign the UKI with any initramfs/kernel update
# - reboot and activate the secure boot and make sure its ok with the UKI
# - move keys into TPM2 and set TPM to unlock with TPM pin
