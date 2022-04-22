#!/bin/bash
set -euo pipefail

# hack: google nvme udev rules are never executed. Create symlinks for the nvme devices manually.
for nvmedisk in /dev/nvme0n+([0-9])
do
  /usr/lib/udev/google_nvme_id -s -d "${nvmedisk}" || true
done


# Prepare the encrypted volume by either initializing it with a random key or by aquiring the key from another coordinator.
# Create symlink to encrypted state disk at /dev/disk/by-id/state-disk (for example: /dev/disk/by-id/state-disk -> /dev/nvme0n2).
# Store encryption key (random or recovered key) in /run/cryptsetup-keys.d/state.key
# Store information about the type of boot (first boot / subsequent boot) in /run/constellation-boot
echo "first-boot" > /run/constellation-boot
disk-mapper -csp "$(< /proc/cmdline tr  ' ' '\n' | grep ignition.platform.id | sed 's/ignition.platform.id=//')"
