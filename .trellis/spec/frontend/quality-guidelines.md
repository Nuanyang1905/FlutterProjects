# Quality Guidelines

> Code quality standards for frontend development.

---

## Required Patterns

### 1. BLE Platform Degradation

BLE features must gracefully degrade on unsupported platforms. The pattern:

```dart
// Abstract interface
abstract class BleServiceInterface {
  bool get isSupported;
  Stream<BleConnectionState> get connectionStateStream;
  Stream<List<BleDeviceModel>> scan();
  void sendCommand(List<int> bytes);
  // ...
}

// Mobile implementation (Android/iOS/macOS/Linux)
class BleService implements BleServiceInterface {
  bool get isSupported => true;
  // ... real BLE implementation (flutter_blue_plus)
}

// Fallback (Web/Windows)
class NoopBleService implements BleServiceInterface {
  bool get isSupported => false;
  Stream<List<BleDeviceModel>> scan() => const Stream.empty();
  void sendCommand(List<int> bytes) {}
  // ... no-op implementations
}
```

Platform selection in `main.dart`:
```dart
if (kIsWeb) {
  bleService = NoopBleService();
} else if (Platform.isWindows) {
  bleService = NoopBleService();
} else {
  bleService = BleService();
}
```

### 2. DirectionPad Performance

For widgets with high-frequency user input (pointer events at ≥ 50 events/sec):
- **DO NOT** route through ViewModel's `notifyListeners()`
- **DO** inject the service reference directly
- Use `context.read()` (not `context.watch()`) in event handlers

### 3. Watering Command Echo Protection

After sending a command, ignore polled state for 3 seconds to prevent the stale server state from reverting the optimistic UI:
```dart
var _pendingPumpState: bool?;
var _pendingPumpStateUntil: DateTime?;

DeviceState _mergeIncomingState(DeviceState incoming) {
  if (_pendingPumpState != null && DateTime.now.isBefore(_pendingPumpStateUntil)) {
    return incoming.copyWith(isPumpOn: _pendingPumpState);
  }
  return incoming;
}
```

### 4. Debounce Thresholds

| Operation | Delay | Implementation |
|-----------|-------|----------------|
| Threshold slider change | 500ms | Timer in ViewModel |
| Config save | 800ms | Timer in SettingsViewModel |

### 5. dispose() Hygiene

Every ViewModel must clean up in `dispose()`:
```dart
@override
void dispose() {
  _pollTimer?.cancel();
  _debounceTimer?.cancel();
  _thresholdTimer?.cancel();
  if (_completer != null && !_completer!.isCompleted) {
    _completer!.complete(false);
  }
  _logSubscription?.cancel();
  super.dispose();
}
```

## Forbidden Patterns

- **Singleton BleService** (`BleService.instance`) — use constructor injection
- **Static CommandService** — use instance methods with injected BleServiceInterface
- **notifyListeners() in pointer event handlers** — causes tree rebuilds at 50Hz
- **context.watch() for call-only operations** — use context.read()

## Testing Requirements

- Unit tests for `DeviceState.parse()` with all 3 data formats
- Unit tests for WateringViewModel debounce logic
- Unit tests for MiniArmViewModel connection state management
- Widget tests for DirectionPad pointer event handling

## Code Review Checklist

- [ ] All ViewModel `dispose()` methods clean up timers + subscriptions
- [ ] No `notifyListeners()` in high-frequency call paths
- [ ] BLE platform degradation correctly implemented
- [ ] `context.read()` used for callbacks, `context.watch()` for reactive state
- [ ] Debounce timers don't leak (cancelled on new call + on dispose)
