# Cerberus IPS - Suricata 7.x Inline IPS Container
# Base: Debian Bookworm with Suricata from OISF PPA

FROM debian:bookworm-slim

LABEL maintainer="Penguin Tech Inc <support@penguintech.io>"
LABEL description="Cerberus IPS - Suricata 7.x inline intrusion prevention"
LABEL version="1.0.0"

# Environment variables
ENV SURICATA_MODE=ips
ENV SURICATA_INTERFACE=eth0
ENV SURICATA_HOME_NET="[192.168.0.0/16,10.0.0.0/8,172.16.0.0/12]"
ENV LOG_LEVEL=info
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies and Suricata
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    gnupg2 \
    curl \
    ca-certificates \
    libpcre3 \
    libyaml-0-2 \
    libjansson4 \
    libpcap0.8 \
    libnet1 \
    libnetfilter-queue1 \
    libhtp2 \
    liblz4-1 \
    python3 \
    python3-pip \
    python3-yaml \
    iptables \
    nftables \
    ethtool \
    iproute2 \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Add OISF Suricata repository and install Suricata 7.x
# Note: eBPF disabled as it requires kernel headers not available in containers
RUN curl -fsSL https://www.openinfosecfoundation.org/download/suricata-7.0.3.tar.gz -o /tmp/suricata.tar.gz \
    && apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    autoconf \
    automake \
    libtool \
    pkg-config \
    libpcre2-dev \
    libyaml-dev \
    libjansson-dev \
    libpcap-dev \
    libnet1-dev \
    libnetfilter-queue-dev \
    libnfnetlink-dev \
    libhtp-dev \
    liblz4-dev \
    libmagic-dev \
    zlib1g-dev \
    libcap-ng-dev \
    liblua5.1-dev \
    rustc \
    cargo \
    && cd /tmp \
    && tar xzf suricata.tar.gz \
    && cd suricata-7.0.3 \
    && ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var \
        --enable-nfqueue \
        --enable-af-packet \
        --disable-ebpf \
        --enable-lua \
        --disable-gccmarch-native \
    && make -j$(nproc) \
    && make install \
    && make install-conf \
    && cd / \
    && rm -rf /tmp/suricata* \
    && apt-get purge -y build-essential autoconf automake libtool pkg-config \
        libpcre2-dev libyaml-dev libjansson-dev libpcap-dev libnet1-dev \
        libnetfilter-queue-dev libnfnetlink-dev libhtp-dev liblz4-dev \
        libmagic-dev zlib1g-dev libcap-ng-dev liblua5.1-dev rustc cargo \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /var/log/suricata \
    && mkdir -p /var/lib/suricata/rules \
    && mkdir -p /var/run/suricata \
    && mkdir -p /etc/suricata/rules

# Install suricata-update for rule management
RUN pip3 install --no-cache-dir --break-system-packages suricata-update

# Copy configuration files
COPY config/suricata.yaml /etc/suricata/suricata.yaml
COPY config/threshold.config /etc/suricata/threshold.config
COPY config/classification.config /etc/suricata/classification.config
COPY config/reference.config /etc/suricata/reference.config
COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/update-rules.sh /usr/local/bin/update-rules.sh
COPY scripts/healthcheck.sh /usr/local/bin/healthcheck.sh

RUN chmod +x /entrypoint.sh /usr/local/bin/update-rules.sh /usr/local/bin/healthcheck.sh

# Expose prometheus metrics port
EXPOSE 9100

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

# Volume for rules and logs
VOLUME ["/var/lib/suricata/rules", "/var/log/suricata"]

ENTRYPOINT ["/entrypoint.sh"]
CMD ["suricata"]
