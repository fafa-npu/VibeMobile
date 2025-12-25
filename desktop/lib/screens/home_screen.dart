import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_provider.dart';
import '../widgets/session_card.dart';
import '../widgets/status_indicator.dart';
import 'settings_screen.dart';
import 'new_session_dialog.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.tertiary,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.phone_iphone,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'VibeMobile',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () {
              context.read<AppProvider>().refreshSessions();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status card with gradient
                _buildStatusCard(context, provider),
                const SizedBox(height: 24),

                // Action buttons
                _buildActionButtons(context, provider),
                const SizedBox(height: 32),

                // Sessions header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.terminal,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '会话列表',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${provider.sessions.length}',
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (context) => const NewSessionDialog(),
                        );
                        if (result == true) {
                          await provider.refreshSessions();
                        }
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('新建会话'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Session list
                if (provider.sessions.isEmpty)
                  _buildEmptyState(context)
                else
                  ...provider.sessions.map(
                    (session) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SessionCard(
                        session: session,
                        onConnect: () => provider.attachSession(session.id),
                        onKill: () => _confirmKillSession(context, provider, session.id),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, AppProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    final isRunning = provider.serverRunning;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isRunning
              ? [
                  colorScheme.primaryContainer,
                  colorScheme.primaryContainer.withOpacity(0.7),
                ]
              : [
                  colorScheme.surfaceContainerHighest,
                  colorScheme.surfaceContainerHigh,
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRunning
              ? colorScheme.primary.withOpacity(0.3)
              : colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isRunning
                    ? colorScheme.primary.withOpacity(0.15)
                    : colorScheme.outline.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: StatusIndicator(
                isActive: isRunning,
                size: 24,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRunning ? '服务运行中' : '服务已停止',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isRunning
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildInfoChip(
                        context,
                        icon: Icons.api,
                        label: 'API: ${provider.settings.apiPort}',
                        isActive: isRunning,
                      ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        context,
                        icon: Icons.web,
                        label: 'Web: ${provider.settings.webPort}',
                        isActive: isRunning,
                      ),
                    ],
                  ),
                  if (provider.tunnelConnected && provider.tunnelUrl != null) ...[
                    const SizedBox(height: 8),
                    _buildInfoChip(
                      context,
                      icon: Icons.cloud_done,
                      label: provider.tunnelUrl!,
                      isActive: true,
                      isHighlighted: true,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    bool isHighlighted = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isHighlighted
            ? colorScheme.tertiary.withOpacity(0.2)
            : (isActive
                ? colorScheme.primary.withOpacity(0.1)
                : colorScheme.outline.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isHighlighted
                ? colorScheme.tertiary
                : (isActive
                    ? colorScheme.primary
                    : colorScheme.outline),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isHighlighted
                  ? colorScheme.tertiary
                  : (isActive
                      ? colorScheme.primary
                      : colorScheme.outline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, AppProvider provider) {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            context,
            icon: Icons.play_arrow_rounded,
            label: '启动服务',
            onTap: provider.serverRunning
                ? null
                : () async {
                    await provider.startServer();
                  },
            isPrimary: true,
            isEnabled: !provider.serverRunning,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            context,
            icon: Icons.stop_rounded,
            label: '停止服务',
            onTap: provider.serverRunning
                ? () async {
                    await provider.stopServer();
                  }
                : null,
            isEnabled: provider.serverRunning,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            context,
            icon: Icons.open_in_browser_rounded,
            label: '网页端',
            onTap: provider.serverRunning
                ? () async {
                    final url = Uri.parse(
                      'http://localhost:${provider.settings.webPort}',
                    );
                    await launchUrl(url);
                  }
                : null,
            isEnabled: provider.serverRunning,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            context,
            icon: provider.tunnelConnected
                ? Icons.cloud_done_rounded
                : Icons.cloud_outlined,
            label: provider.tunnelConnected ? '断开' : 'Tunnel',
            onTap: () async {
              if (provider.tunnelConnected) {
                await provider.stopTunnel();
              } else {
                final installed = await provider.isCloudflaredInstalled();
                if (!installed) {
                  if (context.mounted) {
                    _showCloudflaredDialog(context);
                  }
                  return;
                }
                await provider.startTunnel();
              }
            },
            isEnabled: true,
            isHighlighted: provider.tunnelConnected,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isPrimary = false,
    bool isEnabled = true,
    bool isHighlighted = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isHighlighted
                ? colorScheme.tertiaryContainer
                : (isPrimary && isEnabled
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest.withOpacity(isEnabled ? 1 : 0.5)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHighlighted
                  ? colorScheme.tertiary.withOpacity(0.5)
                  : (isPrimary && isEnabled
                      ? colorScheme.primary.withOpacity(0.3)
                      : colorScheme.outline.withOpacity(0.1)),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 28,
                color: isHighlighted
                    ? colorScheme.onTertiaryContainer
                    : (isEnabled
                        ? (isPrimary
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurface)
                        : colorScheme.outline),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isHighlighted
                      ? colorScheme.onTertiaryContainer
                      : (isEnabled
                          ? (isPrimary
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface)
                          : colorScheme.outline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.terminal_outlined,
              size: 48,
              color: colorScheme.outline,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '暂无会话',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击上方"新建会话"创建 Claude 会话',
            style: TextStyle(
              color: colorScheme.outline,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showCloudflaredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.cloud_download_outlined,
            size: 32,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: const Text('需要安装 cloudflared'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请先在终端中运行以下命令安装:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'brew install cloudflared',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      // Copy to clipboard
                    },
                    tooltip: '复制',
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }

  void _confirmKillSession(BuildContext context, AppProvider provider, String sessionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          size: 48,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('确认关闭会话?'),
        content: Text('确定要关闭会话 "$sessionId" 吗？\n会话中未保存的内容将会丢失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              provider.killSession(sessionId);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
