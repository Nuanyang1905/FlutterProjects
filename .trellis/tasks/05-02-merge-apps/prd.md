# 整合 miniarm 和 smart_watering 两个应用

## Goal

将 miniarm_flutter（BLE 机械臂遥控）和 smart_watering（智能浇水）合并为统一的"匠心农场" Flutter 应用，底部三 Tab 导航（浇水 / 机械臂 / 设置）。

## Requirements

- [ ] 单 Flutter 项目，共享 pubspec.yaml，统合所有依赖
- [ ] 底部 NavigationBar 三 Tab：浇水、机械臂、设置
- [ ] 浇水模块功能完整：湿度监控、水泵控制、模式切换、双阈值滞回控制
- [ ] 机械臂模块功能完整：BLE 扫描/连接、角度滑条控制、方向键移动、预设姿态
- [ ] 统一状态管理：Provider + ChangeNotifier（miniarm 从 setState 迁移）
- [ ] BLE 跨平台降级：Web/桌面显示"该平台不支持 BLE"，不崩溃
- [ ] 统一设置页：巴法云 API 配置 + BLE 设备配置
- [ ] 目录按模块组织：ui/watering, ui/miniarm, ui/settings，为未来扩展预留
- [ ] 模块间预留联动 hook，MVP 不实现

## Acceptance Criteria

- [ ] App 启动后底部 Tab 可切换三个页面
- [ ] 浇水 Tab 内：湿度卡片实时更新、水泵开关/模式切换正常、双阈值滑块可调节
- [ ] 机械臂 Tab 内：可扫描/连接 BLE 设备、角度控制/方向控制/预设功能正常
- [ ] 设置 Tab：巴法云 API 配置可编辑保存、BLE 设备名称可配置
- [ ] 非 Android/iOS 平台打开机械臂 Tab 时显示降级提示，浇水功能正常
- [ ] flutter analyze 零错误
- [ ] 两个模块互不干扰

## Definition of Done

- 一个 Flutter 项目  编译运行
- Lint / typecheck 通过
- 浇水模块和机械臂模块原有功能均正常

## Technical Approach

### 基座选择
以 smart_watering 为基座，其 Provider 分层架构（screens → providers → services → models）作为统一架构基础。

### 目录结构


### 关键技术决策

| 决策 | 选择 | 原因 |
|---|---|---|
| 状态管理 | Provider + ChangeNotifier 统一 | smart_watering 已用 |
| package | 单 package + 目录约定 | 2 模块无需 monorepo |
| BLE 跨平台 | BleServiceInterface + MobileBleService / NoopBleService | Web/桌面降级不崩溃 |
| miniarm 改造 | 单例→构造注入，setState→ViewModel | 可测试，架构一致 |
| 方向键性能 | DirectionPad 直接持有 BleService 引用 | 避免高频 notifyListeners 引起全树重建 |
| 导航 | 底部 NavigationBar 三 Tab | 浇水/机械臂/设置 |

### 实施计划

| PR | 内容 |
|---|---|
| PR1 基建 | 创建合并项目、合并依赖、app.dart + MultiProvider、主题/导航骨架 |
| PR2 浇水 | 移植 smart_watering 代码到新目录结构 |
| PR3 机械臂 | 重构 miniarm（单例→注入，setState→Provider），移植到新目录，BLE 平台降级 |
| PR4 收尾 | 统一设置页、lint/typecheck、测试 |

### 关键注意事项

1. miniarm 需补 Android BLE 权限声明（BLUETOOTH_SCAN / BLUETOOTH_CONNECT）
2. miniarm 的 DEV_SPEC.md 与实际代码不一致（描述 MQTT 但代码用 HTTP）
3. 方向键高频发送不能走 ViewModel.notifyListeners()，需直接注入 BleService
4. Web/桌面 BLE 仅降级提示，不实际运行

## Decision (ADR-lite)

- **Context**: 两个独立 Flutter IoT 应用需合并为统一入口
- **Decision**: 以 smart_watering（Provider架构）为基座，单 package + 混合目录结构（UI按feature，data按type），BLE 抽象接口降级
- **Consequences**: miniarm 需重构（单例→注入，setState→Provider）；后续可直接在 ui/ 下加新模块目录

## Out of Scope

- 多设备管理（多个浇水区域/机械臂）
- 模块间实际联动逻辑（仅预留 hook）
- Web/桌面 BLE 实际运行（仅降级提示）
- go_router 迁移
- 深色模式 / i18n

## Research References

- [research/flutter-modular-architecture.md](research/flutter-modular-architecture.md) — 混合目录结构 + MVVM + 单 package
- [research/ble-platform-support.md](research/ble-platform-support.md) — BLE 平台矩阵，Web 50% API 不可用
- [research/bemfa-api-status.md](research/bemfa-api-status.md) — 巴法云 API 无变更，与现有代码匹配

## Technical Notes

- miniarm: lib/ 下 9 文件 ~1000 行，BLE 队列 + 定时器，C 轴动态联动
- smart_watering: lib/ 下 9 文件 ~2300 行，Provider 分层，HTTP 轮询，三格式兼容
- 共同依赖：cupertino_icons, flutter_lints（可共享）
- 差异：flutter_blue_plus 仅 Android/iOS/macOS/Linux 可用
