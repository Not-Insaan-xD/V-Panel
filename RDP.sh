
#!/bin/bash

clear

# ---------- COLORS ----------
RED="\e[31m"
GREEN="\e[32m"
CYAN="\e[36m"
RESET="\e[0m"

# ---------- ASCII ----------
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
echo "1. RDP Setup (XFCE - Fast)"
echo "0. Exit"
echo
echo "Press Ctrl + C anytime to stop"
echo

read -p "Select option: " opt
[ "$opt" != "1" ] && exit 0

# ---------- FUNCTIONS ----------
loader () {
  echo -ne "$1"
  for i in {1..5}; do
    echo -ne "."
    sleep 0.4
  done
  echo -e " ${GREEN}DONE${RESET}"
}

hide () {
  "$@" >/dev/null 2>&1
}

# ---------- ROOT CHECK ----------
if [ "$EUID" -ne 0 ]; then
  echo "Run as root"
  exit 1
fi

# ---------- DEPENDENCIES ----------
loader "Updating system"
hide apt update -y

loader "Installing core dependencies"
hide apt install -y curl wget sudo openssl software-properties-common

# ---------- TAILSCALE ----------
TOKEN_FILE="/root/.tailscale_key"

if [ -f "$TOKEN_FILE" ]; then
  read -p "Saved Tailscale token found. Use it? (y/n): " ch
  if [[ "$ch" =~ ^[Yy]$ ]]; then
    TS_KEY=$(cat $TOKEN_FILE)
  else
    read -p "Enter Tailscale Auth Key: " TS_KEY
    echo "$TS_KEY" > $TOKEN_FILE
    chmod 600 $TOKEN_FILE
  fi
else
  read -p "Enter Tailscale Auth Key: " TS_KEY
  echo "$TS_KEY" > $TOKEN_FILE
  chmod 600 $TOKEN_FILE
fi

loader "Installing Tailscale"
hide curl -fsSL https://tailscale.com/install.sh | sh
hide systemctl enable tailscaled
hide systemctl start tailscaled

loader "Connecting to Tailscale"
hide tailscale up --authkey="$TS_KEY" --hostname=Insaan-RDP

# ---------- XFCE + XRDP ----------
loader "Installing XFCE Desktop + XRDP"
hide apt install -y xfce4 xfce4-goodies xrdp dbus-x11

hide systemctl enable xrdp
hide systemctl restart xrdp

echo "xfce4-session" > /root/.xsession
sed -i.bak '/fi/a xfce4-session' /etc/xrdp/startwm.sh

# ---------- USER ----------
USER="Insaan"

if id "$USER" &>/dev/null; then
  echo -e "${CYAN}User Insaan already exists${RESET}"
else
  PASS=$(openssl rand -base64 12)
  hide useradd -m -s /bin/bash "$USER"
  echo "$USER:$PASS" | chpasswd
  hide usermod -aG sudo "$USER"

  echo
  echo "==============================="
  echo " RDP LOGIN DETAILS"
  echo " Username : Insaan"
  echo " Password : $PASS"
  echo "==============================="
fi

# ---------- AUTOSTART ----------
loader "Enabling auto start on reboot"

cat <<EOF >/etc/systemd/system/insaan-rdp.service
[Unit]
Description=Insaan RDP Auto Start
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c "systemctl start xrdp && systemctl start tailscaled"

[Install]
WantedBy=multi-user.target
EOF

hide systemctl daemon-reexec
hide systemctl enable insaan-rdp.service

TS_IP=$(tailscale ip -4)

echo
echo "======================================"
echo " RDP READY (XFCE - FAST)"
echo " Address : $TS_IP"
echo " Port    : 3389"
echo " User    : Insaan"
echo "======================================"
echo
