#!/bin/bash
#
# DNSTT Management Panel
# Standard CLI dashboard for DNSTT DNS tunnel server
#
# Usage: dnstt-panel
#

# ============================================================================
# CONFIGURATION
# ============================================================================

CONFIG_DIR="/etc/dnstt"
CONFIG_FILE="${CONFIG_DIR}/dnstt-server.conf"
PUBLIC_KEY_FILE="${CONFIG_DIR}/dnstt-server.pub"
PRIVATE_KEY_FILE="${CONFIG_DIR}/dnstt-server.key"
LOG_DIR="/var/log/dnstt"
SERVICE_NAME="dnstt-server"
REFRESH_INTERVAL=5
USER_MGMT_SCRIPT="/usr/local/lib/dnstt/user-management.sh"

# Source user management module if available
if [[ -f "$USER_MGMT_SCRIPT" ]]; then
    source "$USER_MGMT_SCRIPT"
    USER_MGMT_ENABLED=true
else
    USER_MGMT_ENABLED=false
fi

# ============================================================================
# UI HELPERS
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

print_header() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════════════╗"
    echo "║                         DNSTT SERVER MANAGEMENT                           ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_question() { echo -ne "${MAGENTA}[?]${NC} $1"; }

pause() {
    echo ""
    read -p "Press Enter to continue..."
}

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        NS_SUBDOMAIN="Not configured"
        MTU_VALUE="1232"
        TUNNEL_MODE="ssh"
        PUBLIC_KEY=""
    fi
    
    if [[ -f "$PUBLIC_KEY_FILE" ]]; then
        PUBLIC_KEY=$(cat "$PUBLIC_KEY_FILE")
    fi
}

# ============================================================================
# STATS FUNCTIONS
# ============================================================================

get_service_status() {
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "${GREEN}RUNNING${NC}"
    else
        echo -e "${RED}STOPPED${NC}"
    fi
}

get_service_uptime() {
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        local start_time=$(systemctl show "$SERVICE_NAME" --property=ActiveEnterTimestamp --value)
        if [[ -n "$start_time" ]]; then
            local start_epoch=$(date -d "$start_time" +%s 2>/dev/null)
            local now_epoch=$(date +%s)
            if [[ -n "$start_epoch" ]]; then
                local diff=$((now_epoch - start_epoch))
                local days=$((diff / 86400))
                local hours=$(((diff % 86400) / 3600))
                local mins=$(((diff % 3600) / 60))
                local secs=$((diff % 60))
                if [[ $days -gt 0 ]]; then
                    echo "${days}d ${hours}h ${mins}m"
                elif [[ $hours -gt 0 ]]; then
                    echo "${hours}h ${mins}m ${secs}s"
                else
                    echo "${mins}m ${secs}s"
                fi
            else
                echo "Unknown"
            fi
        else
            echo "Unknown"
        fi
    else
        echo "N/A"
    fi
}

get_connection_count() {
    local count=$(ss -tunp 2>/dev/null | grep -c "dnstt-server" || echo "0")
    echo "$count"
}

get_memory_usage() {
    local pid=$(pgrep -f "dnstt-server" | head -1)
    if [[ -n "$pid" ]]; then
        local mem=$(ps -o rss= -p "$pid" 2>/dev/null | awk '{printf "%.1f", $1/1024}')
        echo "${mem} MB"
    else
        echo "N/A"
    fi
}

get_cpu_usage() {
    local pid=$(pgrep -f "dnstt-server" | head -1)
    if [[ -n "$pid" ]]; then
        local cpu=$(ps -o %cpu= -p "$pid" 2>/dev/null | awk '{printf "%.1f", $1}')
        echo "${cpu}%"
    else
        echo "N/A"
    fi
}

get_server_ip() {
    curl -s --connect-timeout 3 ifconfig.me 2>/dev/null || \
    curl -s --connect-timeout 3 icanhazip.com 2>/dev/null || \
    hostname -I 2>/dev/null | awk '{print $1}' || \
    echo "Unknown"
}

get_log_stats() {
    echo "Logs: $(journalctl -u "$SERVICE_NAME" --since today -q 2>/dev/null | wc -l) entries today"
}

# ============================================================================
# MAIN DASHBOARD
# ============================================================================

