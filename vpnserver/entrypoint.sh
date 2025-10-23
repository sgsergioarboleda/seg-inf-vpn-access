#!/usr/bin/env bash
set -euo pipefail

# Vars de entorno
AS_HOSTNAME="${AS_HOSTNAME:-vpnserver}"
USER_A="${USER_A:-A}"; PASS_A="${PASS_A:-A_password}"
USER_B="${USER_B:-B}"; PASS_B="${PASS_B:-B_password}"
ENABLE_TLS_CRYPT_V2="${ENABLE_TLS_CRYPT_V2:-true}"

SCRIPTS="/usr/local/openvpn_as/scripts"
CLIENTS_DIR="/clients"

# 1) Iniciar Access Server en background para inicializar base de datos
"$SCRIPTS/openvpnas" --nodaemon &
OPENVPNAS_PID=$!

# Esperar a que el servidor esté listo
echo "[vpnserver] Esperando a que OpenVPN Access Server esté listo..."
for i in {1..60}; do
  if "$SCRIPTS/sacli" status >/dev/null 2>&1; then
    echo "[vpnserver] Servidor listo!"
    break
  fi
  sleep 2
done

# 2) Ajustar Hostname/IP que se incrusta en los .ovpn (equivale a Admin UI > Network Settings)
#    host.name afecta lo que verán los clientes como "remote". 
"$SCRIPTS/sacli" --key "host.name" --value "${AS_HOSTNAME}" ConfigPut

# 3) Añadir directiva de servidor "client-to-client" vía campo de texto avanzado
#    (equivale a Configuration > Advanced VPN > Additional OpenVPN config directives)
echo "client-to-client" > /tmp/server_directives.txt
"$SCRIPTS/sacli" --key "vpn.server.config_text" --value_file=/tmp/server_directives.txt ConfigPut
rm -f /tmp/server_directives.txt

# 4) Deshabilitar tls-crypt-v2 para compatibilidad con OpenVPN 2.4
TLSC2=""

# 5) Crear usuarios locales y poner password
create_user () {
  local USERNAME="$1"; local PASSWORD="$2"
  # Crea usuario local y le asigna tipo "user_connect" (usuarios que pueden conectarse)
  "$SCRIPTS/sacli" --user "${USERNAME}" --key "type" --value "user_connect" UserPropPut
  "$SCRIPTS/sacli" --user "${USERNAME}" --new_pass "${PASSWORD}" SetLocalPassword
}

echo "[vpnserver] Creando usuarios..."
create_user "${USER_A}" "${PASS_A}"
create_user "${USER_B}" "${PASS_B}"

# 6) Aplicar cambios
"$SCRIPTS/sacli" start

# Esperar un poco para que los cambios se apliquen
sleep 5

# 7) Exportar perfiles "user-locked" para A y B a un volumen compartido (/clients)
mkdir -p "${CLIENTS_DIR}"
echo "[vpnserver] Generando perfiles de cliente..."
"$SCRIPTS/sacli" ${TLSC2} --user "${USER_A}" GetUserlogin > "${CLIENTS_DIR}/${USER_A}.ovpn"
"$SCRIPTS/sacli" ${TLSC2} --user "${USER_B}" GetUserlogin > "${CLIENTS_DIR}/${USER_B}.ovpn"

echo "[vpnserver] Perfiles generados:"
ls -lh "${CLIENTS_DIR}/"

# 8) Mantener el servidor corriendo en foreground
echo "[vpnserver] Configuración completada. Servidor OpenVPN Access Server corriendo."
wait $OPENVPNAS_PID

