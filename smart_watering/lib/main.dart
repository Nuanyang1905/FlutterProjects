import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/device_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'services/bemfa_api_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化设置 Provider
  final settingsProvider = SettingsProvider(storageService: StorageService());
  await settingsProvider.init();

  // 创建巴法云 API 服务
  final apiService = BemfaApiService(config: settingsProvider.config);

  // 创建设备 Provider
  final deviceProvider = DeviceProvider(apiService: apiService);

  // 设置配置变更监听：当配置修改时，自动更新 API 配置并重连
  settingsProvider.addConfigChangeListener((newConfig) {
    deviceProvider.updateApiConfig(newConfig);
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: deviceProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '匠心农场',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      ),
      home: const HomeScreen(),
    );
  }
}
