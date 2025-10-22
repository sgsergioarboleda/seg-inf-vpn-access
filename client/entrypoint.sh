#!/usr/bin/env bash
set -euo pipefail

CLIENT_NAME="${CLIENT_NAME:?Set CLIENT_NAME}"
CLIENT_USER="${CLIENT_USER:?Set CLIENT_USER}"
CLIENT_PASS="${CLIENT_PASS:?Set CLIENT_PASS}"
HTTP_PORT="${HTTP_PORT:-8080}"
HELLO_TEXT="${HELLO_TEXT:-Hello}"
CLIENT_OVPN="/clients/${CLIENT_NAME}.ovpn"

[ -f "$CLIENT_OVPN" ] || { echo "[client] Falta $CLIENT_OVPN"; exit 1; }

# Página simple
mkdir -p /srv
cat > /srv/index.html <<EOF
<!doctype html><html><head><meta charset="utf-8"><title>${CLIENT_NAME}</title></head>
<body style="font-family:sans-serif;text-align:center;margin-top:10%;">
<h1>${HELLO_TEXT}</h1>
<p>Servicio de ${CLIENT_NAME} accesible solo vía VPN.</p>
</body></html>
EOF

# Credenciales para --auth-user-pass
echo -e "${CLIENT_USER}\n${CLIENT_PASS}" > /tmp/creds
chmod 600 /tmp/creds

# Levantar OpenVPN (daemon) con auth por usuario/clave
openvpn --config "$CLIENT_OVPN" --auth-user-pass /tmp/creds --daemon

# Esperar tun0
for i in {1..30}; do ip link show tun0 >/dev/null 2>&1 && break; sleep 1; done

# Reglas: HTTP solo por tun0
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -i tun0 -p tcp --dport "${HTTP_PORT}" -j ACCEPT
iptables -A INPUT -p tcp --dport "${HTTP_PORT}" -j REJECT

echo "[client:${CLIENT_NAME}] HTTP ${HTTP_PORT} (solo tun0)."
exec python3 -m http.server "${HTTP_PORT}" --directory /srv

