# 匠心农场 - 开发规范文档

> 最后更新: 2026-03-14

---

## 1. 项目信息

| 项目 | 值 |
|------|-----|
| 应用名称 | 匠心农场 |
| 包名 | com.bemfa.smart_watering |
| 目标平台 | Android + iOS |
| Flutter SDK | >=3.0.0 |

---

## 2. MQTT 配置

### 巴法云连接参数

| 参数 | 值 |
|------|-----|
| 服务器 | `bemfa.com` |
| 端口 | `9501` |
| 协议 | MQTT (非 SSL) |
| 默认私钥 (ClientID) | `f148fce62c08490e9ffe25b43948c5c8` |
| 默认主题 | `plant001` |

### 主题规则

| 操作 | 主题 | 说明 |
|------|------|------|
| 订阅 (接收状态) | `plant001` | 设备上传的数据 |
| 发布 (发送指令) | `plant001/set` | 控制设备的指令 |

### 连接示例

```dart
final client = MqttServerClient('bemfa.com', 'f148fce62c08490e9ffe25b43948c5c8');
client.port = 9501;
await client.connect();
client.subscribe('plant001', MqttQos.atMostOnce);
```

---

## 3. 数据协议

### 3.1 接收数据格式

设备每 3 秒上传一次状态，格式：

```
#湿度#水泵状态#阈值#模式
```

**示例**: `#45#1#30#1`

| 索引 | 字段 | 类型 | 说明 |
|------|------|------|------|
| 0 | (空) | - | 以 # 开头 |
| 1 | 湿度 | int | 0-100 百分比 |
| 2 | 水泵状态 | int | 1=开启, 0=关闭 |
| 3 | 阈值 | int | 0-100 百分比 |
| 4 | 模式 | int | 1=自动, 0=手动 |

### 3.2 解析代码

```dart
class DeviceState {
  final int humidity;
  final bool isPumpOn;
  final int threshold;
  final bool isAutoMode;
  final DateTime lastUpdate;

  factory DeviceState.parse(String data) {
    final parts = data.split('#');
    return DeviceState(
      humidity: int.parse(parts[1]),
      isPumpOn: parts[2] == '1',
      threshold: int.parse(parts[3]),
      isAutoMode: parts[4] == '1',
      lastUpdate: DateTime.now(),
    );
  }
}
```

### 3.3 发送指令格式

| 指令 | 格式 | 说明 |
|------|------|------|
| 开启水泵 | `on` | 手动开启浇水 |
| 关闭水泵 | `off` | 手动关闭浇水 |
| 自动模式 | `auto` | 恢复自动控制 |
| 设置阈值 | `t:数值` | 如 `t:40` 设置阈值为 40% |

### 3.4 发送代码

```dart
void sendCommand(String command) {
  final builder = MqttClientPayloadBuilder();
  builder.addString(command);
  client.publishMessage('plant001/set', MqttQos.atMostOnce, builder.payload!);
}
```

---

## 4. 项目结构

```
flutter_4/
├── lib/
│   ├── main.dart                     # 应用入口
│   ├── config/
│   │   └── app_config.dart           # 应用配置类
│   ├── models/
│   │   └── device_state.dart         # 设备状态数据模型
│   ├── services/
│   │   ├── mqtt_service.dart         # MQTT 连接服务
│   │   └── storage_service.dart      # 本地存储服务
│   ├── providers/
│   │   ├── device_provider.dart      # 设备状态 Provider
│   │   └── settings_provider.dart    # 设置 Provider
│   └── screens/
│       ├── home_screen.dart          # 主控制页面
│       └── settings_screen.dart      # 设置页面
├── pubspec.yaml                      # 依赖配置
├── android/                          # Android 原生配置
├── ios/                              # iOS 原生配置
└── DEV_SPEC.md                       # 本文档
```

---

## 5. UI 设计规范

### 5.1 设计风格

- **风格**: 极简纯白风
- **设计系统**: Material Design 3

### 5.2 颜色系统

```dart
// 主色调
const Color primaryColor = Color(0xFF2196F3);   // 蓝色
const Color primaryLight = Color(0xFFBBDEFB);   // 浅蓝
const Color primaryDark = Color(0xFF1976D2);    // 深蓝

// 状态色
const Color successColor = Color(0xFF4CAF50);   // 绿色 - 正常
const Color warningColor = Color(0xFFFF9800);   // 橙色 - 警告
const Color errorColor = Color(0xFFF44336);     // 红色 - 错误

// 背景色
const Color backgroundColor = Color(0xFFFAFAFA); // 浅灰白
const Color cardColor = Colors.white;            // 卡片白色

// 文字色
const Color textPrimary = Color(0xFF212121);    // 主文字
const Color textSecondary = Color(0xFF757575);  // 次要文字
```

### 5.3 字体大小

```dart
const double titleLarge = 22.0;    // 页面标题
const double titleMedium = 18.0;   // 卡片标题
const double bodyLarge = 16.0;     // 主要内容
const double bodyMedium = 14.0;    // 次要内容
const double bodySmall = 12.0;     // 辅助说明
const double humidityValue = 72.0; // 湿度数值 (大号)
```

### 5.4 页面布局

#### 主页面 (home_screen.dart)

