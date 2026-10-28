#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/router_base.sh"

check_prerequisites

# Crear la plantilla dels routers
# create_router_template

# Router 0: sortida a Internet i DMZ
create_router "mikrotik0" 2200 \
  --intnets "r0-r1" "dmz" \
  --ips "10.5.0.225/30" "10.5.0.193/27" \
  --nat

# Router 1: planta baixa general
create_router "mikrotik1" 2201 \
  --intnets "r0-r1" "r1-r2" "pl0" \
  --ips "10.5.0.226/30" "10.5.0.229/30" "10.5.0.1/25" \
  --gateway "10.5.0.225"

# Router 2: planta 1 i planta 2
create_router "mikrotik2" 2202 \
  --intnets "r1-r2" "r2-r3" "pl1" "pl2" \
  --ips "10.5.0.230/30" "10.5.0.233/30" "10.5.1.1/24" "10.5.2.1/24" \
  --gateway "10.5.0.229"

# Router 3: planta 3 i xarxa privada
create_router "mikrotik3" 2203 \
  --intnets "r2-r3" "pl3" "pl3-direccio" \
  --ips "10.5.0.234/30" "10.5.3.1/24" "10.5.0.129/26" \
  --gateway "10.5.0.233"

log_info "=========================================="
log_info "[+] Routers desplegats correctament."
log_info "=========================================="
