#!/bin/bash
set -euo pipefail

NOMBRE="$1"

ANTERIOR="$(hostname)"

hostnamectl set-hostname "$NOMBRE"

sed -i "s/127.0.1.1.*/127.0.1.1 $NOMBRE/" /etc/hosts

rm -f /etc/ssh/ssh_host_*

ssh-keygen -A

rm -f /var/lib/dbus/machine-id
rm -f /etc/machine-id

systemd-machine-id-setup

ln -sf /etc/machine-id /var/lib/dbus/machine-id

mkdir -p /var/lib/virtualcorp

echo "$NOMBRE" > /var/lib/virtualcorp/identity

echo "Identidad anterior: $ANTERIOR"
echo "Nueva identidad: $NOMBRE"
