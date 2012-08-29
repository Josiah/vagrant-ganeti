# postinstall.sh created from Mitchell's official lucid32/64 baseboxes
set -x

date > /etc/vagrant_box_build_time

# Use newer puppet
wget http://apt.puppetlabs.com/puppetlabs-release_1.0-3_all.deb
dpkg -i puppetlabs-release_1.0-3_all.deb
rm puppetlabs-release_1.0-3_all.deb

# Apt-install various things necessary for Ruby, guest additions,
# etc., and remove optional things to trim down the machine.
apt-get -y update
apt-get -y upgrade
apt-get -y install linux-headers-$(uname -r) build-essential vim puppet \
    git-core lvm2 aptitude
apt-get clean

# Setup sudo to allow no-password sudo for "admin"
cp /etc/sudoers /etc/sudoers.orig
sed -i -e '/Defaults\s\+env_reset/a Defaults\texempt_group=admin' /etc/sudoers
sed -i -e 's/%admin ALL=(ALL) ALL/%admin ALL=NOPASSWD:ALL/g' /etc/sudoers

# Install NFS client
apt-get -y install nfs-common

# Installing vagrant keys
mkdir /home/vagrant/.ssh
chmod 700 /home/vagrant/.ssh
cd /home/vagrant/.ssh
wget --no-check-certificate 'https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub' -O authorized_keys
chmod 600 /home/vagrant/.ssh/authorized_keys
chown -R vagrant /home/vagrant/.ssh

# Installing the virtualbox guest additions
VBOX_VERSION=$(cat /home/vagrant/.vbox_version)
cd /tmp
mount -o loop /home/veewee/VBoxGuestAdditions_$VBOX_VERSION.iso /mnt
sh /mnt/VBoxLinuxAdditions.run
umount /mnt
rm /home/veewee/VBoxGuestAdditions_$VBOX_VERSION.iso

# Remove items used for building, since they aren't needed anymore
apt-get -y remove linux-headers-$(uname -r) build-essential
apt-get -y autoremove

# Setting editors
update-alternatives --set editor /usr/bin/vim.basic

# Configure LVM
echo "configuring LVM"
swapoff -a
parted /dev/sda -- rm 2
parted /dev/sda -- mkpart primary ext2 15GB -1s
parted /dev/sda -- toggle 2 lvm
pvcreate /dev/sda2
vgcreate ganeti /dev/sda2
lvcreate -L 512M -n swap ganeti
mkswap -f /dev/ganeti/swap
sed -i -e 's/sda5/ganeti\/swap/' /etc/fstab

# Add ganeti image
echo "adding ganeti guest image"
mkdir -p /var/cache/ganeti-instance-image/
wget -O /var/cache/ganeti-instance-image/cirros-0.3.0-x86_64.tar.gz http://staff.osuosl.org/~ramereth/ganeti-tutorial/cirros-0.3.0-x86_64.tar.gz

# Removing leftover leases and persistent rules
echo "cleaning up dhcp leases"
rm /var/lib/dhcp3/*

# Make sure Udev doesn't block our network
# http://6.ptmc.org/?p=164
echo "cleaning up udev rules"
rm /etc/udev/rules.d/70-persistent-net.rules
mkdir /etc/udev/rules.d/70-persistent-net.rules
rm -rf /dev/.udev/
rm /lib/udev/rules.d/75-persistent-net-generator.rules

# Zero out the free space to save space in the final image:
dd if=/dev/zero of=/EMPTY bs=1M
rm -f /EMPTY

echo "Adding a 2 sec delay to the interface up, to make the dhclient happy"
echo "pre-up sleep 2" >> /etc/network/interfaces
exit
