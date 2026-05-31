#!/usr/bin/env bash
# =============================================================================
# iso/build.sh — Custom Linux ISO Builder
# =============================================================================
# Builds a customized Linux ISO from a source ISO file by:
#   1. Extracting the source ISO contents
#   2. Injecting a preseed.cfg for automated (unattended) installation
#   3. Repacking the directory into a new bootable ISO
#
# TOOLS USED:
#   - xorriso  — ISO manipulation and repackaging
#   - isolinux — Bootloader for the ISO (included in the source ISO)
#
# CONFIGURATION (set in lib/env.sh):
#   ISO_SOURCE     — Path to the source Ubuntu/Debian ISO file
#   ISO_OUTPUT_DIR — Directory where the built ISO will be saved
#   ISO_LABEL      — Volume label for the output ISO (max 32 chars)
#
# USAGE:
#   sudo bash iso/build.sh
#
# REQUIRES: sudo / root privileges, xorriso installed
# =============================================================================
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_ROOT/lib/env.sh"
source "$DOTFILES_ROOT/lib/log.sh"

WORK_DIR="/tmp/iso-workdir"
OUTPUT_ISO="$ISO_OUTPUT_DIR/${ISO_LABEL,,}-$(date +%Y%m%d).iso"
PRESEED_SOURCE="$DOTFILES_ROOT/iso/preseed.cfg"

# --- Pre-flight checks ---
if [[ ! -f "$ISO_SOURCE" ]]; then
  log_error "Source ISO not found: $ISO_SOURCE. Set ISO_SOURCE in lib/env.sh."
fi

if [[ ! -f "$PRESEED_SOURCE" ]]; then
  log_error "preseed.cfg not found: $PRESEED_SOURCE"
fi

# --- Install required tools ---
# Note: preseed + isolinux bootloader injection is Ubuntu/Debian-specific.
#       For Rocky Linux ISOs, use kickstart.cfg instead (requires separate build script).
log_info "Installing xorriso..."
if [[ "$DISTRO_FAMILY" == "rhel" ]]; then
  dnf install -y xorriso syslinux     # syslinux provides isolinux on RHEL family
else
  apt-get install -y xorriso isolinux
fi

# --- Prepare working directory ---
log_info "Preparing work directory: $WORK_DIR"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$ISO_OUTPUT_DIR"

# --- Extract source ISO ---
log_info "Extracting source ISO: $ISO_SOURCE"
xorriso -osirrox on -indev "$ISO_SOURCE" -extract / "$WORK_DIR"

# Remove read-only flags set by xorriso extraction
chmod -R u+w "$WORK_DIR"

# --- Inject preseed.cfg ---
log_info "Injecting preseed.cfg..."
cp "$PRESEED_SOURCE" "$WORK_DIR/preseed.cfg"

# Modify the isolinux/txt.cfg bootloader to auto-select with preseed
if [[ -f "$WORK_DIR/isolinux/txt.cfg" ]]; then
  sed -i "s|append |append auto=true priority=critical preseed/file=/cdrom/preseed.cfg |" \
    "$WORK_DIR/isolinux/txt.cfg"
  log_info "Bootloader updated to use preseed.cfg."
fi

# --- Repack into new ISO ---
log_info "Building output ISO: $OUTPUT_ISO"
xorriso -as mkisofs \
  -iso-level 3 \
  -full-iso9660-filenames \
  -volid "$ISO_LABEL" \
  -eltorito-boot isolinux/isolinux.bin \
  -eltorito-catalog isolinux/boot.cat \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  --eltorito-alt-boot \
  -e boot/grub/efi.img \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  -output "$OUTPUT_ISO" \
  "$WORK_DIR"

# --- Cleanup ---
log_info "Cleaning up work directory..."
rm -rf "$WORK_DIR"

log_success "ISO built successfully: $OUTPUT_ISO"
log_info "Write to USB with: sudo dd if=$OUTPUT_ISO of=/dev/sdX bs=4M status=progress && sync"
