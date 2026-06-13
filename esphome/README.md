# Part 2 — the ESP32 BLE-keyboard waker

An ESP32 flashed as a Bluetooth HID keyboard, bonded to the Deck. Its `Wake`
button fires a **high-duty directed advertising** "knock" that a *suspended*
Deck listens for, then sends a keypress to bring it up.

## Files

- `steamdeck-waker.yaml` — the ESPHome config (edit substitutions/board as needed).
- `secrets.yaml.example` — copy to `secrets.yaml`, fill in Wi‑Fi/OTA/API.
- `components/ble_keyboard/` — the patched native-NimBLE BLE-keyboard component.
- `upstream-examples/` — the original component's example configs (reference).

## The patch

Upstream emulates a BLE keyboard but only does normal (undirected) advertising.
A *sleeping* host won't scan for that. The patch in
`components/ble_keyboard/esp_hid_gap.c` adds
`esp_hid_ble_gap_adv_start_directed()`: on the wake button it stops advertising
and restarts as **`ADV_DIRECT_IND`** aimed at the **bonded peer's identity
address** (`ble_store_util_bonded_peers`), high duty cycle. That's the same
"knock" a real keyboard sends on keypress, and it's what wakes the Deck. Normal
reconnect stays undirected so the Deck can still suspend.

## Build & flash

Use the ESPHome dashboard (or CLI):

```bash
esphome run steamdeck-waker.yaml      # first flash over USB; OTA after that
```

Notes:
- `framework: esp-idf` is required (Arduino framework is not supported by the
  component). The config pins ESP‑IDF 5.5.4 / pioarduino 55.03.38-1 for a
  reproducible BLE stack — delete those two lines to use your defaults.
- Classic ESP32 (WROOM) board shown; the upstream component also supports
  ESP32‑C3/C6/H2 (see `upstream-examples/`).

## Pair to the Deck (once)

1. On the Deck: Settings → Bluetooth → pair **"Steam Deck Waker"** (it advertises
   as a keyboard).
2. Then arm wake permission — **this is required** — see [`../deck-side/`](../deck-side).
   Without `WakeAllowed=true`, the Deck bonds fine but ignores the wake knock.

## Re-pairing / bond issues

If you see a rapid connect/disconnect loop (`reason=517` = one-sided bond):
`esptool erase-flash` the ESP, "Forget" the device on the Deck, then pair fresh.

## Find the device's Bluetooth MAC

You'll need it for the deck-side installer:
```bash
bluetoothctl devices        # on the Deck, after pairing
```
(Note: an ESP32's BT MAC is typically the base/Wi‑Fi MAC + 2.)
