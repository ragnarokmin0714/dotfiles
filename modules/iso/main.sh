#!/usr/bin/env bash
# @desc   ISO (experimental): repack a Debian-installer ISO with preseed.cfg for unattended installs
# @order  90
# @manual
#
# EXPERIMENTAL, and narrower than the supported distros: it needs an ISO booted by
# isolinux with the classic debian-installer, which preseed drives -- Debian netinst,
# or Ubuntu 20.04's legacy server image. Ubuntu 22.04+ live-server ISOs boot GRUB only
# and install through subiquity/autoinstall; RHEL-family ISOs use kickstart. Neither
# is handled. Settings: ISO_SOURCE, ISO_OUTPUT_DIR, ISO_LABEL (config.sh).
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"
df_module_start
df_need_root

preseed="$DOTFILES_ROOT/modules/iso/preseed.cfg"
[[ -n "$ISO_SOURCE" && -f "$ISO_SOURCE" ]] || die "Set ISO_SOURCE to a Debian-installer ISO (config.local.sh)"
output="${ISO_OUTPUT_DIR}/${ISO_LABEL,,}-$(date +%Y%m%d).iso"

case "$OS_FAMILY" in
    debian) pkg_install "${DF_N[@]}" xorriso isolinux ;;
    rhel)   pkg_install "${DF_N[@]}" xorriso syslinux ;;
esac

if df_is_dry; then
    log_info "[dry-run] extract ${ISO_SOURCE}, add preseed.cfg, patch isolinux/txt.cfg, repack as ${output}"
    exit 0
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
log_step "Extracting ${ISO_SOURCE}..."
xorriso -osirrox on -indev "$ISO_SOURCE" -extract / "$work"
chmod -R u+w "$work"
[[ -f "$work/isolinux/isolinux.bin" ]] || die "No isolinux in this ISO -- only Debian-installer ISOs are supported (see the module header)"

cp "$preseed" "$work/preseed.cfg"
if [[ -f "$work/isolinux/txt.cfg" ]]; then
    sed -i "s|append |append auto=true priority=critical preseed/file=/cdrom/preseed.cfg |" "$work/isolinux/txt.cfg"
fi

mkdir -p "$ISO_OUTPUT_DIR"
efi=()
[[ -f "$work/boot/grub/efi.img" ]] && efi=(--eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot -isohybrid-gpt-basdat)
xorriso -as mkisofs -iso-level 3 -full-iso9660-filenames -volid "$ISO_LABEL" \
    -eltorito-boot isolinux/isolinux.bin -eltorito-catalog isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table "${efi[@]}" \
    -output "$output" "$work"
log_ok "ISO built: ${output}"
log_info "Write it to a USB stick with: dd if=${output} of=/dev/sdX bs=4M status=progress && sync"
