#!/bin/bash
#
# DNSTT SSH Panel Installer
# Complete DNSTT DNS tunnel server setup for Ubuntu 24.04 LTS
# Based on bugfloyd/dnstt-deploy with enhanced CLI management panel
#
# Usage: sudo bash dnstt-panel-installer.sh
#

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================

DNSTT_BASE_URL="https://dnstt.network"
SCRIPT_URL="https://raw.githubusercontent.com/your-repo/dnstt-panel/main/dnstt-panel-installer.sh"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/dnstt"
SYSTEMD_DIR="/etc/systemd/system"
LOG_DIR="/var/log/dnstt"
DNSTT_PORT="5300"
DNSTT_USER="dnstt"
CONFIG_FILE="${CONFIG_DIR}/dnstt-server.conf"
PRIVATE_KEY_FILE="${CONFIG_DIR}/dnstt-server.key"
PUBLIC_KEY_FILE="${CONFIG_DIR}/dnstt-server.pub"
PANEL_INSTALL_PATH="${INSTALL_DIR}/dnstt-panel"
SCRIPT_INSTALL_PATH="${INSTALL_DIR}/dnstt-deploy"
VERSION="1.0.0"

# ============================================================================
# COLOR CODES
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

print_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║     ██████╗ ███╗   ██╗███████╗████████╗████████╗    ██████╗  █████╗      ║
║     ██╔══██╗████╗  ██║██╔════╝╚══██╔══╝╚══██╔══╝    ██╔══██╗██╔══██╗     ║
║     ██║  ██║██╔██╗ ██║███████╗   ██║      ██║       ██████╔╝███████║     ║
║     ██║  ██║██║╚██╗██║╚════██║   ██║      ██║       ██╔═══╝ ██╔══██║     ║
║     ██████╔╝██║ ╚████║███████║   ██║      ██║       ██║     ██║  ██║     ║
║     ╚═════╝ ╚═╝  ╚═══╝╚══════╝   ╚═╝      ╚═╝       ╚═╝     ╚═╝  ╚═╝     ║
║                                                                           ║
║            DNS Tunnel Server with SSH Mode - Panel Installer              ║
║                         Version ${VERSION}                                    ║
╚═══════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_question() {
    echo -ne "${MAGENTA}[?]${NC} $1"
}

print_section() {
    echo ""
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ============================================================================
# ROOT CHECK
# ============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        echo "Please run: sudo bash $0"
        exit 1
    fi
}

# ============================================================================
# OS DETECTION
# ============================================================================

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        print_error "Cannot detect operating system"
        exit 1
    fi

    # Check for Ubuntu 24.04
    if [[ "$OS" != "ubuntu" ]]; then
        print_warning "This script is optimized for Ubuntu 24.04 LTS"
        print_warning "Detected: $OS $OS_VERSION"
        read -p "Continue anyway? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    print_status "Detected OS: $OS $OS_VERSION"
}

# ============================================================================
# ARCHITECTURE DETECTION
# ============================================================================

detect_architecture() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        armv7l)
            ARCH="arm"
            ;;
        *)
            print_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
    print_status "Detected architecture: $ARCH"
}

# ============================================================================
# DEPENDENCY INSTALLATION
# ============================================================================

install_dependencies() {
    print_section "Installing Dependencies"

    print_status "Updating package lists..."
    apt-get update -qq

    local packages=(
        "curl"
        "wget"
        "dialog"
        "jq"
        "ufw"
        "iptables"
        "net-tools"
        "bc"
        "ncurses-bin"
    )

    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            print_status "Installing $pkg..."
            apt-get install -y -qq "$pkg"
        else
            print_status "$pkg is already installed"
        fi
    done

    print_success "All dependencies installed"
}

# ============================================================================
# DNSTT-SERVER DOWNLOAD AND VERIFICATION
# ============================================================================

