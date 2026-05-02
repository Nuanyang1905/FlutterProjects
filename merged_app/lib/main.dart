import 'package:flutter/foundation.dart';
import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/services/bemfa_api_service.dart';
import 'data/services/storage_service.dart';
import 'data/services/ble_service.dart';
import 'data/services/noop_ble_service.dart';
import 'data/services/command_service.dart';
import 'data/services/interfaces/ble_service_interface.dart';
import 'domain/models/app_config.dart';
import 'ui/settings/view_models/settings_viewmodel.dart';
import 'ui/watering/view_models/watering_viewmodel.dart';
import 'ui/miniarm/view_models/miniarm_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 初始化配置
  final settingsViewModel = SettingsViewModel(storageService: StorageService());
  await settingsViewModel.init();

  // 2. 创建浇水 API 服务
  final apiService = BemfaApiService(config: settingsViewModel.config);

  // 3. 创建浇水 ViewModel
  final wateringViewModel = WateringViewModel(apiService: apiService);

  // 4. 设置配置变更 → 更新 API 配置
  settingsViewModel.addConfigChangeListener((newConfig) {
    wateringViewModel.updateApiConfig(newConfig);
  });

  // 5. 创建 BLE 服务 (平台自适应)
  late BleServiceInterface bleService;

  try {
    if (kIsWeb) {
      // Web 平台不支持 BLE
      bleService = NoopBleService();
    } else if (dart_io.Platform.isWindows) {
      // Windows BLE 需要额外插件 flutter_blue_plus_winrt
      debugPrint('[main] Windows BLE not supported without flutter_blue_plus_winrt');
      bleService = NoopBleService();
    } else {
      bleService = BleService();
    }
  } catch (e) {
    debugPrint('[main] BLE service init failed, using NoopBleService: $e');
    bleService = NoopBleService();
  }

  // 6. 创建指令服务
  final commandService = CommandService(
    bleService: bleService,
    targetDeviceName: settingsViewModel.config.bleDeviceName,
  );

  // 7. 创建机械臂 ViewModel
  final miniArmViewModel = MiniArmViewModel(
    bleService: bleService,
    commandService: commandService,
    targetDeviceName: settingsViewModel.config.bleDeviceName,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsViewModel),
        ChangeNotifierProvider.value(value: wateringViewModel),
        ChangeNotifierProvider.value(value: miniArmViewModel),
      ],
      child: const AppShell(),
    ),
  );
}
