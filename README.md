# OpenVPN Site-to-Site (S2S) - Entorno de Pruebas

Este repositorio contiene un entorno de pruebas con túnel OpenVPN Site-to-Site entre dos sitios diferentes, simulando gateways de red con comunicación segura cifrada.

## Arquitectura de Red

```
Sitio A (192.168.1.0/24)          Sitio B (192.168.2.0/24)
┌─────────────────────┐           ┌─────────────────────┐
│   Gateway A         │           │   Gateway B         │
│   (VPN Server)      │◄─────────►│   (VPN Client)      │
│   192.168.1.1       │   VPN     │   192.168.2.1       │
│   10.8.0.1          │  Tunnel   │   10.8.0.2          │
└─────────────────────┘           └─────────────────────┘
         │                                   │
         │                                   │
┌─────────────────────┐           ┌─────────────────────┐
│   Kali Linux        │           │   Red Local         │
│   192.168.1.10      │           │   192.168.2.x       │
│   (Sin VPN)         │           │   (Acceso VPN)      │
└─────────────────────┘           └─────────────────────┘
```

## Estructura

```
.
├─ docker-compose.yml
├─ test_connectivity.sh
└─ client/
   ├─ Dockerfile
   └─ entrypoint.sh      # OpenVPN S2S + Gateway + NAT
```

## Componentes

### Sitio A - Gateway VPN Server
- **Función**: Gateway de red 192.168.1.0/24 con servidor OpenVPN
- **IP Local**: 192.168.1.1
- **IP VPN**: 10.8.0.1
- **Características**:
  - Actúa como servidor OpenVPN Site-to-Site
  - Configura NAT para su red local
  - Expone puerto 1194/UDP para conexiones VPN
  - Genera automáticamente certificados CA, servidor y clientes
  - **Interfaz VNC web disponible** para acceso gráfico

### Sitio B - Gateway VPN Client
- **Función**: Gateway de red 192.168.2.0/24 con cliente OpenVPN
- **IP Local**: 192.168.2.1
- **IP VPN**: 10.8.0.2
- **Características**:
  - Se conecta automáticamente al servidor A
  - Configura NAT para su red local
  - Puede comunicarse con A a través del túnel VPN
  - **Interfaz VNC web disponible** para acceso gráfico

### Kali Linux (Sitio A)
- **Función**: Máquina de pruebas en la red del Sitio A
- **IP Local**: 192.168.1.10
- **Características**:
  - Máquina Kali con interfaz gráfica web
  - **NO tiene túnel VPN** - solo acceso a red local
  - Puede comunicarse con Gateway A (misma red)
  - **NO puede acceder a Sitio B** (diferente red)
  - Accesible en http://localhost:6902

## Uso

### Levantar el entorno

```bash
docker compose up -d --build
```

### Acceder a las interfaces web

- **Sitio A VNC**: http://localhost:5901 (sin contraseña)
- **Sitio B VNC**: http://localhost:5902 (sin contraseña)
- **Kali GUI**: http://localhost:6902 (usuario: kasm-user, contraseña: kalipass)

### Ejecutar pruebas de conectividad

```bash
# Ejecutar script de pruebas completo
./test_connectivity.sh
```

### Verificaciones manuales

```bash
# Verificar interfaces VPN
docker exec -it client-a ip addr show tun0
docker exec -it client-b ip addr show tun0

# Probar conectividad VPN Site-to-Site
docker exec -it client-a curl -s http://10.8.0.2:8080
docker exec -it client-b curl -s http://10.8.0.1:8080

# Probar conectividad entre sitios
docker exec -it client-a ping -c 2 192.168.2.1
docker exec -it client-b ping -c 2 192.168.1.1

# Verificar aislamiento de Kali
docker exec -it kali-c ping -c 2 192.168.1.1  # Debe funcionar (misma red)
docker exec -it kali-c ping -c 2 192.168.2.1  # NO debe funcionar (diferente red)
```

### Verificar que Kali NO puede acceder a la VPN

Kali Linux está configurado para:
- ✅ Acceder a Gateway A (192.168.1.1) - misma red
- ❌ NO acceder a Gateway B (192.168.2.1) - diferente red
- ❌ NO acceder a servicios VPN (10.8.0.x) - sin túnel VPN

## Características de Seguridad

1. **Certificados X.509**: Autenticación mutua usando certificados digitales
2. **Comunicación cifrada**: Todo el tráfico entre sitios pasa por el túnel VPN cifrado con AES-256-CBC
3. **Aislamiento de red**: Cada sitio tiene su propia red local aislada
4. **Site-to-Site**: Comunicación directa entre gateways a través del túnel VPN
5. **TLS-Auth**: Protección adicional contra ataques de denegación de servicio
6. **NAT Gateway**: Cada gateway actúa como router NAT para su red local
7. **Seguridad por aislamiento**: Kali no puede acceder a la VPN ni al otro sitio

