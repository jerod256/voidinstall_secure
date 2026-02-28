#######################
## Disk partitioning ##
#######################
# pass as first parameter the dev designation such as /dev/vda
# passed disk should be a minimum of 16GB
#
# to do on script
# 1. test in VM for parameter passing
# 2. go through crypt setup script and add script for LVM

# Format the boot disk - destroys the first 1MB of disk
echo "Formating the disk $1..."
dd if=/dev/zero of=$1 bs=1M count=100

# Create a new gpt partition table
echo "Creating GPT partition table on $1..."
parted -s $1 mklabel gpt

# Create efi partition
echo "Creating $1 EFI partition..."
parted -s -a optimal $1 mkpart primary fat32 2048s 1G

# Create root partition
echo "Creating linux partition on rest of free space..."
parted -s -a optimal $1 mkpart primary ext4 1G 95%

# Set esp on efi partition
echo "Setting esp flag on EFI partition..."
parted -s $1 set 1 esp on

###****
CURRENTLY UNTESTED FROM THIS POINT
###****


#####################
## Disk encryption ##
#####################

# Encrypt root partition
echo "Encrypt root partition with LUKS2 aes-512..."
cryptsetup --label crypt --type luks2 --cipher aes-xts-plain64 --key-size 512 --hash sha512 --iter-time 1000 --use-random luksFormat $12

# Open encrypted partition
echo "Opening crypt partition..."
cryptsetup open --allow-discards --type luks $12 cryptroot

##########################
## Setup Main Volume LVM##
##########################

# Make root partition into an LV group
echo "creating logical volume group on root partition..."
vgcreate cryptroot /dev/mapper/cryptroot
echo "creating root logical volume..."
lvcreate --name root -L 10G cryptroot
echo "creating swap logical volume..."
lvcreate --name swap -L 4G cryptroot
echo "creating home logical volume..."
lvcreate --name home -l 80%FREE cryptroot

echo "Creating EFI filesystem FAT32..."
mkfs.fat -F 32 -n EFI $11
#mkfs.ext4 -L ROOT /dev/mapper/cryptroot

echo "creating root filesystem ext4..."
mkfs.ext4 -L root /dev/cryptroot/root
echo "creating swap filesystem..."
mkswap /dev/cryptroot/swap
echo "mounting swap volume..."
swapon /dev/cryptroot/swap
echo "creating home filesystem ext4..."
mkfs.ext4 -L home /dev/cryptroot/home

########################################
## Mount Volumes to Target Filesystem ##
########################################

# Swap is already mounted, but EFI, root and home still need to be mounted

# mount root and home
echo "mounting root to target filesystem..."
mount /dev/cryptroot/root /mnt

echo "mounting home to target filesystem..."
mkdir -p /mnt/home
mount /dev/cryptroot/home /mnt/home

# since the intention is to use an EFI stub for boot, only create a /mnt/boot folder and mount to EFI partition
echo "mounting EFI stub directory..."
mkdir -p /mnt/boot
mount $11 /mnt/boot
