# before chrooting in cp this script chrootinstallconfig.sh into a temporary file in /mnt
# recommend /mnt/tmp/install/
# then cp <this file> /mnt/tmp/install/
# then chroot in using:
# xchroot /mnt

# then setup:
# chown root:root /
# chmod 755 /
# passwd root # then add the root password
# echo voidvm > /etc/hostname

# chrooted in, this script can be executed and will run:
echo "LANG=en_US.UTF-8" > /etc/local.conf
echo "en_US.UTF-8 UTF-8" >> /etc/default/libc-locales
xbps-reconfigure -f glibc-locales

# setup primary using
# run the following commands manually:
# useradd -m -G wheel,audio,video,cdrom,optical,storage,kvm,input,plugdev,users,xbuilder,bluetooth,_pipewire,_seatd -s /bin/bash $USER
# passwd $USER
# visudo EDITOR=vim /etc/sudoers
