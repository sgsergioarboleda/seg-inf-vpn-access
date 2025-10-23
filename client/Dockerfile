FROM dorowu/ubuntu-desktop-lxde-vnc:focal-lxqt

# Remover repositorio problemático de Google Chrome y actualizar
RUN rm -f /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      openvpn iptables ca-certificates curl python3 iproute2 net-tools \
      openssl netcat-openbsd && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENV CLIENT_NAME=""
ENV CLIENT_USER=""
ENV CLIENT_PASS=""
ENV HELLO_TEXT="Hello"
ENV HTTP_PORT=8080
ENV VPN_ROLE="client"
ENV VPN_SERVER_IP="client-a"
ENV VPN_CLIENT_IP="10.8.0.2"
ENV VPN_SERVER_IP_RANGE="10.8.0.1"
ENV VPN_CLIENT_IPS="10.8.0.2,10.8.0.3"

# Configuración VNC sin contraseña
ENV VNC_PW=""
ENV VNC_RESOLUTION=1024x768

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

