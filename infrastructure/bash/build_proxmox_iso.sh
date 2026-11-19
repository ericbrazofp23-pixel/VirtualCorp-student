#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

VERSION="${PROXMOX_VERSION:-9.2-1}"
DELEGACION="${DELEGACION:-05}"
NUM=$((10#$DELEGACION))

BUILD="$PROJECT_ROOT/artifacts/proxmox-build"
SECRETS="$PROJECT_ROOT/artifacts/secrets"

ISO_ORIGINAL="$PROJECT_ROOT/artifacts/iso/proxmox-ve_$VERSION.iso"
ISO_NUEVA="$BUILD/proxmox-ve_$VERSION-auto.iso"

umask 077

mkdir -p "$BUILD" "$SECRETS"

if [[ ! -s "$SECRETS/proxmox_password" ]]; then
    openssl rand -hex 16 > "$SECRETS/proxmox_password"
fi

HASH="$(openssl passwd -6 -stdin < "$SECRETS/proxmox_password")"

AUDITOR="$(cat "$PROJECT_ROOT/configs/ssh/vcorp_auditor.pub")"
SYSADMIN="$(cat "$PROJECT_ROOT/configs/ssh/vcorp_sysadmin.pub")"

cat > "$BUILD/answer.toml" <<ANSWER
[global]
keyboard = "es"
country = "es"
fqdn = "pve01.virtualcorp.test"
mailto = "admin@virtualcorp.test"
timezone = "Europe/Madrid"
root-password-hashed = "$HASH"
root-ssh-keys = ["$AUDITOR", "$SYSADMIN"]
reboot-on-error = false
reboot-mode = "power-off"

[network]
source = "from-answer"
cidr = "10.$NUM.0.133/26"
gateway = "10.$NUM.0.129"
dns = "1.1.1.1"
filter.ID_NET_NAME = "enp0s3"

[disk-setup]
filesystem = "ext4"
disk-list = ["sda"]
ANSWER

if command -v proxmox-auto-install-assistant >/dev/null; then

    proxmox-auto-install-assistant validate-answer "$BUILD/answer.toml"

    rm -f "$ISO_NUEVA"

    proxmox-auto-install-assistant prepare-iso         "$ISO_ORIGINAL"         --fetch-from iso         --answer-file "$BUILD/answer.toml"         --output "$ISO_NUEVA"

else

    VBOX="${VBOXMANAGE_BIN:-VBoxManage}"
    BUILDER="proxmox-builder"
    SERVER="${TEMPLATE_SERVER:-debian-server-template}"
    KEY="$HOME/.ssh/vcorp_sysadmin"

    if "$VBOX" showvminfo "$BUILDER" >/dev/null 2>&1; then
        echo "ERROR: Ya existe la maquina auxiliar"
        exit 1
    fi

    "$VBOX" clonevm "$SERVER"         --snapshot base         --options link         --mode machine         --name "$BUILDER"         --register

    limpiar_builder() {
        "$VBOX" controlvm "$BUILDER" poweroff 2>/dev/null || true
        sleep 5
        "$VBOX" unregistervm "$BUILDER" --delete || true
    }

    trap limpiar_builder EXIT

    "$VBOX" modifyvm "$BUILDER"         --memory 2048         --cpus 2         --nic1 nat         --natpf1 "builder,tcp,127.0.0.1,2227,,22"

    SSH_OPTS=(-i "$KEY" -o BatchMode=yes
        -o ConnectTimeout=5
        -o StrictHostKeyChecking=accept-new
        -o UserKnownHostsFile="$BUILD/builder_known_hosts")

    rm -f "$BUILD/builder_known_hosts"

    "$VBOX" startvm "$BUILDER" --type headless

    limite=$((SECONDS + 300))

    until ssh "${SSH_OPTS[@]}" -p 2227         sysadmin@127.0.0.1 true 2>/dev/null
    do
        if (( SECONDS >= limite )); then
            echo "ERROR: SSH de la maquina auxiliar no disponible"
            exit 1
        fi
        sleep 5
    done

    ssh "${SSH_OPTS[@]}" -p 2227 sysadmin@127.0.0.1         'sudo -S bash -ec "
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y wget ca-certificates

        wget -O /usr/share/keyrings/proxmox-archive-keyring.gpg         https://enterprise.proxmox.com/debian/proxmox-archive-keyring-trixie.gpg

        echo \"deb [signed-by=/usr/share/keyrings/proxmox-archive-keyring.gpg] http://download.proxmox.com/debian/pve trixie pve-no-subscription\"         > /etc/apt/sources.list.d/proxmox.list

        apt-get update
        apt-get install -y proxmox-auto-install-assistant=9.2.9
        "' < "$SECRETS/sysadmin_password"

    scp "${SSH_OPTS[@]}" -P 2227         "$ISO_ORIGINAL" "$BUILD/answer.toml"         sysadmin@127.0.0.1:/home/sysadmin/

    ssh "${SSH_OPTS[@]}" -p 2227 sysadmin@127.0.0.1         "umask 077
        proxmox-auto-install-assistant validate-answer ~/answer.toml &&
        proxmox-auto-install-assistant prepare-iso         ~/proxmox-ve_$VERSION.iso         --fetch-from iso         --answer-file ~/answer.toml         --output ~/proxmox-auto.iso"

    scp "${SSH_OPTS[@]}" -P 2227         sysadmin@127.0.0.1:/home/sysadmin/proxmox-auto.iso         "$ISO_NUEVA"

fi

chmod 600 "$ISO_NUEVA"

echo "ISO automatica de Proxmox generada correctamente"
