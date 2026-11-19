#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VBOX="${VBOXMANAGE_BIN:-VBoxManage}"
BUILD="$PROJECT_ROOT/artifacts/proxmox-build"

VM="pve01"
VERSION="${PROXMOX_VERSION:-9.2-1}"
ISO="$BUILD/proxmox-ve_$VERSION-auto.iso"
DISCO="$BUILD/pve01.vdi"

if "$VBOX" showvminfo "$VM" >/dev/null 2>&1; then
    echo "pve01 ya existe. Se conserva."
    exit 0
fi

# Generar la ISO automatica antes de instalar Proxmox
"$PROJECT_ROOT/infrastructure/bash/build_proxmox_iso.sh"

if [[ ! -s "$ISO" ]]; then
    echo "ERROR: Falta la ISO automatica de Proxmox"
    exit 1
fi

"$VBOX" createvm \
    --name "$VM" \
    --ostype Debian_64 \
    --groups "/VirtualCorp/Equipment" \
    --register

"$VBOX" modifyvm "$VM" \
    --memory 8192 \
    --cpus 4 \
    --firmware bios \
    --nested-hw-virt on \
    --nic1 intnet \
    --intnet1 privada \
    --cableconnected1 on \
    --boot1 dvd \
    --boot2 disk \
    --audio-enabled off

"$VBOX" createmedium disk \
    --filename "$DISCO" \
    --size 65536 \
    --format VDI \
    --variant Standard

"$VBOX" storagectl "$VM" \
    --name SATA \
    --add sata \
    --controller IntelAhci

"$VBOX" storageattach "$VM" \
    --storagectl SATA \
    --port 0 \
    --device 0 \
    --type hdd \
    --medium "$DISCO"

"$VBOX" storageattach "$VM" \
    --storagectl SATA \
    --port 1 \
    --device 0 \
    --type dvddrive \
    --medium "$ISO"

"$VBOX" startvm "$VM" --type headless

echo "Instalando Proxmox VE..."

limite=$((SECONDS + 7200))

until "$VBOX" showvminfo "$VM" --machinereadable |
    grep -q '^VMState="poweroff"'
do
    if (( SECONDS >= limite )); then
        echo "ERROR: La instalacion no ha finalizado"
        exit 1
    fi
    sleep 10
done

sleep 5

"$VBOX" storageattach "$VM" \
    --storagectl SATA \
    --port 1 \
    --device 0 \
    --type dvddrive \
    --medium emptydrive

"$VBOX" modifyvm "$VM" \
    --boot1 disk \
    --boot2 none

echo "Instalacion de pve01 finalizada"
