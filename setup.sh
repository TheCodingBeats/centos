#!/bin/bash

# TCB Service Manager Bootstrap Script
# Frame: CentOS 8+, Professional, Indestructible V11

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}      TCB Service Manager - Setup      ${NC}"
echo -e "${BLUE}=======================================${NC}"

# 1. OS Detection (CentOS 8+)
OS_VERSION=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"')
if [[ ! "$OS_VERSION" =~ ^[8-9] ]]; then
    echo -e "${RED}[ERROR] This tool is optimized for CentOS 8 and 9.${NC}"
fi

# 2. Path Configuration
TCB_BIN="/usr/local/bin/tcb"
CORE_BIN="/opt/tcb/bin/tcb"
CORE_BIN_GZ="/opt/tcb/bin/tcb.gz"
BINARY_URL="https://raw.githubusercontent.com/TheCodingBeats/centos/main/tcb.gz"

mkdir -p /opt/tcb/bin

# 3. Defensive Download
echo -e "${BLUE}[INFO] Downloading secure core binary...${NC}"
# Purge old versions COMPLETELY
rm -f "$CORE_BIN" "$CORE_BIN_GZ"
CACHE_BUSTER=$(date +%s)

if ! curl -sSLf "$BINARY_URL?v=$CACHE_BUSTER" -o "$CORE_BIN_GZ"; then
    echo -e "${RED}[ERROR] Binary download failed from $BINARY_URL${NC}"
    exit 1
fi

# 4. Integrity Check & Extraction
FILE_SIZE=$(stat -c%s "$CORE_BIN_GZ" 2>/dev/null || stat -f%z "$CORE_BIN_GZ" 2>/dev/null)
echo -e "${BLUE}[INFO] Downloaded $(($FILE_SIZE / 1024 / 1024))MB compressed binary.${NC}"

if ! gunzip -f "$CORE_BIN_GZ"; then
    echo -e "${RED}[ERROR] Corrupted binary downloaded. Please check your GitHub repo.${NC}"
    exit 1
fi

chmod +x "$CORE_BIN"
ln -sf "$CORE_BIN" "$TCB_BIN"

# 5. Firewall Configuration (Port 54444)
if command -v firewall-cmd &> /dev/null; then
    echo -e "${BLUE}[INFO] Checking firewall...${NC}"
    firewall-cmd --permanent --add-port=54444/tcp &>/dev/null
    firewall-cmd --reload &>/dev/null
fi

# 6. Systemd Force-Refresh
SERVICE_FILE="/etc/systemd/system/tcb.service"
echo -e "${BLUE}[INFO] Force-refreshing tcb.service...${NC}"

# Stop and disable before overriding to clear any "failed too quickly" states
systemctl stop tcb &>/dev/null
systemctl disable tcb &>/dev/null
rm -f "$SERVICE_FILE"

cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=TCB Service Manager Daemon
After=network.target

[Service]
Type=simple
User=root
ExecStart=$CORE_BIN daemon
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable tcb
systemctl start tcb

# 7. Verification Launch
echo -e "${GREEN}[SUCCESS] V1.1.6 Installation Complete!${NC}"
echo -e "Wait 2s for core initialization..."
sleep 2

# Diagnostic: check version first
if ! "$TCB_BIN" --version; then
    echo -e "${RED}[ERROR] Binary execution failed. Diagnostic logs below:${NC}"
    journalctl -u tcb --no-pager -n 20
    exit 1
fi

# Force a status check to verify the internal snapshot path
if ! "$TCB_BIN" status; then
    echo -e "${RED}[ERROR] Core initialization failed. Checking logs...${NC}"
    journalctl -u tcb --no-pager -n 20
    exit 1
fi

echo -e "Web Interface: ${BLUE}http://$(hostname -I | awk '{print $1}' | tr -d ' '):54444${NC}"
echo -e "Use ${BLUE}tcb help${NC} for more commands."