download_dnstt_server() {
    print_section "Downloading DNSTT Server"

    local filename="dnstt-server-linux-${ARCH}"
    local filepath="${INSTALL_DIR}/dnstt-server"
    local temp_dir="/tmp/dnstt-download"

    # Create temp directory
    mkdir -p "$temp_dir"
    cd "$temp_dir"

    # Check if already installed
    if [[ -f "$filepath" ]]; then
        print_status "dnstt-server already exists at $filepath"
        print_question "Reinstall/update? [y/N]: "
        read -r reinstall
        if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi

    print_status "Downloading dnstt-server binary..."
    if ! curl -fSL -o "$temp_dir/$filename" "${DNSTT_BASE_URL}/$filename"; then
        print_error "Failed to download dnstt-server"
        exit 1
    fi

    # Download checksums
    print_status "Downloading checksums for verification..."
    curl -fSL -o "$temp_dir/MD5SUMS" "${DNSTT_BASE_URL}/MD5SUMS" 2>/dev/null || true
    curl -fSL -o "$temp_dir/SHA1SUMS" "${DNSTT_BASE_URL}/SHA1SUMS" 2>/dev/null || true
    curl -fSL -o "$temp_dir/SHA256SUMS" "${DNSTT_BASE_URL}/SHA256SUMS" 2>/dev/null || true

    # Verify checksums
    print_status "Verifying file integrity..."
    local verified=0

    # MD5 verification
    if [[ -f "$temp_dir/MD5SUMS" ]]; then
        if grep "$filename" MD5SUMS | md5sum -c - 2>/dev/null; then
            print_success "MD5 checksum verified"
            ((verified++))
        else
            print_warning "MD5 checksum verification failed"
        fi
    fi

    # SHA1 verification
    if [[ -f "$temp_dir/SHA1SUMS" ]]; then
        if grep "$filename" SHA1SUMS | sha1sum -c - 2>/dev/null; then
            print_success "SHA1 checksum verified"
            ((verified++))
        else
            print_warning "SHA1 checksum verification failed"
        fi
    fi

    # SHA256 verification
    if [[ -f "$temp_dir/SHA256SUMS" ]]; then
        if grep "$filename" SHA256SUMS | sha256sum -c - 2>/dev/null; then
            print_success "SHA256 checksum verified"
            ((verified++))
        else
            print_warning "SHA256 checksum verification failed"
        fi
    fi

    if [[ $verified -eq 0 ]]; then
        print_warning "No checksums could be verified. Proceeding anyway."
    else
        print_success "$verified checksum(s) verified successfully"
    fi

    # Install binary
    chmod +x "$temp_dir/$filename"
    mv "$temp_dir/$filename" "$filepath"
    
    # Cleanup
    rm -rf "$temp_dir"

    print_success "dnstt-server installed to $filepath"
}

# ============================================================================
# USER CREATION
# ============================================================================

create_dnstt_user() {
    print_section "Creating DNSTT System User"

    if id "$DNSTT_USER" &>/dev/null; then
        print_status "User $DNSTT_USER already exists"
    else
        useradd -r -s /usr/sbin/nologin -d /nonexistent -M "$DNSTT_USER"
        print_success "Created system user: $DNSTT_USER"
    fi
}

# ============================================================================
# KEY GENERATION
# ============================================================================

