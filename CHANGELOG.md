# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-01-26

### Added
- Initial release
- Main installer script (`dnstt-panel-installer.sh`)
  - OS detection for Ubuntu 24.04 LTS
  - Automatic dependency installation
  - DNSTT server binary download with checksum verification (MD5, SHA1, SHA256)
  - System user creation with restricted permissions
  - Keypair generation
  - UFW and iptables firewall configuration
  - SSH hardening (PermitTunnel enabled)
- Enhanced CLI panel (`dnstt-panel.sh`)
  - ncurses/dialog-based dashboard
  - Real-time stats (connections, memory, CPU, uptime)
  - Service controls (start/stop/restart)
  - Configuration editor
  - Client config generator with public key export
  - Live log viewer with filtering
  - Connection monitor
  - System information display
- Systemd services
  - `dnstt-server.service` with security hardening
  - `dnstt-panel.service` for persistent panel mode
- One-line quick installer (`install.sh`)
- Comprehensive documentation
  - Installation guide
  - Client setup (Desktop, HTTP Injector, DNSTT.XYZ)
  - Security best practices
  - Troubleshooting guide

### Security
- Non-root service execution
- Systemd security hardening (NoNewPrivileges, ProtectSystem, etc.)
- PermitTunnel SSH configuration
- Capability restrictions (CAP_NET_BIND_SERVICE only)
