# Smart Watering Protocol v2

## Topic Direction

- Status topic: `plant001`
- Control topic: `plant001/set`

Direction is important:

- Device publishes status to `plant001`
- Flutter App subscribes to `plant001`
- Flutter App publishes commands to `plant001/set`
- ESP8266 subscribes to `plant001/set`

This fixes the old topic inversion bug where status and control were reversed.

## Device Status Payload

Recommended JSON published by the device:

```json
{
  "ver": 2,
  "type": "status",
  "hum": 45,
  "raw": 678,
  "pump": 0,
  "mode": "auto",
  "th_low": 30,
  "th_high": 60,
  "lock": 0,
  "sensor_ok": 1
}
```

Field rules:

- `ver`: fixed `2`
- `type`: fixed `status`
- `hum`: `0-100`
- `raw`: ADC raw value
- `pump`: `1` on, `0` off
- `mode`: `auto` or `manual`
- `th_low`: lower threshold
- `th_high`: upper threshold
- `lock`: protection lock, `1` locked
- `sensor_ok`: sensor health, `1` normal

When the sensor is abnormal, the firmware keeps `hum` at `0` and sets `sensor_ok` to `0`.

## App Command Payload

Recommended JSON commands published by the App:

```json
{"cmd":"pump","value":"on"}
{"cmd":"pump","value":"off"}
{"cmd":"mode","value":"auto"}
{"cmd":"mode","value":"manual"}
{"cmd":"threshold","low":30,"high":60}
{"cmd":"threshold","value":40}
{"cmd":"unlock"}
```

Command rules:

- Pump command changes pump target in manual mode
- Mode command only changes mode
- `unlock` only clears the protection lock
- Lock and mode are independent and are no longer mixed

## Legacy Compatibility

The new firmware still accepts these text commands:

- `on`
- `off`
- `auto`
- `manual`
- `set:30,60`
- `t:40`
- `unlock`
- `cmd:pump_on`
- `cmd:pump_off`
- `cmd:pump_auto`
- `cmd:set:30,60`
- `cmd:t:40`

The Flutter App now sends JSON by default, but the device side remains backward compatible.

## Serial Bridge Behavior

The ESP8266 normalizes MQTT commands before forwarding them to Arduino:

- JSON `{"cmd":"pump","value":"on"}` -> serial `on`
- JSON `{"cmd":"mode","value":"manual"}` -> serial `manual`
- JSON `{"cmd":"threshold","low":30,"high":60}` -> serial `set:30,60`
- JSON `{"cmd":"unlock"}` -> serial `unlock`

Arduino also accepts JSON directly, so future bridge changes do not require a protocol rewrite.

## Control Logic

- Auto mode uses hysteresis
- `hum < th_low` -> pump on
- `hum > th_high` -> pump off
- Middle band keeps the current pump state
- Sensor abnormal -> auto mode cannot start the pump
- Manual mode times out after 12 hours and returns to auto
- Pump timeout triggers `lock=1`
- `unlock` must be sent explicitly to clear the lock

## Flutter Integration

App-side implementation now lives in these files:

- `lib/models/device_state.dart`
- `lib/services/mqtt_service.dart`
- `lib/providers/device_provider.dart`
- `lib/screens/home_screen.dart`

Behavior:

- Status parsing supports protocol v2 JSON, old JSON, and legacy `#...` payloads
- Commands are sent as JSON v2
- UI shows sensor abnormal state and protection lock separately
- Unlock button is available when `lock=1`

## Fixed Bugs

- Fixed MQTT topic direction: device now publishes to `topic` and subscribes to `topic/set`
- Fixed old App command model that used text only and mixed mode switching with pump switching
- Fixed lock/mode coupling: mode changes no longer implicitly clear the protection lock
- Fixed duplicate reconnect risk on Flutter by removing client auto-reconnect and keeping one app-level reconnect policy
- Fixed repeated MQTT update listeners on reconnect in Flutter

## Stability Improvements

- Removed `String` from Arduino and ESP8266 command handling
- Switched both firmwares to fixed-size line buffers
- Kept all periodic work non-blocking
- Added EEPROM config validation with checksum on Arduino
- Added sensor fault debouncing on Arduino
- Kept bridge UART traffic line-based and compact
- Added optimistic threshold refresh on Flutter so UI does not wait for the next status frame
