#!/bin/bash
set -euo pipefail

# Extract dm-verity hash from kernel cmdline
roothash=$(cat /proc/cmdline)
roothash="${roothash##*verity.sysroot=}"
roothash="${roothash%% *}"
if [[ $roothash =~ ^[a-f0-9]{64}$ ]]
then
    echo "dm-verity roothash (kernel cmdline verity.sysroot) contains well formatted hash: ${roothash}"
else
    echo "dm-verity roothash (kernel cmdline verity.sysroot) contains improperly formatted hash"
    exit 1
fi

rootdevicepath=/dev/disk/by-partlabel/root_raw
hashdevicepath=/dev/disk/by-partlabel/root_verity
vsysrootmapper=/dev/mapper/vsysroot
if ! [ -b "${rootdevicepath}" ]; then
  echo "verity-setup: Failed to find root_raw: ${rootdevicepath}" 1>&2
  exit 1
fi
if ! [ -b "${hashdevicepath}" ]; then
  echo "verity-setup: Failed to find root_verity: ${hashdevicepath}" 1>&2
  exit 1
fi

echo "will now attempt to open dm-verity device with: veritysetup open ${rootdevicepath} vsysroot ${hashdevicepath} ${roothash}"
veritysetup --panic-on-corruption open -v "${rootdevicepath}" vsysroot "${hashdevicepath}" "${roothash}" || exit 1

if [ ! -b $vsysrootmapper ]; then
  echo "veritysetup create did not result in ${vsysrootmapper} being created"
  exit 1
else
  echo "veritysetup create did result in ${vsysrootmapper} being created"
fi

mkdir -p /sysroot || exit 1
# /sysroot should not be mounted by anyone else already
mountpoint -q /sysroot && exit 1

echo "Mounting ${vsysrootmapper} ($(realpath "${vsysrootmapper}")) to /sysroot"
mount -o ro "${vsysrootmapper}" /sysroot || exit 1

if mountpoint -q /sysroot
then
   echo "mounting /sysroot succeeded"
else
   echo "mounting /sysroot failed"
   exit 1
fi

# Ensure we do not have to wait for a disk with label=root
systemctl disable "dev-disk-by\x2dlabel-root.device" || true
systemctl stop "dev-disk-by\x2dlabel-root.device" || true
systemctl mask "dev-disk-by\x2dlabel-root.device"  || true
