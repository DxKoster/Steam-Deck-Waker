# Part 1 — Deck-side `WakeAllowed` persistence (the OS fix)

This is the broadly-useful part: it works for **any** Bluetooth device you use to
wake a Steam Deck (controller, keyboard, phone, or the ESP waker in this repo).

## The problem

A bonded BLE input device can only wake the Deck from suspend if BlueZ's
per-device **`WakeAllowed`** property is `true`. The Steam UI toggle
**Settings → Bluetooth → <device> → "Allow this device to wake Steam Deck"**
sets it — but **SteamOS resets it to `false` on every reboot** and does not
persist it. So wake "works until the next reboot/update," then silently stops.

## The fix

A **user-level** systemd service that re-asserts `WakeAllowed=true` every 30 s.
It runs as the `deck` user (no sudo needed for the `busctl` call), lives in
`/home` so it **survives SteamOS image updates** (anything in `/etc` gets wiped),
and is always armed by the time the Deck suspends — covering reboot *and*
reconnect resets.

## Install (one-time)

1. Enable SSH on the Deck (Desktop Mode → Konsole):
   ```bash
   passwd                                 # set a password for user `deck`
   sudo systemctl enable --now sshd
   ip -4 addr show | grep inet            # note the Deck's IP
   ```
2. Find your waker's Bluetooth MAC:
   ```bash
   bluetoothctl devices                   # or: bluetoothctl info <mac>
   ```
3. Copy `install.sh` to the Deck and run it with that MAC:
   ```bash
   bash install.sh C8:F0:9E:7C:00:6A      # <-- your device's MAC
   ```

Verify:
```bash
systemctl --user status deck-bt-wake.service --no-pager   # active (running)
bluetoothctl info <WAKER_BT_MAC> | grep WakeAllowed       # WakeAllowed: yes
```

The real proof — reboot, wait ~1–2 min, then (without touching any toggle):
```bash
bluetoothctl info <WAKER_BT_MAC> | grep WakeAllowed       # yes, on its own
```

## Manual install (no script)

If you'd rather not run `install.sh`, create the two files by hand — see
[`btwake.sh`](./btwake.sh) and [`deck-bt-wake.service`](./deck-bt-wake.service),
then:
```bash
chmod +x ~/btwake.sh
systemctl --user daemon-reload
systemctl --user enable --now deck-bt-wake.service
sudo loginctl enable-linger "$USER"
```

> **Konsole paste gotcha:** if you create these files by pasting into the
> terminal, Konsole tends to add leading spaces and break long lines / heredocs.
> Prefer `install.sh`, or build files with short `echo '...' >> file` lines so
> any stray indent lands before the command, not inside the file.

## Notes

- Adjust the adapter (`hci0`) in the generated `~/btwake.sh` if `ls
  /sys/class/bluetooth/` shows a different one (the installer auto-detects it).
- A Deck that's fully **powered off** (not suspended) cannot be woken over
  Bluetooth at all — keep it on *sleep*. Letting the battery drain flat forces a
  shutdown.
