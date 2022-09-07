#!/bin/bash
set -euo pipefail

panic () {
  sleep 5 # allow error messages to be printed
  echo 1 > /proc/sys/kernel/sysrq || true
  echo c > /proc/sysrq-trigger || true
}

# Extract dm-verity hash from kernel cmdline
roothash=$(cat /proc/cmdline)
roothash="${roothash##*verity.sysroot=}"
roothash="${roothash%% *}"
if [[ $roothash =~ ^[a-f0-9]{64}$ ]]
then
    echo "dm-verity roothash (kernel cmdline verity.sysroot) contains well formatted hash: ${roothash}"
else
    echo "dm-verity roothash (kernel cmdline verity.sysroot) contains improperly formatted hash"
    panic
fi

rootdevicepath=/dev/disk/by-partlabel/root_raw
hashdevicepath=/dev/disk/by-partlabel/root_verity
vsysrootmapper=/dev/mapper/vsysroot
if ! [ -b "${rootdevicepath}" ]; then
  echo "verity-setup: Failed to find root_raw: ${rootdevicepath}" 1>&2
  panic
fi
if ! [ -b "${hashdevicepath}" ]; then
  echo "verity-setup: Failed to find root_verity: ${hashdevicepath}" 1>&2
  panic
fi

echo "will now attempt to open dm-verity device with: veritysetup open ${rootdevicepath} vsysroot ${hashdevicepath} ${roothash}"
veritysetup --panic-on-corruption open -v "${rootdevicepath}" vsysroot "${hashdevicepath}" "${roothash}" || panic

if [ ! -b $vsysrootmapper ]; then
  echo "veritysetup create did not result in ${vsysrootmapper} being created"
  panic
else
  echo "veritysetup create did result in ${vsysrootmapper} being created"
fi

mkdir -p /sysroot || panic
# /sysroot should not be mounted by anyone else already
mountpoint -q /sysroot && panic

echo "Mounting ${vsysrootmapper} ($(realpath "${vsysrootmapper}")) to /sysroot"
mount -o ro "${vsysrootmapper}" /sysroot || panic

if mountpoint -q /sysroot
then
   echo "mounting /sysroot succeeded"
else
   echo "mounting /sysroot failed"
   panic
fi

# Ensure we do not have to wait for a disk with label=root
systemctl disable "dev-disk-by\x2dlabel-root.device" || true
systemctl stop "dev-disk-by\x2dlabel-root.device" || true
systemctl mask "dev-disk-by\x2dlabel-root.device"  || true
