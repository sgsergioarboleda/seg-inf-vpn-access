#!/usr/bin/env bash
set -euo pipefail

CLIENT_NAME="${CLIENT_NAME:?Set CLIENT_NAME}"
CLIENT_USER="${CLIENT_USER:?Set CLIENT_USER}"
CLIENT_PASS="${CLIENT_PASS:?Set CLIENT_PASS}"
HTTP_PORT="${HTTP_PORT:-8080}"
HELLO_TEXT="${HELLO_TEXT:-Hello}"
VPN_ROLE="${VPN_ROLE:-client}"
VPN_SERVER_IP="${VPN_SERVER_IP:-client-a}"
VPN_CLIENT_IP="${VPN_CLIENT_IP:-10.8.0.2}"
VPN_SERVER_IP_RANGE="${VPN_SERVER_IP_RANGE:-10.8.0.1}"
VPN_CLIENT_IPS="${VPN_CLIENT_IPS:-10.8.0.2,10.8.0.3}"

# Configuración OpenVPN
OPENVPN_DIR="/etc/openvpn"
CA_CERT="$OPENVPN_DIR/ca.crt"
SERVER_CERT="$OPENVPN_DIR/server.crt"
SERVER_KEY="$OPENVPN_DIR/server.key"
CLIENT_CERT="$OPENVPN_DIR/client.crt"
CLIENT_KEY="$OPENVPN_DIR/client.key"
DH_PEM="$OPENVPN_DIR/dh.pem"
TA_KEY="$OPENVPN_DIR/ta.key"

# Página simple
mkdir -p /srv
cat > /srv/index.html <<EOF
<!doctype html><html><head><meta charset="utf-8"><title>${CLIENT_NAME}</title></head>
<body style="font-family:sans-serif;text-align:center;margin-top:10%;">
<h1>${HELLO_TEXT}</h1>
<p>Servicio de ${CLIENT_NAME} accesible solo vía VPN.</p>
<p>IP VPN: <span id="vpn-ip">Cargando...</span></p>
<script>
fetch('/api/ip').then(r=>r.text()).then(ip=>document.getElementById('vpn-ip').textContent=ip);
</script>
</body></html>
EOF

# API simple para obtener IP VPN
mkdir -p /srv/api
cat > /srv/api/ip <<EOF
#!/usr/bin/env python3
import subprocess
import sys
try:
    result = subprocess.run(['ip', 'addr', 'show', 'tun0'], capture_output=True, text=True)
    for line in result.stdout.split('\n'):
        if 'inet ' in line and not '127.0.0.1' in line:
            ip = line.split()[1].split('/')[0]
            print(ip)
            sys.exit(0)
    print("No VPN IP found")
except:
    print("Error getting VPN IP")
EOF
chmod +x /srv/api/ip

# Función para generar certificados y claves
generate_certificates() {
    echo "[${CLIENT_NAME}] Generando certificados OpenVPN..."
    
    # Crear directorio de configuración
    mkdir -p "$OPENVPN_DIR"
    cd "$OPENVPN_DIR"
    
    # Generar CA (Certificate Authority)
    openssl genrsa -out ca.key 2048
    openssl req -new -x509 -days 3650 -key ca.key -out ca.crt -subj "/C=ES/ST=Madrid/L=Madrid/O=VPN/CN=VPN-CA"
    
    # Generar clave DH
    openssl dhparam -out dh.pem 2048
    
    # Generar clave TLS-auth
    openvpn --genkey --secret ta.key
    
    if [ "$VPN_ROLE" = "server" ]; then
        # Configuración del servidor
        echo "[${CLIENT_NAME}] Configurando servidor OpenVPN..."
        
        # Generar certificado del servidor
        openssl genrsa -out server.key 2048
        openssl req -new -key server.key -out server.csr -subj "/C=ES/ST=Madrid/L=Madrid/O=VPN/CN=server"
        openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 3650
        rm server.csr
        
        # Crear configuración del servidor
        cat > server.conf <<EOF
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
client-to-client
keepalive 10 120
tls-auth ta.key 0
cipher AES-256-CBC
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb 3
explicit-exit-notify 1
EOF
        
        # Iniciar servidor OpenVPN
        openvpn --config server.conf --daemon
        echo "[${CLIENT_NAME}] Servidor OpenVPN iniciado en puerto 1194"
        
    else
        # Configuración del cliente
        echo "[${CLIENT_NAME}] Configurando cliente OpenVPN..."
        
        # Generar certificado del cliente
        openssl genrsa -out client.key 2048
        openssl req -new -key client.key -out client.csr -subj "/C=ES/ST=Madrid/L=Madrid/O=VPN/CN=${CLIENT_NAME}"
        openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 3650
        rm client.csr
        
        # Crear configuración del cliente
        cat > client.conf <<EOF
client
dev tun
proto udp
remote ${VPN_SERVER_IP} 1194
resolv-retry infinite
nobind
user nobody
group nogroup
persist-key
persist-tun
ca ca.crt
cert client.crt
key client.key
tls-auth ta.key 1
cipher AES-256-CBC
verb 3
EOF
        
        # Esperar a que el servidor esté listo
        echo "[${CLIENT_NAME}] Esperando a que el servidor esté disponible..."
        for i in {1..30}; do
            if nc -z "$VPN_SERVER_IP" 1194 2>/dev/null; then
                echo "[${CLIENT_NAME}] Servidor disponible, conectando..."
                break
            fi
            sleep 2
        done
        
        # Iniciar cliente OpenVPN
        openvpn --config client.conf --daemon
        echo "[${CLIENT_NAME}] Cliente OpenVPN conectado"
    fi
}

# Generar certificados y configurar OpenVPN
generate_certificates

# Esperar tun0
for i in {1..30}; do ip link show tun0 >/dev/null 2>&1 && break; sleep 1; done

echo "[client:${CLIENT_NAME}] HTTP ${HTTP_PORT} (accesible desde cualquier interfaz)."
echo "[client:${CLIENT_NAME}] VNC disponible en puerto 5900 (sin contraseña)."

# Iniciar servidor HTTP en background
python3 -m http.server "${HTTP_PORT}" --directory /srv &

# Mantener el contenedor corriendo
wait

