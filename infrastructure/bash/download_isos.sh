#!/bin/bash
set -euo pipefail

# Ruta del proyecto
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Comprobar que Makefile ha proporcionado la configuracion
: "${DEBIAN_VERSION:?Falta DEBIAN_VERSION}"
: "${DEBIAN_ISO:?Falta DEBIAN_ISO}"
: "${DEBIAN_URL:?Falta DEBIAN_URL}"

: "${PROXMOX_VERSION:?Falta PROXMOX_VERSION}"
: "${PROXMOX_ISO:?Falta PROXMOX_ISO}"
: "${PROXMOX_URL:?Falta PROXMOX_URL}"

ISO_DIR="$PROJECT_ROOT/artifacts/iso"

mkdir -p "$ISO_DIR"

# Descargar Debian solo si no existe
if [ -f "$ISO_DIR/$DEBIAN_ISO" ]; then
    echo "La ISO de Debian ya existe."
else
    echo "Descargando Debian..."

    curl -4 -fL --retry 3 \
        "$DEBIAN_URL" \
        -o "$ISO_DIR/$DEBIAN_ISO"
fi

# Descargar Proxmox solo si no existe
if [ -f "$ISO_DIR/$PROXMOX_ISO" ]; then
    echo "La ISO de Proxmox ya existe."
else
    echo "Descargando Proxmox..."

    curl -4 -fL --retry 3 \
        "$PROXMOX_URL" \
        -o "$ISO_DIR/$PROXMOX_ISO"
fi

# Verificar la ISO de Debian
echo "Verificando Debian..."

DEBIAN_SHA_URL="${DEBIAN_URL%/*}/SHA256SUMS"

curl -4 -fL --retry 3 \
    "$DEBIAN_SHA_URL" \
    -o "$ISO_DIR/SHA256SUMS"

(
    cd "$ISO_DIR"

    grep -F " $DEBIAN_ISO" SHA256SUMS \
        | sha256sum -c -
)

echo "Debian verificado correctamente."

# Verificar la ISO de Proxmox
echo "Verificando Proxmox..."

: "${PROXMOX_SHA256:?Falta PROXMOX_SHA256}"

echo "$PROXMOX_SHA256  $ISO_DIR/$PROXMOX_ISO" \
    | sha256sum -c -

echo "Proxmox verificado correctamente."

echo "Todas las ISO descargadas y verificadas."
