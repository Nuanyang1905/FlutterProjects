/// 应用配置类
///
/// 存储巴法云 HTTP API 参数，支持持久化和运行时修改
class AppConfig {
  /// 巴法云用户私钥 (UID)
  final String uid;

  /// 控制主题 (发送指令)
  final String controlTopic;

  /// 数据上报主题 (设备上报状态)
  final String reportTopic;

  /// 设备类型 (MQTT 设备为 1)
  final int type;

  const AppConfig({
    this.uid = 'f148fce62c08490e9ffe25b43948c5c8',
    this.controlTopic = 'plant001',
    this.reportTopic = 'plant001up',
    this.type = 1,
  });

  /// 默认配置
  static const AppConfig defaultConfig = AppConfig();

  /// 从 JSON 创建配置
  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      uid: json['uid'] as String? ?? defaultConfig.uid,
      controlTopic:
          json['controlTopic'] as String? ?? defaultConfig.controlTopic,
      reportTopic:
          json['reportTopic'] as String? ?? defaultConfig.reportTopic,
      type: json['type'] as int? ?? defaultConfig.type,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'controlTopic': controlTopic,
      'reportTopic': reportTopic,
      'type': type,
    };
  }

  /// 复制并修改配置
  AppConfig copyWith({
    String? uid,
    String? controlTopic,
    String? reportTopic,
    int? type,
  }) {
    return AppConfig(
      uid: uid ?? this.uid,
      controlTopic: controlTopic ?? this.controlTopic,
      reportTopic: reportTopic ?? this.reportTopic,
      type: type ?? this.type,
    );
  }

  @override
  String toString() {
    return 'AppConfig(uid: $uid, controlTopic: $controlTopic, reportTopic: $reportTopic, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppConfig &&
        other.uid == uid &&
        other.controlTopic == controlTopic &&
        other.reportTopic == reportTopic &&
        other.type == type;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        controlTopic.hashCode ^
        reportTopic.hashCode ^
        type.hashCode;
  }
}
