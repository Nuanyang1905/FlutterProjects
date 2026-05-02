# State Management

> How state is managed in this project.

---

## Overview

We use **Provider** + **ChangeNotifier** (MVVM pattern) for all state management.

**Dependency**: `provider: ^6.1.1`

### Architecture

```
Service Layer (data/services/)
  ↓
ViewModel Layer (ui/*/view_models/)  extends ChangeNotifier
  ↓
Widget Layer (ui/*/widgets/)  uses Consumer / context.watch / context.read
```

### Rules

1. **Services never depend on ViewModels** — services are stand-alone
2. **ViewModels receive services via constructor injection** (not singletons)
3. **Widgets use `context.watch<ViewModel>()` to subscribe, `context.read<ViewModel>()` for one-shot calls**
4. **Dispose is mandatory**: cancel timers, stream subscriptions, and completers in `dispose()`

## Provider Wiring

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => SettingsViewModel(storageService: ...)),
    ChangeNotifierProvider(create: (_) => WateringViewModel(apiService: ...)),
    ChangeNotifierProvider(create: (_) => MiniArmViewModel(bleService: ..., commandService: ...)),
  ],
  child: const AppShell(),
)
```

ViewModels are created once at app startup and live for the app's lifetime.

## State Categories

| Category | Location | Example |
|----------|----------|---------|
| **Global config** | `SettingsViewModel` (app-level) | API keys, BLE device name |
| **Feature state** | Module-level ViewModel | DeviceState in WateringViewModel |
| **Transient UI** | `StatefulWidget.setState()` | Slider values in ControlScreen |

## Common Mistakes

### Don't: Call notifyListeners() on high-frequency events

```dart
// WRONG — causes full tree rebuild on every BLE command
void onPointerMove(int x, int y, int z) {
  _lastMove = (x, y, z);
  notifyListeners();
}
```

```dart
// RIGHT — inject service reference directly, bypass ViewModel
class DirectionPad extends StatelessWidget {
  void _handleDown(ctx, int x, int y, int z) {
    context.read<MiniArmViewModel>().commandService.sendMoveCmd(...);
  }
}
```

### Don't: Use context.watch() for write-only operations

```dart
// WRONG — subscribes unnecessarily
Widget build(ctx) {
  final vm = context.watch<MiniArmViewModel>();
  return TextButton(onPressed: () => vm.disconnect(), child: ...);
}
```

```dart
// RIGHT — use context.read() for callbacks
Widget build(ctx) {
  return ElevatedButton(
    onPressed: () => context.read<MiniArmViewModel>().disconnect(),
    child: const Text('断开'),
  );
}
```
