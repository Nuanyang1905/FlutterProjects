import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../view_models/miniarm_viewmodel.dart';
import '../../../domain/models/ble_device_model.dart';
import 'control_screen.dart';

/// BLE 扫描页面
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mini-Arm 扫描'),
        actions: [
          if (context.watch<MiniArmViewModel>().isConnected)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  Icon(Icons.bluetooth_connected,
                      color: Colors.green, size: 20),
                  SizedBox(width: 4),
                  Text('已连接',
                      style: TextStyle(fontSize: 12, color: Colors.green)),
                ],
              ),
            ),
          Consumer<MiniArmViewModel>(
            builder: (context, vm, child) {
              return IconButton(
                icon: vm.isScanning
                    ? const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : const Icon(Icons.search),
                onPressed: vm.isScanning ? null : () => _startScan(context),
              );
            },
          ),
        ],
      ),
      body: Consumer<MiniArmViewModel>(
        builder: (context, vm, child) {
          if (vm.errorMessage != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(vm.errorMessage!)),
                );
                vm.clearError();
              }
            });
          }

          return Column(
            children: [
              if (vm.isConnecting)
                const LinearProgressIndicator(),
              // BLE 不支持的提示
              if (vm.devices.isEmpty && !vm.isScanning && !vm.isConnecting)
                const Expanded(
                  child: Center(
                    child: Text('点击右上角搜索按钮开始扫描'),
                  ),
                )
              else if (vm.devices.isEmpty && vm.isScanning)
                const Expanded(
                  child: Center(
                    child: Text('正在搜索设备...'),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: vm.devices.length,
                    itemBuilder: (context, index) {
                      final device = vm.devices[index];
                      return ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: Text(device.name),
                        subtitle: Text('${device.mac}\nRSSI: ${device.rssi}'),
                        trailing: ElevatedButton(
                          onPressed: vm.isConnecting
                              ? null
                              : () => _connectAndNavigate(context, vm, device),
                          child: const Text('连接'),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _startScan(BuildContext context) async {
    if (kIsWeb) {
      // Web 不支持 BLE
      context.read<MiniArmViewModel>().startScan();
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

    context.read<MiniArmViewModel>().startScan();
  }

  void _connectAndNavigate(
    BuildContext context,
    MiniArmViewModel vm,
    BleDeviceModel device,
  ) {
    vm.connectDevice(device).then((_) {
      if (vm.isConnected && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ControlScreen(),
          ),
        );
      }
    });
  }
}
