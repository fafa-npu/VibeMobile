import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../models/settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiPortController;
  late TextEditingController _webPortController;
  late TextEditingController _prefixController;
  late TextEditingController _tunnelNameController;
  late TextEditingController _hostnameController;

  late Settings _settings;

  @override
  void initState() {
    super.initState();
    _settings = context.read<AppProvider>().settings;

    _apiPortController = TextEditingController(text: _settings.apiPort.toString());
    _webPortController = TextEditingController(text: _settings.webPort.toString());
    _prefixController = TextEditingController(text: _settings.sessionPrefix);
    _tunnelNameController = TextEditingController(text: _settings.tunnelName ?? '');
    _hostnameController = TextEditingController(text: _settings.tunnelHostname ?? '');
  }

  @override
  void dispose() {
    _apiPortController.dispose();
    _webPortController.dispose();
    _prefixController.dispose();
    _tunnelNameController.dispose();
    _hostnameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surface,
        title: const Text('设置'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service settings
            _buildSectionHeader(context, Icons.dns_outlined, '服务配置'),
            const SizedBox(height: 16),
            _buildSettingsCard(
              context,
              children: [
                _buildTextField(
                  controller: _apiPortController,
                  label: 'API 端口',
                  hint: '8765',
                  icon: Icons.api,
                  keyboardType: TextInputType.number,
                ),
                const Divider(height: 24),
                _buildTextField(
                  controller: _webPortController,
                  label: 'Web 端口',
                  hint: '5173',
                  icon: Icons.web,
                  keyboardType: TextInputType.number,
                ),
                const Divider(height: 24),
                _buildTextField(
                  controller: _prefixController,
                  label: '会话前缀',
                  hint: 'vibe',
                  icon: Icons.label_outline,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Startup settings
            _buildSectionHeader(context, Icons.rocket_launch_outlined, '启动选项'),
            const SizedBox(height: 16),
            _buildSettingsCard(
              context,
              children: [
                _buildSwitchTile(
                  title: '开机自启动',
                  subtitle: '登录时自动启动 VibeMobile',
                  icon: Icons.power_settings_new,
                  value: _settings.launchAtLogin,
                  onChanged: (value) {
                    setState(() {
                      _settings = _settings.copyWith(launchAtLogin: value);
                    });
                  },
                ),
                const Divider(height: 8),
                _buildSwitchTile(
                  title: '自动启动服务',
                  subtitle: '打开应用时自动启动后端服务',
                  icon: Icons.play_circle_outline,
                  value: _settings.autoStartServer,
                  onChanged: (value) {
                    setState(() {
                      _settings = _settings.copyWith(autoStartServer: value);
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Terminal settings
            _buildSectionHeader(context, Icons.terminal, '终端设置'),
            const SizedBox(height: 16),
            _buildSettingsCard(
              context,
              children: [
                _buildDropdownTile(
                  title: '默认终端',
                  subtitle: '连接会话时使用的终端应用',
                  icon: Icons.computer,
                  value: _settings.terminalApp,
                  items: const [
                    DropdownMenuItem(
                      value: TerminalApp.terminal,
                      child: Text('Terminal.app'),
                    ),
                    DropdownMenuItem(
                      value: TerminalApp.iterm,
                      child: Text('iTerm'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _settings = _settings.copyWith(terminalApp: value);
                      });
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Remote access settings
            _buildSectionHeader(context, Icons.cloud_outlined, '远程访问'),
            const SizedBox(height: 16),
            _buildSettingsCard(
              context,
              children: [
                _buildSwitchTile(
                  title: '启用 Cloudflare Tunnel',
                  subtitle: '通过 Tunnel 实现远程访问',
                  icon: Icons.vpn_key_outlined,
                  value: _settings.enableTunnel,
                  onChanged: (value) {
                    setState(() {
                      _settings = _settings.copyWith(enableTunnel: value);
                    });
                  },
                ),
                if (_settings.enableTunnel) ...[
                  const Divider(height: 24),
                  _buildTextField(
                    controller: _tunnelNameController,
                    label: 'Tunnel 名称',
                    hint: 'vibe-tunnel',
                    icon: Icons.label_outline,
                  ),
                  const Divider(height: 24),
                  _buildTextField(
                    controller: _hostnameController,
                    label: '域名',
                    hint: 'vibe.example.com',
                    icon: Icons.link,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 40),

            // Save button
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _saveSettings,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('保存设置'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, IconData icon, String title) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(BuildContext context, {required List<Widget> children}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.outline),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: controller,
                keyboardType: keyboardType,
                decoration: InputDecoration(
                  hintText: hint,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.outline),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDropdownTile<T>({
    required String title,
    required String subtitle,
    required IconData icon,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.outline),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            underline: const SizedBox(),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    );
  }

  void _saveSettings() {
    final apiPort = int.tryParse(_apiPortController.text) ?? 8765;
    final webPort = int.tryParse(_webPortController.text) ?? 5173;
    final newSettings = _settings.copyWith(
      apiPort: apiPort,
      webPort: webPort,
      sessionPrefix: _prefixController.text.isNotEmpty
          ? _prefixController.text
          : 'vibe',
      tunnelName: _tunnelNameController.text.isNotEmpty
          ? _tunnelNameController.text
          : null,
      tunnelHostname: _hostnameController.text.isNotEmpty
          ? _hostnameController.text
          : null,
    );

    context.read<AppProvider>().saveSettings(newSettings);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('设置已保存'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    Navigator.pop(context);
  }
}