```
┌─────────────────────────────────────┐
│  AppBar: 🌱 匠心农场                │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │  💧 土壤湿度                 │   │  Card
│  │       65 %                  │   │
│  │    [========----]           │   │  LinearProgressIndicator
│  │    状态: 湿润适中            │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  🚿 水泵控制                 │   │  Card
│  │   状态: 已关闭               │   │
│  │   [═══●────────] OFF        │   │  Switch
│  │                             │   │
│  │   ⚙️ 模式: [自动] [手动]     │   │  SegmentedButton
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  🎯 浇水阈值                 │   │  Card
│  │   当湿度低于 30% 时自动浇水  │   │
│  │   ○─────●────○   30%        │   │  Slider
│  └─────────────────────────────┘   │
│                                     │
├─────────────────────────────────────┤
│  🔗 已连接巴法云 · 3秒前更新        │  状态栏
└─────────────────────────────────────┘
```

#### 设置页面 (settings_screen.dart)

```
┌─────────────────────────────────────┐
│  ⚙️ 设置                            │
├─────────────────────────────────────┤
│  MQTT 配置                          │
│  ├─ 服务器: [bemfa.com    ]         │
│  ├─ 端口:   [9501         ]         │
│  ├─ 私钥:   [f148fce62c... ]         │
│  └─ 主题:   [plant001     ]         │
├─────────────────────────────────────┤
│  调试信息                           │
│  ├─ 连接日志                        │
│  └─ 清除日志                        │
├─────────────────────────────────────┤
│  关于                               │
│  ├─ 版本: 1.0.0                     │
│  └─ 开发者: iFlow CLI               │
└─────────────────────────────────────┘
```

### 5.5 组件规范

| 组件 | Widget | 说明 |
|------|--------|------|
| 卡片容器 | `Card` | elevation: 2, borderRadius: 12 |
| 湿度进度条 | `LinearProgressIndicator` | 高度 8px, 圆角 |
| 水泵开关 | `Switch` | Material 3 风格 |
| 模式切换 | `SegmentedButton` | 两个选项 |
| 阈值滑块 | `Slider` | min:0, max:100, divisions:20 |
| 状态指示 | `Icon + Text` | 颜色区分状态 |

---

## 6. 依赖列表

### pubspec.yaml

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # MQTT 通信
  mqtt_client: ^10.2.0
  
  # 状态管理
  provider: ^6.1.1
  
  # 本地存储
  shared_preferences: ^2.2.2
  
  # iOS 图标
  cupertino_icons: ^1.0.6

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
```

---

## 7. 交互逻辑

### 7.1 水泵控制

```
用户点击 Switch:
  - 如果当前是自动模式 → 提示"请先切换到手动模式"
  - 如果当前是手动模式:
    - ON  → 发送 "on"
    - OFF → 发送 "off"
```

### 7.2 模式切换

```
用户切换 SegmentedButton:
  - 选择"自动" → 发送 "auto"，Switch 禁用
  - 选择"手动" → Switch 启用，保持当前水泵状态
```

### 7.3 阈值调节

```
用户拖动 Slider:
  - 拖动中: 实时显示数值
  - 松手后: 延迟 500ms 发送 "t:数值" (防抖)
```

### 7.4 状态指示

| 连接状态 | 图标 | 颜色 | 文字 |
|----------|------|------|------|
| 已连接 | 🔗 | 绿色 | "已连接巴法云" |
| 连接中 | 🔄 | 黄色 | "正在连接..." |
| 已断开 | ❌ | 红色 | "连接已断开" |

---

## 8. 错误处理

### 8.1 MQTT 断线重连

```dart
client.onDisconnected = () {
  // 尝试重连
  Future.delayed(Duration(seconds: 5), () {
    client.connect();
  });
};
```

### 8.2 数据解析失败

```dart
try {
  final state = DeviceState.parse(data);
} catch (e) {
  // 记录日志，保持上次状态
  log('解析失败: $e');
}
```

---

## 9. 硬件端参考

### ESP8266 代码要点

- 串口接收 Arduino 数据，格式 `#湿度#水泵#阈值#模式`
- 订阅 `plant001`，发布到 `plant001/up` (带 /up 防止循环)
- 接收指令格式: `on`, `off`, `auto`, `t:数值`
- 转发指令给 Arduino: `CMD:PUMP_ON`, `CMD:PUMP_OFF`, `CMD:PUMP_AUTO`, `CMD:SET_T:数值`

### Arduino 代码要点

- 每 3 秒发送状态到 ESP8266
- 接收 ESP8266 指令执行水泵控制
- 自动模式: 湿度 < 阈值 → 开泵, 湿度 ≥ 阈值+5 → 关泵 (带回差)

---

## 10. 开发检查清单

- [ ] flutter create 初始化项目
- [ ] pubspec.yaml 配置依赖
- [ ] flutter pub get 安装依赖
- [ ] 创建 config/app_config.dart
- [ ] 创建 services/storage_service.dart
- [ ] 创建 models/device_state.dart
- [ ] 创建 services/mqtt_service.dart
- [ ] 创建 providers/device_provider.dart
- [ ] 创建 providers/settings_provider.dart
- [ ] 创建 screens/home_screen.dart
- [ ] 创建 screens/settings_screen.dart
- [ ] 编辑 main.dart 整合
- [ ] flutter run 测试
- [ ] Android 打包测试
- [ ] iOS 打包测试 (需要 Mac)

---

*本文档由 iFlow CLI 自动生成，开发过程中请时刻参考*
