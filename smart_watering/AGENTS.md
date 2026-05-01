# AGENTS.md - 匠心农场智能浇水应用

## 项目概述

**项目名称**: 匠心农场 (smart_watering)  
**项目类型**: Flutter 跨平台应用 (Android + iOS + Web + Windows + macOS + Linux)  
**应用包名**: com.bemfa.smart_watering  
**核心功能**: 通过巴法云 HTTP API（轮询模式）远程监控土壤湿度并控制智能浇水系统

---

## 技术栈

| 类别 | 技术 | 版本 |
|------|------|------|
| 框架 | Flutter | ^3.11.0 |
| 语言 | Dart | ^3.11.0 |
| 状态管理 | Provider | ^6.1.1 |
| HTTP 通信 | http | ^1.2.2 |
| 本地存储 | shared_preferences | ^2.2.2 |
| 代码规范 | flutter_lints | ^6.0.0 |
| 设计系统 | Material Design 3 | - |

---

## 项目结构

```
flutter_4/
├── lib/
│   ├── main.dart                     # 应用入口，初始化 Provider 和 API 服务
│   ├── config/
│   │   └── app_config.dart           # 巴法云 API 配置类，支持 JSON 序列化
│   ├── models/
│   │   └── device_state.dart         # 设备状态数据模型，支持双格式解析
│   ├── services/
│   │   ├── bemfa_api_service.dart    # 巴法云 HTTP API 封装（轮询/指令/在线检测）
│   │   └── storage_service.dart      # 本地存储服务 (SharedPreferences 封装)
│   ├── providers/
│   │   ├── device_provider.dart      # 设备状态管理 Provider，含防抖控制
│   │   └── settings_provider.dart    # 应用设置管理 Provider，含配置变更监听
│   └── screens/
│       ├── home_screen.dart          # 主控制页面（湿度/水泵/阈值控制）
│       └── settings_screen.dart      # 设置页面（巴法云 API 配置/调试日志）
├── pubspec.yaml                      # 依赖配置
├── DEV_SPEC.md                       # 详细开发规范文档
├── analysis_options.yaml             # Dart 代码分析配置
└── android/ ios/ web/ windows/ linux/ macos/  # 平台原生配置
```

---

## 巴法云 HTTP API 配置

### 连接参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| API 基础地址 | `https://apis.bemfa.com` | 巴法云 HTTP API 端点 |
| UID (私钥) | `f148fce62c08490e9ffe25b43948c5c8` | 巴法云设备私钥 |
| 控制主题 | `plant001` | 发送指令的目标主题 |
| 上报主题 | `plant001up` | 设备上报状态的源主题（轮询用） |
| 设备类型 | `1` | MQTT 设备类型 |
| 轮询间隔 | `3` 秒 | 定时拉取设备最新状态 |
| 超时时间 | `10` 秒 | HTTP 请求超时

---

## 数据协议

### 接收数据格式（三格式兼容）

#### 1. JSON v2 格式（固件最新版）

