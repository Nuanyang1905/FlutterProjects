import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/device_state.dart';
import '../services/bemfa_api_service.dart';

/// 设备状态 Provider
///
/// 管理设备状态与 HTTP 轮询，提供 UI 所需的数据和方法
class DeviceProvider extends ChangeNotifier {
  final BemfaApiServiceBase _apiService;
  final Duration _pollInterval;
  static const Duration _commandEchoGracePeriod = Duration(seconds: 3);

  /// 当前设备状态
  DeviceState _deviceState = DeviceState.defaultState;

  /// 连接状态
  AppDeviceConnectionState _connectionState =
      AppDeviceConnectionState.disconnected;

  /// 日志列表
  final List<String> _logs = [];

  /// 是否正在操作中 (防止重复点击)
  bool _isOperating = false;

  /// 本地下发命令后的短暂保护期，避免被旧状态回包覆盖
  bool? _pendingPumpState;
  DateTime? _pendingPumpStateUntil;
  bool? _pendingAutoMode;
  DateTime? _pendingAutoModeUntil;

  /// 流订阅
  StreamSubscription<String>? _logSubscription;

  Timer? _pollTimer;
  bool _isPolling = false;

  DeviceProvider({
    BemfaApiServiceBase? apiService,
    Duration pollInterval = const Duration(seconds: 3),
  })  : _apiService = apiService ?? BemfaApiService(),
        _pollInterval = pollInterval {
    _init();
  }

  // ========== Getters ==========

  DeviceState get deviceState => _deviceState;
  AppDeviceConnectionState get connectionState => _connectionState;
  List<String> get logs => List.unmodifiable(_logs);
  bool get isOperating => _isOperating;

  bool get isConnected => _connectionState == AppDeviceConnectionState.online;
  bool get isConnecting =>
      _connectionState == AppDeviceConnectionState.checking;

  // ========== 初始化 ==========

  void _init() {
    // 监听日志
    _logSubscription = _apiService.logStream.listen((log) {
      _logs.insert(0, log);
      // 限制日志数量
      if (_logs.length > 100) {
        _logs.removeLast();
      }
      notifyListeners();
    });
  }

  // ========== 连接操作 ==========

  /// 开始轮询并检测在线状态
  Future<void> connect() async {
    _updateConnectionState(AppDeviceConnectionState.checking);
    _startPolling();
    await _pollLatest();
  }

