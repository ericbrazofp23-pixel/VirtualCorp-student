#!/bin/bash
set -e

# Crear la carpeta SSH del usuario sysadmin
mkdir -p /home/sysadmin/.ssh

# Instalar las claves publicas autorizadas
install -m 600 /root/authorized_keys \
    /home/sysadmin/.ssh/authorized_keys

# Asignar los permisos correctos
chown -R sysadmin:sysadmin /home/sysadmin/.ssh
chmod 700 /home/sysadmin/.ssh

# Permitir utilizar sudo
usermod -aG sudo sysadmin

# Activar SSH al arrancar Debian
systemctl enable ssh.service