show_dashboard() {
    load_config
    
    local status=$(get_service_status)
    local uptime=$(get_service_uptime)
    local connections=$(get_connection_count)
    local memory=$(get_memory_usage)
    local cpu=$(get_cpu_usage)
    local server_ip=$(get_server_ip)
    local log_stats=$(get_log_stats)
    
    print_header
    
    echo -e "  ${BOLD}Service Status${NC}"
    echo -e "  Status:       $status"
    echo -e "  Uptime:       $uptime"
    echo -e "  Connections:  $connections active"
    echo -e "  Memory:       $memory"
    echo -e "  CPU:          $cpu"
    echo ""
    echo -e "  ${BOLD}Configuration${NC}"
    echo -e "  Domain:       ${NS_SUBDOMAIN:-Not set}"
    echo -e "  MTU:          ${MTU_VALUE:-1232}"
    echo -e "  Mode:         ${TUNNEL_MODE:-ssh}"
    echo -e "  Server IP:    $server_ip"
    echo ""
    echo -e "  $log_stats"
    echo ""
    echo "========================================================================"
    echo "1) Refresh Dashboard"
    echo "2) Service Controls"
    echo "3) View Live Logs"
    echo "4) Configuration"
    echo "5) Generate Client Config"
    echo "6) Connection Monitor"
    echo "7) User Management"
    echo "8) System Info"
    echo "0) Exit"
    echo ""
    print_question "Select an option [0-8]: "
    read -r CHOICE
}

# ============================================================================
# SERVICE CONTROLS
# ============================================================================

show_service_controls() {
    print_header
    echo -e "${BOLD}Service Controls${NC}"
    echo ""
    echo "1) Start Service"
    echo "2) Stop Service"
    echo "3) Restart Service"
    echo "4) Enable on Boot"
    echo "5) Disable on Boot"
    echo "0) Back"
    echo ""
    print_question "Select an option [0-5]: "
    read -r choice
    
    case $choice in
        1)
            print_status "Starting service..."
            if sudo systemctl start "$SERVICE_NAME"; then
                print_success "Service started successfully!"
            else
                print_error "Failed to start service"
            fi
            pause
            ;;
        2)
            read -p "Are you sure you want to stop the service? [y/N]: " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                print_status "Stopping service..."
                if sudo systemctl stop "$SERVICE_NAME"; then
                    print_success "Service stopped."
                else
                    print_error "Failed to stop service"
                fi
            fi
            pause
            ;;
        3)
            print_status "Restarting service..."
            if sudo systemctl restart "$SERVICE_NAME"; then
                print_success "Service restarted successfully!"
            else
                print_error "Failed to restart service"
            fi
            pause
            ;;
        4)
            sudo systemctl enable "$SERVICE_NAME" 2>/dev/null
            print_success "Service enabled on boot."
            pause
            ;;
        5)
            sudo systemctl disable "$SERVICE_NAME" 2>/dev/null
            print_success "Service disabled on boot."
            pause
            ;;
    esac
}

# ============================================================================
# LIVE LOGS
# ============================================================================

show_live_logs() {
    print_header
    echo -e "${BOLD}Log Options${NC}"
    echo ""
    echo "1) Live Log Stream (Ctrl+C to exit)"
    echo "2) Last 50 Entries"
    echo "3) Last 100 Entries"
    echo "0) Back"
    echo ""
    print_question "Select an option [0-3]: "
    read -r choice
    
    case $choice in
        1)
            clear
            echo "═══════════════════════════════════════════════════════════════════"
            echo "                    DNSTT Server Live Logs"
            echo "═══════════════════════════════════════════════════════════════════"
            echo "Press Ctrl+C to return to the panel"
            echo ""
            journalctl -u "$SERVICE_NAME" -f
            ;;
        2)
            echo ""
            journalctl -u "$SERVICE_NAME" -n 50 --no-pager
            pause
            ;;
        3)
            echo ""
            journalctl -u "$SERVICE_NAME" -n 100 --no-pager
            pause
            ;;
    esac
}

# ============================================================================
# CONFIGURATION
# ============================================================================

