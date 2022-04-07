#!/bin/bash
set -euo pipefail

panic () {
  echo 1 > /proc/sys/kernel/sysrq || true
  echo c > /proc/sysrq-trigger || true
}

# as a fallback - if no extra state disk is found - the CoreOS image has an extra partition with a fixed UUID that can hold encrypted state.
# The UUID is set during image creation.
STATEFUL_PART_UUID=57A7EF-57A7-57A7-57A7-57A7EF01
STATEFUL_PART_LABEL=stateful
STATEFUL_PART_NUMBER=6
STATEFUL_DISK_BY_PARTLABEL="/dev/disk/by-partlabel/${STATEFUL_PART_LABEL}"
ROOT_DISK="/dev/$(lsblk -ndo pkname "${STATEFUL_DISK_BY_PARTLABEL}")"
STATEFUL_DISK="/dev/$(lsblk -dno NAME "${STATEFUL_DISK_BY_PARTLABEL}")"

# Prepare the encrypted volume by either initializing it with a random key or by aquiring the key from another coordinator.
# Create symlink to encrypted state disk at /dev/disk/by-id/state-disk (for example: /dev/disk/by-id/state-disk -> /dev/nvme0n2).
# Store encryption key (random or recovered key) in /run/cryptsetup-keys.d/state.key
# Store information about the type of boot (first boot / subsequent boot) in /run/constellation-boot
mkdir -p /dev/disk/by-id/
ln -s "${STATEFUL_DISK}" /dev/disk/by-id/state-disk
mkdir -p /run/cryptsetup-keys.d
echo "testestetsetestsetsetets" > /run/cryptsetup-keys.d/state.key
chmod 0400 /run/cryptsetup-keys.d/state.key
echo "first-boot" > /run/constellation-boot
cryptsetup --cipher aes-xts-plain --key-size 512 --hash sha512 luksFormat --batch-mode --key-file /run/cryptsetup-keys.d/state.key "${STATEFUL_DISK}"
cryptsetup luksDump "${STATEFUL_DISK}"
cryptsetup open --type luks --key-file /run/cryptsetup-keys.d/state.key "${STATEFUL_DISK}" state
cryptsetup status state
