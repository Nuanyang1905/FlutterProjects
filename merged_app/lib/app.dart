import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ui/core/theme.dart';
import 'ui/watering/widgets/watering_home_screen.dart';
import 'ui/miniarm/widgets/scan_screen.dart';
import 'ui/miniarm/widgets/ble_unsupported_screen.dart';
import 'ui/miniarm/view_models/miniarm_viewmodel.dart';
import 'ui/settings/widgets/settings_screen.dart';

/// 应用主壳
///
/// 底部三 Tab 导航：浇水 / 机械臂 / 设置
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '匠心农场',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            const WateringHomeScreen(),
            Consumer<MiniArmViewModel>(
              builder: (context, vm, child) {
                return vm.bleService.isSupported
                    ? const ScanScreen()
                    : const BleUnsupportedScreen();
              },
            ),
            const SettingsScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.water_drop_outlined),
              selectedIcon: Icon(Icons.water_drop),
              label: '浇水',
            ),
            NavigationDestination(
              icon: Icon(Icons.precision_manufacturing_outlined),
              selectedIcon: Icon(Icons.precision_manufacturing),
              label: '机械臂',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: '设置',
            ),
          ],
        ),
      ),
    );
  }


