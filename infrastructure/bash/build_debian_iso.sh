#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

TIPO="${1:-server}"

if [[ "$TIPO" != "server" && "$TIPO" != "desktop" ]]; then
    echo "ERROR: Tipo no valido: $TIPO"
    exit 1
fi

ISO_ORIGINAL="$PROJECT_ROOT/artifacts/iso/debian-13.7.0-amd64-netinst.iso"
ISO_NUEVA="$PROJECT_ROOT/artifacts/debian-build/debian-$TIPO-auto.iso"

BUILD="$PROJECT_ROOT/artifacts/debian-build"
PRESEED="$PROJECT_ROOT/artifacts/preseed"

echo "Preparando instalacion automatica de Debian $TIPO..."

"$PROJECT_ROOT/infrastructure/bash/prepare_preseed.sh" "$TIPO"

for archivo in \
    "$ISO_ORIGINAL" \
    "$PRESEED/$TIPO.cfg" \
    "$PRESEED/files/authorized_keys" \
    "$PRESEED/files/setup_ssh.sh" \
    "$PROJECT_ROOT/configs/debian/isolinux/isolinux.cfg" \
    "$PROJECT_ROOT/configs/debian/grub/grub.cfg"
do
    if [[ ! -f "$archivo" ]]; then
        echo "ERROR: Falta $archivo"
        exit 1
    fi
done

umask 077

mkdir -p "$BUILD"

# Eliminar la ISO anterior para generar una nueva
rm -f "$ISO_NUEVA"

echo "Generando ISO de Debian $TIPO..."

xorriso \
    -indev "$ISO_ORIGINAL" \
    -outdev "$ISO_NUEVA" \
    -overwrite on \
    -map "$PRESEED/$TIPO.cfg" /preseed.cfg \
    -map "$PRESEED/files/authorized_keys" /files/authorized_keys \
    -map "$PRESEED/files/setup_ssh.sh" /files/setup_ssh.sh \
    -map "$PROJECT_ROOT/configs/debian/isolinux/isolinux.cfg" /isolinux/isolinux.cfg \
    -map "$PROJECT_ROOT/configs/debian/grub/grub.cfg" /boot/grub/grub.cfg \
    -boot_image any replay \
    -compliance no_emul_toc \
    -padding included

echo "ISO generada correctamente:"
echo "$ISO_NUEVA"
