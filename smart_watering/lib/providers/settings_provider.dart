import 'dart:async';

import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../services/storage_service.dart';

/// 配置变更回调类型定义
typedef ConfigChangeCallback = void Function(AppConfig newConfig);

/// 设置 Provider
///
/// 管理应用配置的读取、保存和修改
class SettingsProvider extends ChangeNotifier {
  final StorageService _storageService;

  /// 当前配置
  AppConfig _config = AppConfig.defaultConfig;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 防抖 Timer，用于延迟保存配置
  Timer? _debounceTimer;

  /// 防抖延迟时间
  static const Duration _debounceDelay = Duration(milliseconds: 800);

  /// 待保存的配置（用于确保最后的内容被保存）
  AppConfig? _pendingConfig;

  /// 最近一次通知给 API 层的配置（避免重复重连）
  AppConfig? _lastNotifiedConfig;

  /// 配置变更监听器列表
  final List<ConfigChangeCallback> _configChangeListeners = [];

  SettingsProvider({StorageService? storageService})
    : _storageService = storageService ?? StorageService();

  // ========== Getters ==========

  AppConfig get config => _config;
  bool get isInitialized => _isInitialized;

  // ========== 配置变更监听 ==========

  /// 添加配置变更监听器
  void addConfigChangeListener(ConfigChangeCallback callback) {
    _configChangeListeners.add(callback);
  }

  /// 移除配置变更监听器
  void removeConfigChangeListener(ConfigChangeCallback callback) {
    _configChangeListeners.remove(callback);
  }

  /// 通知所有配置变更监听器
  void _notifyConfigChangeListeners(AppConfig newConfig) {
    for (final listener in _configChangeListeners) {
      listener(newConfig);
    }
  }

  // ========== 初始化 ==========

  /// 初始化 (从本地存储加载配置)
  Future<void> init() async {
    if (_isInitialized) return;

    await _storageService.init();
    _config = _storageService.loadConfig();
    _lastNotifiedConfig = _config;
    _isInitialized = true;
    notifyListeners();
  }

  // ========== 配置修改 ==========

  /// 更新 UID
  Future<void> updateUid(String uid) async {
    final next = _config.copyWith(uid: uid);
    if (next == _config) return;
    _config = next;
    await _saveConfig();
  }

  /// 更新控制主题
  Future<void> updateControlTopic(String topic) async {
    final next = _config.copyWith(controlTopic: topic);
    if (next == _config) return;
    _config = next;
    await _saveConfig();
  }

  /// 更新上报主题
  Future<void> updateReportTopic(String topic) async {
    final next = _config.copyWith(reportTopic: topic);
    if (next == _config) return;
    _config = next;
    await _saveConfig();
  }

  /// 更新设备类型
  Future<void> updateType(int type) async {
    final next = _config.copyWith(type: type);
    if (next == _config) return;
    _config = next;
    await _saveConfig();
  }

  /// 批量更新配置
  Future<void> updateConfig(AppConfig newConfig) async {
    if (newConfig == _config) return;
    _config = newConfig;
    await _saveConfig();
  }

  /// 重置为默认配置
  Future<void> resetToDefault() async {
    if (_config == AppConfig.defaultConfig) return;
    _config = AppConfig.defaultConfig;
    await _saveConfig();
  }

  // ========== 私有方法 ==========

  Future<void> _saveConfig() async {
    // 立即通知 UI 更新
    notifyListeners();

    // 记录待保存的配置
    _pendingConfig = _config;

    // 取消之前的 Timer
    _debounceTimer?.cancel();

    // 创建新的 Timer，延迟保存到本地存储
    _debounceTimer = Timer(_debounceDelay, () async {
      if (_pendingConfig != null) {
        final configToPersist = _pendingConfig!;
        await _storageService.saveConfig(configToPersist);
        if (_lastNotifiedConfig != configToPersist) {
          _notifyConfigChangeListeners(configToPersist);
          _lastNotifiedConfig = configToPersist;
        }
        _pendingConfig = null;
        if (kDebugMode) {
          // ignore: avoid_print
          print('SettingsProvider: 配置已保存到 SharedPreferences');
        }
      }
    });
  }

  /// 强制立即保存（用于 dispose 前确保数据保存）
  Future<void> flush() async {
    _debounceTimer?.cancel();
    if (_pendingConfig != null) {
      final configToPersist = _pendingConfig!;
      await _storageService.saveConfig(configToPersist);
      if (_lastNotifiedConfig != configToPersist) {
        _notifyConfigChangeListeners(configToPersist);
        _lastNotifiedConfig = configToPersist;
      }
      _pendingConfig = null;
    } else {
      await _storageService.saveConfig(_config);
      if (_lastNotifiedConfig != _config) {
        _notifyConfigChangeListeners(_config);
        _lastNotifiedConfig = _config;
      }
    }
  }

  @override
  void dispose() {
    // 清理配置变更监听器
    _configChangeListeners.clear();

    // 确保最后的内容被保存
    _debounceTimer?.cancel();
    if (_pendingConfig != null) {
      _storageService.saveConfig(_pendingConfig!).catchError((e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('SettingsProvider: dispose 时保存失败: $e');
        }
        return false;
      });
    }
    super.dispose();
  }
}