## Configuración de Red

### Redes Locales
- **Sitio A**: 192.168.1.0/24 (Gateway: 192.168.1.1)
- **Sitio B**: 192.168.2.0/24 (Gateway: 192.168.2.1)

### Red VPN
- **Red VPN**: 10.8.0.0/24
- **Gateway A**: 10.8.0.1
- **Gateway B**: 10.8.0.2
- **Puerto**: 1194/UDP
- **Cifrado**: AES-256-CBC
- **Autenticación**: Certificados X.509 + TLS-Auth

## Configuración Avanzada

Las variables de entorno en `docker-compose.yml` permiten personalizar:

- `VPN_ROLE`: "server" para A, "client" para B
- `VPN_SERVER_IP`: IP del servidor (client-a para B)
- `VPN_CLIENT_IP`: IP VPN asignada al cliente
- `SITE_NETWORK`: Red local del sitio
- `SITE_GATEWAY`: IP del gateway local

## Resolución de Problemas VPN

### Problema: Cliente B no puede establecer conexión VPN

**Síntomas:**
- El cliente B no puede acceder al puerto 1194 del servidor A
- La interfaz tun0 del cliente B no se activa
- Error "Connection refused (code=111)" en los logs de OpenVPN

**Causas identificadas:**
1. **Detección incorrecta de servidor**: El script usaba TCP para verificar puerto UDP
2. **Rutas de certificados incorrectas**: OpenVPN buscaba archivos en directorio relativo
3. **Directorio de trabajo incorrecto**: OpenVPN se ejecutaba desde `/root` en lugar de `/etc/openvpn`
4. **Configuración manual requerida**: La interfaz tun0 necesita activación manual

### Comandos para Resolver el Problema

#### 1. Verificar estado actual
```bash
# Ejecutar script de diagnóstico
./test_connectivity.sh

# Verificar interfaces VPN
docker exec client-a ip addr show tun0
docker exec client-b ip addr show tun0

# Verificar procesos OpenVPN
docker exec client-a ps aux | grep openvpn
docker exec client-b ps aux | grep openvpn
```

#### 2. Reiniciar contenedores
```bash
# Reiniciar todo el entorno
docker compose down
docker compose up -d --build

# O reiniciar solo el cliente B
docker compose restart client-b
```

#### 3. Configuración manual de interfaz VPN (si es necesario)
```bash
# Activar interfaz tun0 en cliente B
docker exec client-b ip link set tun0 up
docker exec client-b ip addr add 10.8.0.2/24 dev tun0

# Verificar configuración
docker exec client-b ip addr show tun0
```

#### 4. Reiniciar procesos OpenVPN manualmente
```bash
# Detener procesos existentes
docker exec client-a pkill -f openvpn
docker exec client-b pkill -f openvpn

# Iniciar servidor
docker exec client-a bash -c "cd /etc/openvpn && openvpn --config server.conf --daemon"

# Iniciar cliente
docker exec client-b bash -c "cd /etc/openvpn && openvpn --config client.conf --daemon"
```

#### 5. Verificar conectividad final
```bash
# Probar conectividad VPN
docker exec client-a ping -c 3 10.8.0.2
docker exec client-b ping -c 3 10.8.0.1

# Ejecutar script de pruebas completo
./test_connectivity.sh
```

### Estado Esperado Después de la Resolución

**✅ Servidor A (client-a):**
- Interfaz tun0 con IP 10.8.0.1
- Servidor OpenVPN escuchando en puerto 1194 UDP
- Rutas VPN configuradas

**✅ Cliente B (client-b):**
- Interfaz tun0 con IP 10.8.0.2
- Cliente OpenVPN conectado al servidor
- Rutas VPN configuradas

**✅ Conectividad:**
- A ↔ B (172.20.0.x) - Conectividad básica
- A ↔ B (10.8.0.x) - Conectividad VPN
- Kali aislado sin acceso VPN

## Notas

- Los certificados se generan automáticamente al iniciar cada contenedor
- El túnel VPN se establece automáticamente entre los gateways
- Cada gateway configura NAT automáticamente para su red local
- Para uso en producción, usar certificados firmados por una CA externa
- El hostname `client-a` es resoluble dentro de la red Docker bridge
- **Importante**: Si el cliente B no se conecta automáticamente, usar los comandos de resolución de problemas

