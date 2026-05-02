import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/services/interfaces/ble_service_interface.dart';
import '../../../data/services/command_service.dart';
import '../../../domain/models/ble_device_model.dart';
import '../../../domain/models/device_state_model.dart';

/// 机械臂模块 ViewModel
///
/// 管理 BLE 连接、设备扫描和机械臂状态
class MiniArmViewModel extends ChangeNotifier {
  final BleServiceInterface _bleService;
  final CommandService _commandService;
  final String _targetDeviceName;

  BleConnectionState _connectionState = BleConnectionState.disconnected;
  final List<BleDeviceModel> _devices = [];
  bool _isScanning = false;
  String? _errorMessage;

  // 发送队列相关
  StreamSubscription<BleConnectionState>? _connectionSub;
  StreamSubscription<List<int>>? _dataSub;
  StreamSubscription<bool>? _transmittingSub;
  StreamSubscription<List<BleDeviceModel>>? _scanSub;

  MiniArmViewModel({
    required BleServiceInterface bleService,
    required CommandService commandService,
    String targetDeviceName = 'Mini-Arm',
  })  : _bleService = bleService,
        _commandService = commandService,
        _targetDeviceName = targetDeviceName {
    _listenToConnections();
  }

  // ========== Getters ==========

  BleConnectionState get connectionState => _connectionState;
  List<BleDeviceModel> get devices => List.unmodifiable(_devices);
  bool get isScanning => _isScanning;
  String? get errorMessage => _errorMessage;
  String? get connectedDeviceMac => _bleService.connectedDeviceMac;
  bool get isConnected =>
      _connectionState == BleConnectionState.connected;
  bool get isConnecting =>
      _connectionState == BleConnectionState.connecting;
  BleServiceInterface get bleService => _bleService;
  CommandService get commandService => _commandService;
  String get targetDeviceName => _targetDeviceName;

  // ========== 连接监听 ==========

  void _listenToConnections() {
    _connectionSub = _bleService.connectionStateStream.listen((state) {
      _connectionState = state;
      notifyListeners();
    });
  }

  // ========== 扫描操作 ==========

  void startScan() {
    _devices.clear();
    _isScanning = true;
    _errorMessage = null;
    notifyListeners();

    _scanSub = _bleService.scan().listen((results) {
      _devices
        ..clear()
        ..addAll(results);
      notifyListeners();
    }, onError: (error) {
      _errorMessage = '扫描失败: $error';
      _isScanning = false;
      notifyListeners();
    });
  }

  void stopScan() {
    _scanSub?.cancel();
    _scanSub = null;
    _bleService.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  // ========== 连接操作 ==========

  Future<void> connectDevice(BleDeviceModel device) async {
    if (!_bleService.isTargetDevice(device, _targetDeviceName)) {
      _errorMessage = '请选择名称为 $_targetDeviceName 的设备';
      notifyListeners();
      return;
    }

    if (_connectionState == BleConnectionState.connected) {
      return;
    }

    stopScan();
    _errorMessage = null;
    notifyListeners();

    try {
      await _bleService.connect(device.mac);
      // 直接读取服务状态，避免 stream 异步延迟导致 UI 状态不一致
      _connectionState = _bleService.state;
      notifyListeners();
    } catch (e) {
      _connectionState = _bleService.state;
      notifyListeners();
      _errorMessage = '连接失败: $e';
      notifyListeners();
    }
  }

  Future<void> disconnectDevice() async {
    await _bleService.disconnect();
  }

  // ========== 错误清除 ==========

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ========== 资源释放 ==========

  @override
  void dispose() {
    _scanSub?.cancel();
    _connectionSub?.cancel();
    _dataSub?.cancel();
    _transmittingSub?.cancel();
    _bleService.dispose();
    super.dispose();
  }
}
