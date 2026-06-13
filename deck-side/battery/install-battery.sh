#!/bin/bash
# Install the Steam Deck -> Home Assistant MQTT battery reporter as a user
# systemd service. Pure stdlib (no pip). Run ON THE DECK.
#
# Usage (broker settings via env; password prompted, never echoed):
#   curl -fsSL https://raw.githubusercontent.com/DxKoster/Steam-Deck-Waker/main/deck-side/battery/install-battery.sh \
#     | SD_MQTT_HOST=10.0.0.21 SD_MQTT_USER=mqtt SD_MQTT_PORT=1883 bash
#
# It will ask for the MQTT password interactively.
set -euo pipefail

RAW=https://raw.githubusercontent.com/DxKoster/Steam-Deck-Waker/main/deck-side/battery/sdbattery.py
HOST="${SD_MQTT_HOST:-}"
USER_="${SD_MQTT_USER:-}"
PORT="${SD_MQTT_PORT:-1883}"
INTERVAL="${SD_INTERVAL:-60}"

[ -z "$HOST" ] && { read -rp "MQTT broker host (e.g. 10.0.0.21): " HOST < /dev/tty; }
[ -z "$USER_" ] && { read -rp "MQTT username: " USER_ < /dev/tty; }
read -rsp "MQTT password: " PASS < /dev/tty; echo

# 1) the reporter script
echo "Downloading reporter..."
curl -fsSL "$RAW" -o "$HOME/sdbattery.py"
chmod +x "$HOME/sdbattery.py"

# 2) config (password lives here, chmod 600, never committed anywhere)
mkdir -p "$HOME/.config"
umask 077
cat > "$HOME/.config/sdbattery.env" <<EOF
SD_MQTT_HOST=$HOST
SD_MQTT_PORT=$PORT
SD_MQTT_USER=$USER_
SD_MQTT_PASS=$PASS
SD_INTERVAL=$INTERVAL
EOF
umask 022

# 3) user systemd service
mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/sd-battery.service" <<EOF
[Unit]
Description=Steam Deck battery -> Home Assistant (MQTT)

[Service]
EnvironmentFile=%h/.config/sdbattery.env
ExecStart=/usr/bin/python3 %h/sdbattery.py
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now sd-battery.service
sudo loginctl enable-linger "$USER" 2>/dev/null || true

echo
echo "Installed. Check it with:"
echo "  systemctl --user status sd-battery.service --no-pager"
echo "In Home Assistant, a 'Steam Deck' device with Battery + Charging should appear."
