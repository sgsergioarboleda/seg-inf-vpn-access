# OpenVPN Access Server - Entorno de Pruebas

Este repositorio contiene un entorno de pruebas con OpenVPN Access Server y clientes que demuestran comunicación segura peer-to-peer a través de VPN.

## Estructura

```
.
├─ docker-compose.yml
├─ vpnserver/
│  ├─ Dockerfile
│  └─ entrypoint.sh      # inicia AS, configura host, client-to-client, crea A/B y exporta .ovpn
└─ client/
   ├─ Dockerfile
   └─ entrypoint.sh      # OpenVPN client + HTTP "hello" solo por tun0
```

## Componentes

### VPN Server (OpenVPN Access Server)
- Expone puertos 943/TCP (Web UI), 443/TCP y 1194/UDP
- Configura automáticamente usuarios A y B con credenciales
- Habilita `client-to-client` para comunicación directa entre clientes
- Genera perfiles `.ovpn` automáticamente

### Clientes A y B
- Se conectan automáticamente al servidor VPN con sus credenciales
- Ejecutan un servidor HTTP simple en puerto 8080
- El servidor HTTP **solo es accesible a través de la interfaz tun0** (VPN)
- Pueden comunicarse entre sí a través de la VPN

### Cliente C (Kali Linux con GUI)
- Máquina Kali con interfaz gráfica web
- **NO tiene credenciales VPN** y por tanto no puede acceder a A/B
- Accesible en http://localhost:6901 (usuario: kasm_user, contraseña: kali)

## Uso

### Levantar el entorno

```bash
docker compose up -d --build
```

### Ver la contraseña auto-generada del admin (primera vez)

```bash
docker logs vpnserver | grep -i "Auto-generated pass"
```

### Acceder a las interfaces web

- **Admin UI**: https://localhost:943/admin
- **Client UI**: https://localhost:943/
- **Kali GUI**: http://localhost:6901

### Verificar IPs de los clientes VPN

```bash
# Ver IP tun0 de A
docker exec -it A bash -lc "ip -4 addr show tun0"

# Ver IP tun0 de B
docker exec -it B bash -lc "ip -4 addr show tun0"
```

### Probar conectividad entre A y B

```bash
# Desde A hacia B (sustituye <IP_TUN_DE_B> por la IP obtenida arriba)
docker exec -it A bash -lc "curl -s http://<IP_TUN_DE_B>:8080"

# Desde B hacia A (sustituye <IP_TUN_DE_A> por la IP obtenida arriba)
docker exec -it B bash -lc "curl -s http://<IP_TUN_DE_A>:8080"
```

### Verificar que C no puede acceder

El cliente C no tiene credenciales VPN ni túnel activo, por lo que:
- No puede acceder a los servicios HTTP de A/B por sus IPs VPN (no tiene túnel)
- No puede acceder por la red Docker directamente (iptables bloquea todo excepto tun0)

## Características de Seguridad

1. **Autenticación por usuario/contraseña**: Los clientes A y B requieren credenciales válidas
2. **Comunicación cifrada**: Todo el tráfico entre clientes pasa por el túnel VPN cifrado
3. **Aislamiento de red**: Los servicios HTTP solo son accesibles a través de tun0
4. **Client-to-client**: Los clientes VPN pueden comunicarse directamente entre sí
5. **Seguridad por falta de credenciales**: C no puede acceder porque no tiene credenciales VPN válidas

## Credenciales por Defecto

**⚠️ Cambiar en producción ⚠️**

- Usuario A: `A` / Contraseña: `A_password`
- Usuario B: `B` / Contraseña: `B_password`
- Kali GUI: `kasm_user` / `kali`

## Configuración Avanzada

Las variables de entorno en `docker-compose.yml` permiten personalizar:

- `AS_HOSTNAME`: Nombre del servidor VPN (debe ser resoluble por los clientes)
- `USER_A`, `PASS_A`: Credenciales del usuario A
- `USER_B`, `PASS_B`: Credenciales del usuario B
- `ENABLE_TLS_CRYPT_V2`: Habilitar TLS-crypt v2 en los perfiles

## Notas

- La licencia gratuita de OpenVPN Access Server permite 2 conexiones simultáneas
- Los perfiles `.ovpn` se generan automáticamente y se comparten vía volumen Docker
- El hostname `vpnserver` es resoluble dentro de la red Docker bridge
- Para uso en producción, configurar un FQDN público y abrir/forwardear los puertos necesarios

# seg-inf-vpn-access
