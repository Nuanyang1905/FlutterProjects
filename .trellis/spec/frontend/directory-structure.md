# Directory Structure

> How frontend code is organized in this project.

---

## Overview

This project uses a **hybrid directory structure**: UI code organized **by feature**, data code organized **by type**.

```
lib/
  main.dart                     # Entry point + MultiProvider setup
  app.dart                      # MaterialApp + scaffold + navigation

  ui/                           # UI layer — organized BY FEATURE
    core/                       # Shared widgets and themes
      theme.dart                # M3 theme definition
    watering/                   # Module: smart watering
      view_models/              # WateringViewModel (ChangeNotifier)
      widgets/                  # WateringHomeScreen
    miniarm/                    # Module: BLE robot arm
      view_models/              # MiniArmViewModel (ChangeNotifier)
      widgets/                  # ScanScreen, ControlScreen, DirectionPad
    settings/                   # Module: unified settings
      view_models/              # SettingsViewModel (ChangeNotifier)
      widgets/                  # SettingsScreen

  domain/                       # Domain models (used by both layers)
    models/
      device_state.dart         # Watering data model
      app_config.dart           # App configuration model
      ble_device_model.dart     # BLE device model
      device_state_model.dart   # BLE connection state enum

  data/                         # Data layer — organized BY TYPE
    services/
      interfaces/               # Abstract service interfaces (e.g. BleServiceInterface)
      bemfa_api_service.dart    # Watering HTTP backend
      ble_service.dart          # BLE mobile implementation
      noop_ble_service.dart     # BLE fallback for unsupported platforms
      command_service.dart      # Robot arm command builder
      storage_service.dart      # SharedPreferences wrapper

  routing/
    app_router.dart             # Route definitions (placeholder)
```

## Module Organization

Each feature module (`ui/<module>/`) contains exactly:

| Directory | Contents | Purpose |
|-----------|----------|---------|
| `view_models/` | One `ChangeNotifier` subclass per module | State + business logic |
| `widgets/` | One or more `Widget` files | Pure UI, no direct service access |

## Key Rules

1. **Widgets never access services directly** — only through their ViewModel
2. **ViewModels never access UI** — they expose state via `notifyListeners()`
3. **Services are stateless or state-per-call** — no global singletons (exceptions: StorageService, BleService)
4. **New module = new directory under `ui/`** — follow the existing pattern

## Platforms

- Android/iOS: Full BLE support
- macOS/Linux: BLE supported (some MTU limitations)
- Web/Windows: BLE not supported → `NoopBleService` + `BleUnsupportedScreen`
