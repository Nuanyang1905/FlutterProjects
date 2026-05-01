import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_watering/providers/device_provider.dart';
import 'package:smart_watering/providers/settings_provider.dart';
import 'package:smart_watering/screens/settings_screen.dart';

import 'test_support/fake_bemfa_api_service.dart';

void main() {
  testWidgets('shows bemfa api configuration fields', (tester) async {
    final settingsProvider = SettingsProvider();
    final deviceProvider = DeviceProvider(
      apiService: FakeBemfaApiService(),
      pollInterval: const Duration(days: 1),
    );
    addTearDown(settingsProvider.dispose);
    addTearDown(deviceProvider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(
            value: settingsProvider,
          ),
          ChangeNotifierProvider<DeviceProvider>.value(value: deviceProvider),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    expect(find.text('UID (私钥)'), findsOneWidget);
    expect(find.text('控制主题'), findsOneWidget);
    expect(find.text('上报主题'), findsOneWidget);
    expect(find.text('设备类型 (Type)'), findsOneWidget);
  });
}
