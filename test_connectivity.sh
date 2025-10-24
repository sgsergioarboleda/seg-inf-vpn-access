#!/bin/bash

echo "=== VPN Site-to-Site - Pruebas de Conectividad ==="
echo ""

# Función para mostrar el estado de los contenedores
show_container_status() {
    echo "📋 Estado de los contenedores:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(client-a|client-b|kali-c)"
    echo ""
}

# Función para verificar interfaces VPN
check_vpn_interfaces() {
    echo "🔍 Verificando interfaces VPN:"
    echo "--- Sitio A (Gateway):"
    docker exec -it client-a ip addr show tun0 2>/dev/null || echo "❌ No hay interfaz tun0 en A"
    echo ""
    echo "--- Sitio B (Gateway):"
    docker exec -it client-b ip addr show tun0 2>/dev/null || echo "❌ No hay interfaz tun0 en B"
    echo ""
}

# Función para verificar rutas
check_routes() {
    echo "🛣️ Verificando rutas de red:"
    echo "--- Rutas en Sitio A:"
    docker exec -it client-a ip route show | grep -E "(192.168|10.8)" || echo "❌ No hay rutas VPN en A"
    echo ""
    echo "--- Rutas en Sitio B:"
    docker exec -it client-b ip route show | grep -E "(192.168|10.8)" || echo "❌ No hay rutas VPN en B"
    echo ""
}

# Función para probar conectividad VPN
test_vpn_connectivity() {
    get_container_ips
    
    echo "🌐 Probando conectividad VPN Site-to-Site:"
    
    echo "--- A → B (a través de VPN):"
    if [ -n "$CLIENT_B_VPN_IP" ]; then
        docker exec -it client-a curl -s --connect-timeout 5 http://${CLIENT_B_VPN_IP}:8080 2>/dev/null && echo "✅ Conectividad A→B OK" || echo "❌ Fallo A→B"
    else
        echo "❌ IP VPN de B no disponible"
    fi
    
    echo "--- B → A (a través de VPN):"
    if [ -n "$CLIENT_A_VPN_IP" ]; then
        docker exec -it client-b curl -s --connect-timeout 5 http://${CLIENT_A_VPN_IP}:8080 2>/dev/null && echo "✅ Conectividad B→A OK" || echo "❌ Fallo B→A"
    else
        echo "❌ IP VPN de A no disponible"
    fi
    
    echo ""
}

# Función para probar conectividad entre sitios
test_site_connectivity() {
    get_container_ips
    
    echo "🏢 Probando conectividad entre sitios:"
    
    echo "--- A → Red del Sitio B:"
    if [ -n "$CLIENT_B_IP" ]; then
        docker exec -it client-a ping -c 2 ${CLIENT_B_IP} 2>/dev/null && echo "✅ A puede alcanzar gateway de B" || echo "❌ A no puede alcanzar gateway de B"
    else
        echo "❌ IP de B no disponible"
    fi
    
    echo "--- B → Red del Sitio A:"
    if [ -n "$CLIENT_A_IP" ]; then
        docker exec -it client-b ping -c 2 ${CLIENT_A_IP} 2>/dev/null && echo "✅ B puede alcanzar gateway de A" || echo "❌ B no puede alcanzar gateway de A"
    else
        echo "❌ IP de A no disponible"
    fi
    
    echo ""
}

# Función para verificar que Kali NO puede acceder a la VPN
test_kali_isolation() {
    get_container_ips
    
    echo "🔒 Verificando aislamiento de Kali (no debe acceder a VPN):"
    
    echo "--- Kali → Sitio A (debe funcionar - misma red):"
    if [ -n "$CLIENT_A_IP" ]; then
        docker exec -it kali-c ping -c 2 ${CLIENT_A_IP} 2>/dev/null && echo "✅ Kali puede alcanzar A (correcto - misma red)" || echo "❌ Kali no puede alcanzar A (problema)"
    else
        echo "❌ IP de A no disponible"
    fi
    
    echo "--- Kali → Sitio B (NO debe funcionar - diferente red):"
    if [ -n "$CLIENT_B_IP" ]; then
        docker exec -it kali-c ping -c 2 ${CLIENT_B_IP} 2>/dev/null && echo "❌ Kali puede alcanzar B (problema de seguridad)" || echo "✅ Kali no puede alcanzar B (correcto)"
    else
        echo "❌ IP de B no disponible"
    fi
    
    echo "--- Kali → VPN A (NO debe funcionar):"
    if [ -n "$CLIENT_A_VPN_IP" ]; then
        docker exec -it kali-c curl -s --connect-timeout 3 http://${CLIENT_A_VPN_IP}:8080 2>/dev/null && echo "❌ Kali puede acceder a VPN A (problema)" || echo "✅ Kali no puede acceder a VPN A (correcto)"
    else
        echo "❌ IP VPN de A no disponible"
    fi
    
    echo "--- Kali → VPN B (NO debe funcionar):"
    if [ -n "$CLIENT_B_VPN_IP" ]; then
        docker exec -it kali-c curl -s --connect-timeout 3 http://${CLIENT_B_VPN_IP}:8080 2>/dev/null && echo "❌ Kali puede acceder a VPN B (problema)" || echo "✅ Kali no puede acceder a VPN B (correcto)"
    else
        echo "❌ IP VPN de B no disponible"
    fi
    
    echo ""
}

# Función para obtener IPs dinámicamente
get_container_ips() {
    # Obtener IP de client-a en site-a
    CLIENT_A_IP=$(docker inspect client-a --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null | head -1)
    
    # Obtener IP de client-b en site-b  
    CLIENT_B_IP=$(docker inspect client-b --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null | head -1)
    
    # Obtener IP de kali-c en site-a
    KALI_IP=$(docker inspect kali-c --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null | head -1)
    
    # Obtener IP VPN de client-a
    CLIENT_A_VPN_IP=$(docker exec -it client-a ip addr show tun0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1 | head -1)
    
    # Obtener IP VPN de client-b
    CLIENT_B_VPN_IP=$(docker exec -it client-b ip addr show tun0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1 | head -1)
}

# Función para mostrar resumen de IPs
show_network_summary() {
    get_container_ips
    
    echo "📊 Resumen de la configuración de red:"
    echo ""
    echo "Sitio A (Gateway VPN Server):"
    echo "  - IP Local: ${CLIENT_A_IP:-No disponible}"
    echo "  - IP VPN: ${CLIENT_A_VPN_IP:-No disponible}"
    echo "  - Red: site-a"
    echo ""
    echo "Sitio B (Gateway VPN Client):"
    echo "  - IP Local: ${CLIENT_B_IP:-No disponible}"
    echo "  - IP VPN: ${CLIENT_B_VPN_IP:-No disponible}"
    echo "  - Red: site-b"
    echo ""
    echo "Kali Linux:"
    echo "  - IP Local: ${KALI_IP:-No disponible}"
    echo "  - Red: site-a (misma que A)"
    echo "  - Sin acceso VPN"
    echo ""
}

# Ejecutar todas las pruebas
main() {
    show_network_summary
    show_container_status
    check_vpn_interfaces
    check_routes
    test_vpn_connectivity
    test_site_connectivity
    test_kali_isolation
    
    echo "=== Pruebas completadas ==="
    echo "Para acceder a las interfaces web:"
    echo "  - Sitio A VNC: http://localhost:5901"
    echo "  - Sitio B VNC: http://localhost:5902"
    echo "  - Kali GUI: http://localhost:6902"
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
