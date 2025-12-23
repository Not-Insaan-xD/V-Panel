#!/bin/bash

clear

while true; do
  echo "=============================="
  echo "        VPS SETUP MENU        "
  echo "=============================="
  echo
  echo "1. RDP Setup"
  echo "2. Tailscale IP"
  echo "3. Uninstall Service"
  echo "4. Exit"
  echo
  read -p "Select option: " opt
  echo

  case $opt in

    1)
      echo "Running RDP setup..."
      echo

      sudo apt update && sudo apt upgrade -y

      sudo apt install xfce4 xfce4-goodies xrdp -y

      echo "startxfce4" > ~/.xsession
      sudo chown $(whoami):$(whoami) ~/.xsession

      sudo systemctl enable xrdp
      sudo systemctl restart xrdp

      echo
      echo "======================================"
      echo " RDP setup complete"
      echo " Please reboot your VPS"
      echo "======================================"
      echo
      ;;

    2)
      echo "Setting up Tailscale..."
      echo

      if ! command -v tailscale >/dev/null 2>&1; then
        curl -fsSL https://tailscale.com/install.sh | sh
      fi

      sudo systemctl enable tailscaled
      sudo systemctl start tailscaled

      echo
      echo "Login prompt will open (browser or link)"
      echo
      sudo tailscale up

      echo
      echo "======================================"
      echo " Your Tailscale IP:"
      sudo tailscale ip -4
      echo "======================================"
      echo
      ;;

    3)
      echo "Uninstalling all services..."
      echo

      sudo systemctl stop xrdp tailscaled 2>/dev/null
      sudo systemctl disable xrdp tailscaled 2>/dev/null

      sudo apt remove --purge -y xrdp xfce4 xfce4-goodies tailscale
      sudo apt autoremove -y
      sudo rm -f ~/.xsession

      echo
      echo "======================================"
      echo " All services uninstalled"
      echo "======================================"
      echo
      ;;

    4)
      echo "Exiting..."
      exit 0
      ;;

    *)
      echo "Invalid option, try again"
      echo
      ;;
  esac
done

