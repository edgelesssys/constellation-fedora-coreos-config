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
        veritysetup
    inst_script "$moddir/verity-setup.sh" \
        "/usr/sbin/verity-setup"
    install_and_enable_unit "verity-setup.service" \
        "basic.target"
}