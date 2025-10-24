#!/usr/bin/env bash
set -euo pipefail

CONF="${OVPN_CONFIG_PATH:-/etc/openvpn/server.conf}"

# Si no hay PKI, mantenemos el contenedor vivo para que puedas entrar y crearla.
if [[ ! -f /etc/openvpn/pki/ca.crt ]]; then
  echo "[entrypoint] PKI no encontrada en /etc/openvpn/pki. Deja este contenedor corriendo,"
  echo "abre una shell (docker exec -it ubuntu-a bash) y genera la PKI con easy-rsa."
  echo "Cuando termines, ejecuta: docker restart ubuntu-a"
  # Evita salida del contenedor
  tail -f /dev/null
else
  echo "[entrypoint] PKI encontrada. Iniciando servidor Python..."
  python3 /usr/local/bin/server.py &
  
  echo "[entrypoint] Iniciando OpenVPN con ${CONF}..."
  exec openvpn --config "${CONF}"
fi