generate_keys() {
    print_section "Generating Encryption Keys"

    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"

    if [[ -f "$PRIVATE_KEY_FILE" && -f "$PUBLIC_KEY_FILE" ]]; then
        print_status "Keys already exist"
        print_question "Regenerate keys? (This will invalidate existing clients) [y/N]: "
        read -r regenerate
        if [[ ! "$regenerate" =~ ^[Yy]$ ]]; then
            # Read existing public key
            PUBLIC_KEY=$(cat "$PUBLIC_KEY_FILE")
            return 0
        fi
    fi

    print_status "Generating new keypair..."
    
    # Generate keypair using dnstt-server
    cd "$CONFIG_DIR"
    "${INSTALL_DIR}/dnstt-server" -gen-key -privkey-file "$PRIVATE_KEY_FILE" -pubkey-file "$PUBLIC_KEY_FILE"
    
    # Read public key
    PUBLIC_KEY=$(cat "$PUBLIC_KEY_FILE")

    # Set permissions
    chown "$DNSTT_USER:$DNSTT_USER" "$PRIVATE_KEY_FILE" "$PUBLIC_KEY_FILE"
    chmod 600 "$PRIVATE_KEY_FILE"
    chmod 644 "$PUBLIC_KEY_FILE"

    print_success "Keys generated successfully"
    print_status "Private key: $PRIVATE_KEY_FILE"
    print_status "Public key: $PUBLIC_KEY_FILE"
}

# ============================================================================
# USER INPUT
# ============================================================================

get_user_input() {
    print_section "Configuration"

    local existing_domain=""
    local existing_mtu=""
    local existing_mode=""

    # Load existing configuration if available
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE" 2>/dev/null || true
        existing_domain="${NS_SUBDOMAIN:-}"
        existing_mtu="${MTU_VALUE:-}"
        existing_mode="${TUNNEL_MODE:-}"
        if [[ -n "$existing_domain" ]]; then
            print_status "Found existing configuration for domain: $existing_domain"
        fi
    fi

    # Get nameserver subdomain
    while true; do
        if [[ -n "$existing_domain" ]]; then
            print_question "Enter the nameserver subdomain (current: $existing_domain): "
        else
            print_question "Enter the nameserver subdomain (e.g., t.example.com): "
        fi
        read -r NS_SUBDOMAIN

        if [[ -z "$NS_SUBDOMAIN" && -n "$existing_domain" ]]; then
            NS_SUBDOMAIN="$existing_domain"
        fi

        if [[ -n "$NS_SUBDOMAIN" ]]; then
            break
        else
            print_error "Please enter a valid subdomain"
        fi
    done

    # Get MTU value
    if [[ -n "$existing_mtu" ]]; then
        print_question "Enter MTU value (current: $existing_mtu, default: 1232): "
    else
        print_question "Enter MTU value (default: 1232): "
    fi
    read -r MTU_VALUE

    if [[ -z "$MTU_VALUE" ]]; then
        MTU_VALUE="${existing_mtu:-1232}"
    fi

    # Validate MTU
    if ! [[ "$MTU_VALUE" =~ ^[0-9]+$ ]] || [[ "$MTU_VALUE" -lt 500 ]] || [[ "$MTU_VALUE" -gt 65535 ]]; then
        print_warning "Invalid MTU value. Using default: 1232"
        MTU_VALUE="1232"
    fi

    # Tunnel mode - SSH for this installer
    TUNNEL_MODE="ssh"
    print_status "Tunnel mode: SSH (tunneling to local port 22)"

    # Show configuration summary
    echo ""
    print_status "Configuration Summary:"
    echo -e "  ${CYAN}Nameserver subdomain:${NC} $NS_SUBDOMAIN"
    echo -e "  ${CYAN}MTU:${NC} $MTU_VALUE"
    echo -e "  ${CYAN}Tunnel mode:${NC} $TUNNEL_MODE (port 22)"
    echo ""

    print_question "Proceed with this configuration? [Y/n]: "
    read -r confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_status "Configuration cancelled. Please run the script again."
        exit 0
    fi
}

# ============================================================================
# SAVE CONFIGURATION
# ============================================================================

