depends() {
    echo rdcore systemd
}

install_and_enable_unit() {
    unit="$1"; shift
    target="$1"; shift
    inst_simple "$moddir/$unit" "$systemdsystemunitdir/$unit"
    mkdir -p "${initdir}${systemdsystemconfdir}/${target}.wants"
    ln_r "${systemdsystemunitdir}/${unit}" \
        "${systemdsystemconfdir}/${target}.wants/${unit}"
}

install() {
    inst_multiple \
        bash \
        cat \
        realpath \
        mount \
        mountpoint \
        mkdir \
        xxd \
        grep \
        sed \
        nvme \
        veritysetup \
        cryptsetup \
        dmsetup \
        sgdisk \
        partx \
        disk-mapper
    inst_script "$moddir/verity-setup.sh" \
        "/usr/sbin/verity-setup"
    install_and_enable_unit "verity-setup.service" \
        "basic.target"
    inst_script "$moddir/prepare-state-disk.sh" \
        "/usr/sbin/prepare-state-disk"
    install_and_enable_unit "prepare-state-disk.service" \
        "basic.target"
    inst_simple "/usr/lib/udev/rules.d/64-gce-disk-removal.rules" \
        "/usr/lib/udev/rules.d/64-gce-disk-removal.rules"
    inst_simple "/usr/lib/udev/rules.d/65-gce-disk-removal-persistent.rules" \
        "/usr/lib/udev/rules.d/65-gce-disk-removal-persistent.rules"
    inst_script "/usr/lib/udev/google_nvme_id" \
        "/usr/lib/udev/google_nvme_id"
}