```json
{
  "ver": 2,
  "type": "status",
  "hum": 45,
  "raw": 678,
  "pump": 0,
  "mode": "auto",
  "th_low": 30,
  "th_high": 60,
  "lock": 0,
  "sensor_ok": 1
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `ver` | int | 协议版本号 |
| `hum` | int | 土壤湿度 0-100% |
| `raw` | int | 传感器 ADC 原始值 |
| `pump` | int | 水泵状态 1=开启, 0=关闭 |
| `mode` | string | `"auto"`=自动模式, `"manual"`=手动模式 |
| `th_low` | int | 浇水下限阈值 0-100%（低于此值开泵） |
| `th_high` | int | 浇水上限阈值 0-100%（高于此值关泵） |
| `lock` | int | 保护锁 1=触发, 0=未触发 |
| `sensor_ok` | int | 传感器状态 1=正常, 0=异常 |

#### 2. JSON 格式（旧版兼容）

```json
{
  "hum": 45,
  "mode": "auto",
  "pump": 0,
  "th_L": 30,
  "th_H": 60,
  "lock": 0
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `hum` | int | 土壤湿度 0-100% |
| `pump` | int | 水泵状态 1=开启, 0=关闭 |
| `mode` | string | `"auto"`=自动模式, `"manual"`=手动模式 |
| `th_L` | int | 浇水下限阈值 0-100%（低于此值开泵） |
| `th_H` | int | 浇水上限阈值 0-100%（高于此值关泵） |
| `lock` | int | 锁定状态（可选） |

#### 2. 旧版分隔符格式（向后兼容）

```
#湿度#水泵状态#阈值#模式
```

**示例**: `#45#1#30#1`

| 索引 | 字段 | 说明 |
|------|------|------|
| 1 | 湿度 | 0-100% |
| 2 | 水泵状态 | 1=开启, 0=关闭 |
| 3 | 阈值 | 0-100%（旧版单阈值，自动转换为 th_L） |
| 4 | 模式 | 1=自动, 0=手动 |

**旧版转换规则**: 单阈值自动转换为双阈值，`th_L = 阈值`, `th_H = 阈值 + 20`

### 发送指令

| 指令 | 格式 | 说明 |
|------|------|------|
| 开启水泵 | `on` | 手动开启浇水 |
| 关闭水泵 | `off` | 手动关闭浇水 |
| 切换自动模式 | `auto` | 切换到自动控制模式 |
| 设置双阈值 | `set:下限,上限` | 如 `set:30,60` 设置 th_L=30%, th_H=60% |
| 设置单阈值（兼容） | `t:数值` | 如 `t:40`（旧版兼容） |

### 双阈值控制逻辑（滞回控制）

```
湿度 < th_L (下限)  →  自动开泵浇水
th_L ≤ 湿度 ≤ th_H  →  保持当前状态
湿度 > th_H (上限)  →  自动关泵停止
```

**优势**: 避免湿度在阈值附近波动时水泵频繁启停。

---

## 构建与运行

### 环境要求

- Flutter SDK: ^3.11.0
- Dart SDK: ^3.11.0
- Android Studio / VS Code
- Android SDK (Android 平台)
- Xcode (iOS 平台，需 macOS)

### 常用命令

```bash
# 获取依赖
flutter pub get

# 运行应用（自动检测平台）
flutter run

# 运行到特定平台
flutter run -d android
flutter run -d ios
flutter run -d chrome          # Web 平台
flutter run -d windows
flutter run -d macos
flutter run -d linux

# 构建发布版本
flutter build apk              # Android APK
flutter build apk --split-per-abi  # 分 ABI 构建
flutter build ios              # iOS（需 macOS + Xcode）
flutter build web              # Web 版本
flutter build windows          # Windows 桌面版
flutter build macos            # macOS 桌面版
flutter build linux            # Linux 桌面版

# 代码分析
flutter analyze

# 检查依赖更新
flutter pub outdated
```

### 平台特定要求

| 平台 | 要求 | 注意事项 |
|------|------|----------|
| **Android** | Android SDK 21+ | 无特殊要求 |
| **iOS** | iOS 11+ | 需要 macOS 和 Xcode |
| **Web** | 现代浏览器 | 自动使用 WebSocket 连接 (端口 9504) |
| **Windows** | Windows 10+ | 支持 x64 |
| **macOS** | macOS 10.14+ | 支持 Intel/Apple Silicon |
| **Linux** | GTK 开发库 | 需安装 libgtk-3-dev |

---

## 开发规范

### 状态管理架构

使用 **Provider** 进行状态管理，采用分层设计：

#### SettingsProvider
- 管理巴法云 API 配置（UID、主题、设备类型）
- 支持配置持久化（SharedPreferences）
- 实现防抖保存（800ms 延迟，避免频繁写入）
- 配置变更监听器模式，修改后自动通知 API 服务重连

#### DeviceProvider
- 管理设备状态（湿度、水泵、模式、阈值）
- 管理 API 连接状态
- 提供设备控制方法（水泵开关、模式切换、阈值设置）
- 阈值设置防抖（500ms 延迟发送指令）
- 操作锁防止重复点击

### 服务层设计

#### BemfaApiService
- 封装巴法云 HTTP API（在线检测、指令发送、状态轮询）
- 3 秒定时轮询获取设备最新状态
- 连接状态流（Stream）供 UI 监听
- 日志流用于调试
- 抽象接口 BemfaApiServiceBase 便于测试 Mock

#### StorageService
- SharedPreferences 单例封装
- 配置 JSON 序列化/反序列化
- 异常时返回默认配置

### UI 设计规范

#### 视觉风格
- **设计风格**: 极简纯白风
- **设计系统**: Material Design 3
- **主色调**: 蓝色 (#2196F3)
- **背景色**: 浅灰白 (#FAFAFA)
- **卡片**: 白色背景，圆角 12px，阴影 elevation 2

#### 状态颜色
| 状态 | 颜色 | 说明 |
|------|------|------|
| 需要浇水 | 红色 | 湿度 < th_L |
| 正在浇水 | 蓝色 | th_L ≤ 湿度 < th_H |
| 湿润适中 | 绿色 | th_H ≤ 湿度 < th_H+10 |
| 非常湿润 | 蓝色 | 湿度 ≥ th_H+10 |

### 关键实现要点

1. **Web 平台**: 必须使用 WebSocket 连接 (`MqttBrowserClient`)，TCP 在浏览器中不可用
2. **移动/桌面平台**: 使用 TCP MQTT 连接 (`MqttServerClient`)
3. **自动重连**: 断线后最多重试 5 次，间隔 5 秒
4. **阈值防抖**: 拖动滑块后延迟 500ms 发送指令，避免频繁通信
5. **配置防抖**: 设置修改后延迟 800ms 保存到本地存储
6. **双格式兼容**: 设备状态解析支持 JSON 和旧版分隔符两种格式
7. **命令回声保护期**: 发送指令后 3 秒内忽略轮询到的旧状态，防止乐观 UI 被回滚
8. **数据三格式兼容**: 支持 JSON v2、旧版 JSON、`#` 分隔符旧版三种格式解析

---

## 核心文件说明

### 配置层
- `lib/config/app_config.dart`: 定义 API 连接参数，支持 JSON 序列化、copyWith 模式

### 模型层
- `lib/models/device_state.dart`: 
  - 解析设备状态数据（JSON + 旧版格式双兼容）
  - 双阈值控制逻辑（th_L/th_H）
  - 湿度状态判断（需要浇水/正在浇水/湿润适中/非常湿润）

### 服务层
- `lib/services/bemfa_api_service.dart`: 
  - 巴法云 HTTP API 封装（在线检测、指令发送、状态轮询）
  - 抽象接口 BemfaApiServiceBase 便于测试 Mock
  - 日志流用于调试
- `lib/services/storage_service.dart`: 
  - SharedPreferences 单例封装
  - 配置读写

### 状态层
- `lib/providers/device_provider.dart`: 
  - 设备状态管理
  - API 连接控制（轮询/重连）
  - 设备指令发送（水泵/模式/阈值）
  - 防抖控制
- `lib/providers/settings_provider.dart`: 
  - 配置管理
  - 配置变更监听
  - 持久化防抖

### UI 层
- `lib/screens/home_screen.dart`: 
  - 湿度显示卡片
  - 水泵控制卡片（开关 + 模式切换）
  - 双阈值调节卡片（下限/上限滑块）
  - 连接状态栏
- `lib/screens/settings_screen.dart`: 
  - 巴法云 API 配置编辑
  - 调试日志查看
  - 配置重置

---

## 注意事项

1. **Web 平台必须使用 WebSocket**: TCP 端口在浏览器环境中不可用，框架会自动切换
2. **配置修改自动重连**: 在设置页面修改巴法云 API 配置后，会自动断开并重新连接
3. **双阈值控制**: 新版使用 th_L（下限）和 th_H（上限）双阈值，避免水泵频繁启停
4. **数据格式兼容**: `DeviceState.parse()` 会自动识别 JSON 和旧版分隔符格式
5. **自动模式限制**: 自动模式下水泵开关由硬件自动控制，APP 仅显示状态，无法手动操作
6. **防抖机制**: 
   - 阈值滑块：500ms 防抖
   - 配置保存：800ms 防抖
7. **连接日志**: 最多保留 100 条，可在设置页面查看

---

## 调试与故障排除

### 常见问题

| 问题 | 可能原因 | 解决方案 |
|------|----------|----------|
| Web 平台无法连接 | WebSocket 配置错误 | 检查使用 wss:// 而非 tcp://（HTTP API 模式不会遇到此问题） |
| 数据解析失败 | 设备发送格式不正确 | 检查设备端数据格式是否为 JSON 或 #分隔符格式 |
| 阈值设置不生效 | 指令格式错误 | 确认使用 `set:下限,上限` 格式 |
| 配置保存失败 | SharedPreferences 异常 | 重启应用，检查存储权限 |

### 调试功能

- **连接日志**: 设置页面 → 调试信息 → 连接日志
- **实时日志**: BemfaApiService 通过 debugPrint 输出到控制台
- **配置重置**: 设置页面 → 重置为默认配置

---

## 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| 1.0.0+1 | 2026-03-18 | 初始版本，支持全平台 |

---

*本文档由 iFlow CLI 维护，开发过程中请保持更新*