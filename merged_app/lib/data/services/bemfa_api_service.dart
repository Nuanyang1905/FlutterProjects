import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/app_config.dart';
import '../../domain/models/device_state.dart';

/// 设备在线状态 (应用层)
enum AppDeviceConnectionState {
  disconnected,
  checking,
  online,
  failed,
}

/// Bemfa HTTP API 抽象接口，便于测试
abstract class BemfaApiServiceBase {
  AppConfig get config;

  Stream<String> get logStream;

  void updateConfig(AppConfig config);

  Future<bool> checkOnline();

  Future<bool> sendCommand(String cmd);

  Future<DeviceState?> fetchLatestState();

  void dispose();
}

/// 巴法云 HTTP API 服务
class BemfaApiService implements BemfaApiServiceBase {
  static const String _baseUrl = 'https://apis.bemfa.com';
  static const Duration _defaultTimeout = Duration(seconds: 10);
  static const int _pollBatchSize = 5;

  final http.Client _client;
  final Duration _timeout;
  final StreamController<String> _logController =
      StreamController<String>.broadcast();

  AppConfig _config;

  BemfaApiService({
    AppConfig? config,
    http.Client? httpClient,
    Duration timeout = _defaultTimeout,
  })  : _config = config ?? AppConfig.defaultConfig,
        _client = httpClient ?? http.Client(),
        _timeout = timeout;

  @override
  AppConfig get config => _config;

  @override
  Stream<String> get logStream => _logController.stream;

  @override
  void updateConfig(AppConfig config) {
    _config = config;
  }

  /// 查询设备是否在线
  @override
  Future<bool> checkOnline() async {
    final uri = _buildUri('/va/online', {
      'uid': _config.uid,
      'topic': _config.controlTopic,
      'type': _config.type.toString(),
    });

    try {
      final response = await _client.get(uri).timeout(_timeout);
      final payload = _decodeResponse(response);
      if (payload == null) return false;

      if (payload['code'] == 0) {
        final data = payload['data'];
        final online = data is bool ? data : data == true;
        _log('在线状态: ${online ? "在线" : "离线"}');
        return online;
      }

      _log('在线检测失败: ${payload['message'] ?? '未知错误'}');
      return false;
    } catch (e) {
      _log('在线检测异常: $e');
      return false;
    }
  }

  /// 发送控制指令
  @override
  Future<bool> sendCommand(String cmd) async {
    final uri = _buildUri('/va/postJsonMsg');
    final body = jsonEncode({
      'uid': _config.uid,
      'topic': _config.controlTopic,
      'type': _config.type,
      'msg': cmd,
    });

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: body,
          )
          .timeout(_timeout);

      final payload = _decodeResponse(response);
      if (payload == null) return false;

      final ok = payload['code'] == 0;
      if (ok) {
        _log('指令发送成功: $cmd');
      } else {
        _log('指令发送失败: ${payload['message'] ?? '未知错误'}');
      }
      return ok;
    } catch (e) {
      _log('指令发送异常: $e');
      return false;
    }
  }

  /// 拉取最新设备状态
  @override
  Future<DeviceState?> fetchLatestState() async {
    return _fetchLatestStateFromTopic(_config.reportTopic);
  }

  Future<DeviceState?> _fetchLatestStateFromTopic(String topic) async {
    final uri = _buildUri('/va/getmsg', {
      'uid': _config.uid,
      'topic': topic,
      'type': _config.type.toString(),
      'num': _pollBatchSize.toString(),
    });

    try {
      final response = await _client.get(uri).timeout(_timeout);
      final payload = _decodeResponse(response);
      if (payload == null) return null;

      if (payload['code'] != 0) {
        _log('状态拉取失败: ${payload['message'] ?? '未知错误'}');
        return null;
      }

      final data = payload['data'];
      if (data is! List || data.isEmpty) {
        _log('状态拉取成功但无数据');
        return null;
      }

      for (final entry in data) {
        if (entry is! Map<String, dynamic>) {
          continue;
        }

        final msgValue = entry['msg'];
        if (msgValue is! String) {
          continue;
        }
        if (msgValue.trim().isEmpty) {
          continue;
        }

        final parsedState = _parseNestedMessage(msgValue);
        if (parsedState != null) {
          return parsedState;
        }
      }

      _log('状态解析失败: 未找到可解析消息');
      return null;
    } catch (e) {
      _log('状态拉取异常: $e');
      return null;
    }
  }

  DeviceState? _parseNestedMessage(String msgValue) {
    try {
      final decoded = jsonDecode(msgValue);
      if (decoded is Map<String, dynamic>) {
        return DeviceState.tryParse(jsonEncode(decoded));
      }
    } catch (_) {
      // ignore and fallback below
    }
    return DeviceState.tryParse(msgValue);
  }

  Uri _buildUri(String path, [Map<String, String>? query]) {
    return Uri.parse('$_baseUrl$path').replace(queryParameters: query);
  }

  Map<String, dynamic>? _decodeResponse(http.Response response) {
    if (response.statusCode != 200) {
      _log('HTTP ${response.statusCode}: ${response.body}');
      return null;
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      _log('响应格式异常');
      return null;
    } catch (e) {
      _log('响应解析失败: $e');
      return null;
    }
  }

  void _log(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logMessage = '[$timestamp] $message';
    _logController.add(logMessage);
    if (kDebugMode) {
      debugPrint('[BemfaApi] $logMessage');
    }
  }

  @override
  void dispose() {
    _logController.close();
    _client.close();
  }
}
