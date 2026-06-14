# Part 3 — Home Assistant trigger (optional)

Optional glue if you drive the waker from Home Assistant. Both files are
templates — adjust the entity IDs to match your setup.

- `wake_steam_deck.script.yaml` — a script that fires the ESP `Wake` button up to
  5×, knocking **only while the link is down** and treating success as the BLE
  link **staying** connected for ≥5 s (a real resume), not a bare connect edge.
  A marginal link can connect for a couple of seconds *without* waking the host,
  so stopping on the first connect gives false successes — this waits for a stable
  link and retries otherwise. Point your dashboard buttons at
  `script.wake_steam_deck` instead of the raw button so they all retry.
- `wake_on_tv_input.automation.yaml` — example: wake the Deck when a TV switches
  to its HDMI input. Read the comments — there are two non-obvious gotchas
  (which TV entity actually reports the input, and gating on the BLE sensor
  rather than a wattage proxy).

## Entities you'll reference

The ESP (Part 2) exposes these to HA via the ESPHome/native API:

| Entity (default-ish) | What |
|---|---|
| `button.steam_deck_waker_wake_steam_deck` | fire one wake knock |
| `binary_sensor.steam_deck_waker_connected` | BLE link up (on) / down=asleep (off) |

Exact entity IDs depend on your device name/area — check Developer Tools →
States and adjust the YAML accordingly.

## Reminder

None of this matters unless the Deck-side `WakeAllowed` service (Part 1) is
installed — otherwise the Deck bonds and accepts knocks but refuses to wake.
