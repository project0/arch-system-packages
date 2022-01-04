#!/bin/bash -e
# setup target disk for installation

DM_NAME=root

DEVICE="$1"
ENCRYPT=${2-false}
ARCH_INSTALL=${3-/mnt/arch_install}

_fatal() {
  echo "$1"
  exit 1
}

[ -b "$DEVICE" ] ||  _fatal "device '$DEVICE' not found"

# Backup
# In case of emergency we may want to know the old layout...
sfdisk -l
backup_table="/root/sfdisk.$(date +%s)"
sfdisk --backup -d "$DEVICE" > "${backup_table}.dump" || echo "No parition table found, no backup generated"

echo "Partition layout can be restored with, see also man sfdisk:"
echo "sfdisk -f '$DEVICE' < $backup_table.dump"
echo 'example from docs: dd if=~/sfdisk-sda-0x00000200.bak of=/dev/sda seek=$0x00000200 bs=1 conv=notrunc'
echo
echo "Please also check setting proper sectore size first! e.g.: "
echo "nvme id-ns -H $DEVICE"
echo "nvme format $DEVICE --lbaf=1 --reset"
echo

read -p "Are you sure to continue reset device '$DEVICE' (y/n) ?" -n 1 -r confirm
echo    # (optional) move to a new line
[[ "$confirm" =~ ^[Yy]$ ]] || _fatal "aborted"

# init new table with layout, sector size will be used properly
sfdisk "$DEVICE"  << EOF
label: gpt
name=ESP,size=512MB,type=uefi
name=boot,size=1024MB,type=linux-extended-boot
name=crypt,type=linux
EOF

_get_partition(){
  # $1 == partition number + 1
  lsblk "$DEVICE" -o NAME -n  -p  --raw  | tail -n +"$1" | head -n 1
}

device_esp=$(_get_partition "2")
device_boot=$(_get_partition "3")
device_crypt=$(_get_partition "4")
device_root="$device_crypt"

### Encryption
if [ "$ENCRYPT" == "true" ]; then
  cryptsetup luksFormat "$device_crypt"
  cryptsetup luksOpen "$device_crypt" "$DM_NAME"

  device_root=/dev/mapper/"$DM_NAME"
fi

### Format
mkfs.vfat     "$device_esp"
mkfs.ext4  -F  "$device_boot"
mkfs.btrfs -f "$device_root"

mkdir -p "$ARCH_INSTALL"
mount "$device_root" "$ARCH_INSTALL"

### btrfs create all subvolumes
for subvol in {'',home,var/log,var/spool,var/lib/docker}; do
  subvol="${subvol//\//_}"
  btrfs subvolume create "$ARCH_INSTALL"/@"$subvol"
done
btrfs subvolume set-default "$ARCH_INSTALL"/@

# proper remount for fstab generation
umount "$ARCH_INSTALL"
mount "$device_root" "$ARCH_INSTALL"

# subvols
for subvol in {home,var/log,var/spool,var/lib/docker}; do
  mkdir -p "$ARCH_INSTALL"/"$subvol"
  subvolid="${subvol//\//_}"
  mount "$device_root" -o subvol=@"$subvolid" "$ARCH_INSTALL"/"$subvol"
done

### boot partitions
mkdir -p "$ARCH_INSTALL"/{boot,efi}
mount "$device_boot" "$ARCH_INSTALL"/boot
mount "$device_esp" "$ARCH_INSTALL"/efi

# setup EFI
mkdir -p "$ARCH_INSTALL"/efi/EFI  "$ARCH_INSTALL"/boot/efi
mount --bind "$ARCH_INSTALL"/efi "$ARCH_INSTALL"/boot/efi
