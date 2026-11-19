#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

VBOX="${VBOXMANAGE_BIN:-VBoxManage}"
GRUPO="${VBOX_ROOT_GROUP:-/VirtualCorp}/Equipment"

INVENTARIO="$PROJECT_ROOT/configs/equipment.conf"

SERVER="${TEMPLATE_SERVER:-debian-server-template}"
DESKTOP="${TEMPLATE_DESKTOP:-debian-desktop-template}"

while read -r nombre tipo red ram cpu
do
    [[ -z "$nombre" || "$nombre" == \#* ]] && continue

    case "$tipo" in
        server)
            template="$SERVER"
            ;;
        desktop)
            template="$DESKTOP"
            ;;
        *)
            echo "ERROR: Template desconocido: $tipo"
            exit 1
            ;;
    esac

    if "$VBOX" showvminfo "$nombre" >/dev/null 2>&1; then
        echo "$nombre ya existe. Se conserva."
        continue
    fi

    echo "Creando clon enlazado: $nombre"

    "$VBOX" clonevm "$template" \
        --snapshot base \
        --options link \
        --mode machine \
        --name "$nombre" \
        --groups "$GRUPO" \
        --register

    "$VBOX" modifyvm "$nombre" \
        --memory "$ram" \
        --cpus "$cpu" \
        --nic1 intnet \
        --intnet1 "$red" \
        --cableconnected1 on \
        --boot1 disk \
        --boot2 none

    echo "$nombre creado correctamente"

done < "$INVENTARIO"

echo "Despliegue de equipos Debian finalizado"
