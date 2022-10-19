#!/bin/bash -e
# setup target disk for installation


_fatal() {
  echo "FATAL: $1"
  exit 1
}

_info() {
  echo "INFO: $1"
}

DM_NAME=root
ENCRYPT=false
ARCH_INSTALL="/mnt/arch_install"
DEVICE=""
EXTRA_PARTITION="0"
SKIP_DISK_FORMAT=""
SKIP_FS_FORMAT=""
SKIP_MOUNT=""

usage="$(basename "$0") [-h] [-w size] [-e] [-sd] [-sf] [-sm] [-m path] <device> -- format and prepare disk for arch installation

where:
    -h  show this help text
    -p  extra partition size in GB (enabled only when set)
    -e  enable luks encryption
    -sd skip disk format and setup (use existing partition table)
    -sf skip filesystem format (use existing filesystems)
    -sm skip mounting filesystems
    -m  installation mount path (default: ${ARCH_INSTALL})"


while [[ $# -gt 0 ]]; do
  case $1 in
    -h)
      echo "$usage"
      exit 0
      ;;
    -p)
      EXTRA_PARTITION="$2"
      _info "Enable additional partition with ${2}GB"
      shift
      ;;
    -m)
      ARCH_INSTALL="$2"
      _info "Set mount path to ${2}"
      shift
      ;;
    -e)
      ENCRYPT=true
      _info "Enable LUKS encryption"
      ;;
    -sd)
      SKIP_DISK_FORMAT=true
      _info "Skip disk format"
      ;;
    -sf)
      SKIP_FS_FORMAT=true
      _info "Skip filesystem format"
      ;;
    -sm)
      SKIP_MOUNT=true
      _info "Skip mount"
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      DEVICE="$1"
      ;;
  esac
  shift

done

[ -b "$DEVICE" ] ||  _fatal "device '$DEVICE' not found."$'\n'"$usage"

if [ -z "$SKIP_DISK_FORMAT" ]; then
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

  # default partition
  partitions="name=linux,type=linux"
  if [ "$EXTRA_PARTITION" -gt 0 ]; then
      # add optional partition, size is reduced from the linux partition
      root_size=$(($(sfdisk -s "$DEVICE")/1024/1024-"$EXTRA_PARTITION"))
      partitions="${partitions},size=${root_size}GiB"$'\n'"name=extra"
  fi

  # init new table with layout, sector size will be used properly
  sfdisk "$DEVICE"  << EOF
  label: gpt
  name=ESP,size=512MB,type=uefi
  name=boot,size=1024MB,type=linux-extended-boot
  ${partitions}
EOF

fi

_get_partition(){
  # $1 == partition number + 1
  lsblk "$DEVICE" -o NAME -n  -p  --raw  | tail -n +"$1" | head -n 1
}

device_esp=$(_get_partition "2")
device_boot=$(_get_partition "3")
device_crypt=$(_get_partition "4")
device_root="$device_crypt"
if [ "$ENCRYPT" == "true" ]; then
  device_root=/dev/mapper/"$DM_NAME"
fi

if [ -z "$SKIP_FS_FORMAT" ]; then
  ### Encryption
  if [ "$ENCRYPT" == "true" ]; then
    cryptsetup luksFormat "$device_crypt"
    cryptsetup luksOpen "$device_crypt" "$DM_NAME"
  fi

  ### Format
  mkfs.vfat     "$device_esp"
  mkfs.ext4  -F "$device_boot"
  mkfs.btrfs -f "$device_root"

  # prepare btrfs subvolumes
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
fi

if [ -z "$SKIP_MOUNT" ]; then

  if [ "$ENCRYPT" == "true" ] && [ ! -b "$device_crypt" ]; then
    cryptsetup luksOpen "$device_crypt" "$DM_NAME"
  fi

  # proper remount for fstab generation
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
  mkdir -p "$ARCH_INSTALL"/efi/EFI "$ARCH_INSTALL"/boot/efi
  mount --bind "$ARCH_INSTALL"/efi "$ARCH_INSTALL"/boot/efi
fi