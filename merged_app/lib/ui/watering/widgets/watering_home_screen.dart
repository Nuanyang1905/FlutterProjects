import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/device_state.dart';
import '../../settings/widgets/settings_screen.dart';
import '../../../data/services/bemfa_api_service.dart';
import '../view_models/watering_viewmodel.dart';

/// 浇水模块主页
class WateringHomeScreen extends StatefulWidget {
  const WateringHomeScreen({super.key});

  @override
  State<WateringHomeScreen> createState() => _WateringHomeScreenState();
}

class _WateringHomeScreenState extends State<WateringHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WateringViewModel>().connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Consumer<WateringViewModel>(
        builder: (context, provider, child) {
          return RefreshIndicator(
            onRefresh: () => provider.reconnect(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HumidityCard(deviceState: provider.deviceState),
                  const SizedBox(height: 16),
                  _PumpControlCard(
                    deviceState: provider.deviceState,
                    isConnected: provider.isConnected,
                    isOperating: provider.isOperating,
                    onTogglePump: provider.togglePump,
                    onSetAutoMode: provider.setAutoMode,
                    onSetManualMode: provider.setManualMode,
                    onUnlock: provider.clearProtectionLock,
                  ),
                  const SizedBox(height: 16),
                  _ThresholdCard(
                    deviceState: provider.deviceState,
                    isConnected: provider.isConnected,
                    onThresholdChange: provider.setThreshold,
                  ),
                  const SizedBox(height: 16),
                  _ConnectionStatusBar(
                    connectionState: provider.connectionState,
                    lastUpdate: provider.deviceState.lastUpdate,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.eco, size: 24),
          SizedBox(width: 8),
          Text('匠心农场'),
        ],
      ),
      centerTitle: true,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ==================== 湿度卡片 ====================

class _HumidityCard extends StatelessWidget {
  final DeviceState deviceState;

  const _HumidityCard({required this.deviceState});

  @override
  Widget build(BuildContext context) {
    final humidity = deviceState.humidity;
    final thL = deviceState.thL;
    final thH = deviceState.thH;
    final hasData = deviceState.hasReceivedData;

    Color statusColor;
    final statusText = hasData ? deviceState.humidityStatus : '等待数据';

    if (!hasData) {
      statusColor = Colors.grey;
    } else if (!deviceState.isSensorOk) {
      statusColor = Colors.deepOrange;
    } else if (deviceState.isLocked) {
      statusColor = Colors.amber[800]!;
    } else if (humidity < thL) {
      statusColor = Colors.red;
    } else if (humidity < thH) {
      statusColor = Colors.blue;
    } else if (humidity < thH + 10) {
      statusColor = Colors.green;
    } else {
      statusColor = Colors.blue;
    }

    return Card(
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.water_drop, color: Colors.blue[400], size: 18),
                const SizedBox(width: 6),
                const Text(
                  '土壤湿度',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    hasData && deviceState.isSensorOk ? '$humidity' : '--',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                      height: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      '%',
                      style:
                          TextStyle(fontSize: 24, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: hasData ? humidity / 100 : 0,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                '${_buildSensorSummary(hasData)} · 原始值 ${deviceState.rawValue}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildSensorSummary(bool hasData) {
    if (!hasData) return '等待数据';
    if (!deviceState.isSensorOk) return '传感器数据异常';

    final humidity = deviceState.humidity;
    if (humidity < deviceState.thL) return '土壤偏干';
    if (humidity < deviceState.thH) return '土壤正在回湿';
    if (humidity < deviceState.thH + 10) return '土壤湿度适中';
    return '土壤较湿润';
  }
}

// ==================== 水泵控制卡片 ====================

class _PumpControlCard extends StatelessWidget {
  final DeviceState deviceState;
  final bool isConnected;
  final bool isOperating;
  final Future<bool> Function() onTogglePump;
  final Future<bool> Function() onSetAutoMode;
  final Future<bool> Function() onSetManualMode;
  final Future<bool> Function() onUnlock;

  const _PumpControlCard({
    required this.deviceState,
    required this.isConnected,
    required this.isOperating,
    required this.onTogglePump,
    required this.onSetAutoMode,
    required this.onSetManualMode,
    required this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    final isAutoMode = deviceState.isAutoMode;
    final isPumpOn = deviceState.isPumpOn;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.opacity, color: Colors.blue[400], size: 18),
                const SizedBox(width: 6),
                const Text(
                  '水泵控制',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 水泵状态
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isPumpOn ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isPumpOn ? '正在浇水' : '已关闭',
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            isPumpOn ? Colors.green : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: isPumpOn,
                  onChanged: isAutoMode || !isConnected || isOperating
                      ? null
                      : (value) => onTogglePump(),
                  activeThumbColor: Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            // 模式切换
            const Text('工作模式', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment<bool>(
                    value: true,
                    icon: Icon(Icons.auto_mode, size: 18),
                    label: Text('自动'),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    icon: Icon(Icons.pan_tool, size: 18),
                    label: Text('手动'),
                  ),
                ],
                selected: {isAutoMode},
                onSelectionChanged: !isConnected || isOperating
                    ? null
                    : (selection) {
                        final targetAuto = selection.first;
                        if (targetAuto == isAutoMode) return;
                        if (targetAuto) {
                          onSetAutoMode();
                        } else {
                          onSetManualMode();
                        }
                      },
              ),
            ),
            const SizedBox(height: 6),
            Text(
              !deviceState.isSensorOk
                  ? '传感器异常，自动模式不会开泵'
                  : deviceState.isLocked
                      ? '已触发超时保护锁，需解锁后才能恢复自动控制'
                      : isAutoMode
                          ? '低于下限${deviceState.thL}%开泵，浇到上限${deviceState.thH}%关泵'
                          : '手动模式最长保持 12 小时',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (deviceState.isLocked) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      !isConnected || isOperating ? null : () => onUnlock(),
                  icon: const Icon(Icons.lock_open),
                  label: const Text('清除保护锁'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================== 阈值调节卡片 ====================

class _ThresholdCard extends StatefulWidget {
  final DeviceState deviceState;
  final bool isConnected;
  final Future<bool> Function(int lower, int upper) onThresholdChange;

  const _ThresholdCard({
    required this.deviceState,
    required this.isConnected,
    required this.onThresholdChange,
  });

  @override
  State<_ThresholdCard> createState() => _ThresholdCardState();
}

class _ThresholdCardState extends State<_ThresholdCard> {
  late double _sliderValueLower;
  late double _sliderValueUpper;

  @override
  void initState() {
    super.initState();
    _sliderValueLower = widget.deviceState.thL.toDouble();
    _sliderValueUpper = widget.deviceState.thH.toDouble();
  }

  @override
  void didUpdateWidget(_ThresholdCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deviceState.thL != widget.deviceState.thL ||
        oldWidget.deviceState.thH != widget.deviceState.thH) {
      _sliderValueLower = widget.deviceState.thL.toDouble();
      _sliderValueUpper = widget.deviceState.thH.toDouble();
    }
  }

  void _onSliderChanged() {
    if (_sliderValueLower > _sliderValueUpper) {
      _sliderValueLower = _sliderValueUpper;
    }
    setState(() {});
    widget.onThresholdChange(
      _sliderValueLower.round(),
      _sliderValueUpper.round(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final thL = _sliderValueLower.round();
    final thH = _sliderValueUpper.round();

    return Card(
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: Colors.blue[400], size: 18),
                const SizedBox(width: 6),
                const Text(
                  '阈值设置',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 下限滑块
            Row(
              children: [
                const Text('下限:', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: _sliderValueLower,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${_sliderValueLower.round()}%',
                    onChanged: widget.isConnected
                        ? (value) {
                            setState(() {
                              _sliderValueLower = value;
                            });
                          }
                        : null,
                    onChangeEnd: (_) => _onSliderChanged(),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${_sliderValueLower.round()}%',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            // 上限滑块
            Row(
              children: [
                const Text('上限:', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: _sliderValueUpper,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${_sliderValueUpper.round()}%',
                    onChanged: widget.isConnected
                        ? (value) {
                            setState(() {
                              _sliderValueUpper = value;
                            });
                          }
                        : null,
                    onChangeEnd: (_) => _onSliderChanged(),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${_sliderValueUpper.round()}%',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '低于 $thL% 开泵，浇到 $thH% 关泵',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 连接状态栏 ====================

class _ConnectionStatusBar extends StatelessWidget {
  final AppDeviceConnectionState connectionState;
  final DateTime? lastUpdate;

  const _ConnectionStatusBar({
    required this.connectionState,
    required this.lastUpdate,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String text;

    switch (connectionState) {
      case AppDeviceConnectionState.online:
        icon = Icons.link;
        color = Colors.green;
        text = '设备在线';
        break;
      case AppDeviceConnectionState.checking:
        icon = Icons.sync;
        color = Colors.orange;
        text = '正在检测...';
        break;
      case AppDeviceConnectionState.failed:
        icon = Icons.error_outline;
        color = Colors.red;
        text = '请求失败';
        break;
      case AppDeviceConnectionState.disconnected:
        icon = Icons.link_off;
        color = Colors.grey;
        text = '设备离线';
        break;
    }

    String updateTimeText;
    if (lastUpdate == null) {
      updateTimeText = '等待数据...';
    } else {
      final diff = DateTime.now().difference(lastUpdate!);
      if (diff.inSeconds < 5) {
        updateTimeText = '刚刚';
      } else if (diff.inSeconds < 60) {
        updateTimeText = '${diff.inSeconds}秒前';
      } else if (diff.inMinutes < 60) {
        updateTimeText = '${diff.inMinutes}分钟前';
      } else {
        updateTimeText = '很久之前';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (connectionState == AppDeviceConnectionState.checking)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            )
          else
            Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 12, color: color)),
          const SizedBox(width: 16),
          Text(
            '· $updateTimeText',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
