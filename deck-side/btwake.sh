#!/bin/bash
# Keep BlueZ's WakeAllowed=true for the waker device so the Steam Deck will
# wake from suspend on its BLE "knock". SteamOS resets this flag on every
# reboot, so we re-assert it every 30 s. Runs as the `deck` user (no sudo).
#
# Replace the MAC below with your device's Bluetooth MAC (colons -> underscores),
# and the adapter (hci0) if `ls /sys/class/bluetooth/` shows a different one.
# Tip: install.sh generates this file for you with the right values.

D=/org/bluez/hci0/dev_C8_F0_9E_7C_00_6A

while true; do
  busctl set-property org.bluez "$D" org.bluez.Device1 WakeAllowed b true 2>/dev/null
  sleep 30
done
