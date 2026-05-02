import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/miniarm_viewmodel.dart';
import '../../../domain/models/device_state_model.dart';
import '../../../data/services/command_service.dart';
import 'move_screen.dart';
import 'direction_pad.dart';

/// 机械臂控制页面
class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  StreamSubscription? _connectionSub;

  static const int _min1 = 0, _max1 = 180;
  static const int _min2 = 0, _max2 = 80;
  static const int _min4 = 0, _max4 = 37;

  double _val1 = 90;
  double _val2 = 0;
  double _val3 = 180;
  double _val4 = 0;
  double _val5 = 0;

  double _cMin = 55;
  double _cMax = 180;
  DateTime _lastSend = DateTime(2000);

  @override
  void initState() {
    super.initState();
    _connectionSub =
        context.read<MiniArmViewModel>().bleService.connectionStateStream.listen(
              (state) {
                if (state == BleConnectionState.disconnected && mounted) {
                  Navigator.popUntil(context, (route) => route.isFirst);
                }
              },
            );
  }

  bool _throttleSend(VoidCallback sendFn) {
    final now = DateTime.now();
    if (now.difference(_lastSend).inMilliseconds < 100) return false;
    _lastSend = now;
    sendFn();
    return true;
  }

  void _updateCFromB(double bValue) {
    final b = bValue.round();
    setState(() {
      _cMin = (140 - b).toDouble();
      final countMin = 196 - b;
      _cMax = countMin <= 180 ? countMin.toDouble() : 180.0;
      if (_val3 < _cMin) _val3 = _cMin;
      if (_val3 > _cMax) _val3 = _cMax;
    });
  }

  void _sendAngleCommand() {
    final cmdService = context.read<MiniArmViewModel>().commandService;
    cmdService.sendAngleCmd(
      rot: _val1.round(),
      b: _val2.round(),
      c: _val3.round(),
      grip: _val4.round(),
      line: _val5.round(),
    );
  }

  void _sendLineCommand() {
    final cmdService = context.read<MiniArmViewModel>().commandService;
    cmdService.sendLineModuleCmd(_val5.round());
  }

  void _setPreset(int r, int b, int c, int g, [int l = 0]) {
    final newCMin = (140 - b).toDouble();
    final countMin = 196 - b;
    final newCMax = countMin <= 180 ? countMin.toDouble() : 180.0;
    var clampedC = c.toDouble();
    if (clampedC < newCMin) clampedC = newCMin;
    if (clampedC > newCMax) clampedC = newCMax;
    setState(() {
      _val1 = r.toDouble();
      _val2 = b.toDouble();
      _val3 = clampedC;
      _val4 = g.toDouble();
      _val5 = l.toDouble();
      _cMin = newCMin;
      _cMax = newCMax;
    });
    _sendAngleCommand();
    if (_val5.round() != 0) _sendLineCommand();
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MiniArmViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Mini-Arm ${vm.connectedDeviceMac ?? ''}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MoveScreen()),
              );
            },
            icon: const Icon(Icons.open_with),
            label: const Text('方向控制'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSlider('旋转', _val1, _min1.toDouble(), _max1.toDouble(),
              (v) => _val1 = v, () {
            _sendAngleCommand();
          }),
          _buildSlider('B轴', _val2, _min2.toDouble(), _max2.toDouble(),
              (v) => _val2 = v, () {
            _sendAngleCommand();
            _updateCFromB(_val2);
          }),
          _buildSlider('C轴', _val3, _cMin, _cMax, (v) => _val3 = v, () {
            _sendAngleCommand();
          }),
          _buildSlider('夹爪', _val4, _min4.toDouble(), _max4.toDouble(),
              (v) => _val4 = v, () {
            _sendAngleCommand();
          }),
          const SizedBox(height: 16),
          Row(
            children: [
              _presetButton(
                  '复位', Colors.blue, () => _setPreset(90, 0, 180, 0)),
              const SizedBox(width: 8),
              _presetButton('预设1', Colors.green,
                  () => _setPreset(130, 50, 130, 0)),
              const SizedBox(width: 8),
              _presetButton('预设2', Colors.orange,
                  () => _setPreset(100, 60, 120, 15)),
              const SizedBox(width: 8),
              _presetButton('预设3', Colors.purple,
                  () => _setPreset(50, 50, 125, 35)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    VoidCallback onSend,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$label 范围 ${min.toInt()}°-${max.toInt()}°'),
            Text('${value.round()}°',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: ((max - min).round()).clamp(0, 200),
          onChanged: (v) {
            setState(() {
              onChanged(v);
            });
            _throttleSend(onSend);
          },
          onChangeEnd: (v) {
            onSend();
          },
        ),
      ],
    );
  }

  Widget _presetButton(
      String label, Color color, VoidCallback onPressed) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
