#!/bin/bash
# Install a user-level systemd service on a Steam Deck that keeps BlueZ's
# WakeAllowed=true for a given Bluetooth device, so remote wake-from-suspend
# survives reboots and SteamOS image updates.
#
# Usage:  bash install.sh <BT_MAC>
#   e.g.  bash install.sh C8:F0:9E:7C:00:6A
# Find the MAC with:  bluetoothctl devices
set -euo pipefail

MAC="${1:-}"
if [ -z "$MAC" ]; then
  echo "Usage: $0 <BT_MAC>    (find it with: bluetoothctl devices)"
  exit 1
fi

DEVPATH="dev_$(echo "$MAC" | tr 'a-f:' 'A-F_')"
ADAPTER="$(ls /sys/class/bluetooth/ 2>/dev/null | head -1)"
ADAPTER="${ADAPTER:-hci0}"

echo "Device MAC : $MAC"
echo "Adapter    : $ADAPTER"
echo "D-Bus path : /org/bluez/$ADAPTER/$DEVPATH"

mkdir -p "$HOME/.config/systemd/user"

cat > "$HOME/btwake.sh" <<EOF
#!/bin/bash
D=/org/bluez/$ADAPTER/$DEVPATH
while true; do
  busctl set-property org.bluez "\$D" org.bluez.Device1 WakeAllowed b true 2>/dev/null
  sleep 30
done
EOF
chmod +x "$HOME/btwake.sh"

cat > "$HOME/.config/systemd/user/deck-bt-wake.service" <<EOF
[Unit]
Description=Keep BLE device WakeAllowed=true (Steam Deck remote wake)

[Service]
ExecStart=$HOME/btwake.sh
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now deck-bt-wake.service
sudo loginctl enable-linger "$USER"

echo
echo "Installed. Verify with:"
echo "  systemctl --user status deck-bt-wake.service --no-pager"
echo "  bluetoothctl info $MAC | grep WakeAllowed   # expect: yes"
