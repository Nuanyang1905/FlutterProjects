import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_watering/config/app_config.dart';
import 'package:smart_watering/providers/settings_provider.dart';
import 'package:smart_watering/services/storage_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsProvider initialization', () {
    test('loads default config when no stored data exists', () async {
      final provider = SettingsProvider(storageService: StorageService());
      addTearDown(provider.dispose);

      await provider.init();

      expect(provider.isInitialized, isTrue);
      expect(provider.config.uid, AppConfig.defaultConfig.uid);
      expect(provider.config.controlTopic, AppConfig.defaultConfig.controlTopic);
      expect(provider.config.reportTopic, AppConfig.defaultConfig.reportTopic);
      expect(provider.config.type, AppConfig.defaultConfig.type);
    });

    test('loads persisted config from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'app_config':
            '{"uid":"test123","controlTopic":"myplant","reportTopic":"myplantup","type":3}',
      });

      final provider = SettingsProvider(storageService: StorageService());
      addTearDown(provider.dispose);

      await provider.init();

      expect(provider.config.uid, 'test123');
      expect(provider.config.controlTopic, 'myplant');
      expect(provider.config.reportTopic, 'myplantup');
      expect(provider.config.type, 3);
    });

    test('falls back to default config on corrupted data', () async {
      SharedPreferences.setMockInitialValues({
        'app_config': 'not valid json',
      });

      final provider = SettingsProvider(storageService: StorageService());
      addTearDown(provider.dispose);

      await provider.init();

      expect(provider.config.uid, AppConfig.defaultConfig.uid);
    });
  });

  group('SettingsProvider config updates', () {
    test('updateUid changes config and notifies listeners', () async {
      final provider = SettingsProvider(storageService: StorageService());
      addTearDown(provider.dispose);
      await provider.init();

      AppConfig? notifiedConfig;
      provider.addConfigChangeListener((cfg) {
        notifiedConfig = cfg;
      });

      await provider.updateUid('new-uid');

      expect(provider.config.uid, 'new-uid');
      expect(provider.config.controlTopic, AppConfig.defaultConfig.controlTopic);
      expect(notifiedConfig, isNull); // listener not called yet (within debounce)

      // flush to trigger immediate save + notification
      await provider.flush();

      expect(notifiedConfig, isNotNull);
      expect(notifiedConfig!.uid, 'new-uid');
    });

    test('updateControlTopic changes config', () async {
      final provider = SettingsProvider(storageService: StorageService());
      addTearDown(provider.dispose);
      await provider.init();

      await provider.updateControlTopic('new-topic');
      await provider.flush();

      expect(provider.config.controlTopic, 'new-topic');
    });

    test('batch updateConfig replaces entire config', () async {
      final provider = SettingsProvider(storageService: StorageService());
      addTearDown(provider.dispose);
      await provider.init();

      const newConfig = AppConfig(
        uid: 'batch-uid',
        controlTopic: 'batch-topic',
        reportTopic: 'batch-up',
        type: 5,
      );

      await provider.updateConfig(newConfig);
      await provider.flush();

      expect(provider.config.uid, 'batch-uid');
      expect(provider.config.controlTopic, 'batch-topic');
      expect(provider.config.reportTopic, 'batch-up');
      expect(provider.config.type, 5);
    });

    test('resetToDefault restores factory defaults', () async {
      SharedPreferences.setMockInitialValues({
        'app_config':
            '{"uid":"custom","controlTopic":"custom","reportTopic":"customup","type":2}',
      });

      final provider = SettingsProvider(storageService: StorageService());
      addTearDown(provider.dispose);
      await provider.init();

      await provider.resetToDefault();
      await provider.flush();

      expect(provider.config, AppConfig.defaultConfig);
    });
  });

  group('SettingsProvider persistence', () {
    test('config is persisted after debounce delay', () async {
      final provider = SettingsProvider(storageService: StorageService());
      addTearDown(provider.dispose);
      await provider.init();

      await provider.updateUid('persist-uid');

      // Wait for debounce (800ms) + small buffer
      await Future.delayed(const Duration(milliseconds: 900));

      // Load config from storage to verify persistence
      final loadedConfig = StorageService().loadConfig();
      expect(loadedConfig.uid, 'persist-uid');
    });

    test('flush persists immediately without waiting for debounce', () async {
      final provider = SettingsProvider(storageService: StorageService());
      addTearDown(provider.dispose);
      await provider.init();

      await provider.updateUid('immediate-uid');
      await provider.flush();

      final loadedConfig = StorageService().loadConfig();
      expect(loadedConfig.uid, 'immediate-uid');
    });
  });

  group('SettingsProvider config change listeners', () {
    test('listener is notified when config changes', () async {
      final provider = SettingsProvider(storageService: StorageService());
      addTearDown(provider.dispose);
      await provider.init();

      AppConfig? captured;
      provider.addConfigChangeListener((cfg) {
        captured = cfg;
      });

      await provider.updateUid('listener-uid');
      await provider.flush();

      expect(captured, isNotNull);
      expect(captured!.uid, 'listener-uid');
    });

    test('removed listener is not notified', () async {
      final provider = SettingsProvider(storageService: StorageService());
      addTearDown(provider.dispose);
      await provider.init();

      AppConfig? captured;
      void callback(AppConfig cfg) {
        captured = cfg;
      }

      provider.addConfigChangeListener(callback);
      provider.removeConfigChangeListener(callback);

      await provider.updateUid('removed-uid');
      await provider.flush();

      expect(captured, isNull);
    });
  });

  group('SettingsProvider edge cases', () {
    test('updating to same config does nothing', () async {
      final provider = SettingsProvider(storageService: StorageService());
      addTearDown(provider.dispose);
      await provider.init();

      int notifyCount = 0;
      provider.addListener(() {
        notifyCount++;
      });

      await provider.updateUid(provider.config.uid);

      expect(notifyCount, 0);
    });

    test('flush during debounce preserves latest config', () async {
      final provider = SettingsProvider(storageService: StorageService());
      addTearDown(provider.dispose);
      await provider.init();

      await provider.updateUid('first');
      await provider.updateUid('second');
      await provider.flush();

      final loaded = StorageService().loadConfig();
      expect(loaded.uid, 'second');
    });
  });
}
