import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/settings_provider.dart';
import '../../providers/tunnel_provider.dart';
import '../../../data/models/settings.dart';

/// Settings screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Server Settings
          _buildSectionHeader(context, 'Server'),
          _buildPortSetting(
            context: context,
            title: 'API Port',
            value: settings.apiPort,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setApiPort(value);
            },
          ),
          _buildPortSetting(
            context: context,
            title: 'Web UI Port',
            value: settings.webPort,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setWebPort(value);
            },
          ),
          const SizedBox(height: 24),

          // Session Settings
          _buildSectionHeader(context, 'Sessions'),
          _buildTextSetting(
            context: context,
            title: 'Session Prefix',
            value: settings.sessionPrefix,
            hint: 'vibe',
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setSessionPrefix(value);
            },
          ),
          _buildDropdownSetting(
            context: context,
            title: 'Terminal App',
            value: settings.terminalApp,
            items: [
              const DropdownMenuItem(
                value: TerminalApp.terminal,
                child: Text('Terminal.app'),
              ),
              const DropdownMenuItem(
                value: TerminalApp.iterm,
                child: Text('iTerm'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                ref.read(settingsProvider.notifier).setTerminalApp(value);
              }
            },
          ),
          const SizedBox(height: 24),

          // Startup Settings
          _buildSectionHeader(context, 'Startup'),
          _buildSwitchSetting(
            context: context,
            title: 'Auto-start API Server',
            subtitle: 'Start the API server when app launches',
            value: settings.autoStartServer,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setAutoStartServer(value);
            },
          ),
          _buildSwitchSetting(
            context: context,
            title: 'Auto-start Web UI',
            subtitle: 'Start the Web UI server when app launches',
            value: settings.autoStartWeb,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setAutoStartWeb(value);
            },
          ),
          _buildSwitchSetting(
            context: context,
            title: 'Launch at Login',
            subtitle: 'Open VibeMobile when you log in',
            value: settings.launchAtLogin,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setLaunchAtLogin(value);
            },
          ),
          const SizedBox(height: 24),

          // Tunnel Settings
          _buildSectionHeader(context, 'Remote Access'),
          _buildSwitchSetting(
            context: context,
            title: 'Enable Tunnel',
            subtitle: 'Allow remote access through a secure tunnel provider',
            value: settings.enableTunnel,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setEnableTunnel(value);
            },
          ),
          if (settings.enableTunnel) ...[
            _buildDropdownSetting(
              context: context,
              title: 'Tunnel Provider',
              value: settings.tunnelProvider,
              items: const [
                DropdownMenuItem(
                  value: RemoteTunnelProvider.cloudflare,
                  child: Text('Cloudflare Tunnel'),
                ),
                DropdownMenuItem(
                  value: RemoteTunnelProvider.microsoftDevTunnel,
                  child: Text('Microsoft Dev Tunnel'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  ref.read(settingsProvider.notifier).setTunnelProvider(value);
                }
              },
            ),
            if (settings.tunnelProvider == RemoteTunnelProvider.microsoftDevTunnel)
              _buildDevTunnelLoginSetting(context, ref),
            if (settings.tunnelProvider == RemoteTunnelProvider.cloudflare) ...[
              _buildTextSetting(
                context: context,
                title: 'Tunnel Name (Optional)',
                value: settings.tunnelName ?? '',
                hint: 'my-tunnel',
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).setTunnelName(value.isEmpty ? null : value);
                },
              ),
              _buildTextSetting(
                context: context,
                title: 'Tunnel Hostname (Optional)',
                value: settings.tunnelHostname ?? '',
                hint: 'vibe.example.com',
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).setTunnelHostname(value.isEmpty ? null : value);
                },
              ),
            ],
            _buildTextSetting(
              context: context,
              title: 'Proxy URL (Optional)',
              value: settings.proxyUrl ?? '',
              hint: 'http://127.0.0.1:7890',
              onChanged: (value) {
                ref.read(settingsProvider.notifier).setProxyUrl(value.isEmpty ? null : value);
              },
            ),
          ],
          const SizedBox(height: 24),

          // Reset Settings
          Center(
            child: OutlinedButton.icon(
              onPressed: () => _confirmReset(context, ref),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              icon: const Icon(Icons.restore),
              label: const Text('Reset to Defaults'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPortSetting({
    required BuildContext context,
    required String title,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: SizedBox(
          width: 100,
          child: TextFormField(
            initialValue: value.toString(),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (text) {
              final port = int.tryParse(text);
              if (port != null && port > 0 && port < 65536) {
                onChanged(port);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTextSetting({
    required BuildContext context,
    required String title,
    required String value,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: SizedBox(
          width: 200,
          child: TextFormField(
            initialValue: value,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              hintText: hint,
            ),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchSetting({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDropdownSetting<T>({
    required BuildContext context,
    required String title,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          underline: const SizedBox(),
        ),
      ),
    );
  }

  Widget _buildDevTunnelLoginSetting(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: const Text('Microsoft Account'),
        subtitle: const Text('Sign in once to create Microsoft Dev Tunnels.'),
        trailing: OutlinedButton(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final success = await ref.read(tunnelServiceProvider).loginDevTunnel();
            if (!context.mounted) return;
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  success
                      ? 'Microsoft Dev Tunnel sign-in completed.'
                      : 'Sign-in did not complete. Try running devtunnel user login in Terminal.',
                ),
              ),
            );
          },
          child: const Text('Sign In'),
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('Are you sure you want to reset all settings to their default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(settingsProvider.notifier).resetToDefaults();
    }
  }
}
