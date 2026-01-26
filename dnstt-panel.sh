#!/bin/bash
#
# DNSTT Management Panel
# Enhanced ncurses/dialog-based CLI dashboard for DNSTT DNS tunnel server
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

# Dialog dimensions
DIALOG_HEIGHT=24
DIALOG_WIDTH=78

# Colors for dialog
export DIALOGRC="/tmp/dnstt-panel-dialogrc"

# ============================================================================
# INITIALIZATION
# ============================================================================

# Check if dialog is installed
if ! command -v dialog &>/dev/null; then
    echo "Error: 'dialog' is not installed. Please run the installer first."
    exit 1
fi

# Create custom dialog theme
create_dialog_theme() {
    cat > "$DIALOGRC" << 'EOF'
# DNSTT Panel Dialog Theme
use_shadow = ON
use_colors = ON

screen_color = (CYAN,BLACK,ON)
shadow_color = (BLACK,BLACK,ON)
dialog_color = (BLACK,WHITE,OFF)
title_color = (BLUE,WHITE,ON)
border_color = (WHITE,WHITE,ON)
button_active_color = (WHITE,BLUE,ON)
button_inactive_color = (BLACK,WHITE,OFF)
button_key_active_color = (WHITE,BLUE,ON)
button_key_inactive_color = (RED,WHITE,OFF)
button_label_active_color = (YELLOW,BLUE,ON)
button_label_inactive_color = (BLACK,WHITE,ON)
inputbox_color = (BLACK,WHITE,OFF)
inputbox_border_color = (BLACK,WHITE,OFF)
searchbox_color = (BLACK,WHITE,OFF)
searchbox_title_color = (BLUE,WHITE,ON)
searchbox_border_color = (WHITE,WHITE,ON)
position_indicator_color = (BLUE,WHITE,ON)
menubox_color = (BLACK,WHITE,OFF)
menubox_border_color = (WHITE,WHITE,ON)
item_color = (BLACK,WHITE,OFF)
item_selected_color = (WHITE,BLUE,ON)
tag_color = (BLUE,WHITE,ON)
tag_selected_color = (YELLOW,BLUE,ON)
tag_key_color = (RED,WHITE,OFF)
tag_key_selected_color = (RED,BLUE,ON)
check_color = (BLACK,WHITE,OFF)
check_selected_color = (WHITE,BLUE,ON)
uarrow_color = (GREEN,WHITE,ON)
darrow_color = (GREEN,WHITE,ON)
itemhelp_color = (WHITE,BLACK,OFF)
form_active_text_color = (WHITE,BLUE,ON)
form_text_color = (BLACK,WHITE,ON)
form_item_readonly_color = (CYAN,WHITE,ON)
gauge_color = (BLUE,WHITE,ON)
EOF
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
        echo "RUNNING"
    else
        echo "STOPPED"
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
    # Count active connections by looking at ss output for dnstt-server process
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
    # Parse recent logs for bandwidth estimation
    local bytes_in=0
    local bytes_out=0
    local log_lines=$(journalctl -u "$SERVICE_NAME" --since "1 hour ago" -q 2>/dev/null | tail -100)
    
    # This is a basic estimation - actual implementation depends on dnstt-server log format
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
    
    local status_color
    if [[ "$status" == "RUNNING" ]]; then
        status_color="\\Z2$status\\Zn"  # Green
    else
        status_color="\\Z1$status\\Zn"  # Red
    fi

    local dashboard_content="
╔════════════════════════════════════════════════════════════════════════╗
║                         DNSTT SERVER DASHBOARD                         ║
╠════════════════════════════════════════════════════════════════════════╣
║                                                                        ║
║  ┌─ Service Status ─────────────────────────────────────────────────┐  ║
║  │  Status:       $status                                             ║
║  │  Uptime:       $uptime                                             ║
║  │  Connections:  $connections active                                 ║
║  │  Memory:       $memory                                             ║
║  │  CPU:          $cpu                                                ║
║  └──────────────────────────────────────────────────────────────────┘  ║
║                                                                        ║
║  ┌─ Configuration ──────────────────────────────────────────────────┐  ║
║  │  Domain:       ${NS_SUBDOMAIN:-Not set}
║  │  MTU:          ${MTU_VALUE:-1232}
║  │  Mode:         ${TUNNEL_MODE:-ssh}
║  │  Server IP:    $server_ip
║  └──────────────────────────────────────────────────────────────────┘  ║
║                                                                        ║
║  $log_stats
║                                                                        ║
╚════════════════════════════════════════════════════════════════════════╝

Press any key to refresh or select an option below.
"

    dialog --colors --title " DNSTT Panel v1.0 " \
           --menu "$dashboard_content" \
           $DIALOG_HEIGHT $DIALOG_WIDTH 8 \
           "1" "Refresh Dashboard" \
           "2" "Service Controls" \
           "3" "View Live Logs" \
           "4" "Configuration" \
           "5" "Generate Client Config" \
           "6" "Connection Monitor" \
           "7" "System Info" \
           "0" "Exit" \
           2>/tmp/dnstt-panel-choice
    
    return $?
}