show_configuration() {
    load_config
    print_header
    echo -e "${BOLD}Configuration${NC}"
    echo -e "  Domain: ${NS_SUBDOMAIN}"
    echo -e "  MTU: ${MTU_VALUE}"
    echo -e "  Mode: ${TUNNEL_MODE}"
    echo ""
    echo "1) Edit Domain"
    echo "2) Edit MTU"
    echo "3) View Config File"
    echo "4) Reload Configuration"
    echo "0) Back"
    echo ""
    print_question "Select an option [0-4]: "
    read -r choice
    
    case $choice in
        1)
            echo ""
            read -p "Enter new nameserver subdomain [${NS_SUBDOMAIN}]: " new_domain
            if [[ -n "$new_domain" ]]; then
                sudo sed -i "s/^NS_SUBDOMAIN=.*/NS_SUBDOMAIN=\"$new_domain\"/" "$CONFIG_FILE"
                print_success "Domain updated to: $new_domain"
                print_warning "Restart service to apply changes."
            fi
            pause
            ;;
        2)
            echo ""
            read -p "Enter new MTU value (500-65535) [${MTU_VALUE}]: " new_mtu
            if [[ -n "$new_mtu" ]]; then
                if [[ "$new_mtu" =~ ^[0-9]+$ ]] && [[ "$new_mtu" -ge 500 ]] && [[ "$new_mtu" -le 65535 ]]; then
                    sudo sed -i "s/^MTU_VALUE=.*/MTU_VALUE=\"$new_mtu\"/" "$CONFIG_FILE"
                    print_success "MTU updated to: $new_mtu"
                    print_warning "Restart service to apply changes."
                else
                    print_error "Invalid MTU value. Must be between 500 and 65535."
                fi
            fi
            pause
            ;;
        3)
            echo ""
            cat "$CONFIG_FILE"
            pause
            ;;
        4)
            print_status "Reloading configuration..."
            sudo systemctl restart "$SERVICE_NAME" 2>/dev/null
            sleep 2
            print_success "Configuration reloaded."
            pause
            ;;
    esac
}

# ============================================================================
# CLIENT CONFIG GENERATOR
# ============================================================================

show_client_config() {
    load_config
    local server_ip=$(get_server_ip)
    
    print_header
    echo -e "${BOLD}Client Configuration${NC}"
    echo ""
    echo "1) Desktop (dnstt-client)"
    echo "2) HTTP Injector (Android)"
    echo "3) DNSTT.XYZ App"
    echo "4) Export Public Key"
    echo "0) Back"
    echo ""
    print_question "Select an option [0-4]: "
    read -r choice
    
    case $choice in
        1)
            echo ""
            echo "═══════════════════════════════════════════════════════════════"
            echo "              DNSTT Desktop Client Configuration"
            echo "═══════════════════════════════════════════════════════════════"
            echo ""
            echo "1. Download client from: https://dnstt.network"
            echo ""
            echo "2. Save this public key to 'server.pub':"
            echo "─────────────────────────────────────────────────────────────"
            echo "$PUBLIC_KEY"
            echo "─────────────────────────────────────────────────────────────"
            echo ""
            echo "3. Run client command:"
            echo "   dnstt-client -udp DNS_IP:53 -pubkey-file server.pub \\"
            echo "       ${NS_SUBDOMAIN} 127.0.0.1:7000"
            echo ""
            echo "4. Connect via SSH:"
            echo "   ssh -p 7000 user@127.0.0.1"
            echo ""
            echo "Notes:"
            echo "- Replace DNS_IP with your ISP's DNS or 8.8.8.8"
            echo "- Replace 'user' with your SSH username"
            echo "═══════════════════════════════════════════════════════════════"
            pause
            ;;
        2)
            echo ""
            echo "═══════════════════════════════════════════════════════════════"
            echo "            HTTP Injector Configuration (Android)"
            echo "═══════════════════════════════════════════════════════════════"
            echo ""
            echo "SSH Settings:"
            echo "─────────────────────────────────────────────────────────────"
            echo "  Host:     127.0.0.1"
            echo "  Port:     7000"
            echo "  Username: [Your SSH username]"
            echo "  Password: [Your SSH password]"
            echo ""
            echo "DNSTT/DNS Tunnel Settings:"
            echo "─────────────────────────────────────────────────────────────"
            echo "  DNS Server:  Use your ISP DNS or 8.8.8.8"
            echo "  DNS Domain:  ${NS_SUBDOMAIN}"
            echo ""
            echo "  Public Key:"
            echo "  $PUBLIC_KEY"
            echo ""
            echo "Remote Proxy:"
            echo "─────────────────────────────────────────────────────────────"
            echo "  Leave empty or use 127.0.0.1:8080 for local proxy"
            echo "═══════════════════════════════════════════════════════════════"
            pause
            ;;
        3)
            echo ""
            echo "═══════════════════════════════════════════════════════════════"
            echo "              DNSTT.XYZ App Configuration"
            echo "═══════════════════════════════════════════════════════════════"
            echo ""
            echo "Server Settings:"
            echo "─────────────────────────────────────────────────────────────"
            echo "  Server Domain:  ${NS_SUBDOMAIN}"
            echo "  Local Port:     7000"
            echo ""
            echo "  Public Key:"
            echo "  $PUBLIC_KEY"
            echo ""
            echo "After connecting:"
            echo "─────────────────────────────────────────────────────────────"
            echo "  Use any SSH client to connect to:"
            echo "    Host: 127.0.0.1"
            echo "    Port: 7000"
            echo "═══════════════════════════════════════════════════════════════"
            pause
            ;;
        4)
            local export_path="/tmp/dnstt-server-${NS_SUBDOMAIN//\./_}.pub"
            cp "$PUBLIC_KEY_FILE" "$export_path" 2>/dev/null
            print_success "Public key exported to: $export_path"
            echo ""
            echo "Key content:"
            echo "$PUBLIC_KEY"
            pause
            ;;
    esac
}

