#!/usr/bin/env python3
"""
Steam Deck -> Home Assistant battery reporter (pure stdlib, no pip needed).

Reads the Deck's battery % and charging status from sysfs and publishes them to
an MQTT broker using Home Assistant MQTT Discovery, so HA auto-creates:
  - sensor.steamdeck_battery        (device_class: battery, %)
  - binary_sensor.steamdeck_charging (device_class: battery_charging)
under a "Steam Deck" device. `expire_after` makes them go Unavailable while the
Deck is suspended (Wi-Fi off = no updates).

Config via environment (see ~/.config/sdbattery.env, loaded by the systemd unit):
  SD_MQTT_HOST, SD_MQTT_PORT, SD_MQTT_USER, SD_MQTT_PASS, SD_INTERVAL (seconds)
"""
import os, sys, time, glob, json, socket

HOST = os.environ.get("SD_MQTT_HOST", "127.0.0.1")
PORT = int(os.environ.get("SD_MQTT_PORT", "1883"))
USER = os.environ.get("SD_MQTT_USER", "")
PASS = os.environ.get("SD_MQTT_PASS", "")
INTERVAL = int(os.environ.get("SD_INTERVAL", "60"))
EXPIRE = INTERVAL * 3 + 60  # mark Unavailable if no update for ~3 cycles

DEV = {"identifiers": ["steamdeck"], "name": "Steam Deck", "manufacturer": "Valve"}
DISCOVERY = [
    ("homeassistant/sensor/steamdeck_battery/config", json.dumps({
        "name": "Battery", "unique_id": "steamdeck_battery",
        "state_topic": "steamdeck/battery", "unit_of_measurement": "%",
        "device_class": "battery", "state_class": "measurement",
        "expire_after": EXPIRE, "device": DEV})),
    ("homeassistant/binary_sensor/steamdeck_charging/config", json.dumps({
        "name": "Charging", "unique_id": "steamdeck_charging",
        "state_topic": "steamdeck/charging", "device_class": "battery_charging",
        "payload_on": "ON", "payload_off": "OFF",
        "expire_after": EXPIRE, "device": DEV})),
]


def read_battery():
    for d in glob.glob("/sys/class/power_supply/*"):
        try:
            if open(d + "/type").read().strip() != "Battery":
                continue
            cap = int(open(d + "/capacity").read().strip())
            status = open(d + "/status").read().strip()
            return cap, status
        except Exception:
            continue
    return None, None


# --- minimal MQTT 3.1.1 publisher (QoS 0) ----------------------------------
def _rl(n):
    out = bytearray()
    while True:
        b = n % 128
        n //= 128
        if n:
            b |= 0x80
        out.append(b)
        if not n:
            return bytes(out)


def _s(t):
    b = t.encode()
    return len(b).to_bytes(2, "big") + b


def mqtt_publish(msgs):
    """msgs: list of (topic, payload). All published retained, QoS 0."""
    sock = socket.create_connection((HOST, PORT), timeout=10)
    try:
        flags = 0x02  # clean session
        payload = _s("sdbattery")
        if USER:
            flags |= 0x80
            payload += _s(USER)
        if PASS:
            flags |= 0x40
            payload += _s(PASS)
        vh = _s("MQTT") + bytes([0x04, flags]) + (60).to_bytes(2, "big")
        sock.sendall(bytes([0x10]) + _rl(len(vh) + len(payload)) + vh + payload)
        sock.recv(4)  # CONNACK
        for topic, pl in msgs:
            plb = pl.encode()
            vh = _s(topic)
            sock.sendall(bytes([0x31]) + _rl(len(vh) + len(plb)) + vh + plb)  # PUBLISH retain
        sock.sendall(bytes([0xE0, 0x00]))  # DISCONNECT
    finally:
        sock.close()


def report():
    cap, status = read_battery()
    if cap is None:
        return
    charging = "ON" if status in ("Charging", "Full") else "OFF"
    mqtt_publish(DISCOVERY + [
        ("steamdeck/battery", str(cap)),
        ("steamdeck/charging", charging),
    ])


def main():
    while True:
        try:
            report()
        except Exception as e:
            print(f"sdbattery: {e}", file=sys.stderr)
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