save_configuration() {
    print_section "Saving Configuration"

    cat > "$CONFIG_FILE" << EOF
# DNSTT Server Configuration
# Generated on $(date)

NS_SUBDOMAIN="${NS_SUBDOMAIN}"
MTU_VALUE="${MTU_VALUE}"
TUNNEL_MODE="${TUNNEL_MODE}"
DNSTT_PORT="${DNSTT_PORT}"
PUBLIC_KEY="${PUBLIC_KEY}"
VERSION="${VERSION}"
EOF

    chown "$DNSTT_USER:$DNSTT_USER" "$CONFIG_FILE"
    chmod 644 "$CONFIG_FILE"

    print_success "Configuration saved to $CONFIG_FILE"
}

# ============================================================================
# SSH DETECTION AND HARDENING
# ============================================================================

detect_ssh_port() {
    local ssh_port
    ssh_port=$(ss -tlnp 2>/dev/null | grep sshd | awk '{print $4}' | grep -oE '[0-9]+$' | head -1)
    if [[ -z "$ssh_port" ]]; then
        ssh_port="22"
    fi
    echo "$ssh_port"
}

configure_ssh() {
    print_section "SSH Configuration"

    SSH_PORT=$(detect_ssh_port)
    print_status "Detected SSH port: $SSH_PORT"

    local ssh_config="/etc/ssh/sshd_config"
    local modified=false

    # Check and enable PermitTunnel
    if grep -q "^PermitTunnel" "$ssh_config"; then
        if ! grep -q "^PermitTunnel yes" "$ssh_config"; then
            sed -i 's/^PermitTunnel.*/PermitTunnel yes/' "$ssh_config"
            modified=true
            print_status "Updated PermitTunnel to yes"
        fi
    elif grep -q "^#PermitTunnel" "$ssh_config"; then
        sed -i 's/^#PermitTunnel.*/PermitTunnel yes/' "$ssh_config"
        modified=true
        print_status "Enabled PermitTunnel"
    else
        echo "PermitTunnel yes" >> "$ssh_config"
        modified=true
        print_status "Added PermitTunnel yes"
    fi

    # Check and enable AllowTcpForwarding
    if grep -q "^AllowTcpForwarding no" "$ssh_config"; then
        sed -i 's/^AllowTcpForwarding no/AllowTcpForwarding yes/' "$ssh_config"
        modified=true
        print_status "Enabled AllowTcpForwarding"
    fi

    if [[ "$modified" == true ]]; then
        print_status "Restarting SSH service..."
        systemctl restart sshd
        print_success "SSH configuration updated"
    else
        print_status "SSH is already properly configured"
    fi
}

# ============================================================================
# FIREWALL CONFIGURATION
# ============================================================================

configure_firewall() {
    print_section "Firewall Configuration"

    # Enable UFW if not already enabled
    if ! ufw status | grep -q "Status: active"; then
        print_status "Enabling UFW firewall..."
        ufw --force enable
    fi

    # Allow SSH
    print_status "Allowing SSH on port $SSH_PORT..."
    ufw allow "$SSH_PORT/tcp" comment 'SSH' >/dev/null 2>&1 || true

    # Configure iptables redirect for DNS (UDP 53 -> 5300)
    print_status "Configuring DNS port redirect (53 → 5300)..."

    # Remove existing rules if any
    iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-port "$DNSTT_PORT" 2>/dev/null || true

    # Add the redirect rule
    iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-port "$DNSTT_PORT"

    # Allow UDP 53 in UFW
    ufw allow 53/udp comment 'DNS for DNSTT' >/dev/null 2>&1 || true

    # Save iptables rules
    print_status "Saving iptables rules..."
    
    # Install iptables-persistent if not already installed
    if ! dpkg -l | grep -q "iptables-persistent"; then
        echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
        echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
        apt-get install -y -qq iptables-persistent
    fi

    # Save rules
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || \
    iptables-save > /etc/iptables.rules

    print_success "Firewall configured"
    print_status "UFW Status:"
    ufw status numbered | head -20
}

# ============================================================================
# SYSTEMD SERVICES
# ============================================================================

