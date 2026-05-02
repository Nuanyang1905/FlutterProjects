# Research: flutter_blue_plus 跨平台支持分析

- **Query**: flutter_blue_plus 在非移动端平台（Web, Windows, macOS, Linux）的支持情况
- **Scope**: external (pub.dev + GitHub docs)
- **Date**: 2026-05-02

## Findings

### 1. 官方平台支持矩阵 (v2.2.1)

pub.dev 上 flutter_blue_plus v2.2.1 标注 **6 个平台**均支持：

| 平台 | 官方声明 | 实际情况 |
|------|----------|----------|
| **Android** | ✅ | 完整支持，最成熟 |
| **iOS** | ✅ | 完整支持，CoreBluetooth 后端 |
| **macOS** | ✅ | 完整支持，需 Xcode 配置 Bluetooth Hardware 沙箱权限 |
| **Linux** | ✅ | 1.35.0 加入，多数功能支持 |
| **Web** | ⚠️ 标注支持 | **功能严重受限**（见下文） |
| **Windows** | ❌ 核心包 | 需额外安装 `flutter_blue_plus_winrt` |

### 2. 各平台功能差异详情（来自官方 API Reference 表）

#### Web 平台关键限制：

| 功能 | Web 支持 |
|------|----------|
| `setLogLevel` | ❌ |
| `setOptions` | ❌ |
| `turnOn` / `turnOff` | ❌ |
| `adapterState` | ❌ |
| `adapterStateNow` | ❌ |
| `stopScan` | ❌ |
| `systemDevices` | ❌ |
| `onMtuChanged` | ❌ |
| `onReadRssi` | ❌ |
| `onServicesReset` | ❌ |
| `onBondStateChanged` | ❌ |
| `onNameChanged` | ❌ |
| `device.advName` | ❌ |
| `device.mtu` / `device.mtuNow` | ❌ |
| `device.readRssi` | ❌ |
| `device.requestMtu` | ❌ |
| `device.bondState` / `createBond` / `removeBond` | ❌ |
| `startScan` | ✅ |
| `connect` / `disconnect` | ✅ |
| `discoverServices` | ✅ |
| `read` / `write` Characteristic | ✅ |
| `setNotifyValue` | ✅ |
| `isScanning` / `isScanningNow` | ✅ |

> **结论：Web 仅支持核心 BLE Central 操作（扫描、连接、读写特征），缺少 Adapter 状态管理、MTU 协商、RSSI、Bonding 等高级功能。**

#### Linux 平台关键限制：

| 功能 | Linux 支持 |
|------|------------|
| `adapterState` | ✅ |
| `startScan` / `stopScan` | ✅ |
| `connect` / `disconnect` | ✅ |
| `discoverServices` | ✅ |
| `read` / `write` Characteristic | ✅ |
| `setNotifyValue` | ✅ |
| `mtu` / `onMtuChanged` | ❌ |
| `requestMtu` | ❌ |
| `createBond` / `removeBond` | ❌ |
| `turnOn` / `turnOff` | ❌ (仅 Android) |
| `setPreferredPhy` | ❌ (仅 Android) |

#### macOS 平台完整度很高，缺少的功能极少：
| 功能 | macOS 支持 |
|------|------------|
| `turnOn` / `turnOff` | ❌ |
| `requestMtu` | ❌ |
| `createBond` / `removeBond` | ❌ |
| `setPreferredPhy` | ❌ |

#### Windows 平台：
- 核心包 **不直接支持 Windows**
- 需要使用第三方插件 `flutter_blue_plus_winrt` (v0.0.18)
- 该包由社区维护者 @chan150 维护，已获官方 endorse
- 许可：MIT License
- 总下载量约 49.3k

### 3. 当前项目版本和使用情况

**miniarm_flutter/pubspec.yaml:**
```yaml
flutter_blue_plus: ^2.2.1
permission_handler: ^11.4.0
```

**当前 BLE 使用模式** (`lib/service/ble_service.dart`):
- 使用 `FlutterBluePlus.adapterState` 流监听蓝牙开关状态
- 使用 `FlutterBluePlus.startScan()` + `FlutterBluePlus.scanResults` 扫描设备
- 使用 `FlutterBluePlus.stopScan()` 停止扫描
- 使用 `BluetoothDevice(remoteId: DeviceIdentifier(deviceId))` 创建设备对象
- 使用 `device.connect(license: License.free, timeout: ...)` 连接
- 使用 `device.requestMtu(250)` 请求 MTU
- 使用 `device.discoverServices()` 发现服务
- 使用 `characteristic.setNotifyValue(true)` 订阅通知
- 使用 `characteristic.write(bytes, withoutResponse: ...)` 写入数据
- 使用 `characteristic.onValueReceived.listen(...)` 接收数据

