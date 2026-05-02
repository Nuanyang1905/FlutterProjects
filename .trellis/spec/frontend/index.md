# Frontend Development Guidelines

> Best practices for frontend development in this project.

---

## Overview

This directory contains guidelines for frontend development in the 匠心农场 (smart_watering) merged Flutter application.

Architecture: **MVVM with Provider + ChangeNotifier**
Directory pattern: **Hybrid (UI by feature, data by type)**

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Directory Structure](./directory-structure.md) | Module organization and file layout | ✅ Filled |
| [Component Guidelines](./component-guidelines.md) | Component patterns, DirectionPad performance | ✅ Filled |
| [State Management](./state-management.md) | Provider MVVM, DI chain, debounce, dispose | ✅ Filled |
| [Quality Guidelines](./quality-guidelines.md) | BLE degradation, forbidden patterns, code review checklist | ✅ Filled |

---

## Key Conventions

- **Provider DI chain**: Services → ViewModels (constructor injection) → Widgets (context.watch/read)
- **BLE cross-platform**: Abstract `BleServiceInterface` with platform-conditional instantiation
- **High-frequency input**: Bypass ViewModel.notifyListeners() — inject service directly
- **Watering debounce**: Threshold 500ms, config save 800ms
- **Command echo protection**: 3s grace window after sending commands

---

## How to Add a New Module

1. Create `ui/<module>/view_models/<module>_viewmodel.dart` (ChangeNotifier)
2. Create `ui/<module>/widgets/` for screens
3. Wire the ViewModel into `MultiProvider` in `main.dart`
4. Add tab destination in `app.dart` if needed
