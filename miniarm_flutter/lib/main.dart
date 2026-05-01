import 'package:flutter/material.dart';

import 'page/scan_page.dart';
import 'service/ble_service.dart';

void main() {
  runApp(const MiniArmApp());
}

class MiniArmApp extends StatefulWidget {
  const MiniArmApp({super.key});

  @override
  State<MiniArmApp> createState() => _MiniArmAppState();
}

class _MiniArmAppState extends State<MiniArmApp> {
  @override
  void dispose() {
    BleService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mini-Arm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const ScanPage(),
    );
  }
}