# ============================================================================
# CONNECTION MONITOR
# ============================================================================

show_connection_monitor() {
    while true; do
        local connections=$(ss -tunp 2>/dev/null | grep -E "dnstt|:5300" | head -20)
        local count=$(echo "$connections" | grep -c . 2>/dev/null || echo "0")
        
        clear
        echo -e "${CYAN}Connection Monitor${NC} (Auto-refresh: ${REFRESH_INTERVAL}s)"
        echo "Active Connections: $count"
        echo ""
        ss -tunp 2>/dev/null | head -1
        echo "$connections"
        echo ""
        echo "Press Ctrl+C to return to dashboard"
        
        sleep $REFRESH_INTERVAL
    done
}

# ============================================================================
# USER MANAGEMENT
# ============================================================================

show_user_management() {
    if [[ "$USER_MGMT_ENABLED" != "true" ]]; then
        print_error "User Management module not installed."
        print_status "Run the installer to enable this feature."
        pause
        return
    fi
    
    while true; do
        # Get user count
        local user_count=$(getent group dnstt-users 2>/dev/null | cut -d: -f4 | tr ',' '\n' | grep -c . || echo "0")
        local active_sessions=$(who 2>/dev/null | wc -l)
        
        print_header
        echo -e "${BOLD}User Management${NC}"
        echo "Total Users: $user_count | Active Sessions: $active_sessions"
        echo ""
        echo "1) List All Users"
        echo "2) Create New User"
        echo "3) Delete User"
        echo "4) Enable/Disable User"
        echo "5) Change Password"
        echo "6) Set Connection Limit"
        echo "7) Set Expiry Date"
        echo "8) View Active Sessions"
        echo "9) Kick User Session"
        echo "10) Bulk Create Users"
        echo "11) Generate User Credentials"
        echo "12) Cleanup Expired Users"
        echo "0) Back"
        echo ""
        print_question "Select an option [0-12]: "
        read -r choice
        
        case $choice in
            1) # List Users
                echo ""
                list_tunnel_users 2>/dev/null
                pause
                ;;
            2) # Create User
                echo ""
                read -p "Enter username (lowercase, 3-31 chars): " username
                [[ -z "$username" ]] && continue
                
                read -p "Enter password: " password
                [[ -z "$password" ]] && continue
                
                read -p "Max concurrent connections (default: 2): " max_conn
                max_conn=${max_conn:-2}
                
                read -p "Expiry in days (0 = never): " expiry_days
                expiry_days=${expiry_days:-0}
                
                create_tunnel_user "$username" "$password" "$max_conn" "$expiry_days"
                pause
                ;;
            3) # Delete User
                echo ""
                read -p "Enter username to delete: " username
                [[ -z "$username" ]] && continue
                
                read -p "Are you sure you want to delete user '$username'? [y/N]: " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    delete_tunnel_user "$username"
                fi
                pause
                ;;
            4) # Enable/Disable
                echo ""
                read -p "Enter username: " username
                [[ -z "$username" ]] && continue
                
                echo "1) Enable User"
                echo "2) Disable User"
                read -p "Select action: " action
                
                if [[ "$action" == "1" ]]; then
                    enable_tunnel_user "$username"
                elif [[ "$action" == "2" ]]; then
                    disable_tunnel_user "$username"
                fi
                pause
                ;;
            5) # Change Password
                echo ""
                read -p "Enter username: " username
                [[ -z "$username" ]] && continue
                
                read -p "Enter new password: " password
                [[ -z "$password" ]] && continue
                
                change_user_password "$username" "$password"
                pause
                ;;
            6) # Set Connection Limit
                echo ""
                read -p "Enter username: " username
                [[ -z "$username" ]] && continue
                
                read -p "Enter max concurrent connections: " limit
                [[ -z "$limit" ]] && continue
                
                set_user_connection_limit "$username" "$limit"
                pause
                ;;
            7) # Set Expiry
                echo ""
                read -p "Enter username: " username
                [[ -z "$username" ]] && continue
                
                read -p "Enter expiry date (YYYY-MM-DD) [$(date -d '+30 days' +%Y-%m-%d)]: " expiry
                expiry=${expiry:-$(date -d '+30 days' +%Y-%m-%d)}
                
                set_user_expiry "$username" "$expiry"
                pause
                ;;
            8) # View Sessions
                echo ""
                get_active_sessions 2>/dev/null
                pause
                ;;
            9) # Kick Session
                echo ""
                read -p "Enter username to kick (all sessions): " username
                [[ -z "$username" ]] && continue
                
                read -p "Terminate all sessions for '$username'? [y/N]: " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    kick_user_session "$username" "all"
                fi
                pause
                ;;
            10) # Bulk Create
                echo ""
                read -p "How many users to create? [10]: " count
                count=${count:-10}
                
                read -p "Username prefix [user]: " prefix
                prefix=${prefix:-user}
                
                read -p "Expiry in days (0 = never) [30]: " expiry_days
                expiry_days=${expiry_days:-30}
                
                print_status "Creating $count users..."
                create_users_bulk "$count" "$prefix" "12" "2" "$expiry_days"
                pause
                ;;
            11) # Generate Credentials
                echo ""
                read -p "Enter username: " username
                [[ -z "$username" ]] && continue
                
                generate_user_credentials "$username"
                pause
                ;;
            12) # Cleanup Expired
                echo ""
                read -p "Delete all expired users? [y/N]: " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    cleanup_expired_users
                fi
                pause
                ;;
            0)
                break
                ;;
        esac
    done
}

