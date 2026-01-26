# DNSTT SSH Panel

Complete DNSTT DNS tunnel server setup for Ubuntu 24.04 LTS with an enhanced ncurses/dialog-based CLI management panel. Tunnels to local SSH port 22 for secure access via DNS queries.

Based on [bugfloyd/dnstt-deploy](https://github.com/bugfloyd/dnstt-deploy) with significant enhancements.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04%20LTS-orange.svg)

## Features

### Core
- **One-click installation** - Fully automated setup with `dnstt-panel-installer.sh`
- **SSH mode tunneling** - Tunnel to local SSH port 22 via DNS queries
- **Binary verification** - MD5, SHA1, SHA256 checksum validation
- **Systemd integration** - Automatic startup, restart on failure
- **Security hardened** - Non-root service execution, capability restrictions

### Enhanced CLI Panel (`dnstt-panel`)
- **Real-time dashboard** - Connection count, memory, CPU, uptime stats
- **Service controls** - Start/Stop/Restart with one keypress
- **Configuration editor** - Modify domain, MTU without editing files
- **Client config generator** - Export settings for HTTP Injector, DNSTT.XYZ
- **Live log viewer** - Streaming journalctl output
- **Connection monitor** - Active connection tracking

### Network
- **Automatic firewall setup** - UFW + iptables configuration
- **Port redirect** - UDP 53 → 5300 for non-root operation
- **SSH hardening** - Enables PermitTunnel for tunnel support

---

## Prerequisites

### Server Requirements
- Ubuntu 24.04 LTS (also works on 22.04, Debian 12)
- Root access
- Public IP address
- Domain with DNS access

### DNS Configuration

Before running the installer, configure your DNS:

1. **Create NS Record** pointing your tunnel subdomain to a nameserver:
   ```
   t.example.com.    IN    NS    ns.example.com.
   ```

2. **Create A Record** for the nameserver pointing to your server IP:
   ```
   ns.example.com.   IN    A     YOUR_SERVER_IP
   ```

**Example for `t.example.com` with server IP `1.2.3.4`:**
| Type | Name | Value |
|------|------|-------|
| NS | t | ns.example.com |
| A | ns | 1.2.3.4 |

---

## Quick Start

### One-Click Installation

```bash
# Download and run installer
bash <(curl -Ls https://raw.githubusercontent.com/atakhadiviom/DNSTT-SSH-Panel/main/dnstt-panel-installer.sh)
```

Or clone and run:

```bash
git clone https://github.com/atakhadiviom/DNSTT-SSH-Panel.git
cd DNSTT-SSH-Panel
sudo bash dnstt-panel-installer.sh
```

### Installation Process

1. **Enter your domain** (e.g., `t.example.com`)
2. **Set MTU** (default: 1232)
3. **Confirm SSH mode**
4. Installer auto-configures:
   - Downloads and verifies dnstt-server binary
   - Creates system user and generates keys
   - Configures firewall (UFW + iptables)
   - Creates and starts systemd service
   - Installs management panel

### Post-Installation

Access the management panel:
```bash
dnstt-panel
```

Or use quick commands:
```bash
# Service management
sudo systemctl status dnstt-server
sudo systemctl restart dnstt-server

# View logs
journalctl -u dnstt-server -f
```

---

## Client Setup

### Desktop (Linux/macOS/Windows)

1. **Download client** from [dnstt.network](https://dnstt.network):
   - Linux x64: `dnstt-client-linux-amd64`
   - macOS Intel: `dnstt-client-darwin-amd64`
   - macOS ARM: `dnstt-client-darwin-arm64`
   - Windows: `dnstt-client-windows-amd64.exe`

2. **Save public key** (displayed after installation) to `server.pub`

3. **Run client:**
   ```bash
   ./dnstt-client -udp DNS_IP:53 -pubkey-file server.pub t.example.com 127.0.0.1:7000
   ```

4. **Connect via SSH:**
   ```bash
   ssh -p 7000 username@127.0.0.1
   ```

### DNS_IP Options
- Your ISP's DNS server
- Router IP (e.g., `192.168.1.1`)
- System DNS: `127.0.0.53` (systemd-resolved)
- Public DNS: `8.8.8.8` or `1.1.1.1` (if allowed)

Check your DNS:
```bash
# Linux
systemd-resolve --status | grep "DNS Servers"

# macOS
scutil --dns | grep nameserver

# Windows
ipconfig /all | findstr "DNS Servers"
```

---

### Mobile Apps (Android/iOS)

#### HTTP Injector (Recommended)

**Download:**
- [Android - Play Store](https://play.google.com/store/apps/details?id=com.evozi.injector)
- [iOS - App Store](https://apps.apple.com/us/app/http-injector/id1659992827)

**Configuration:**

1. **SSH Settings:**
   | Setting | Value |
   |---------|-------|
   | Host | 127.0.0.1 |
   | Port | 7000 |
   | Username | Your SSH username |
   | Password | Your SSH password |

2. **DNS Tunnel Settings:**
   | Setting | Value |
   |---------|-------|
   | DNS Server | Your ISP DNS or 8.8.8.8 |
   | DNS/DNSTT Mode | Enabled |
   | DNS Domain | t.example.com |
   | Public Key | (from server) |

#### DNSTT.XYZ App

| Setting | Value |
|---------|-------|
| Server Domain | t.example.com |
| Public Key | (from server) |
| Local Port | 7000 |

After connecting, use any SSH client to connect to `127.0.0.1:7000`.

#### Other Compatible Apps
- [HTTP Custom](https://play.google.com/store/apps/details?id=xyz.easypro.httpcustom) (Android)
- [DarkTunnel](https://play.google.com/store/apps/details?id=net.darktunnel.app) (Android)

---

## Panel Usage

Launch the panel:
```bash
dnstt-panel
# or with sudo for full control
sudo dnstt-panel
```

### Dashboard
```
╔════════════════════════════════════════════════════════════════════════╗
║                         DNSTT SERVER DASHBOARD                         ║
╠════════════════════════════════════════════════════════════════════════╣
║  ┌─ Service Status ─────────────────────────────────────────────────┐  ║
║  │  Status:       RUNNING                                           │  ║
║  │  Uptime:       2d 5h 30m                                         │  ║
║  │  Connections:  3 active                                          │  ║
║  │  Memory:       12.5 MB                                           │  ║
║  │  CPU:          0.5%                                              │  ║
║  └──────────────────────────────────────────────────────────────────┘  ║
╚════════════════════════════════════════════════════════════════════════╝
```

### Menu Options
| Key | Action |
|-----|--------|
| 1 | Refresh Dashboard |
| 2 | Service Controls (Start/Stop/Restart) |
| 3 | View Live Logs |
| 4 | Edit Configuration |
| 5 | Generate Client Configs |
| 6 | Connection Monitor |
| 7 | System Information |
| 0 | Exit |

---

## File Locations

| File | Path |
|------|------|
| Config | `/etc/dnstt/dnstt-server.conf` |
| Private Key | `/etc/dnstt/dnstt-server.key` |
| Public Key | `/etc/dnstt/dnstt-server.pub` |
| Binary | `/usr/local/bin/dnstt-server` |
| Panel | `/usr/local/bin/dnstt-panel` |
| Service | `/etc/systemd/system/dnstt-server.service` |

---

## Security Best Practices

### Server Hardening

1. **Use SSH key authentication:**
   ```bash
   # Disable password auth
   sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
   sudo systemctl restart sshd
   ```

2. **Install fail2ban:**
   ```bash
   sudo apt install fail2ban
   ```

3. **Keep system updated:**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

4. **Use strong SSH keys:**
   ```bash
   ssh-keygen -t ed25519 -a 100
   ```

### Firewall Rules

The installer configures these rules:
```bash
# View current rules
sudo ufw status numbered
sudo iptables -t nat -L -n -v

# Manual rule management
sudo ufw allow 22/tcp  # SSH
sudo ufw allow 53/udp  # DNS (DNSTT)
```

### Key Security

- Private key is stored with mode 600 (owner-only read)
- Service runs as unprivileged `dnstt` user
- systemd enforces capability restrictions

---

## Troubleshooting

### Service Won't Start
```bash
# Check logs
journalctl -u dnstt-server -n 50 --no-pager

# Verify configuration
cat /etc/dnstt/dnstt-server.conf

# Check binary
/usr/local/bin/dnstt-server -h
```

### Connection Issues

1. **Verify DNS records:**
   ```bash
   dig NS t.example.com
   dig A ns.example.com
   ```

2. **Check firewall:**
   ```bash
   sudo ufw status
   sudo iptables -t nat -L PREROUTING -n -v
   ```

3. **Test locally:**
   ```bash
   nc -uvz localhost 5300
   ```

### MTU Issues
If connections drop or are unstable, try lower MTU:
```bash
# Edit in panel or manually:
sudo sed -i 's/MTU_VALUE=.*/MTU_VALUE="1000"/' /etc/dnstt/dnstt-server.conf
sudo systemctl restart dnstt-server
```

---

## Advanced

### Persistent Panel Mode
Run panel on a dedicated TTY (useful for headless servers):
```bash
sudo systemctl enable dnstt-panel
sudo systemctl start dnstt-panel
```

### Multiple Domains
Edit the systemd service to add multiple instances:
```bash
sudo systemctl edit dnstt-server
# Add custom ExecStart with different domain
```

### Auto-Updates
Add to crontab for automatic updates:
```bash
# Weekly update check
0 3 * * 0 /usr/local/bin/dnstt-deploy --update 2>/dev/null
```

---

## Credits

- [DNSTT](https://www.bamsoftware.com/software/dnstt/) by David Fifield
- [bugfloyd/dnstt-deploy](https://github.com/bugfloyd/dnstt-deploy) - Original deployment script
- [dnstt.network](https://dnstt.network) - Official binary distribution

---

## License

MIT License - See [LICENSE](LICENSE) file for details.

---

## Support

- **Issues:** Open a GitHub issue
- **Documentation:** Check the [wiki](../../wiki)
- **Updates:** Watch this repository for updates