# ============================================================================
# SERVICE CONTROLS
# ============================================================================

show_service_controls() {
    local status=$(get_service_status)
    
    dialog --title " Service Controls " \
           --menu "\nCurrent Status: $status\n\nSelect action:" \
           15 50 6 \
           "1" "Start Service" \
           "2" "Stop Service" \
           "3" "Restart Service" \
           "4" "Enable on Boot" \
           "5" "Disable on Boot" \
           "0" "Back" \
           2>/tmp/dnstt-panel-choice
    
    local choice=$(cat /tmp/dnstt-panel-choice 2>/dev/null)
    
    case $choice in
        1)
            dialog --infobox "Starting service..." 3 30
            sudo systemctl start "$SERVICE_NAME" 2>/tmp/dnstt-error
            if [[ $? -eq 0 ]]; then
                dialog --msgbox "Service started successfully!" 6 40
            else
                dialog --msgbox "Failed to start service:\n$(cat /tmp/dnstt-error)" 10 50
            fi
            ;;
        2)
            dialog --yesno "Are you sure you want to stop the service?" 6 45
            if [[ $? -eq 0 ]]; then
                dialog --infobox "Stopping service..." 3 30
                sudo systemctl stop "$SERVICE_NAME" 2>/tmp/dnstt-error
                if [[ $? -eq 0 ]]; then
                    dialog --msgbox "Service stopped." 6 40
                else
                    dialog --msgbox "Failed to stop service:\n$(cat /tmp/dnstt-error)" 10 50
                fi
            fi
            ;;
        3)
            dialog --infobox "Restarting service..." 3 30
            sudo systemctl restart "$SERVICE_NAME" 2>/tmp/dnstt-error
            if [[ $? -eq 0 ]]; then
                dialog --msgbox "Service restarted successfully!" 6 40
            else
                dialog --msgbox "Failed to restart service:\n$(cat /tmp/dnstt-error)" 10 50
            fi
            ;;
        4)
            sudo systemctl enable "$SERVICE_NAME" 2>/dev/null
            dialog --msgbox "Service enabled on boot." 6 40
            ;;
        5)
            sudo systemctl disable "$SERVICE_NAME" 2>/dev/null
            dialog --msgbox "Service disabled on boot." 6 40
            ;;
    esac
}

# ============================================================================
# LIVE LOGS
# ============================================================================

show_live_logs() {
    dialog --title " Log Options " \
           --menu "\nSelect log view:" \
           12 50 4 \
           "1" "Live Log Stream (Ctrl+C to exit)" \
           "2" "Last 50 Entries" \
           "3" "Last 100 Entries" \
           "0" "Back" \
           2>/tmp/dnstt-panel-choice
    
    local choice=$(cat /tmp/dnstt-panel-choice 2>/dev/null)
    
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
            local logs=$(journalctl -u "$SERVICE_NAME" -n 50 --no-pager 2>/dev/null)
            dialog --title " Last 50 Log Entries " \
                   --scrollbar \
                   --textbox <(echo "$logs") 22 76
            ;;
        3)
            local logs=$(journalctl -u "$SERVICE_NAME" -n 100 --no-pager 2>/dev/null)
            dialog --title " Last 100 Log Entries " \
                   --scrollbar \
                   --textbox <(echo "$logs") 22 76
            ;;
    esac
}

# ============================================================================
# CONFIGURATION
# ============================================================================

