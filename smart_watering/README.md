# smart_watering

匠心农场智能浇水应用，基于 Flutter 开发，支持 Android、iOS、Web 和桌面平台。应用通过巴法云 HTTP API 轮询设备状态，实时展示土壤湿度，并支持自动/手动浇水控制。

## 核心能力

- 多平台运行，统一通过 HTTP API 轮询设备状态
- 兼容两种设备状态协议：JSON 新格式和 `#` 分隔旧格式
- 支持自动模式双阈值控制，减少湿度临界点附近的频繁启停
- API 配置可持久化保存，设置变更后自动刷新
- 提供连接日志，方便排查设备和云端通信问题

## 默认 API 配置

- UID：`f148fce62c08490e9ffe25b43948c5c8`
- 控制主题：`plant001`
- 上报主题：`plant001up`
- 设备类型：`1`

## 快速开始

```bash
flutter pub get
flutter run
```

常用命令：

```bash
flutter analyze
flutter test
flutter run -d chrome
flutter run -d windows
flutter build apk
flutter build web
```

## 数据协议

接收设备状态支持两种格式：

```json
{"hum":45,"mode":"auto","pump":0,"th_L":30,"th_H":60,"lock":0}
```

```text
#45#1#30#1
```

发送控制指令：

- `on`：手动开泵
- `off`：手动关泵
- `auto`：切换自动模式
- `set:30,60`：设置双阈值
- `t:40`：旧版单阈值兼容指令

## 项目结构

```text
lib/
  config/      API 配置模型
  models/      设备状态解析与展示逻辑
  providers/   应用状态管理
  screens/     主页面与设置页面
  services/    巴法云 API 和本地存储服务
```

## 测试与质量

- `flutter analyze`：静态检查
- `flutter test`：覆盖设备状态解析、配置模型、关键状态切换和设置页基础展示

更多设计约束和协议细节请参考 [AGENTS.md](./AGENTS.md) 与 [DEV_SPEC.md](./DEV_SPEC.md)。
