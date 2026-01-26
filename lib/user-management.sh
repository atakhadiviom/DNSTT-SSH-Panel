#!/bin/bash
#
# DNSTT User Management Module
# Manages SSH users for DNSTT tunnel access
#
# This module is sourced by dnstt-panel.sh
#

# ============================================================================
# CONFIGURATION
# ============================================================================

USER_DB_DIR="/etc/dnstt/users"
USER_GROUP="dnstt-users"
MAX_CONNECTIONS_DEFAULT=2
SHELL_NOLOGIN="/usr/sbin/nologin"
SHELL_RBASH="/bin/rbash"

# ============================================================================
# INITIALIZATION
# ============================================================================

init_user_management() {
    # Create user database directory
    mkdir -p "$USER_DB_DIR"
    chmod 700 "$USER_DB_DIR"

    # Create user group if not exists
    if ! getent group "$USER_GROUP" &>/dev/null; then
        groupadd "$USER_GROUP"
    fi

    # Create connection limiter script
    create_connection_limiter
}

# ============================================================================
# CONNECTION LIMITER
# ============================================================================

create_connection_limiter() {
    local limiter_script="/usr/local/bin/dnstt-connection-limit"
    
    cat > "$limiter_script" << 'LIMITER_EOF'
#!/bin/bash
# DNSTT Connection Limiter
# Limits concurrent SSH connections per user

USER="$PAM_USER"
LIMIT_FILE="/etc/dnstt/users/${USER}.limit"
DEFAULT_LIMIT=2

# Get limit for this user
if [[ -f "$LIMIT_FILE" ]]; then
    MAX_CONN=$(cat "$LIMIT_FILE")
else
    MAX_CONN=$DEFAULT_LIMIT
fi

# Count current connections
CURRENT_CONN=$(who | grep -c "^${USER} ")

if [[ $CURRENT_CONN -ge $MAX_CONN ]]; then
    echo "Maximum connections ($MAX_CONN) reached for user $USER"
    exit 1
fi

exit 0
LIMITER_EOF

    chmod +x "$limiter_script"

    # Add to PAM configuration if not already present
    local pam_sshd="/etc/pam.d/sshd"
    if [[ -f "$pam_sshd" ]] && ! grep -q "dnstt-connection-limit" "$pam_sshd"; then
        echo "session required pam_exec.so /usr/local/bin/dnstt-connection-limit" >> "$pam_sshd"
    fi
}

# ============================================================================
# USER FUNCTIONS
# ============================================================================

create_tunnel_user() {
    local username="$1"
    local password="$2"
    local max_conn="${3:-$MAX_CONNECTIONS_DEFAULT}"
    local expiry_days="${4:-0}"  # 0 = no expiry

    # Validate username
    if [[ ! "$username" =~ ^[a-z][a-z0-9_-]{2,30}$ ]]; then
        echo "Invalid username. Use lowercase letters, numbers, underscore, hyphen. 3-31 chars."
        return 1
    fi

    # Check if user exists
    if id "$username" &>/dev/null; then
        echo "User $username already exists"
        return 1
    fi

    # Create user with restricted shell
    useradd -m -g "$USER_GROUP" -s "$SHELL_RBASH" "$username"
    
    # Set password
    echo "$username:$password" | chpasswd
    
    # Set connection limit
    echo "$max_conn" > "${USER_DB_DIR}/${username}.limit"
    
    # Set expiry if specified
    if [[ $expiry_days -gt 0 ]]; then
        local expiry_date=$(date -d "+${expiry_days} days" +%Y-%m-%d)
        chage -E "$expiry_date" "$username"
        echo "$expiry_date" > "${USER_DB_DIR}/${username}.expiry"
    fi
    
    # Store creation info
    cat > "${USER_DB_DIR}/${username}.info" << EOF
created=$(date +%Y-%m-%d)
max_connections=$max_conn
expiry_days=$expiry_days
status=active
EOF

    echo "User $username created successfully"
    return 0
}

delete_tunnel_user() {
    local username="$1"
    
    if ! id "$username" &>/dev/null; then
        echo "User $username does not exist"
        return 1
    fi
    
    # Kill user sessions
    pkill -u "$username" 2>/dev/null
    
    # Delete user and home directory
    userdel -r "$username" 2>/dev/null
    
    # Remove user data files
    rm -f "${USER_DB_DIR}/${username}."*
    
    echo "User $username deleted"
    return 0
}