**受影响分析：**
- `BleService.adapterStateStream` — 在 Web 上不可用（adapterState 不支持）
- `scan()` / `stopScan()` — Web 上 stopScan 不可用
- `connect()` 中的 `requestMtu()` — Web 和 macOS 上不可用
- 整体：Web 上约 50% 的 API 调用会失败或不可用

### 4. 最近版本和破坏性变更

#### 最新版本：2.2.1（2 个月前发布）

**2.x 系列关键变更：**

| 版本 | 变更 |
|------|------|
| **2.2.0** | License 按公司规模分层收费 |
| **2.1.1** | Darwin RSSI nil-guard crash fix |
| **2.1.0** | 商用许可证要求 ≥15 人公司；endorse `flutter_blue_plus_winrt` |
| **2.0.0** | 切换到 FlutterBluePlus License（从 Apache 2.0 变为商业许可） |
| **1.36.8** | `isNotifying` bug fix；最后一个 Apache 2.0 版本 |

**⚠️ 重要：License 变更**
- 2.0.0+：需要商业许可证（≥15 名员工的公司）
- 个人使用、非营利组织、教育机构免费
- 当前 miniarm_flutter 代码中已使用 `license: License.free` 参数

#### 1.x → 2.x 主要破坏性变更回顾：

| 版本 | 破坏性变更 |
|------|-----------|
| 1.35.0 | 添加 Web、Linux、Platform Interface 支持 |
| 1.33.0 | iOS 18 兼容：`systemDevices` 需要 UUID 参数 |
| 1.29.0 | `scanResults` 在 `stopScan` 后不清空（需用 `onScanResults`） |
| 1.27.0 | `continuousUpdates` 默认改为 `false`（性能优化） |
| 1.22.0 | Android 默认请求 MTU 512 |
| 1.15.0 | 扫描 API 重构（移除 `FlutterBluePlus.scan`） |
| 1.10.0 | 静态 API 替代 `FlutterBluePlus.instance` |

### 5. 替代 BLE 插件方案

| 插件 | Web | Desktop | 特点 |
|------|-----|---------|------|
| **flutter_blue_plus** | 有限 | macOS/Linux 支持，Windows 需 winrt 扩展 | 最成熟，功能最全 |
| **flutter_reactive_ble** | ❌ | ❌ (仅 iOS/Android) | 响应式 API，适合简单场景 |
| **flutter_ble_lib** | ❌ | ❌ (仅 iOS/Android) | 较老，不再活跃维护 |
| **web_bluetooth** (Dart) | ✅ | ❌ (仅 Web) | Web Bluetooth API 原生绑定 |
| **quick_blue** | ❌ | macOS/Windows | 简化 API，Desktop 支持 |

### 6. 推荐的优雅降级模式

基于官方文档和实践，推荐的跨平台 BLE 优雅降级策略：

```dart
import 'package:flutter/foundation.dart';

// 检测平台是否真正支持 BLE
bool get isBleSupported {
  if (kIsWeb) {
    // Web 上需额外检查 Web Bluetooth API 可用性
    // flutter_blue_plus 内部会设置 isSupported
    return true; // 让 FlutterBluePlus.isSupported 来判断
  }
  return true; // 原生平台通常支持
}

// 连接前检查
Future<bool> canUseBle() async {
  if (!await FlutterBluePlus.isSupported) {
    // 显示"设备不支持蓝牙"UI
    return false;
  }
  return true;
}
```

**各平台降级建议：**

| 平台 | 策略 |
|------|------|
| **Web** | 检测 `FlutterBluePlus.isSupported`；扫描/连接最基本可用；缺失功能显示"当前平台不支持"提示 |
| **Windows** | 提示安装 `flutter_blue_plus_winrt` 或显示"Windows 暂不支持" |
| **Linux** | 基本可用；MTU 功能缺失需在写入时做长度限制 |
| **macOS** | 基本完整；缺少 MTU 手动设置（但系统会自动协商） |

### 7. Web Bluetooth API 注意事项

Flutter Web 上的 BLE 依赖浏览器的 [Web Bluetooth API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Bluetooth_API)：

- **浏览器支持有限**：目前仅 Chrome/Edge/Opera 支持（Firefox/Safari 不支持）
- **需要 HTTPS**：Web Bluetooth API 要求安全上下文（localhost 除外）
- **用户手势要求**：扫描等操作需要用户交互触发
- **权限弹窗**：浏览器会弹出设备选择对话框

## Caveats / Not Found

- `flutter_blue_plus_winrt` 的具体功能覆盖度未深入调研（仅查看了 pub.dev 页面）
- 没有找到 flutter_blue_plus 官方对于"完全无蓝牙环境"的 mock/降级建议文档
- 当前 miniarm_flutter 的 AndroidManifest.xml 尚未配置 BLE 权限（需添加 `BLUETOOTH_SCAN`、`BLUETOOTH_CONNECT` 等权限声明）
