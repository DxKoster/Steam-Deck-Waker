# Steam Deck battery → Home Assistant (MQTT)

Report the Deck's battery % and charging state to Home Assistant so you can do
battery-friendly charge control (e.g. only charge while gaming, stop at 80%)
instead of leaving it pinned at 100%.

- **Pure stdlib** — a tiny built-in MQTT publisher, so **no `pip`/extra packages**
  (handy on SteamOS's read-only root).
- **MQTT Discovery** — HA auto-creates a `Steam Deck` device with:
  - `sensor.steamdeck_battery` (device_class battery, %)
  - `binary_sensor.steamdeck_charging` (device_class battery_charging)
- **`expire_after`** marks them *Unavailable* while the Deck is suspended (Wi‑Fi
  is off in sleep, so there are no updates — expected).
- Runs as a **user systemd service** (survives reboots & SteamOS updates, like
  the wake fix).

> Requires the [HA MQTT integration](https://www.home-assistant.io/integrations/mqtt/)
> and a reachable broker. Values only update while the Deck is **awake** — which
> is fine for charge control: "start charging" is driven by your play trigger,
> and "stop at 80%" works because the Deck is awake (and reporting) while it
> charges.

## Install (on the Deck, via SSH)

```bash
curl -fsSL https://raw.githubusercontent.com/DxKoster/Steam-Deck-Waker/main/deck-side/battery/install-battery.sh \
  | SD_MQTT_HOST=10.0.0.21 SD_MQTT_USER=mqtt SD_MQTT_PORT=1883 bash
```

It downloads the reporter, asks for the **MQTT password** (typed once, stored in
`~/.config/sdbattery.env` with `chmod 600`), and installs+starts the service.

Verify:
```bash
systemctl --user status sd-battery.service --no-pager
```
…and a **Steam Deck** device should appear in HA (Settings → Devices).

## Files

- `sdbattery.py` — the reporter (reads sysfs, publishes MQTT discovery + state).
- `install-battery.sh` — sets up the env file + user systemd service.

## Notes

- Broker host is your HA box's **LAN IP** (e.g. `10.0.0.21`) — not
  `core-mosquitto`, which only resolves inside HA's own network.
- Update interval defaults to 60 s (`SD_INTERVAL`).
- Uninstall: `systemctl --user disable --now sd-battery.service` and remove
  `~/sdbattery.py`, `~/.config/sdbattery.env`, and the unit file.
