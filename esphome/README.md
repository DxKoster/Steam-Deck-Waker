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
- ⚠️ **Re-flashing can drop the BLE bond — re-pair afterwards.** A re-flash
  *usually* keeps the bond (it lives in NVS, which flashing doesn't erase), but not
  always: sometimes the Deck ends up with a **one-sided bond** (`reason=517`) where
  the ESP flaps connect/disconnect — and those reconnect storms can even **wake the
  Deck by themselves**. After every re-flash, do a quick wake test; if it flaps or
  the waker vanishes from the Deck's Bluetooth list, re-pair (next section).

## Pair to the Deck (once)

1. On the Deck: Settings → Bluetooth → pair **"Steam Deck Waker"** (it advertises
   as a keyboard).
2. Then arm wake permission — **this is required** — see [`../deck-side/`](../deck-side).
   Without `WakeAllowed=true`, the Deck bonds fine but ignores the wake knock.

## Re-pairing / bond issues

A **one-sided bond** (`reason=517`) shows up as a rapid connect/disconnect loop: the
ESP keeps reconnecting, the waker **disappears from the Deck's Bluetooth list**, the
deck-side keep-alive logs *"Failed to set property WakeAllowed … doesn't exist"*, and
the reconnect storms can **spuriously wake the Deck**. **Re-flashing the ESP is the
most common trigger** (the bond usually survives a flash — but not always). Fix:

1. On the Deck: Settings → Bluetooth → **Forget** "Steam Deck Waker"
   (or `bluetoothctl remove <WAKER_BT_MAC>`).
2. `esptool erase-flash` the ESP to clear its stored bond.
3. Pair fresh (the Deck re-discovers it as a keyboard), then confirm `WakeAllowed`
   is back on — the deck-side keep-alive re-asserts it within ~30 s.

## Find the device's Bluetooth MAC

You'll need it for the deck-side installer:
```bash
bluetoothctl devices        # on the Deck, after pairing
```
(Note: an ESP32's BT MAC is typically the base/Wi‑Fi MAC + 2.)
