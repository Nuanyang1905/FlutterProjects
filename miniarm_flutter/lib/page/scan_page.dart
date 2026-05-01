import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../model/ble_device_model.dart';
import '../model/device_state_model.dart';
import '../service/ble_service.dart';
import 'control_page.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final BleService _bleService = BleService.instance;
  final List<BleDeviceModel> _devices = [];
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSub;
  StreamSubscription? _adapterSub;
  bool _isScanning = false;
  bool _isBluetoothOn = false;
  DeviceState _connectionState = DeviceState.disconnected;

  @override
  void initState() {
    super.initState();
    _connectionSub = _bleService.connectionStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _connectionState = state;
        });
      }
    });
    _adapterSub = _bleService.adapterStateStream.listen((on) {
      if (mounted) {
        setState(() {
          _isBluetoothOn = on;
        });
      }
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _bleService.stopScan();
    _isScanning = false;
    _connectionSub?.cancel();
    _adapterSub?.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (!_isBluetoothOn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请打开蓝牙')),
      );
      return;
    }

    final scanStatus = await Permission.bluetoothScan.request();
    if (!scanStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要蓝牙扫描权限才能搜索设备')),
        );
      }
      return;
    }

    final connectStatus = await Permission.bluetoothConnect.request();
    if (!connectStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要蓝牙连接权限才能连接设备')),
        );
      }
      return;
    }

    setState(() {
      _devices.clear();
      _isScanning = true;
    });

    _scanSubscription = _bleService.scan().listen((results) {
      if (!mounted) return;
      final list = _bleService.scanResultsToList(results);
      setState(() {
        _devices
          ..clear()
          ..addAll(list);
      });
    });
  }

  void _stopScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _bleService.stopScan();
    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _connectAndNavigate(BleDeviceModel device) async {
    if (!_bleService.isMiniArmDevice(device)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请选择名称为 Mini-Arm 的设备')),
        );
      }
      return;
    }

    if (_connectionState == DeviceState.connected) {
      _navigateToControl();
      return;
    }

    setState(() {
      _connectionState = DeviceState.connecting;
    });

    _stopScan();

    try {
      await _bleService.connect(device.mac);
      if (mounted) {
        _navigateToControl();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionState = DeviceState.disconnected;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接失败: $e')),
        );
      }
    }
  }

  void _navigateToControl() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ControlPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mini-Arm 扫描'),
        actions: [
          if (_connectionState == DeviceState.connected)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  Icon(Icons.bluetooth_connected, color: Colors.green, size: 20),
                  SizedBox(width: 4),
                  Text('已连接', style: TextStyle(fontSize: 12, color: Colors.green)),
                ],
              ),
            ),
          IconButton(
            icon: _isScanning
                ? const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : const Icon(Icons.search),
            onPressed: _isScanning ? null : _startScan,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_connectionState == DeviceState.connecting)
            const LinearProgressIndicator(),
          if (_devices.isEmpty && !_isScanning)
            const Expanded(
              child: Center(
                child: Text('点击右上角搜索按钮开始扫描'),
              ),
            )
          else if (_devices.isEmpty && _isScanning)
            const Expanded(
              child: Center(
                child: Text('正在搜索设备...'),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  return ListTile(
                    leading: const Icon(Icons.bluetooth),
                    title: Text(device.name),
                    subtitle: Text('${device.mac}\nRSSI: ${device.rssi}'),
                    trailing: ElevatedButton(
                      onPressed: _connectionState == DeviceState.connecting
                          ? null
                          : () => _connectAndNavigate(device),
                      child: const Text('连接'),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