disable_tunnel_user() {
    local username="$1"
    
    if ! id "$username" &>/dev/null; then
        echo "User $username does not exist"
        return 1
    fi
    
    # Lock the account
    usermod -L "$username"
    
    # Update status
    if [[ -f "${USER_DB_DIR}/${username}.info" ]]; then
        sed -i 's/status=.*/status=disabled/' "${USER_DB_DIR}/${username}.info"
    fi
    
    # Kill existing sessions
    pkill -u "$username" 2>/dev/null
    
    echo "User $username disabled"
    return 0
}

enable_tunnel_user() {
    local username="$1"
    
    if ! id "$username" &>/dev/null; then
        echo "User $username does not exist"
        return 1
    fi
    
    # Unlock the account
    usermod -U "$username"
    
    # Update status
    if [[ -f "${USER_DB_DIR}/${username}.info" ]]; then
        sed -i 's/status=.*/status=active/' "${USER_DB_DIR}/${username}.info"
    fi
    
    echo "User $username enabled"
    return 0
}

set_user_expiry() {
    local username="$1"
    local expiry_date="$2"  # Format: YYYY-MM-DD
    
    if ! id "$username" &>/dev/null; then
        echo "User $username does not exist"
        return 1
    fi
    
    chage -E "$expiry_date" "$username"
    echo "$expiry_date" > "${USER_DB_DIR}/${username}.expiry"
    
    echo "User $username expiry set to $expiry_date"
    return 0
}

set_user_connection_limit() {
    local username="$1"
    local limit="$2"
    
    if ! id "$username" &>/dev/null; then
        echo "User $username does not exist"
        return 1
    fi
    
    echo "$limit" > "${USER_DB_DIR}/${username}.limit"
    
    # Update info file
    if [[ -f "${USER_DB_DIR}/${username}.info" ]]; then
        sed -i "s/max_connections=.*/max_connections=$limit/" "${USER_DB_DIR}/${username}.info"
    fi
    
    echo "Connection limit for $username set to $limit"
    return 0
}

change_user_password() {
    local username="$1"
    local new_password="$2"
    
    if ! id "$username" &>/dev/null; then
        echo "User $username does not exist"
        return 1
    fi
    
    echo "$username:$new_password" | chpasswd
    
    echo "Password changed for $username"
    return 0
}

# ============================================================================
# QUERY FUNCTIONS
# ============================================================================

list_tunnel_users() {
    echo "Username|Status|Connections|Max|Expiry|Created"
    echo "--------|------|-----------|---|------|-------"
    
    for user in $(getent group "$USER_GROUP" 2>/dev/null | cut -d: -f4 | tr ',' '\n'); do
        if [[ -n "$user" ]]; then
            local status="active"
            local max_conn="2"
            local expiry="never"
            local created="unknown"
            local current_conn=0
            
            # Get current connections
            current_conn=$(who | grep -c "^${user} " 2>/dev/null || echo "0")
            
            # Read user info
            if [[ -f "${USER_DB_DIR}/${user}.info" ]]; then
                source "${USER_DB_DIR}/${user}.info" 2>/dev/null
                max_conn="${max_connections:-2}"
                created="${created:-unknown}"
            fi
            
            # Check if locked
            if passwd -S "$user" 2>/dev/null | grep -q " L "; then
                status="disabled"
            fi
            
            # Get expiry
            if [[ -f "${USER_DB_DIR}/${user}.expiry" ]]; then
                expiry=$(cat "${USER_DB_DIR}/${user}.expiry")
                # Check if expired
                if [[ $(date +%s) -gt $(date -d "$expiry" +%s 2>/dev/null || echo 0) ]]; then
                    status="expired"
                fi
            fi
            
            # Get limit
            if [[ -f "${USER_DB_DIR}/${user}.limit" ]]; then
                max_conn=$(cat "${USER_DB_DIR}/${user}.limit")
            fi
            
            echo "$user|$status|$current_conn|$max_conn|$expiry|$created"
        fi
    done
}

get_active_sessions() {
    echo "User|TTY|From|Login Time|Idle"
    echo "----|---|----|-----------|----|"
    
    who -u 2>/dev/null | while read user tty date time idle pid from; do
        # Filter to only dnstt-users group
        if groups "$user" 2>/dev/null | grep -q "$USER_GROUP"; then
            echo "$user|$tty|${from:-local}|$date $time|${idle:-active}"
        fi
    done
}

kick_user_session() {
    local username="$1"
    local session="${2:-all}"
    
    if [[ "$session" == "all" ]]; then
        pkill -u "$username"
        echo "All sessions for $username terminated"
    else
        # Kill specific TTY
        pkill -t "$session"
        echo "Session $session terminated"
    fi
}

