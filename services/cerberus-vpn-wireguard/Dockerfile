# Cerberus VPN - WireGuard Server
# High-performance VPN using kernel WireGuard

FROM debian:bookworm-slim

LABEL maintainer="Penguin Tech Inc"
LABEL description="Cerberus WireGuard VPN Server"

# Install WireGuard and dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    wireguard-tools \
    iptables \
    iproute2 \
    procps \
    curl \
    jq \
    qrencode \
    && rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /etc/wireguard /data/wireguard

# Copy scripts
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh

# Copy default config template
COPY config/ /etc/wireguard/

# Environment variables
ENV WG_INTERFACE=wg0
ENV WG_PORT=51820
ENV WG_ADDRESS=10.100.0.1/24
ENV WG_DNS=1.1.1.1,8.8.8.8
ENV WG_ALLOWED_IPS=0.0.0.0/0
ENV WG_PERSISTENT_KEEPALIVE=25
ENV WG_POST_UP="iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE"
ENV WG_POST_DOWN="iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE"
ENV API_LISTEN_ADDR=:8080

# Expose ports
EXPOSE 51820/udp
EXPOSE 8080/tcp

# Volume for persistent data
VOLUME ["/data/wireguard"]

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wg show ${WG_INTERFACE} 2>/dev/null || exit 1

# Entrypoint
ENTRYPOINT ["/scripts/entrypoint.sh"]
