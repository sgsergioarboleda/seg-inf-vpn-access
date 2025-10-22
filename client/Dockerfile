FROM debian:stable-slim

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      openvpn iptables ca-certificates curl python3 && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENV CLIENT_NAME=""
ENV CLIENT_USER=""
ENV CLIENT_PASS=""
ENV HELLO_TEXT="Hello"
ENV HTTP_PORT=8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