get_user_info() {
    local username="$1"
    
    if ! id "$username" &>/dev/null; then
        echo "User not found"
        return 1
    fi
    
    local info=""
    info+="Username: $username\n"
    info+="UID: $(id -u "$username")\n"
    info+="Groups: $(groups "$username" | cut -d: -f2)\n"
    info+="Home: $(eval echo ~"$username")\n"
    info+="Shell: $(getent passwd "$username" | cut -d: -f7)\n"
    
    # Account status
    if passwd -S "$username" 2>/dev/null | grep -q " L "; then
        info+="Status: LOCKED\n"
    else
        info+="Status: Active\n"
    fi
    
    # Connection info
    local max_conn="2"
    if [[ -f "${USER_DB_DIR}/${username}.limit" ]]; then
        max_conn=$(cat "${USER_DB_DIR}/${username}.limit")
    fi
    local current_conn=$(who | grep -c "^${username} " 2>/dev/null || echo "0")
    info+="Connections: $current_conn / $max_conn\n"
    
    # Expiry
    local expiry=$(chage -l "$username" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
    info+="Expires: ${expiry:-never}\n"
    
    # Last login
    local last_login=$(last -1 "$username" 2>/dev/null | head -1)
    info+="Last login: ${last_login:-never}\n"
    
    echo -e "$info"
}

generate_user_credentials() {
    local username="$1"
    local server_ip="${2:-$(curl -s ifconfig.me 2>/dev/null)}"
    
    source /etc/dnstt/dnstt-server.conf 2>/dev/null
    
    cat << EOF
═══════════════════════════════════════════════════════════════
            DNSTT SSH Tunnel Credentials
═══════════════════════════════════════════════════════════════

Username: $username
Password: [Set by admin]

═══ Connection Details ═══

DNS Domain: ${NS_SUBDOMAIN:-Not configured}
Public Key: $(cat /etc/dnstt/dnstt-server.pub 2>/dev/null)

═══ For Desktop Client ═══

1. Run DNSTT client:
   dnstt-client -udp DNS_IP:53 -pubkey-file server.pub ${NS_SUBDOMAIN} 127.0.0.1:7000

2. Connect SSH:
   ssh -p 7000 ${username}@127.0.0.1

═══ For HTTP Injector ═══

SSH Host: 127.0.0.1
SSH Port: 7000
SSH User: $username
SSH Pass: [Your password]
DNS Domain: ${NS_SUBDOMAIN}
Public Key: $(cat /etc/dnstt/dnstt-server.pub 2>/dev/null)

═══════════════════════════════════════════════════════════════
EOF
}

# ============================================================================
# BULK OPERATIONS
# ============================================================================

create_users_bulk() {
    local count="$1"
    local prefix="${2:-user}"
    local password_length="${3:-12}"
    local max_conn="${4:-2}"
    local expiry_days="${5:-30}"
    
    local output_file="/tmp/dnstt-users-$(date +%Y%m%d-%H%M%S).txt"
    
    echo "Creating $count users with prefix '$prefix'..."
    echo "Username,Password,Created" > "$output_file"
    
    for i in $(seq 1 "$count"); do
        local username="${prefix}${i}"
        local password=$(tr -dc 'A-Za-z0-9!@#$%' < /dev/urandom | head -c "$password_length")
        
        if create_tunnel_user "$username" "$password" "$max_conn" "$expiry_days" &>/dev/null; then
            echo "$username,$password,$(date +%Y-%m-%d)" >> "$output_file"
            echo "Created: $username"
        else
            echo "Failed: $username"
        fi
    done
    
    echo ""
    echo "User list saved to: $output_file"
    cat "$output_file"
}

cleanup_expired_users() {
    local deleted=0
    
    for user in $(getent group "$USER_GROUP" 2>/dev/null | cut -d: -f4 | tr ',' '\n'); do
        if [[ -f "${USER_DB_DIR}/${user}.expiry" ]]; then
            local expiry=$(cat "${USER_DB_DIR}/${user}.expiry")
            if [[ $(date +%s) -gt $(date -d "$expiry" +%s 2>/dev/null || echo 0) ]]; then
                if delete_tunnel_user "$user"; then
                    ((deleted++))
                fi
            fi
        fi
    done
    
    echo "Cleaned up $deleted expired users"
}

# Initialize on source
init_user_management 2>/dev/null
