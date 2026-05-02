# Research: Flutter Modular Architecture Best Practices

- **Query**: Best practices for Flutter modular architecture in a single-repo project with multiple independent feature modules (BLE robot arm control + smart watering) that share common infrastructure (theme, navigation, settings).
- **Scope**: external + internal
- **Date**: 2026-05-02

## Key Questions Answered

1. Feature-first vs layer-first directory structure
2. Shared code vs feature-specific code organization
3. Shared state management across modules using Provider
4. Platform-specific features (BLE only on mobile) in a modular architecture
5. Module registration/discovery patterns
6. Single package vs monorepo (multiple pubspec.yaml) decision

---

## Findings

### 1. Recommended Directory Structure: Hybrid Approach

Flutter's official documentation (Compass app case study) recommends a **hybrid approach** combining feature-first and layer-first:

```
lib/
  main.dart
  main_development.dart    # separate entry point for dev
  main_staging.dart        # separate entry point for staging

  ui/                      # UI layer — organized BY FEATURE
    core/                  # shared widgets and themes
      ui/
        <shared_widgets>/
      themes/
    <feature_name>/        # each feature = one view + one view model
      view_models/
        <feature>_viewmodel.dart
      widgets/
        <feature>_screen.dart
        <other_widgets>/

  domain/                  # domain models (used by both UI and data layers)
    models/
      <model_name>.dart

  data/                    # data layer — organized BY TYPE
    repositories/
      <repository_class>.dart
    services/
      <service_class>.dart
    models/
      <api_model_class>.dart    # separate from domain models

  config/                  # app configuration
  utils/                   # general utilities
  routing/                 # centralized routing
```

**Key principles:**
- **UI layer**: Organized **by feature** — each feature has exactly one View and one ViewModel, grouped together
- **Data layer**: Organized **by type** — repositories and services are shared across features and view models
- **Domain layer**: Models used by both layers, acts as a bridge

