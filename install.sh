#!/bin/bash
#
# DNSTT Quick Install Script
# One-line installer for Ubuntu 24.04 LTS
#
# Usage: bash <(curl -Ls URL)
#

set -e

REPO_URL="https://github.com/atakhadiviom/DNSTT-SSH-Panel"
BRANCH="main"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          DNSTT SSH Panel - Quick Installer                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check root
if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] This script must be run as root"
    echo "Try: sudo bash <(curl -Ls $REPO_URL/raw/$BRANCH/install.sh)"
    exit 1
fi

# Create temp directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

echo "[INFO] Downloading installer files..."

# Download main installer
curl -fsSL "$REPO_URL/raw/$BRANCH/dnstt-panel-installer.sh" -o dnstt-panel-installer.sh
curl -fsSL "$REPO_URL/raw/$BRANCH/dnstt-panel.sh" -o dnstt-panel.sh

# Make executable
chmod +x dnstt-panel-installer.sh dnstt-panel.sh

echo "[INFO] Starting installation..."
echo ""

# Run main installer
bash dnstt-panel-installer.sh "$@"

# Cleanup
cd /
rm -rf "$TEMP_DIR"

echo ""
echo "[SUCCESS] Installation complete!"
echo "Run 'dnstt-panel' to access the management panel."
