#!/bin/bash
set -euo pipefail
shopt -s extglob nullglob

panic () {
  echo 1 > /proc/sys/kernel/sysrq || true
  echo c > /proc/sysrq-trigger || true
}

# as a fallback - if no extra state disk is found - the CoreOS image has an extra partition with a fixed UUID that can hold encrypted state.
# The UUID is set during image creation.
STATEFUL_PART_UUID_UNITIALIZED=57A7EF01-57A7-57A7-57A7-57A7EF011000 # UUID of an unintialized partition
STATEFUL_PART_UUID_INITIALIZED=57A7EF01-57A7-57A7-57A7-57A7EF011FFF # UUID of an initialized paritition
STATEFUL_PART_LABEL=stateful
STATEFUL_PART_NUMBER=6
STATEFUL_DISK_BY_PARTLABEL="/dev/disk/by-partlabel/${STATEFUL_PART_LABEL}"
ROOT_DISK="/dev/$(lsblk -ndo pkname "${STATEFUL_DISK_BY_PARTLABEL}")"
STATEFUL_DISK="/dev/$(lsblk -dno NAME "${STATEFUL_DISK_BY_PARTLABEL}")"

# hack: google nvme udev rules are never executed. Create symlinks for the nvme devices manually.
for nvmedisk in /dev/nvme0n+([0-9])
do
  /usr/lib/udev/google_nvme_id -s -d "${nvmedisk}" || true
done

# changing the GPT/parition table of the boot disk causes PCR[5] to be different on reboot
# this means the node will not be able to automatically request its encryption key, and manual recovery is required
# to avoid this we only resize the fallback partition if absolutely necessary, i.e. if no external disk exists
if [ ! -L "/dev/disk/by-id/google-state-disk" ] && [ ! -L "/dev/disk/azure/scsi1/lun0" ]
then
  # only  resize the disk if it is not already initialized
  # we change the UUID of the partition to mark it as initialized
  IFS=" " read -r -a guid <<< "$(sgdisk -i ${STATEFUL_PART_NUMBER} "${ROOT_DISK}" | grep "Partition unique GUID")"
  if [[ "${guid[3]}" == "$STATEFUL_PART_UUID_UNITIALIZED" ]]
  then
    end_position=$(sgdisk -E "${ROOT_DISK}")
    sgdisk -d "${STATEFUL_PART_NUMBER}" -e -n "${STATEFUL_PART_NUMBER}:0:$(( $end_position - ($end_position + 1) % 8 ))" -c "${STATEFUL_PART_NUMBER}:stateful" -u "${STATEFUL_PART_NUMBER}:${STATEFUL_PART_UUID_INITIALIZED}" -t 1:0700 "${ROOT_DISK}" || panic
    partx -u "${ROOT_DISK}"
    partx -u "${STATEFUL_DISK}"
  fi
fi

# Prepare the encrypted volume by either initializing it with a random key or by aquiring the key from another coordinator.
# Create symlink to encrypted state disk at /dev/disk/by-id/state-disk (for example: /dev/disk/by-id/state-disk -> /dev/nvme0n2).
# Store encryption key (random or recovered key) in /run/cryptsetup-keys.d/state.key
# Store information about the type of boot (first boot / subsequent boot) in /run/constellation-boot
mkdir -p /dev/disk/by-id/
ln -s "${STATEFUL_DISK}" /dev/disk/by-id/state-disk
echo "first-boot" > /run/constellation-boot
disk-mapper -csp "$(< /proc/cmdline tr  ' ' '\n' | grep ignition.platform.id | sed 's/ignition.platform.id=//')"