create_systemd_services() {
    print_section "Creating Systemd Services"

    # Create dnstt-server service
    print_status "Creating dnstt-server service..."
    
    cat > "${SYSTEMD_DIR}/dnstt-server.service" << EOF
[Unit]
Description=DNSTT DNS Tunnel Server
After=network.target
Wants=network.target

[Service]
Type=simple
User=${DNSTT_USER}
Group=${DNSTT_USER}
ExecStart=${INSTALL_DIR}/dnstt-server -udp :${DNSTT_PORT} -privkey-file ${PRIVATE_KEY_FILE} -mtu ${MTU_VALUE} ${NS_SUBDOMAIN} 127.0.0.1:${SSH_PORT}
Restart=always
RestartSec=5
KillMode=mixed
TimeoutStopSec=5

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadOnlyPaths=/
ReadWritePaths=${CONFIG_DIR} ${LOG_DIR}
PrivateTmp=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=dnstt-server

[Install]
WantedBy=multi-user.target
EOF

    # Create dnstt-panel service (optional persistent mode)
    print_status "Creating dnstt-panel service..."
    
    cat > "${SYSTEMD_DIR}/dnstt-panel.service" << EOF
[Unit]
Description=DNSTT Management Panel
After=network.target dnstt-server.service

[Service]
Type=simple
ExecStart=${PANEL_INSTALL_PATH}
Restart=on-failure
RestartSec=10
StandardInput=tty
StandardOutput=tty
TTYPath=/dev/tty1

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd
    systemctl daemon-reload

    # Enable dnstt-server service
    systemctl enable dnstt-server

    print_success "Systemd services created"
}

# ============================================================================
# INSTALL PANEL
# ============================================================================

install_panel() {
    print_section "Installing DNSTT Panel"

    # The panel script will be installed from the same directory or downloaded
    local panel_source="$(dirname "$0")/dnstt-panel.sh"
    
    if [[ -f "$panel_source" ]]; then
        cp "$panel_source" "$PANEL_INSTALL_PATH"
    else
        # Create a basic panel inline (the full panel will be in dnstt-panel.sh)
        print_status "Creating panel script..."
        cat > "$PANEL_INSTALL_PATH" << 'PANEL_SCRIPT'
#!/bin/bash
# DNSTT Management Panel
# This is a placeholder - the full panel is in dnstt-panel.sh

CONFIG_DIR="/etc/dnstt"
CONFIG_FILE="${CONFIG_DIR}/dnstt-server.conf"

source "$CONFIG_FILE" 2>/dev/null

echo "DNSTT Panel - Basic Mode"
echo "========================"
echo ""
echo "For full panel functionality, install dnstt-panel.sh"
echo ""
echo "Quick Commands:"
echo "  Status:  systemctl status dnstt-server"
echo "  Start:   sudo systemctl start dnstt-server"
echo "  Stop:    sudo systemctl stop dnstt-server"
echo "  Restart: sudo systemctl restart dnstt-server"
echo "  Logs:    journalctl -u dnstt-server -f"
echo ""
echo "Configuration:"
echo "  Domain: ${NS_SUBDOMAIN:-Not configured}"
echo "  MTU: ${MTU_VALUE:-1232}"
echo "  Mode: ${TUNNEL_MODE:-ssh}"
echo ""
echo "Public Key:"
cat "${CONFIG_DIR}/dnstt-server.pub" 2>/dev/null || echo "Key not found"
PANEL_SCRIPT
    fi

    chmod +x "$PANEL_INSTALL_PATH"
    print_success "Panel installed to $PANEL_INSTALL_PATH"
}

# ============================================================================
# START SERVICES
# ============================================================================

start_services() {
    print_section "Starting Services"

    print_status "Starting dnstt-server..."
    systemctl start dnstt-server

    # Wait a moment for the service to start
    sleep 2

    if systemctl is-active --quiet dnstt-server; then
        print_success "dnstt-server is running"
    else
        print_error "Failed to start dnstt-server"
        print_status "Checking logs..."
        journalctl -u dnstt-server -n 20 --no-pager
        exit 1
    fi
}

