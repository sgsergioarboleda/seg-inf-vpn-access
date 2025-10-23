# OpenVPN Site-to-Site (S2S) - Entorno de Pruebas

Este repositorio contiene un entorno de pruebas con túnel OpenVPN Site-to-Site entre las máquinas A y B, demostrando comunicación segura cifrada entre sitios.

## Estructura

```
.
├─ docker-compose.yml
└─ client/
   ├─ Dockerfile
   └─ entrypoint.sh      # OpenVPN S2S server/client + HTTP "hello" solo por tun0
```

## Componentes

### Máquina A (Servidor OpenVPN S2S)
- Actúa como servidor OpenVPN Site-to-Site
- Expone puerto 1194/UDP para conexiones de clientes
- Genera automáticamente certificados CA, servidor y clientes
- Configura red VPN 10.8.0.0/24
- Ejecuta servidor HTTP en puerto 8080 accesible solo por tun0
- **Interfaz VNC web disponible** para acceso gráfico

### Máquina B (Cliente OpenVPN S2S)
- Se conecta automáticamente al servidor A
- Obtiene IP VPN: B=10.8.0.6
- Ejecuta servidor HTTP simple en puerto 8080
- **Interfaz VNC web disponible** para acceso gráfico
- El servidor HTTP **solo es accesible a través de la interfaz tun0** (VPN)
- Puede comunicarse con A a través del túnel VPN

### Cliente C (Kali Linux con GUI)
- Máquina Kali con interfaz gráfica web
- **NO tiene túnel VPN** y por tanto no puede acceder a A/B
- Accesible en http://localhost:6902 (usuario: kasm_user, contraseña: kali)

## Uso

### Levantar el entorno

```bash
docker compose up -d --build
```

### Acceder a las interfaces web

- **Cliente A VNC**: http://localhost:5901 (sin contraseña)
- **Cliente B VNC**: http://localhost:5902 (sin contraseña)
- **Kali GUI**: http://localhost:6902

### Verificar IPs de los clientes VPN

```bash
# Ver IP tun0 de A (servidor)
docker exec -it client-a bash -lc "ip -4 addr show tun0"

# Ver IP tun0 de B
docker exec -it client-b bash -lc "ip -4 addr show tun0"

```

### Probar conectividad entre máquinas VPN

```bash
# Desde A hacia B (IP VPN: 10.8.0.6)
docker exec -it client-a bash -lc "curl -s http://10.8.0.6:8080"

# Desde B hacia A (IP VPN: 10.8.0.1)
docker exec -it client-b bash -lc "curl -s http://10.8.0.1:8080"
```

### Verificar que C no puede acceder

El cliente C no tiene túnel VPN activo, por lo que:
- No puede acceder a los servicios HTTP de A/B por sus IPs VPN (no tiene túnel)
- No puede acceder por la red Docker directamente (iptables bloquea todo excepto tun0)

## Características de Seguridad

1. **Certificados X.509**: Autenticación mutua usando certificados digitales
2. **Comunicación cifrada**: Todo el tráfico entre sitios pasa por el túnel VPN cifrado con AES-256-CBC
3. **Aislamiento de red**: Los servicios HTTP solo son accesibles a través de tun0
4. **Site-to-Site**: Comunicación directa entre sitios a través del túnel VPN
5. **TLS-Auth**: Protección adicional contra ataques de denegación de servicio
6. **Seguridad por falta de túnel**: C no puede acceder porque no tiene túnel VPN activo

## Configuración de Red VPN

- **Red VPN**: 10.8.0.0/24
- **Servidor A**: 10.8.0.1
- **Cliente B**: 10.8.0.6
- **Puerto**: 1194/UDP
- **Cifrado**: AES-256-CBC
- **Autenticación**: Certificados X.509 + TLS-Auth

## Configuración Avanzada

Las variables de entorno en `docker-compose.yml` permiten personalizar:

- `VPN_ROLE`: "server" para A, "client" para B
- `VPN_SERVER_IP`: IP del servidor (client-a para B)
- `VPN_CLIENT_IP`: IP VPN asignada al cliente
- `VPN_SERVER_IP_RANGE`: Rango de IPs del servidor

## Notas

- Los certificados se generan automáticamente al iniciar cada contenedor
- El túnel VPN se establece automáticamente entre A y B
- Para uso en producción, usar certificados firmados por una CA externa
- El hostname `client-a` es resoluble dentro de la red Docker bridge

# seg-inf-vpn-access
