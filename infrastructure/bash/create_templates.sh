#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$PROJECT_ROOT/artifacts/debian-build"

VBOX="${VBOXMANAGE_BIN:-VBoxManage}"
GRUPO="${VM_TEMPLATES_GROUP:-/VirtualCorp/templates}"

crear_template() {
    local tipo="$1"
    local vm="$2"
    local red="$3"
    local iso="$BUILD/debian-$tipo-auto.iso"
    local disco="$BUILD/$vm.vdi"

    if "$VBOX" showvminfo "$vm" >/dev/null 2>&1; then
        echo "El template $vm ya existe. Se conserva."
        return 0
    fi

    "$PROJECT_ROOT/infrastructure/bash/build_debian_iso.sh" "$tipo"

    "$VBOX" createvm \
        --name "$vm" \
        --ostype Debian_64 \
        --groups "$GRUPO" \
        --register

    "$VBOX" modifyvm "$vm" \
        --memory 2048 \
        --cpus 2 \
        --firmware bios \
        --boot1 dvd \
        --boot2 disk \
        --nic1 nat \
        --audio-enabled off

    "$VBOX" createmedium disk \
        --filename "$disco" \
        --size 12288 \
        --format VDI \
        --variant Standard

    "$VBOX" storagectl "$vm" \
        --name SATA \
        --add sata \
        --controller IntelAhci

    "$VBOX" storageattach "$vm" \
        --storagectl SATA \
        --port 0 \
        --device 0 \
        --type hdd \
        --medium "$disco"

    "$VBOX" storageattach "$vm" \
        --storagectl SATA \
        --port 1 \
        --device 0 \
        --type dvddrive \
        --medium "$iso"

    "$VBOX" startvm "$vm" --type headless

    echo "Instalando $vm..."

    local limite=$((SECONDS + 7200))

    until "$VBOX" showvminfo "$vm" --machinereadable |
        grep -q '^VMState="poweroff"'
    do
        if (( SECONDS >= limite )); then
            echo "ERROR: La instalacion no ha finalizado a tiempo"
            return 1
        fi

        sleep 10
    done

    "$VBOX" storageattach "$vm" \
        --storagectl SATA \
        --port 1 \
        --device 0 \
        --type dvddrive \
        --medium none

    "$VBOX" modifyvm "$vm" \
        --boot1 disk \
        --boot2 none \
        --nic1 intnet \
        --intnet1 "$red"

    "$VBOX" snapshot "$vm" take base

    echo "Template $vm creado correctamente"
}

crear_template server "${TEMPLATE_SERVER:-debian-server-template}" privada
crear_template desktop "${TEMPLATE_DESKTOP:-debian-desktop-template}" pl0

echo "Proceso de creacion de templates finalizado"