show_configuration() {
    load_config
    
    dialog --title " Configuration " \
           --menu "\nCurrent Settings:\n  Domain: ${NS_SUBDOMAIN}\n  MTU: ${MTU_VALUE}\n  Mode: ${TUNNEL_MODE}\n" \
           16 55 5 \
           "1" "Edit Domain" \
           "2" "Edit MTU" \
           "3" "View Config File" \
           "4" "Reload Configuration" \
           "0" "Back" \
           2>/tmp/dnstt-panel-choice
    
    local choice=$(cat /tmp/dnstt-panel-choice 2>/dev/null)
    
    case $choice in
        1)
            local new_domain
            new_domain=$(dialog --title " Edit Domain " \
                         --inputbox "Enter new nameserver subdomain:" \
                         8 50 "$NS_SUBDOMAIN" \
                         2>&1 >/dev/tty)
            
            if [[ $? -eq 0 && -n "$new_domain" ]]; then
                sudo sed -i "s/^NS_SUBDOMAIN=.*/NS_SUBDOMAIN=\"$new_domain\"/" "$CONFIG_FILE"
                dialog --msgbox "Domain updated to: $new_domain\n\nRestart service to apply changes." 8 50
            fi
            ;;
        2)
            local new_mtu
            new_mtu=$(dialog --title " Edit MTU " \
                      --inputbox "Enter new MTU value (500-65535):" \
                      8 50 "$MTU_VALUE" \
                      2>&1 >/dev/tty)
            
            if [[ $? -eq 0 && -n "$new_mtu" ]]; then
                if [[ "$new_mtu" =~ ^[0-9]+$ ]] && [[ "$new_mtu" -ge 500 ]] && [[ "$new_mtu" -le 65535 ]]; then
                    sudo sed -i "s/^MTU_VALUE=.*/MTU_VALUE=\"$new_mtu\"/" "$CONFIG_FILE"
                    dialog --msgbox "MTU updated to: $new_mtu\n\nRestart service to apply changes." 8 50
                else
                    dialog --msgbox "Invalid MTU value. Must be between 500 and 65535." 7 50
                fi
            fi
            ;;
        3)
            dialog --title " Configuration File " \
                   --textbox "$CONFIG_FILE" 18 70
            ;;
        4)
            dialog --infobox "Reloading configuration..." 3 35
            sudo systemctl restart "$SERVICE_NAME" 2>/dev/null
            sleep 2
            dialog --msgbox "Configuration reloaded." 6 30
            ;;
    esac
}

# ============================================================================
# CLIENT CONFIG GENERATOR
# ============================================================================

show_client_config() {
    load_config
    local server_ip=$(get_server_ip)
    
    dialog --title " Client Configuration " \
           --menu "\nGenerate configuration for:" \
           14 55 5 \
           "1" "Desktop (dnstt-client)" \
           "2" "HTTP Injector (Android)" \
           "3" "DNSTT.XYZ App" \
           "4" "Export Public Key" \
           "0" "Back" \
           2>/tmp/dnstt-panel-choice
    
    local choice=$(cat /tmp/dnstt-panel-choice 2>/dev/null)
    
    case $choice in
        1)
            local config="
═══════════════════════════════════════════════════════════════
              DNSTT Desktop Client Configuration
═══════════════════════════════════════════════════════════════

1. Download client from: https://dnstt.network

2. Save this public key to 'server.pub':
─────────────────────────────────────────────────────────────
$PUBLIC_KEY
─────────────────────────────────────────────────────────────

3. Run client command:
   dnstt-client -udp DNS_IP:53 -pubkey-file server.pub \\
       ${NS_SUBDOMAIN} 127.0.0.1:7000

4. Connect via SSH:
   ssh -p 7000 user@127.0.0.1

Notes:
- Replace DNS_IP with your ISP's DNS or 8.8.8.8
- Replace 'user' with your SSH username
═══════════════════════════════════════════════════════════════
"
            dialog --title " Desktop Client Config " \
                   --msgbox "$config" 26 65
            ;;
        2)
            local config="
═══════════════════════════════════════════════════════════════
            HTTP Injector Configuration (Android)
═══════════════════════════════════════════════════════════════

SSH Settings:
─────────────────────────────────────────────────────────────
  Host:     127.0.0.1
  Port:     7000
  Username: [Your SSH username]
  Password: [Your SSH password]

DNSTT/DNS Tunnel Settings:
─────────────────────────────────────────────────────────────
  DNS Server:  Use your ISP DNS or 8.8.8.8
  DNS Domain:  ${NS_SUBDOMAIN}
  
  Public Key:
  $PUBLIC_KEY

