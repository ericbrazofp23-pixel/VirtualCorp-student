#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

TIPO="${1:-server}"

if [[ "$TIPO" != "server" && "$TIPO" != "desktop" ]]; then
    echo "ERROR: Tipo no valido: $TIPO"
    exit 1
fi

PRESEED_BASE="$PROJECT_ROOT/configs/debian/$TIPO.cfg"
PASSWORD_HASH="$PROJECT_ROOT/artifacts/secrets/sysadmin_password.hash"
OUTPUT_DIR="$PROJECT_ROOT/artifacts/preseed"
OUTPUT_FILE="$OUTPUT_DIR/$TIPO.cfg"

if [[ ! -f "$PRESEED_BASE" ]]; then
    echo "ERROR: No existe $PRESEED_BASE"
    exit 1
fi

umask 077

mkdir -p "$PROJECT_ROOT/artifacts/secrets"
mkdir -p "$OUTPUT_DIR/files"
chmod 700 "$OUTPUT_DIR"

PASSWORD="$PROJECT_ROOT/artifacts/secrets/sysadmin_password"

if [[ ! -s "$PASSWORD" ]]; then
    openssl rand -hex 16 > "$PASSWORD"
fi

if [[ ! -s "$PASSWORD_HASH" ]]; then
    openssl passwd -6 -stdin < "$PASSWORD" > "$PASSWORD_HASH"
fi

cat "$PROJECT_ROOT/configs/ssh/vcorp_sysadmin.pub"     "$PROJECT_ROOT/configs/ssh/vcorp_auditor.pub"     > "$OUTPUT_DIR/files/authorized_keys"

cp "$PROJECT_ROOT/configs/debian/setup_ssh.sh"     "$OUTPUT_DIR/files/setup_ssh.sh"

cp "$PRESEED_BASE" "$OUTPUT_FILE"
chmod 600 "$OUTPUT_FILE"

HASH="$(cat "$PASSWORD_HASH")"

printf '\nd-i passwd/user-password-crypted password %s\n' \
    "$HASH" >> "$OUTPUT_FILE"

echo "Preseed de Debian $TIPO generado correctamente."
