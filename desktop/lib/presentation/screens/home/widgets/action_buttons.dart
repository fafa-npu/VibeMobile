import 'package:flutter/material.dart';

import '../../../providers/server_provider.dart';
import '../../../providers/tunnel_provider.dart';
import '../../../../data/models/settings.dart';

/// Action buttons for controlling services.
/// Note: API Server and Web UI are now unified into a single server.
class ActionButtons extends StatelessWidget {
  final ServerState serverState;
  final TunnelState tunnelState;
  final Settings settings;
  final VoidCallback onStartServer;
  final VoidCallback onStopServer;
  final VoidCallback onStartTunnel;
  final VoidCallback onStopTunnel;
  final VoidCallback onCancelTunnel;

  const ActionButtons({
    super.key,
    required this.serverState,
    required this.tunnelState,
    required this.settings,
    required this.onStartServer,
    required this.onStopServer,
    required this.onStartTunnel,
    required this.onStopTunnel,
    required this.onCancelTunnel,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Server button (unified API + Web UI)
        _buildServiceButton(
          context: context,
          label: serverState.isRunning ? 'Stop Server' : 'Start Server',
          icon: serverState.isRunning ? Icons.stop : Icons.play_arrow,
          isLoading: serverState.isStarting || serverState.isStopping,
          isActive: serverState.isRunning,
          isPrimary: !serverState.isRunning,
          onPressed: serverState.isRunning ? onStopServer : onStartServer,
        ),

        // Tunnel button
        if (!tunnelState.isConnected && !tunnelState.isConnecting)
          _buildServiceButton(
            context: context,
            label: 'Start Tunnel',
            icon: Icons.cloud_upload,
            isLoading: false,
            isActive: false,
            onPressed: serverState.isRunning ? onStartTunnel : null,
            tooltip: serverState.isRunning ? null : 'Start server first',
          ),

        // Stop All button (only show when tunnel is connected)
        if (tunnelState.isConnected && serverState.isRunning)
          _buildServiceButton(
            context: context,
            label: 'Stop All',
            icon: Icons.stop_circle,
            isLoading: false,
            isActive: false,
            isDestructive: true,
            onPressed: () async {
              if (tunnelState.isConnected) {
                onStopTunnel();
              }
              if (serverState.isRunning) {
                onStopServer();
              }
            },
          ),
      ],
    );
  }

  Widget _buildServiceButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isLoading,
    required bool isActive,
    VoidCallback? onPressed,
    String? tooltip,
    bool isPrimary = false,
    bool isDestructive = false,
  }) {
    Widget button;

    if (isPrimary) {
      button = FilledButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(label),
      );
    } else if (isDestructive) {
      button = OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(label),
      );
    } else if (isActive) {
      button = FilledButton.tonalIcon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(label),
      );
    } else {
      button = OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(label),
      );
    }

    if (tooltip != null && onPressed == null) {
      return Tooltip(
        message: tooltip,
        child: button,
      );
    }

    return button;
  }
}
