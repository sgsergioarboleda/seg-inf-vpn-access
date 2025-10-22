FROM openvpn/openvpn-as:latest

# Añadimos un entrypoint que arranca AS y luego aplica configuración vía sacli.
COPY entrypoint.sh /usr/local/bin/entrypoint-bootstrap.sh
RUN chmod +x /usr/local/bin/entrypoint-bootstrap.sh

# Conservamos el proceso principal en primer plano al final del script.
ENTRYPOINT ["/usr/local/bin/entrypoint-bootstrap.sh"]

