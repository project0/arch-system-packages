#!/usr/bin/bash -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

REPO_SERVER=${1-'https://arch.packages.project0.de'}
ARCH_INSTALL=${2-/mnt/arch_install}

# curl raw.github...
cp /etc/pacman.conf "/tmp/pacman.conf"
cat << EOF >> "/tmp/pacman.conf"
[project0-system]
Server = $REPO_SERVER/\$repo
[project0-aur]
Server = $REPO_SERVER/\$repo
[project0-packages]
Server = $REPO_SERVER/\$repo
EOF

read -p "Hostname: " -r hostname

# ensure keyring is up to date
pacman -Sy --noconfirm archlinux-keyring
pacstrap -i -C "/tmp/pacman.conf" "$ARCH_INSTALL" base linux "project0-host-${hostname,,}"

# finalize
# echo "$hostname" > "$ARCH_INSTALL"/etc/hostname # installed by package...
genfstab -t UUID "$ARCH_INSTALL" > "$ARCH_INSTALL"/etc/fstab

echo "Next steps:"
echo "arch-chroot $ARCH_INSTALL"
echo "Set root: passwd"
echo "User: useradd -m -s /bin/zsh -G wheel --btrfs-subvolume-home <user> && passwd <user>"
echo "Bootloader (usually automated): project0-refind-generate"
echo "Generate a recovery key: systemd-cryptenroll --recovery-key --wipe-slots=empty,recovery"
echo "Done!"

