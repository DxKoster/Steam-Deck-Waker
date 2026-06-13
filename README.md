# Steam Deck BLE Waker — remote wake-from-suspend over Bluetooth

Wake a **Steam Deck from suspend** with a network/Home Assistant trigger — using
an **ESP32 that pretends to be a Bluetooth keyboard**, plus the one OS-side fix
nobody documents: keeping BlueZ's **`WakeAllowed`** flag armed across reboots.

> Built for a Steam Deck that lives in a different room from the TV it drives
> (tidy, quiet, out of sight), woken from a Home Assistant dashboard / when the
> TV switches to its input. But the **`WakeAllowed` fix (Part 1) applies to *any*
> BLE device** you use to wake a Deck — controller, keyboard, phone, ESP — so
> even if you skip the ESP, that part may be what you came for.

---

## Why this is hard (and why the usual answers don't work)

- **Wi‑Fi sleeps in suspend.** The Deck powers down its Wi‑Fi radio while
  suspended, so a network wake over Wi‑Fi never reaches it. (Wake‑on‑LAN over
  the official dock's wired Ethernet can work for some setups — it didn't in
  this one — and this approach doesn't rely on it.)
- The Deck **keeps Bluetooth alive in suspend** — that's how a paired
  controller/keyboard wakes it. So the waker is a BLE **HID keyboard** that
  "knocks" on the Deck.
- **The hidden gotcha:** even with a perfectly bonded BLE keyboard, the Deck
  **ignores the wake** unless its per-device **`WakeAllowed`** flag is `true` —
  and SteamOS **resets that flag to `false` on every reboot** and doesn't
  persist it. This is why so many people get it "working" once, then it silently
  dies after a SteamOS update. **Part 1 fixes exactly that.**

---

## What's in here

| Folder | What |
|---|---|
| [`deck-side/`](./deck-side) | **Part 1 — the OS fix.** A tiny user systemd service that re-asserts `WakeAllowed=true` every 30 s, surviving reboots **and** SteamOS image updates. The high-value, broadly-useful part. |
| [`esphome/`](./esphome) | **Part 2 — the wake device.** ESPHome config for an ESP32 BLE-keyboard waker, using a patched native-NimBLE component that fires **high-duty *directed* advertising** (the "knock" a sleeping host actually listens for). |
| [`homeassistant/`](./homeassistant) | **Part 3 — the trigger (optional).** Example HA script (multi-try wake with early-exit) and an automation that wakes the Deck when a TV input is selected. |

---

## Quick start

1. **Build the waker** (`esphome/`): flash an ESP32 with the config, pair it to
   the Deck once as a Bluetooth keyboard. See [`esphome/`](./esphome).
2. **Arm the wake permission** (`deck-side/`): on the Deck, run the installer
   with your waker's Bluetooth MAC:
   ```bash
   ssh deck@<deck-ip>
   curl -fsSL .../deck-side/install.sh -o install.sh   # or scp it over
   bash install.sh <WAKER_BT_MAC>                       # e.g. C8:F0:9E:7C:00:6A
   ```
   This is the step that makes wake **stick across reboots**.
3. **Trigger it** (`homeassistant/`, optional): import the script/automation, or
   just press the ESP's `Wake` button entity.

Verify any time, on the Deck:
```bash
bluetoothctl info <WAKER_BT_MAC> | grep WakeAllowed   # want: yes
```

---

## The `WakeAllowed` discovery (the part that took the longest)

Symptoms looked like flaky RF or a bad bond: it worked sometimes, then a
suspended Deck wouldn't wake. All red herrings. The waker and Deck were 20–30 cm
apart, line-of-sight. The real cause:

```
Device XX:XX:XX:XX:XX:XX (Steam Deck Waker)
    Trusted:     yes
    Connected:   yes
    WakeAllowed: no      <-- the Deck silently ignores the wake knock
```

The Steam UI toggle **Settings → Bluetooth → <device> → "Allow this device to
wake Steam Deck"** sets BlueZ's `WakeAllowed` property. SteamOS **does not
persist it** (there's no `/var/lib/bluetooth/<adapter>/<mac>/info` entry for it),
so every reboot/update silently flips it back to `no`. Set it `true` and the
Deck wakes in ~9 s. `deck-side/` keeps it `true` forever.

---

## Heads-up & support (or lack of it 🙂)

Shared as-is, in the hope it saves someone the days it cost me to figure out —
not as a polished product. Everything here pokes at system-level bits (your
Deck's Bluetooth wake permissions, a systemd service) and custom ESP firmware,
so please understand each step before you run it and keep your own backups.

**Use it entirely at your own risk.** I can't take responsibility for anything
that happens to your Deck, ESP, or setup, and I'm not able to offer support or
troubleshoot individual configurations — think of this as "here's exactly what
worked for me, you're on your own from here," and that's perfectly fine. Bug
reports and PRs with fixes are genuinely welcome, but with no promise of a reply
or a merge. (The MIT license below says the same thing formally: no warranty.)

## Credits & license

- The `esphome/components/ble_keyboard` component is a patched fork of
  [**adesanto84/esphome-blekeyboard**](https://github.com/adesanto84/esphome-blekeyboard)
  (ESP‑IDF native NimBLE), itself a fork of
  [**dmamontov/esphome-blekeyboard**](https://github.com/dmamontov). **MIT.**
- The added bit is the **directed‑advertising wake** patch in
  `esp_hid_gap.c` (`esp_hid_ble_gap_adv_start_directed`) and the `WakeAllowed`
  persistence approach.

MIT — see [LICENSE](./LICENSE). Original component copyrights retained.

> Not affiliated with Valve. "Steam Deck" is a trademark of Valve Corporation.
