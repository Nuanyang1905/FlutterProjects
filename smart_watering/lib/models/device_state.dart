import 'dart:convert';

/// 设备状态数据模型
///
/// 支持三种解析格式：
/// 1. JSON v2: {"ver":2,"type":"status","hum":45,"raw":678,"pump":0,"mode":"auto","th_low":30,"th_high":60,"lock":0,"sensor_ok":1}
/// 2. 旧版 JSON: {"hum":45,"mode":"auto","pump":0,"th_L":30,"th_H":60,"lock":0}
/// 3. 旧版格式: #湿度#水泵状态#阈值#模式 (如: #45#1#30#1)
class DeviceState {
  /// 协议版本，0 表示旧版/未知
  final int protocolVersion;

  /// 土壤湿度百分比 (0-100)
  final int humidity;

  /// 传感器原始值
  final int rawValue;

  /// 水泵是否开启
  final bool isPumpOn;

  /// 浇水下限阈值百分比 (0-100) - 低于此值自动开泵
  final int thL;

  /// 浇水上限阈值百分比 (0-100) - 高于此值自动关泵
  final int thH;

  /// 是否为自动模式
  final bool isAutoMode;

  /// 保护锁是否触发
  final bool isLocked;

  /// 传感器是否正常
  final bool isSensorOk;

  /// 最后更新时间 (null 表示尚未收到任何数据)
  final DateTime? lastUpdate;

  const DeviceState({
    required this.protocolVersion,
    required this.humidity,
    required this.rawValue,
    required this.isPumpOn,
    required this.thL,
    required this.thH,
    required this.isAutoMode,
    required this.isLocked,
    required this.isSensorOk,
    this.lastUpdate,
  });

  /// 默认状态 (尚未收到设备数据)
  static const DeviceState defaultState = DeviceState(
    protocolVersion: 0,
    humidity: 0,
    rawValue: 0,
    isPumpOn: false,
    thL: 30,
    thH: 60,
    isAutoMode: true,
    isLocked: false,
    isSensorOk: true,
    lastUpdate: null,
  );

  /// 是否已收到过设备数据
  bool get hasReceivedData => lastUpdate != null;

  /// 兼容旧版的 threshold 属性 (返回下限值)
  int get threshold => thL;

  /// 解析硬件发送的状态字符串
  ///
  /// 支持格式：
  /// 1. JSON v2: {"ver":2,"type":"status","hum":45,"raw":678,"pump":0,"mode":"auto","th_low":30,"th_high":60,"lock":0,"sensor_ok":1}
  /// 2. 旧版 JSON: {"hum":45,"mode":"auto","pump":0,"th_L":30,"th_H":60,"lock":0}
  /// 3. 旧版格式: #湿度#水泵状态#阈值#模式 (如: #45#1#30#1)
  factory DeviceState.parse(String data) {
    // 尝试 JSON 格式解析
    if (data.trim().startsWith('{')) {
      return _parseJson(data);
    }
    // 旧版格式解析
    return _parseLegacy(data);
  }

  /// 解析 JSON 格式
  static DeviceState _parseJson(String data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('状态 JSON 不是对象');
      }

      final version = _readInt(decoded, 'ver') ?? 0;
      final humidity = (_readInt(decoded, 'hum') ?? 0).clamp(0, 100);
      final rawValue = _readInt(decoded, 'raw') ?? 0;
      final pumpState = _readBoolLike(decoded['pump']);
      final modeValue = decoded['mode'];
      final isAutoMode = _readMode(modeValue);
      final lowerThreshold =
          (_readInt(decoded, 'th_low') ?? _readInt(decoded, 'th_L') ?? 30)
              .clamp(0, 100);
      final upperThreshold =
          (_readInt(decoded, 'th_high') ?? _readInt(decoded, 'th_H') ?? 60)
              .clamp(lowerThreshold, 100);
      final isLocked = _readBoolLike(decoded['lock']);
      final isSensorOk = decoded.containsKey('sensor_ok')
          ? _readBoolLike(decoded['sensor_ok'])
          : true;