**Source**: [Flutter Architecture Case Study — Package Structure](https://docs.flutter.dev/app-architecture/case-study#package-structure)

### 2. MVVM Architecture Pattern (Official Recommendation)

Flutter strongly recommends the **MVVM (Model-View-ViewModel)** pattern:

| Component | Responsibility | Communication Rules |
|-----------|---------------|---------------------|
| **View** (widgets) | Renders UI, passes user events to ViewModel | Aware of exactly 1 ViewModel; never touches data/repos/services |
| **ViewModel** | Retrieves data, transforms it for display, exposes commands | Aware of 1+ repositories; passed in via constructor |
| **Repository** | Data source abstraction, single source of truth | Aware of 0+ services; used by many ViewModels |
| **Service** | External API / platform integration | Used by many repos; never aware of consumers |

**State management**: Flutter recommends using `ChangeNotifier` + `Listenable` (the Flutter SDK built-in APIs), with `package:provider` for dependency injection. This is what our smart_watering app already uses.

**Source**: [Flutter Architecture Guide — MVVM](https://docs.flutter.dev/app-architecture/guide#mvvm)

### 3. Dependency Injection with Provider (Recommended)

Official recommendation:
- Use `package:provider` for dependency injection
- Services/repos exposed at the top of the widget tree via `MultiProvider`
- ViewModels injected with repos via `context.read<>()` at router/build time
- Repos and services are **private fields** inside their consumers

**Pattern**:
```dart
runApp(
  MultiProvider(
    providers: [
      // Services
      Provider(create: (_) => ApiClient()),
      // Repositories (depend on services)
      Provider(create: (ctx) => AuthRepository(apiClient: ctx.read())),
      // ViewModels can be created at route level
    ],
    child: const MainApp(),
  ),
);
```

**Source**: [Dependency Injection in Flutter Architecture](https://docs.flutter.dev/app-architecture/case-study/dependency-injection)

### 4. Shared State Across Modules

For multiple feature modules sharing state:

**Approach A: Shared Providers at App Level** (Recommended for this project)
- Providers that need cross-module access (theme, settings, user auth) are defined at the `MaterialApp` level
- Feature-specific providers are scoped to their feature's widget subtree
- Modules communicate through their shared providers, NOT directly

**Approach B: Module-specific providers + event bus**
- Each module owns its state independently
- Cross-module communication via an event bus or shared service interfaces
- Better for very large apps with strict module boundaries

**For our use case** (2-3 modules, same developer): Approach A is simpler and sufficient. A `SettingsProvider` at the app level manages global settings (theme, language), while each module has its own `FeatureViewModel` for feature-specific state.

### 5. Platform-Specific Features (BLE) in Modular Architecture

**Strategy for BLE (mobile-only)**:

1. **Abstract the service**: Define a `BleServiceInterface` that exposes BLE operations
2. **Platform-conditional instantiation**: Use `dart:io` `Platform` to decide which implementation to inject:
   ```dart
   Provider<BleServiceInterface>(
     create: (_) {
       if (Platform.isAndroid || Platform.isIOS) {
         return MobileBleService();
       } else {
         return NoopBleService(); // returns "not supported" state
       }
     },
   )
   ```
3. **UI guard**: BLE feature screens can check `kIsWeb` or `Platform` to show a notice on unsupported platforms
4. **Module-level independence**: The miniarm module's ViewModel depends on the `BleServiceInterface`, not the concrete implementation

**Source**: [Flutter Platform Integration docs](https://docs.flutter.dev/platform-integration/platform-channels)

### 6. Single Package vs Monorepo Decision

| Approach | Pros | Cons | Recommendation |
|----------|------|------|----------------|
| **Single package** (one pubspec.yaml) | Simple, fast builds, shared deps | Less strict module boundaries, harder to enforce separation | **Recommended for this project** |
| **Monorepo with packages** (multiple pubspec.yaml) | Strict module boundaries, can version separately | Complex build, dependency management overhead | For large teams / truly independent modules |

**Decision: Single package with directory conventions.**

For a project of this size (2 feature modules, 1 developer), monorepo splitting adds more complexity than value. The hybrid directory structure (feature-first for UI, type-first for data) provides sufficient separation without the overhead of multiple Dart packages.

### 7. Module Registration / Discovery Patterns

For future extensibility:

**Simple approach (sufficient for now)**:
- Central `app_routes.dart` that registers all feature modules' routes
- Central `app_providers.dart` that registers all shared providers
- Each module exports a `routes` list and a `providers` list

**Advanced approach (future consideration)**:
- A `ModuleRegistry` that modules register themselves with at app startup
- Each module implements a `FeatureModule` interface:
  ```dart
  abstract class FeatureModule {
    String get name;
    List<GoRoute> get routes;
    List<Provider> get providers;
    Future<void> initialize();
  }
  ```
- Not needed now; add when you have 5+ modules

### 8. Analysis of Existing Apps' Structures

#### miniarm_flutter (`lib/`):
```
lib/
  main.dart
  page/               # screens (scan_page, control_page, move_page)
  widget/             # reusable widgets (direction_pad)
  service/            # BLE + command services
  model/              # data models
```
- **Layer-first** organization (page/widget/service/model)
- No state management library (uses raw StatefulWidget + Stream subscriptions)
- No DI pattern (singleton BleService.instance)
- BLE dependency: `flutter_blue_plus`, `permission_handler`

#### smart_watering (`lib/`):
```
lib/
  main.dart
  config/             # app config
  models/             # data models
  services/           # API + storage services
  providers/          # Provider ChangeNotifiers
  screens/            # UI screens
```
- Also **layer-first** organization
- Uses `provider` + `ChangeNotifier` (already following Flutter's recommended pattern)
- Good DI pattern: services injected into providers via constructors
- Dependencies: `provider`, `shared_preferences`, `http`

**Both apps** currently use layer-first with independently named directories (`page/` vs `screens/`, `service/` vs `services/`). Migration to a unified structure will need directory renaming and consolidation.

### 9. Proposed Target Directory Structure

For the merged app:

```
merged_app/
  lib/
    main.dart
    app.dart                    # MaterialApp + MultiProvider setup
    
    ui/
      core/                     # shared widgets, theme
        themes/
        widgets/                # common: app_icon, loading_indicator, etc.
      home/                     # home screen (module selector)
        view_models/
          home_viewmodel.dart
        widgets/
          home_screen.dart
      miniarm/                  # BLE robot arm feature
        view_models/
          miniarm_viewmodel.dart
        widgets/
          scan_screen.dart
          control_screen.dart
          direction_pad.dart
      watering/                 # smart watering feature
        view_models/
          watering_viewmodel.dart
        widgets/
          watering_home_screen.dart
          settings_screen.dart
      settings/                 # shared app settings
        view_models/
          settings_viewmodel.dart
        widgets/
          app_settings_screen.dart
    
    domain/
      models/
        device_state.dart       # watering model
        ble_device.dart         # BLE model
        arm_state.dart          # robot arm model
    
    data/
      repositories/
        watering_repository.dart
        ble_repository.dart
      services/
        bemfa_api_service.dart  # watering backend
        ble_service.dart        # BLE communication
        command_service.dart    # arm commands
        storage_service.dart    # shared preferences
    
    config/
      app_config.dart
      theme_config.dart
    
    routing/
      app_router.dart
```

### 10. Key Migration Steps

1. Create the unified `pubspec.yaml` combining all dependencies (provider, shared_preferences, http, flutter_blue_plus, permission_handler)
2. Create the shared `app.dart` with `MultiProvider` setup
3. Convert miniarm's `BleService.instance` singleton to DI-injected service
4. Convert miniarm's `CommandService` to use the injected BleService
5. Reorganize files into the hybrid structure
6. Create a home screen that navigates to either module
7. Add go_router for centralized navigation (optional but recommended)

---

## External References

- [Flutter App Architecture Guide](https://docs.flutter.dev/app-architecture/guide) — Official MVVM recommendation, layer structure
- [Flutter Architecture Case Study (Compass App)](https://docs.flutter.dev/app-architecture/case-study) — Package structure, DI with provider, testing
- [Flutter Architecture Recommendations](https://docs.flutter.dev/app-architecture/recommendations) — Prioritized best practices (strongly recommend / recommend / conditional)
- [Dependency Injection in Flutter](https://docs.flutter.dev/app-architecture/case-study/dependency-injection) — How to wire services→repos→viewmodels with provider
- [Simple App State Management](https://docs.flutter.dev/data-and-backend/state-mgmt/simple) — Provider + ChangeNotifier pattern (what smart_watering already uses)
- [Flutter Platform Integration](https://docs.flutter.dev/platform-integration/platform-channels) — Platform-specific code patterns
- [Compass App on GitHub](https://github.com/flutter/samples/tree/main/compass_app) — Real-world Flutter app using the recommended architecture

---

## Caveats / Not Found

- **go_router vs Navigator 2.0**: The official docs recommend go_router for 90% of apps. For a 2-module app, either go_router or the built-in Navigator API works. go_router is more future-proof but adds a dependency.
- **Module isolation enforcement**: Without Dart package boundaries, module isolation is by convention (import discipline). For a solo dev project, this is fine. If a team grows, consider extracting to packages later.
- **Deferred loading**: Flutter supports deferred components for code splitting, but it's complex and not worth it for 2 modules. Consider if the app grows to 5+ heavy modules.