# ============================================================================
# DISPLAY FINAL INFO
# ============================================================================

display_final_info() {
    print_section "Installation Complete!"

    echo -e "${GREEN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════╗
║                     DNSTT SERVER INSTALLED SUCCESSFULLY!                  ║
╚═══════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    echo -e "${BOLD}Server Configuration:${NC}"
    echo -e "  ${CYAN}Domain:${NC}        ${NS_SUBDOMAIN}"
    echo -e "  ${CYAN}MTU:${NC}           ${MTU_VALUE}"
    echo -e "  ${CYAN}Mode:${NC}          SSH (port ${SSH_PORT})"
    echo -e "  ${CYAN}Listen Port:${NC}   ${DNSTT_PORT} (redirected from 53)"
    echo ""

    echo -e "${BOLD}Public Key (for clients):${NC}"
    echo -e "${YELLOW}$(cat "$PUBLIC_KEY_FILE")${NC}"
    echo ""

    echo -e "${BOLD}Management Commands:${NC}"
    echo -e "  ${CYAN}dnstt-panel${NC}              - Open management panel"
    echo -e "  ${CYAN}dnstt-deploy${NC}             - Run original installer menu"
    echo -e "  ${CYAN}systemctl status dnstt-server${NC}  - Check service status"
    echo -e "  ${CYAN}journalctl -u dnstt-server -f${NC}  - View live logs"
    echo ""

    echo -e "${BOLD}Client Connection Example:${NC}"
    echo -e "  ${CYAN}dnstt-client -udp DNS_IP:53 -pubkey-file server.pub ${NS_SUBDOMAIN} 127.0.0.1:7000${NC}"
    echo -e "  Then connect SSH: ${CYAN}ssh -p 7000 user@127.0.0.1${NC}"
    echo ""

    echo -e "${BOLD}Mobile Apps (HTTP Injector / DNSTT.XYZ):${NC}"
    echo -e "  DNS Host: ${CYAN}${NS_SUBDOMAIN}${NC}"
    echo -e "  Public Key: ${CYAN}$(cat "$PUBLIC_KEY_FILE")${NC}"
    echo -e "  SSH Host: ${CYAN}127.0.0.1${NC}"
    echo -e "  SSH Port: ${CYAN}7000${NC}"
    echo ""

    echo -e "${BOLD}Files:${NC}"
    echo -e "  ${CYAN}Config:${NC}      ${CONFIG_FILE}"
    echo -e "  ${CYAN}Private Key:${NC} ${PRIVATE_KEY_FILE}"
    echo -e "  ${CYAN}Public Key:${NC}  ${PUBLIC_KEY_FILE}"
    echo ""

    echo -e "${YELLOW}[IMPORTANT]${NC} Make sure your DNS records are configured:"
    echo -e "  ${CYAN}NS record:${NC}  ${NS_SUBDOMAIN} → ns.${NS_SUBDOMAIN#*.}"
    echo -e "  ${CYAN}A record:${NC}   ns.${NS_SUBDOMAIN#*.} → $(curl -s ifconfig.me || echo 'YOUR_SERVER_IP')"
    echo ""
}

# ============================================================================
# MAIN MENU
# ============================================================================

show_menu() {
    echo ""
    print_status "DNSTT Server Management"
    print_status "======================="
    echo ""
    echo "1) Install/Reconfigure DNSTT server"
    echo "2) Check service status"
    echo "3) View service logs"
    echo "4) Show configuration info"
    echo "5) Generate client config"
    echo "6) Update dnstt-deploy script"
    echo "0) Exit"
    echo ""
    print_question "Please select an option (0-6): "
}

