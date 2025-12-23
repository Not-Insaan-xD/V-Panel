#!/bin/bash

set -e
clear

# ---------------- COLORS ----------------
RED="\e[31m"
GREEN="\e[32m"
CYAN="\e[36m"
RESET="\e[0m"

# ---------------- ASCII ----------------
echo -e "${RED}"
cat <<'EOF'
██▓ ███▄    █   ██████  ▄▄▄      ▄▄▄       ███▄    █ 
▓██▒ ██ ▀█   █ ▒██    ▒ ▒████▄   ▒████▄     ██ ▀█   █ 
▒██▒▓██  ▀█ ██▒░ ▓██▄   ▒██  ▀█▄ ▒██  ▀█▄  ▓██  ▀█ ██▒
░██░▓██▒  ▐▌██▒  ▒   ██▒░██▄▄▄▄██░██▄▄▄▄██ ▓██▒  ▐▌██▒
░██░▒██░   ▓██░▒██████▒▒ ▓█   ▓██▒▓█   ▓██▒▒██░   ▓██░
░▓  ░ ▒░   ▒ ▒ ▒ ▒▓▒ ▒ ░ ▒▒   ▓▒█░▒▒   ▓▒█░░ ▒░   ▒ ▒ 
 ▒ ░░ ░░   ░ ▒░░ ░▒  ░ ░  ▒   ▒▒ ░ ▒   ▒▒ ░░ ░░   ░ ▒░
 ▒ ░   ░   ░ ░ ░  ░  ░    ░   ▒    ░   ▒      ░   ░ ░ 
 ░           ░       ░        ░  ░     ░  ░         ░ 
EOF
echo -e "${RESET}"
echo "--------------------------------------------------"
echo
echo "1. RDP Setup (XFCE - Stable)"
echo "0. Exit"
echo
echo "Press Ctrl + C anytime to stop"
echo

read -p "Select option: " opt
[ "$opt" != "1" ] && exit 0

# ---------------- FUNCTIONS ----------------
loader () {
  echo -ne "$1"
  for i in {1..6}; do
    echo -ne "."
    sleep 0.4
  done
  echo -e " ${GREEN}DONE${RESET}"
}

hide () {
  "$@" >/dev/null 2>&1 || true
}

# ---------------- ROOT CHECK ----------------
if [ "$EUID" -ne 0 ]; then
  echo "❌ Run as root (sudo -i)"
  exit 1
fi

# ---------------- SYSTEM ----------------
loader "Updating system"
hide apt update -y

loader "Installing base dependencies"
hide apt install -y curl wget sudo openssl ca-certificates dbus-x11

# ---------------- TAILSCALE ----------------
TOKEN_FILE="/root/.tailscale_key"

if [ -f "$TOKEN_FILE" ]; then
  read -p "Saved Tailscale token found. Use it? (y/n): " ch
  if [[ "$ch" =~ ^[Yy]$ ]]; then
    TS_KEY=$(cat "$TOKEN_FILE")
  else
    read -p "Enter Tailscale Auth Key: " TS_KEY
    echo "$TS_KEY" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
  fi
else
  read -p "Enter Tailscale Auth Key: " TS_KEY
  echo "$TS_KEY" > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
fi

loader "Installing Tailscale"
if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh >/dev/null 2>&1
fi

hide systemctl enable tailscaled
hide systemctl start tailscaled

loader "Connecting to Tailscale"
/usr/bin/tailscale up --authkey="$TS_KEY" --hostname=Insaan-RDP >/dev/null 2>&1 || true

# ---------------- XFCE + XRDP ----------------
loader "Installing XFCE Desktop + XRDP"
hide apt install -y xfce4 xfce4-goodies xrdp

hide systemctl enable xrdp
hide systemctl restart xrdp

# XFCE session (safe for all distros)
echo "startxfce4" > /root/.xsession
chmod 644 /root/.xsession
echo "startxfce4" | tee /etc/skel/.xsession >/dev/null

# ---------------- USER ----------------
USER="Insaan"

if id "$USER" >/dev/null 2>&1; then
  echo -e "${CYAN}User Insaan already exists${RESET}"
else
  PASS=$(openssl rand -base64 12)
  useradd -m -s /bin/bash "$USER"
  echo "$USER:$PASS" | chpasswd
  usermod -aG sudo "$USER"

  echo
  echo "==============================="
  echo " RDP LOGIN DETAILS"
  echo " Username : Insaan"
  echo " Password : $PASS"
  echo "==============================="
fi

# ---------------- AUTOSTART ----------------
loader "Enabling auto start on reboot"

cat <<EOF >/etc/systemd/system/insaan-rdp.service
[Unit]
Description=Insaan RDP Auto Start
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c "/usr/bin/systemctl start xrdp && /usr/bin/systemctl start tailscaled"

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl enable insaan-rdp.service >/dev/null 2>&1

# ---------------- FINAL INFO ----------------
TS_IP=$(/usr/bin/tailscale ip -4 2>/dev/null | head -n1)

echo
echo "======================================"
echo " RDP READY (STABLE)"
echo " Address : ${TS_IP:-Check with: tailscale ip -4}"
echo " Port    : 3389"
echo " User    : Insaan"
echo " Desktop : XFCE"
echo "======================================"
echo

