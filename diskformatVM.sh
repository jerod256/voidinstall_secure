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
parted -s -a optimal $1 mkpart primary ext4 1G 100%

# Set esp on efi partition
echo "Setting esp flag on EFI partition..."
parted -s $1 set 1 esp on

#####################
## Disk encryption ##
#####################

# Encrypt root partition
echo "Encrypt root partition with LUKS2 aes-512..."
###cryptsetup --label crypt --type luks2 --cipher aes-xts-plain64 --key-size 512 --hash sha512 --iter-time 1000 --use-random luksFormat /dev/${DISK}p2

# Open encrypted partition
echo "Opening crypt partition..."
###cryptsetup open --allow-discards --type luks /dev/${DISK}p2 root

######################
## Filesystem setup ##
######################

# Make filesystems
echo "Creating filesystems..."
###mkfs.fat -F 32 -n EFI /dev/${DISK}p1
###mkfs.ext4 -L ROOT /dev/mapper/root