      return DeviceState(
        protocolVersion: version,
        humidity: humidity,
        rawValue: rawValue,
        isPumpOn: pumpState,
        thL: lowerThreshold,
        thH: upperThreshold,
        isAutoMode: isAutoMode,
        isLocked: isLocked,
        isSensorOk: isSensorOk,
        lastUpdate: DateTime.now(),
      );
    } catch (_) {
      throw FormatException('无效的JSON状态数据格式: $data');
    }
  }

  /// 解析旧版格式 #湿度#水泵状态#阈值#模式
  static DeviceState _parseLegacy(String data) {
    final parts = data.split('#');

    if (parts.length < 5) {
      throw FormatException('无效的状态数据格式: $data');
    }

    final humidity = int.tryParse(parts[1]) ?? 0;
    final pumpState = parts[2] == '1';
    final threshold = int.tryParse(parts[3]) ?? 30;
    final autoMode = parts[4] == '1';

    // 旧版只有单个阈值，转换为双阈值
    return DeviceState(
      protocolVersion: 0,
      humidity: humidity.clamp(0, 100),
      rawValue: 0,
      isPumpOn: pumpState,
      thL: threshold.clamp(0, 100),
      thH: (threshold + 20).clamp(0, 100), // 默认上限比下限高20%
      isAutoMode: autoMode,
      isLocked: false,
      isSensorOk: true,
      lastUpdate: DateTime.now(),
    );
  }

  /// 尝试解析状态字符串，失败返回 null
  static DeviceState? tryParse(String data) {
    try {
      return DeviceState.parse(data);
    } catch (_) {
      return null;
    }
  }

  /// 获取湿度状态描述 (基于双阈值)
  String get humidityStatus {
    if (!isSensorOk) {
      return '传感器异常';
    } else if (isLocked) {
      return '保护锁定';
    } else if (humidity < thL) {
      return '需要浇水';
    } else if (humidity < thH) {
      return '正在浇水';
    } else if (humidity < thH + 10) {
      return '湿润适中';
    } else {
      return '非常湿润';
    }
  }

  /// 判断是否需要浇水 (基于下限阈值)
  bool get needsWatering => isSensorOk && !isLocked && humidity < thL;

  /// 复制并修改状态
  DeviceState copyWith({
    int? protocolVersion,
    int? humidity,
    int? rawValue,
    bool? isPumpOn,
    int? thL,
    int? thH,
    bool? isAutoMode,
    bool? isLocked,
    bool? isSensorOk,
    DateTime? lastUpdate,
  }) {
    return DeviceState(
      protocolVersion: protocolVersion ?? this.protocolVersion,
      humidity: humidity ?? this.humidity,
      rawValue: rawValue ?? this.rawValue,
      isPumpOn: isPumpOn ?? this.isPumpOn,
      thL: thL ?? this.thL,
      thH: thH ?? this.thH,
      isAutoMode: isAutoMode ?? this.isAutoMode,
      isLocked: isLocked ?? this.isLocked,
      isSensorOk: isSensorOk ?? this.isSensorOk,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }

  /// 计算距离上次更新的时间差
  Duration? get timeSinceUpdate {
    if (lastUpdate == null) return null;
    return DateTime.now().difference(lastUpdate!);
  }

  /// 格式化最后更新时间为可读字符串
  String get lastUpdateText {
    final diff = timeSinceUpdate;
    if (diff == null) return '等待数据...';
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}秒前';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else {
      return '${diff.inDays}天前';
    }
  }

  @override
  String toString() {
    return 'DeviceState(ver: $protocolVersion, humidity: $humidity%, raw: $rawValue, pump: ${isPumpOn ? "ON" : "OFF"}, thL: $thL%, thH: $thH%, mode: ${isAutoMode ? "AUTO" : "MANUAL"}, lock: $isLocked, sensorOk: $isSensorOk)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceState &&
        other.protocolVersion == protocolVersion &&
        other.humidity == humidity &&
        other.rawValue == rawValue &&
        other.isPumpOn == isPumpOn &&
        other.thL == thL &&
        other.thH == thH &&
        other.isAutoMode == isAutoMode &&
        other.isLocked == isLocked &&
        other.isSensorOk == isSensorOk;
  }

  @override
  int get hashCode {
    return protocolVersion.hashCode ^
        humidity.hashCode ^
        rawValue.hashCode ^
        isPumpOn.hashCode ^
        thL.hashCode ^
        thH.hashCode ^
        isAutoMode.hashCode ^
        isLocked.hashCode ^
        isSensorOk.hashCode;
  }

  static int? _readInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool _readBoolLike(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == '1' ||
          normalized == 'true' ||
          normalized == 'on' ||
          normalized == 'yes';
    }
    return false;
  }

  static bool _readMode(Object? value) {
    if (value is String) {
      return value.trim().toLowerCase() != 'manual';
    }
    if (value is num) {
      return value != 0;
    }
    return true;
  }
}
