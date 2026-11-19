#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VBOX="${VBOXMANAGE_BIN:-VBoxManage}"

cd "$PROJECT_ROOT"

KEY="$HOME/.ssh/vcorp_sysadmin"
PORT=2228

SSH_OPTS=(-i "$KEY"
    -o BatchMode=yes
    -o ConnectTimeout=5
    -o StrictHostKeyChecking=accept-new
    -o UserKnownHostsFile=artifacts/identity_known_hosts)

while read -r nombre tipo red ram cpu
do
    [[ -z "$nombre" || "$nombre" == \#* ]] && continue

    echo "===== Configurando $nombre ====="

    if ! "$VBOX" showvminfo "$nombre" --machinereadable |
        grep -q '^VMState="poweroff"'
    then
        echo "ERROR: $nombre debe estar apagado"
        exit 1
    fi

    rm -f artifacts/identity_known_hosts

    "$VBOX" modifyvm "$nombre" \
        --nic1 nat \
        --natpf1 "identidad,tcp,127.0.0.1,$PORT,,22"

    "$VBOX" startvm "$nombre" --type headless

    limite=$((SECONDS + 300))

    until ssh -n "${SSH_OPTS[@]}" -p "$PORT" \
        sysadmin@127.0.0.1 true 2>/dev/null
    do
        if (( SECONDS >= limite )); then
            echo "ERROR: No se puede conectar con $nombre"
            exit 1
        fi
        sleep 5
    done

    if ssh -n "${SSH_OPTS[@]}" -p "$PORT" \
        sysadmin@127.0.0.1 \
        "test \"\$(cat /var/lib/virtualcorp/identity 2>/dev/null)\" = '$nombre'"
    then
        echo "$nombre ya tiene identidad propia"
    else
        scp "${SSH_OPTS[@]}" -P "$PORT" \
            configs/debian/setup_identity.sh \
            sysadmin@127.0.0.1:/tmp/setup_identity.sh

        ssh "${SSH_OPTS[@]}" -p "$PORT" \
            sysadmin@127.0.0.1 \
            "sudo -S bash /tmp/setup_identity.sh $nombre" \
            < artifacts/secrets/sysadmin_password
    fi

    "$VBOX" controlvm "$nombre" acpipowerbutton

    limite=$((SECONDS + 180))

    until "$VBOX" showvminfo "$nombre" --machinereadable |
        grep -q '^VMState="poweroff"'
    do
        if (( SECONDS >= limite )); then
            echo "ERROR: $nombre no se ha apagado"
            exit 1
        fi
        sleep 2
    done

    sleep 3

    "$VBOX" modifyvm "$nombre" \
        --natpf1 delete identidad \
        --nic1 intnet \
        --intnet1 "$red"

    echo "$nombre configurado correctamente"

done < "${1:-configs/equipment.conf}"

echo "Todos los equipos configurados"
