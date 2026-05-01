import 'dart:async';

import 'package:smart_watering/config/app_config.dart';
import 'package:smart_watering/models/device_state.dart';
import 'package:smart_watering/services/bemfa_api_service.dart';

class FakeBemfaApiService implements BemfaApiServiceBase {
  FakeBemfaApiService({AppConfig? config})
    : _config = config ?? AppConfig.defaultConfig;

  final StreamController<String> _logController =
      StreamController<String>.broadcast();

  AppConfig _config;
  bool online = true;
  bool throwOnCheckOnline = false;
  bool sendCommandResult = true;
  String? lastCommand;
  final List<DeviceState> _stateQueue = [];

  /// Optional override for fine-grained command behavior in tests.
  /// When set, lastCommand is still recorded.
  Future<bool> Function(String cmd)? sendCommandFn;

  @override
  AppConfig get config => _config;

  @override
  Stream<String> get logStream => _logController.stream;

  @override
  void updateConfig(AppConfig config) {
    _config = config;
  }

  void enqueueState(DeviceState state) {
    _stateQueue.add(state);
  }

  @override
  Future<bool> checkOnline() async {
    if (throwOnCheckOnline) throw Exception('simulated failure');
    return online;
  }

  @override
  Future<bool> sendCommand(String cmd) async {
    lastCommand = cmd;
    if (sendCommandFn != null) {
      return sendCommandFn!(cmd);
    }
    return sendCommandResult;
  }

  @override
  Future<DeviceState?> fetchLatestState() async {
    if (_stateQueue.isEmpty) return null;
    return _stateQueue.removeAt(0);
  }

  @override
  void dispose() {
    _logController.close();
  }
}