# ============================================================================
# SYSTEM INFO
# ============================================================================

show_system_info() {
    local os_info=$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2)
    local kernel=$(uname -r)
    local hostname=$(hostname)
    local server_ip=$(get_server_ip)
    local uptime_sys=$(uptime -p 2>/dev/null || uptime)
    local memory=$(free -h | awk '/^Mem:/ {print $3 "/" $2}')
    local disk=$(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')
    local load=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
    
    local ufw_status="Unknown"
    if command -v ufw &>/dev/null; then
        ufw_status=$(ufw status 2>/dev/null | head -1)
    fi
    
    print_header
    echo -e "${BOLD}System Information${NC}"
    echo ""
    echo -e "${BOLD}Server:${NC}"
    echo "───────────────────────────────────────────────────────────────────"
    echo "  Hostname:     $hostname"
    echo "  IP Address:   $server_ip"
    echo "  OS:           $os_info"
    echo "  Kernel:       $kernel"
    echo "  Uptime:       $uptime_sys"
    echo ""
    echo -e "${BOLD}Resources:${NC}"
    echo "───────────────────────────────────────────────────────────────────"
    echo "  Memory:       $memory"
    echo "  Disk (/):     $disk"
    echo "  Load Average: $load"
    echo ""
    echo -e "${BOLD}Network:${NC}"
    echo "───────────────────────────────────────────────────────────────────"
    echo "  Firewall:     $ufw_status"
    echo ""
    echo -e "${BOLD}DNSTT:${NC}"
    echo "───────────────────────────────────────────────────────────────────"
    echo "  Config Dir:   $CONFIG_DIR"
    echo "  Service:      $SERVICE_NAME"
    echo "  Binary:       /usr/local/bin/dnstt-server"
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    pause
}

# ============================================================================
# MAIN LOOP
# ============================================================================

main() {
    # Check for root for certain operations
    if [[ $EUID -ne 0 ]]; then
        print_warning "Note: Some operations require root privileges. Consider running with sudo."
        sleep 2
    fi
    
    load_config
    
    while true; do
        show_dashboard
        
        case $CHOICE in
            1)
                continue
                ;;
            2)
                show_service_controls
                ;;
            3)
                show_live_logs
                ;;
            4)
                show_configuration
                ;;
            5)
                show_client_config
                ;;
            6)
                show_connection_monitor
                ;;
            7)
                show_user_management
                ;;
            8)
                show_system_info
                ;;
            0)
                print_status "Goodbye!"
                exit 0
                ;;
            *)
                ;;
        esac
    done
}

# Run main
main "$@"
