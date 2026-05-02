# Component Guidelines

> How components are built in this project.

---

## Component Structure

Each widget file follows this pattern:

```dart
class FeatureScreen extends StatefulWidget {
  const FeatureScreen({super.key});

  @override
  State<FeatureScreen> createState() => _FeatureScreenState();
}

class _FeatureScreenState extends State<FeatureScreen> {
  // Private state fields (slider values, etc.)

  @override
  void initState() {
    super.initState();
    // Set up subscriptions if needed
  }

  @override
  Widget build(BuildContext context) {
    // Use Consumer or context.watch to access ViewModel
    return Scaffold(
      // ...
    );
  }

  @override
  void dispose() {
    // Cancel subscriptions
    super.dispose();
  }
}
```

### Rules

- **StatelessWidget** for pure presentation widgets with no mutable state
- **StatefulWidget** when you need `initState`/`dispose` lifecycle or local UI state (e.g., slider values)
- Private nested `_Card()` widgets for internal UI composition (see `watering_home_screen.dart`)

## DirectionPad Pattern (High-Frequency Input)

Widgets that respond to rapid pointer events (like the 8-direction control pad) must **not** trigger ViewModel rebuilds:

```dart
class DirectionPad extends StatefulWidget {
  const DirectionPad({super.key});

  @override
  State<DirectionPad> createState() => _DirectionPadState();
}

class _DirectionPadState extends State<DirectionPad> {
  void _handleDown(int x, int y, int z) {
    // Use context.read() — NOT context.watch()
    // This avoids calling notifyListeners() on every pointer event
    context.read<MiniArmViewModel>().commandService.sendMoveCmd(
      moveX: x, moveY: y, moveZ: z,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _handleDown(0, 1, 0),
      onPointerUp: (_) => _handleDown(0, 0, 0),
      onPointerCancel: (_) => _handleDown(0, 0, 0),
      child: Container(/* styled button */),
    );
  }
}
```

## Card Pattern (Watering Module)

Main screens use a Card-based layout:

```dart
Card(
  elevation: 2,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(/* content */),
  ),
)
```

This matches the Material Design 3 card theme defined in `AppTheme`.

## Theme

- **Material Design 3** with blue seed color (`0xFF2196F3`)
- Background: `0xFFFAFAFA` (light grey-white)
- Card elevation: 2, border-radius: 12px
- Defined in `ui/core/theme.dart`
