import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/settings_viewmodel.dart';
import '../../watering/view_models/watering_viewmodel.dart';

/// 统一设置页面
///
/// 包含巴法云 API 配置和 BLE 设备配置
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _uidController;
  late TextEditingController _controlTopicController;
  late TextEditingController _reportTopicController;
  late TextEditingController _typeController;
  late TextEditingController _bleDeviceNameController;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();

    final config = context.read<SettingsViewModel>().config;
    _uidController = TextEditingController(text: config.uid);
    _controlTopicController =
        TextEditingController(text: config.controlTopic);
    _reportTopicController =
        TextEditingController(text: config.reportTopic);
    _typeController = TextEditingController(text: config.type.toString());
    _bleDeviceNameController =
        TextEditingController(text: config.bleDeviceName);
  }

  @override
  void dispose() {
    _uidController.dispose();
    _controlTopicController.dispose();
    _reportTopicController.dispose();
    _typeController.dispose();
    _bleDeviceNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text('设置'), centerTitle: true, elevation: 0),
      body: Consumer2<SettingsViewModel, WateringViewModel>(
        builder: (context, settingsProvider, wateringProvider, child) {
          return ListView(
            children: [
              // 巴法云 API 配置
              _buildSectionHeader('巴法云 API 配置'),
              _buildConfigTile(
                icon: Icons.key,
                title: 'UID (私钥)',
                controller: _uidController,
                keyboardType: TextInputType.text,
                obscureText: true,
              ),
              _buildConfigTile(
                icon: Icons.topic,
                title: '控制主题',
                controller: _controlTopicController,
                keyboardType: TextInputType.text,
              ),
              _buildConfigTile(
                icon: Icons.cloud_upload,
                title: '上报主题',
                controller: _reportTopicController,
                keyboardType: TextInputType.text,
              ),
              _buildConfigTile(
                icon: Icons.memory,
                title: '设备类型 (Type)',
                controller: _typeController,
                keyboardType: TextInputType.number,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  '状态轮询使用上报主题 (建议为 topicup，例如 plant001up)。',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),

              const Divider(height: 32),

              // BLE 设备配置
              _buildSectionHeader('BLE 设备配置'),
              _buildConfigTile(
                icon: Icons.bluetooth,
                title: '目标设备名称',
                controller: _bleDeviceNameController,
                keyboardType: TextInputType.text,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'BLE 扫描时按此名称过滤设备。',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),

              const Divider(height: 32),

              // 应用配置按钮
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton.icon(
                  onPressed: _isApplying
                      ? null
                      : () => _applyConfig(context),
                  icon: _isApplying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(_isApplying ? '应用中...' : '应用配置并刷新'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const Divider(height: 32),

              // 调试信息
              _buildSectionHeader('调试信息'),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('连接日志'),
                trailing: Text(
                  '${wateringProvider.logs.length} 条',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                onTap: () =>
                    _showLogsDialog(context, wateringProvider.logs),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('清除日志'),
                onTap: () {
                  wateringProvider.clearLogs();
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('日志已清除')));
                },
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('重置为默认配置'),
                onTap: () =>
                    _showResetConfirmDialog(context, settingsProvider),
              ),

              const Divider(height: 32),

              // 关于
              _buildSectionHeader('关于'),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('版本'),
                trailing: Text('1.0.0'),
              ),
              const ListTile(
                leading: Icon(Icons.code),
                title: Text('开发者'),
                trailing: Text('匠心农场'),
              ),
              const ListTile(
                leading: Icon(Icons.water_drop),
                title: Text('云平台'),
                trailing: Text('巴法云'),
              ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Future<void> _applyConfig(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final uid = _uidController.text.trim();
    final controlTopic = _controlTopicController.text.trim();
    final reportTopic = _reportTopicController.text.trim();
    final type = int.tryParse(_typeController.text.trim());
    final bleDeviceName = _bleDeviceNameController.text.trim();

    final errorMessage = _validateConfigInputs(
      uid: uid,
      controlTopic: controlTopic,
      reportTopic: reportTopic,
      type: type,
    );
    if (errorMessage != null) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
      return;
    }

    setState(() {
      _isApplying = true;
    });

    try {
      final settingsProvider = context.read<SettingsViewModel>();
      final newConfig = settingsProvider.config.copyWith(
        uid: uid,
        controlTopic: controlTopic,
        reportTopic: reportTopic,
        type: type!,
        bleDeviceName: bleDeviceName,
      );
      await settingsProvider.updateConfig(newConfig);
      await settingsProvider.flush();
      if (!mounted) return;
      messenger
          .showSnackBar(const SnackBar(content: Text('配置已应用')));
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }

  String? _validateConfigInputs({
    required String uid,
    required String controlTopic,
    required String reportTopic,
    required int? type,
  }) {
    if (uid.isEmpty) return 'UID 不能为空';
    if (controlTopic.isEmpty) return '控制主题不能为空';
    if (reportTopic.isEmpty) return '上报主题不能为空';
    if (type == null || type < 1) {
      return '设备类型 (Type) 必须为正整数';
    }
    return null;
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildConfigTile({
    required IconData icon,
    required String title,
    required TextEditingController controller,
    required TextInputType keyboardType,
    bool obscureText = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue[400]),
      title: Text(title),
      trailing: SizedBox(
        width: 150,
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          textAlign: TextAlign.end,
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
    );
  }

  void _showLogsDialog(BuildContext context, List<String> logs) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('连接日志'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: logs.isEmpty
                ? const Center(child: Text('暂无日志'))
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          logs[index],
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  void _showResetConfirmDialog(
    BuildContext context,
    SettingsViewModel provider,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认重置'),
          content: const Text('确定要重置为默认配置吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                provider.resetToDefault();

                _uidController.text = provider.config.uid;
                _controlTopicController.text =
                    provider.config.controlTopic;
                _reportTopicController.text =
                    provider.config.reportTopic;
                _typeController.text = provider.config.type.toString();
                _bleDeviceNameController.text =
                    provider.config.bleDeviceName;

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已重置为默认配置')),
                );
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }
}
