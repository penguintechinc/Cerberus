[![CI](https://github.com/PenguinCloud/Cerberus/actions/workflows/ci.yml/badge.svg)](https://github.com/PenguinCloud/Cerberus/actions/workflows/ci.yml)
[![Docker Build](https://github.com/PenguinCloud/Cerberus/actions/workflows/docker-build.yml/badge.svg)](https://github.com/PenguinCloud/Cerberus/actions/workflows/docker-build.yml)
[![codecov](https://codecov.io/gh/PenguinCloud/Cerberus/branch/main/graph/badge.svg)](https://codecov.io/gh/PenguinCloud/Cerberus)
[![version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://semver.org)
[![License](https://img.shields.io/badge/License-Limited%20AGPL3-blue.svg)](LICENSE.md)

```
  _____ _____ ____  ____  ___________  _   _______
 / ____| ____|  _ \|  _ \|  _______ \| | | / _____|
| |    | |_  | |_) | |_) | |_______| | | | (___
| |    |  _| |  __/|  _ <|______   | | | |\___ \
| |____| |___| |   | |_) |_______| | | |_|____) |
 \_____|_____|_|   |____/|__________|_|\___/|____/

     Enterprise NGFW/UTM Platform for Datacenter Edge
```

# Cerberus NGFW

**Enterprise-Grade Next-Generation Firewall and Unified Threat Management**

Cerberus NGFW is a comprehensive, enterprise-ready Next-Generation Firewall (NGFW) and Unified Threat Management (UTM) platform purpose-built for datacenter edge deployments. Built on MarchProxy technology, Cerberus delivers high-performance packet processing, advanced threat detection, and multi-layered network security in a containerized, Kubernetes-ready architecture.

## Features

### Network Security & Filtering
- **IPS Engine**: Suricata-powered Intrusion Prevention System with real-time threat detection
- **Content Filtering**: Advanced DPI (Deep Packet Inspection) and policy-based content control
- **SSL/TLS Inspection**: Decrypt and inspect encrypted traffic for threat detection
- **Packet Steering**: XDP (eXpress Data Path) kernel-level packet processing for sub-millisecond latency

### VPN Services
- **WireGuard**: Modern, high-performance VPN protocol with minimal overhead
- **IPSec**: Standards-based VPN for enterprise interoperability
- **OpenVPN**: Community-supported VPN protocol for broad compatibility

### Architecture & Performance
- **High-Performance Backend**: Go-based services for handling >10K requests/second
- **Scalable API**: Flask + Flask-Security-Too backend with multi-tenant support
- **Modern WebUI**: ReactJS-based dashboard with real-time monitoring
- **MarchProxy Integration**: Transparent proxy for advanced traffic manipulation

### Enterprise Features
- **Role-Based Access Control (RBAC)**: Admin, Maintainer, and Viewer roles
- **JWT Authentication**: Secure, stateless API authentication
- **Multi-Database Support**: PostgreSQL, MySQL, MariaDB via PyDAL
- **License Server Integration**: Feature gating via PenguinTech License Server
- **Monitoring & Observability**: Prometheus metrics and structured logging

## Quick Start

### Prerequisites
- Docker and Docker Compose 20.10+
- Git
- 4GB RAM minimum (8GB recommended)

### Local Development

```bash
# Clone the repository
git clone https://github.com/PenguinCloud/Cerberus.git
cd Cerberus

# Install dependencies and setup environment
make setup

# Start the development environment
make dev

# Verify all services are healthy
make health
```

The WebUI will be available at `http://localhost:3000` and the API at `http://localhost:5000`.

### Production Deployment

```bash
# Build all service containers
make docker-build

# Deploy to Kubernetes (requires kubectl and Helm)
make deploy-prod
```

## Architecture Overview

Cerberus uses a three-container microservices architecture for optimal scalability and separation of concerns:

```
┌─────────────────────────────────────────────────────┐
│              WebUI (React + Node.js)                │
│         Modern, responsive dashboard interface      │
└────────────────────┬────────────────────────────────┘
                     │ REST API (http://api:5000)
                     │
┌────────────────────▼────────────────────────────────┐
│         Flask Backend (Python 3.13)                 │
│  • Authentication & Authorization (Flask-Security)  │
│  • User Management & RBAC                           │
│  • Policy Management API                            │
│  • Database ORM (PyDAL)                             │
└────────────────────┬────────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
        ▼            ▼            ▼
   ┌─────────┐ ┌─────────┐ ┌─────────┐
   │ Filter  │ │   IPS   │ │  VPN    │
   │ Engine  │ │ (Suricata)  Services │
   │ (Go)    │ │ (Go)    │ │ (Go)    │
   └─────────┘ └─────────┘ └─────────┘
        │            │            │
        └────────────┼────────────┘
                     │
        ┌────────────▼────────────┐
        │    PostgreSQL/Redis     │
        │    (Persistent Storage) │
        └─────────────────────────┘
```

### Service Components

| Service | Language | Purpose | Load |
|---------|----------|---------|------|
| **webui** | Node.js + React | User interface and dashboards | <1K req/sec |
| **flask-backend** | Python 3.13 | APIs, auth, user management | <5K req/sec |
| **cerberus-filter** | Go | Content filtering, DPI engine | >10K req/sec |
| **cerberus-ips** | Go | Suricata IPS integration | >10K req/sec |
| **cerberus-ssl-inspector** | Go | SSL/TLS decryption & inspection | >10K req/sec |
| **cerberus-vpn-wireguard** | Go | WireGuard VPN service | >10K concurrent |
| **cerberus-vpn-ipsec** | Go | IPSec VPN service | >10K concurrent |
| **cerberus-vpn-openvpn** | Go | OpenVPN service | >10K concurrent |

### Data Flow

1. **Inbound Traffic** → XDP packet steering
2. **Traffic Analysis** → Suricata IPS engine checks against threat signatures
3. **Policy Evaluation** → Flask API evaluates content and policy rules
4. **SSL Inspection** → Decrypt/inspect encrypted traffic (if enabled)
5. **Action Taken** → Allow, block, redirect, or mirror traffic
6. **Logging** → Structured logs to centralized logging system

## Essential Commands

### Development
```bash
make setup                    # Install dependencies and setup
make dev                      # Start all services
make test                     # Run all tests
make lint                     # Run linters
make build                    # Build all services
make clean                    # Clean build artifacts
```

### Docker
```bash
make docker-build             # Build all containers
make docker-push              # Push to registry
make health                   # Check service health
docker-compose logs -f <service>  # View service logs
```

### Deployment
```bash
make deploy-dev               # Deploy to development environment
make deploy-prod              # Deploy to production
make rollback                 # Rollback to previous version
```

## Configuration

### Environment Variables

**Core Configuration**
```bash
# Flask Backend
FLASK_ENV=development|production
FLASK_DEBUG=0|1
SECRET_KEY=your-secret-key

# Database (supports PostgreSQL, MySQL, MariaDB)
DB_TYPE=postgres              # postgres, mysql, sqlite, oracle, etc.
DB_HOST=postgres
DB_PORT=5432
DB_NAME=cerberus
DB_USER=cerberus
DB_PASSWORD=secure-password

# Redis Cache
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=

# License Server
LICENSE_KEY=PENG-XXXX-XXXX-XXXX-XXXX-ABCD
LICENSE_SERVER_URL=https://license.penguintech.io
PRODUCT_NAME=cerberus-ngfw
RELEASE_MODE=false            # Set to true in production
```

**Security**
```bash
# TLS Configuration
TLS_CERT_PATH=/etc/certs/tls.crt
TLS_KEY_PATH=/etc/certs/tls.key
TLS_MIN_VERSION=1.2

# IPS Engine
SURICATA_HOME=/var/lib/suricata
SURICATA_RULE_PATH=/etc/suricata/rules

# SSL/TLS Inspection
ENABLE_SSL_INSPECTION=false
SSL_INSPECTION_CERT_PATH=/etc/certs/inspection.crt
SSL_INSPECTION_KEY_PATH=/etc/certs/inspection.key
```

**VPN Services**
```bash
# WireGuard
WIREGUARD_INTERFACE=wg0
WIREGUARD_PORT=51820

# IPSec
IPSEC_CONFIG_PATH=/etc/ipsec.conf
IPSEC_SECRETS_PATH=/etc/ipsec.secrets

# OpenVPN
OPENVPN_CONFIG_PATH=/etc/openvpn/server.conf
OPENVPN_PORT=1194
```

See `.env.example` for complete configuration options.

## Documentation

Comprehensive documentation is available in the `docs/` folder:

- **[Getting Started](docs/development/)** - Setup, development, and deployment guides
- **[API Reference](docs/api/)** - Complete REST API documentation
- **[Architecture](docs/architecture/)** - Detailed architecture and design patterns
- **[Deployment Guide](docs/deployment/)** - Production deployment procedures
- **[Configuration Guide](docs/configuration/)** - Advanced configuration options
- **[License Integration](docs/licensing/)** - PenguinTech License Server setup
- **[Network Standards](docs/standards/)** - Network protocol specifications
- **[Troubleshooting](docs/troubleshooting/)** - Common issues and solutions

## Support & Resources

- **Documentation**: [./docs/](docs/)
- **API Health Check**: `GET http://localhost:5000/api/v1/health`
- **Metrics**: `GET http://localhost:5000/metrics` (Prometheus)
- **License Status**: Visit https://license.penguintech.io
- **Premium Support**: https://support.penguintech.io
- **Community Issues**: [GitHub Issues](https://github.com/PenguinCloud/Cerberus/issues)
- **Status Page**: https://status.penguintech.io

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on:
- Code style and standards
- Testing requirements
- Commit message format
- Pull request process

### Development Team

- **Primary Maintainers**: Penguin Tech Inc
- **Company**: [www.penguintech.io](https://www.penguintech.io)
- **Contact**: info@penguintech.io

## License

This project is licensed under the **Limited AGPL3 with preamble for fair use** - see [LICENSE.md](docs/LICENSE.md) for details.

**License Highlights:**
- **Personal & Internal Use**: Free under AGPL-3.0
- **Commercial Use**: Requires commercial license
- **SaaS Deployment**: Requires commercial license if providing as a service

### Contributor Employer Exception (GPL-2.0 Grant)

Companies employing official contributors receive GPL-2.0 access to community features:

- **Perpetual for Contributed Versions**: GPL-2.0 rights to versions where employees contributed remain valid permanently
- **Attribution Required**: Contributor must be credited in commit history or release notes
- **Future Versions**: New versions released after employment ends require standard licensing
- **Community Only**: Enterprise features still require a commercial license

## Performance Specifications

- **Throughput**: >100 Gbps (with appropriate hardware)
- **Latency**: <10ms average (XDP-enabled)
- **Concurrent Connections**: >100K simultaneous sessions
- **IPS Signatures**: >50K threat definitions (Suricata)
- **Packet Rate**: >1M packets/second
- **CPU**: Optimized for modern multi-core processors (NUMA-aware)

## Roadmap

- Q1 2025: Advanced threat intelligence integration
- Q2 2025: Multi-tenant support enhancements
- Q3 2025: Machine learning-based anomaly detection
- Q4 2025: Enhanced compliance reporting (SOC2, PCI-DSS)

## Acknowledgments

Cerberus NGFW is built on proven technologies:
- **Suricata IPS**: Open-source threat detection engine
- **MarchProxy**: Advanced packet processing framework
- **WireGuard**: Modern VPN protocol
- **Flask-Security-Too**: Enterprise-grade authentication
- **PyDAL**: Multi-database abstraction layer

---

**Cerberus NGFW v1.0.0**
Enterprise NGFW Platform for Modern Datacenters
Built by [Penguin Tech Inc](https://www.penguintech.io)
Licensed under Limited AGPL3
Status: [https://status.penguintech.io](https://status.penguintech.io)
