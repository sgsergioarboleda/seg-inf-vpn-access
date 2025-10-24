FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends openvpn easy-rsa iproute2 iputils-ping && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/openvpn /etc/openvpn/ccd
COPY ovpn-entrypoint.sh /usr/local/bin/ovpn-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/ovpn-entrypoint.sh"]