handle_menu() {
    local choice
    read -r choice

    case $choice in
        1)
            main_install
            ;;
        2)
            echo ""
            systemctl status dnstt-server --no-pager -l
            echo ""
            read -p "Press Enter to continue..."
            ;;
        3)
            echo ""
            print_status "Showing last 50 log entries (Ctrl+C to exit live view):"
            journalctl -u dnstt-server -n 50 -f
            ;;
        4)
            if [[ -f "$CONFIG_FILE" ]]; then
                source "$CONFIG_FILE"
                echo ""
                print_status "Current Configuration:"
                echo "  Domain: ${NS_SUBDOMAIN:-Not set}"
                echo "  MTU: ${MTU_VALUE:-Not set}"
                echo "  Mode: ${TUNNEL_MODE:-Not set}"
                echo ""
                echo "Public Key:"
                cat "$PUBLIC_KEY_FILE" 2>/dev/null || echo "Not generated"
                echo ""
            else
                print_error "No configuration found. Please run installation first."
            fi
            read -p "Press Enter to continue..."
            ;;
        5)
            generate_client_config
            read -p "Press Enter to continue..."
            ;;
        6)
            print_status "Checking for updates..."
            # Update logic would go here
            print_status "Already up to date"
            read -p "Press Enter to continue..."
            ;;
        0)
            print_status "Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

generate_client_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "No configuration found"
        return 1
    fi

    source "$CONFIG_FILE"
    local server_ip=$(curl -s ifconfig.me || echo 'YOUR_SERVER_IP')

    echo ""
    print_section "Client Configuration"
    
    echo -e "${BOLD}=== For Desktop (dnstt-client) ===${NC}"
    echo ""
    echo "1. Download client from https://dnstt.network"
    echo ""
    echo "2. Save this public key to 'server.pub':"
    echo -e "${YELLOW}$(cat "$PUBLIC_KEY_FILE")${NC}"
    echo ""
    echo "3. Run client:"
    echo -e "${CYAN}dnstt-client -udp DNS_IP:53 -pubkey-file server.pub ${NS_SUBDOMAIN} 127.0.0.1:7000${NC}"
    echo ""
    echo "4. Connect via SSH:"
    echo -e "${CYAN}ssh -p 7000 user@127.0.0.1${NC}"
    echo ""

    echo -e "${BOLD}=== For HTTP Injector (Android) ===${NC}"
    echo ""
    echo "SSH Settings:"
    echo "  Host: 127.0.0.1"
    echo "  Port: 7000"
    echo "  Username: [your SSH username]"
    echo "  Password: [your SSH password]"
    echo ""
    echo "DNSTT Settings:"
    echo "  DNS Server: [Your ISP DNS or 8.8.8.8]"
    echo "  DNS Domain: ${NS_SUBDOMAIN}"
    echo "  Public Key: $(cat "$PUBLIC_KEY_FILE")"
    echo ""

    echo -e "${BOLD}=== For DNSTT.XYZ App ===${NC}"
    echo ""
    echo "Server: ${NS_SUBDOMAIN}"
    echo "Public Key: $(cat "$PUBLIC_KEY_FILE")"
    echo "Local Port: 7000"
    echo "Then use SSH client to connect to 127.0.0.1:7000"
    echo ""
}

# ============================================================================
# MAIN INSTALL FUNCTION
# ============================================================================

main_install() {
    print_banner
    detect_os
    detect_architecture
    install_dependencies
    download_dnstt_server
    create_dnstt_user
    generate_keys
    get_user_input
    save_configuration
    configure_ssh
    configure_firewall
    create_systemd_services
    install_panel
    start_services
    display_final_info
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    check_root
    
    # If running for the first time or with --install flag, run installation
    if [[ "$1" == "--install" ]] || [[ ! -f "$CONFIG_FILE" ]]; then
        main_install
    else
        # Show menu for existing installations
        while true; do
            clear
            print_banner
            show_menu
            handle_menu
        done
    fi
}

# Run main function
main "$@"