Remote Proxy:
─────────────────────────────────────────────────────────────
  Leave empty or use 127.0.0.1:8080 for local proxy

═══════════════════════════════════════════════════════════════
"
            dialog --title " HTTP Injector Config " \
                   --msgbox "$config" 28 65
            ;;
        3)
            local config="
═══════════════════════════════════════════════════════════════
              DNSTT.XYZ App Configuration
═══════════════════════════════════════════════════════════════

Server Settings:
─────────────────────────────────────────────────────────────
  Server Domain:  ${NS_SUBDOMAIN}
  Local Port:     7000
  
  Public Key:
  $PUBLIC_KEY

After connecting:
─────────────────────────────────────────────────────────────
  Use any SSH client to connect to:
    Host: 127.0.0.1
    Port: 7000

═══════════════════════════════════════════════════════════════
"
            dialog --title " DNSTT.XYZ Config " \
                   --msgbox "$config" 22 65
            ;;
        4)
            local export_path="/tmp/dnstt-server-${NS_SUBDOMAIN//\./_}.pub"
            cp "$PUBLIC_KEY_FILE" "$export_path" 2>/dev/null
            dialog --title " Public Key Exported " \
                   --msgbox "Public key exported to:\n$export_path\n\nKey content:\n$PUBLIC_KEY" 12 65
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
        
        local monitor="
Active Connections: $count

$(ss -tunp 2>/dev/null | head -1)
$connections

Press ESC or select Back to return.
Auto-refreshing every ${REFRESH_INTERVAL} seconds...
"
        
        dialog --title " Connection Monitor " \
               --timeout $REFRESH_INTERVAL \
               --menu "$monitor" \
               20 76 1 \
               "0" "Back to Dashboard" \
               2>/tmp/dnstt-panel-choice
        
        local ret=$?
        local choice=$(cat /tmp/dnstt-panel-choice 2>/dev/null)
        
        # Exit if user selected Back or pressed ESC
        if [[ "$choice" == "0" ]] || [[ $ret -eq 255 ]] || [[ $ret -eq 1 ]]; then
            break
        fi
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
    
    local info="
═══════════════════════════════════════════════════════════════════
                         SYSTEM INFORMATION
═══════════════════════════════════════════════════════════════════

Server:
───────────────────────────────────────────────────────────────────
  Hostname:     $hostname
  IP Address:   $server_ip
  OS:           $os_info
  Kernel:       $kernel
  Uptime:       $uptime_sys

Resources:
───────────────────────────────────────────────────────────────────
  Memory:       $memory
  Disk (/):     $disk
  Load Average: $load

Network:
───────────────────────────────────────────────────────────────────
  Firewall:     $ufw_status
  
DNSTT:
───────────────────────────────────────────────────────────────────
  Config Dir:   $CONFIG_DIR
  Service:      $SERVICE_NAME
  Binary:       /usr/local/bin/dnstt-server

═══════════════════════════════════════════════════════════════════
"
    dialog --title " System Information " \
           --msgbox "$info" 30 72
}

# ============================================================================
# CLEANUP
# ============================================================================

cleanup() {
    rm -f /tmp/dnstt-panel-choice
    rm -f /tmp/dnstt-error
    rm -f "$DIALOGRC"
    clear
    echo "DNSTT Panel closed."
}

trap cleanup EXIT

# ============================================================================
# MAIN LOOP
# ============================================================================

main() {
    # Check for root for certain operations
    if [[ $EUID -ne 0 ]]; then
        echo "Note: Some operations require root privileges. Consider running with sudo."
        sleep 2
    fi
    
    create_dialog_theme
    load_config
    
    while true; do
        show_dashboard
        local ret=$?
        
        if [[ $ret -ne 0 ]]; then
            # User pressed ESC or Cancel
            dialog --yesno "Exit DNSTT Panel?" 6 25
            if [[ $? -eq 0 ]]; then
                break
            fi
            continue
        fi
        
        local choice=$(cat /tmp/dnstt-panel-choice 2>/dev/null)
        
        case $choice in
            1)
                # Refresh - just continue the loop
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
                show_system_info
                ;;
            0)
                dialog --yesno "Exit DNSTT Panel?" 6 25
                if [[ $? -eq 0 ]]; then
                    break
                fi
                ;;
        esac
    done
}

# Run main
main "$@"