  /// 停止轮询
  void disconnect() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _updateConnectionState(AppDeviceConnectionState.disconnected);
  }

  /// 重连
  Future<void> reconnect() async {
    disconnect();
    await Future.delayed(const Duration(milliseconds: 300));
    await connect();
  }

  /// 更新 API 配置
  ///
  /// 当用户在设置页面修改配置后调用，会更新 API 配置并重连
  Future<void> updateApiConfig(AppConfig newConfig) async {
    if (_apiService.config == newConfig) {
      return;
    }

    _apiService.updateConfig(newConfig);
    await reconnect();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      _pollLatest();
    });
  }

  Future<void> _pollLatest() async {
    if (_isPolling) return;
    _isPolling = true;
    try {
      final online = await _apiService.checkOnline();
      _updateConnectionState(
        online
            ? AppDeviceConnectionState.online
            : AppDeviceConnectionState.disconnected,
      );

      final latest = await _apiService.fetchLatestState();
      if (latest != null) {
        _deviceState = _mergeIncomingState(latest);
        notifyListeners();
      }
    } catch (_) {
      _updateConnectionState(AppDeviceConnectionState.failed);
    } finally {
      _isPolling = false;
    }
  }

  void _updateConnectionState(AppDeviceConnectionState state) {
    if (_connectionState == state) return;
    _connectionState = state;
    notifyListeners();
  }

  // ========== 水泵控制 ==========

  /// 开启水泵
  Future<bool> turnOnPump() async {
    if (_isOperating || !isConnected) return false;

    _isOperating = true;
    notifyListeners();

    final result = await _apiService.sendCommand('on');

    _isOperating = false;
    if (result) {
      _setPendingPumpState(true);
      _deviceState = _deviceState.copyWith(isPumpOn: true);
    }
    notifyListeners();

    return result;
  }

  /// 关闭水泵
  Future<bool> turnOffPump() async {
    if (_isOperating || !isConnected) return false;

    _isOperating = true;
    notifyListeners();

    final result = await _apiService.sendCommand('off');

    _isOperating = false;
    if (result) {
      _setPendingPumpState(false);
      _deviceState = _deviceState.copyWith(isPumpOn: false);
    }
    notifyListeners();

    return result;
  }

  /// 切换水泵状态
  Future<bool> togglePump() async {
    if (_deviceState.isPumpOn) {
      return turnOffPump();
    } else {
      return turnOnPump();
    }
  }

  // ========== 模式控制 ==========

  /// 切换到自动模式
  Future<bool> setAutoMode() async {
    if (_isOperating || !isConnected) return false;

    _isOperating = true;
    notifyListeners();

    final result = await _apiService.sendCommand('auto');

    _isOperating = false;
    if (result) {
      _setPendingAutoMode(true);
      _deviceState = _deviceState.copyWith(isAutoMode: true);
    }
    notifyListeners();

    return result;
  }

  /// 切换到手动模式
  Future<bool> setManualMode() async {
    if (_isOperating || !isConnected) return false;

    _isOperating = true;
    notifyListeners();

    final result = await _apiService.sendCommand('manual');

    _isOperating = false;
    if (result) {
      _setPendingAutoMode(false);
      _deviceState = _deviceState.copyWith(isAutoMode: false);
    }
    notifyListeners();

    return result;
  }

  /// 切换模式
  Future<bool> toggleMode() async {
    if (_deviceState.isAutoMode) {
      // 自动 -> 手动
      return setManualMode();
    } else {
      // 手动 -> 自动
      return setAutoMode();
    }
  }

  // ========== 阈值控制 ==========

  /// 设置阈值 (带防抖) - 双阈值
  /// [lower] 下限阈值 (低于此值自动开泵)
  /// [upper] 上限阈值 (高于此值自动关泵)
  Timer? _thresholdTimer;
  Completer<bool>? _thresholdCompleter;

  Future<bool> setThreshold(int lower, int upper) async {
    // 取消之前的定时器和 Completer
    _thresholdTimer?.cancel();
    if (_thresholdCompleter != null && !_thresholdCompleter!.isCompleted) {
      _thresholdCompleter!.complete(false);
    }

    // 延迟 500ms 发送，实现防抖
    final completer = Completer<bool>();
    _thresholdCompleter = completer;

    _thresholdTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!isConnected) {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
        return;
      }

      final effectiveLower = lower.clamp(0, 100);
      final effectiveUpper = upper.clamp(effectiveLower, 100);
      final result = await _apiService.sendCommand(
        'set:$effectiveLower,$effectiveUpper',
      );

      if (result) {
        _deviceState = _deviceState.copyWith(
          thL: effectiveLower,
          thH: effectiveUpper,
        );
        notifyListeners();
      }

      if (!completer.isCompleted) {
        completer.complete(result);
      }
    });

    return completer.future;
  }

  /// 立即发送阈值 (不防抖) - 双阈值
  Future<bool> setThresholdImmediate(int lower, int upper) async {
    if (!isConnected) return false;

    final effectiveLower = lower.clamp(0, 100);
    final effectiveUpper = upper.clamp(effectiveLower, 100);
    final result = await _apiService.sendCommand(
      'set:$effectiveLower,$effectiveUpper',
    );
    if (result) {
      _deviceState = _deviceState.copyWith(
        thL: effectiveLower,
        thH: effectiveUpper,
      );
      notifyListeners();
    }
    return result;
  }

  /// 清除保护锁
  Future<bool> clearProtectionLock() async {
    if (_isOperating || !isConnected) return false;

    _isOperating = true;
    notifyListeners();

    final result = await _apiService.sendCommand('unlock');

    _isOperating = false;
    if (result) {
      _deviceState = _deviceState.copyWith(isLocked: false);
    }
    notifyListeners();

    return result;
  }

  // ========== 日志操作 ==========

  /// 清除日志
  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  DeviceState _mergeIncomingState(DeviceState incomingState) {
    var mergedState = incomingState;
    final now = DateTime.now();

    if (_pendingPumpState != null) {
      if (incomingState.isPumpOn == _pendingPumpState) {
        _pendingPumpState = null;
        _pendingPumpStateUntil = null;
      } else if (_pendingPumpStateUntil != null &&
          now.isBefore(_pendingPumpStateUntil!)) {
        mergedState = mergedState.copyWith(isPumpOn: _pendingPumpState);
      } else {
        _pendingPumpState = null;
        _pendingPumpStateUntil = null;
      }
    }

    if (_pendingAutoMode != null) {
      if (incomingState.isAutoMode == _pendingAutoMode) {
        _pendingAutoMode = null;
        _pendingAutoModeUntil = null;
      } else if (_pendingAutoModeUntil != null &&
          now.isBefore(_pendingAutoModeUntil!)) {
        mergedState = mergedState.copyWith(isAutoMode: _pendingAutoMode);
      } else {
        _pendingAutoMode = null;
        _pendingAutoModeUntil = null;
      }
    }

    return mergedState;
  }

  void _setPendingPumpState(bool pumpState) {
    _pendingPumpState = pumpState;
    _pendingPumpStateUntil = DateTime.now().add(_commandEchoGracePeriod);
  }

  void _setPendingAutoMode(bool isAutoMode) {
    _pendingAutoMode = isAutoMode;
    _pendingAutoModeUntil = DateTime.now().add(_commandEchoGracePeriod);
  }

  // ========== 资源释放 ==========

  @override
  void dispose() {
    _pollTimer?.cancel();
    _thresholdTimer?.cancel();
    // 确保 Completer 完成，避免调用者永远等待
    if (_thresholdCompleter != null && !_thresholdCompleter!.isCompleted) {
      _thresholdCompleter!.complete(false);
    }
    _logSubscription?.cancel();
    _apiService.dispose();
    super.dispose();
  }
}
