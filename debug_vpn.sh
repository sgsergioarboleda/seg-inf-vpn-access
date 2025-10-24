#!/bin/bash

echo "=== DEBUGGING VPN CONNECTION ==="

echo "1. Verificando conectividad básica..."
docker exec client-b ping -c 2 172.20.0.2

echo "2. Verificando si el servidor está escuchando..."
docker exec client-a netstat -tulpn | grep 1194

echo "3. Verificando procesos OpenVPN..."
docker exec client-a ps aux | grep openvpn
docker exec client-b ps aux | grep openvpn

echo "4. Verificando interfaces de red..."
docker exec client-a ip addr show tun0 2>/dev/null || echo "No tun0 en client-a"
docker exec client-b ip addr show tun0 2>/dev/null || echo "No tun0 en client-b"

echo "5. Intentando conexión UDP..."
docker exec client-b nc -u -z -v 172.20.0.2 1194

echo "6. Verificando configuración del cliente..."
docker exec client-b cat /etc/openvpn/client.conf

echo "7. Verificando certificados..."
docker exec client-b ls -la /etc/openvpn/

echo "8. Intentando conectar manualmente..."
docker exec client-b timeout 10 openvpn --config /etc/openvpn/client.conf --verb 3
