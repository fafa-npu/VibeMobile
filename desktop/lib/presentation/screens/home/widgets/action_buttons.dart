import 'package:flutter/material.dart';

import '../../../providers/server_provider.dart';
import '../../../providers/web_provider.dart';
import '../../../providers/tunnel_provider.dart';
import '../../../../data/models/settings.dart';

/// Action buttons for controlling services.
class ActionButtons extends StatelessWidget {
  final ServerState serverState;
  final WebState webState;
  final TunnelState tunnelState;
  final Settings settings;
  final VoidCallback onStartServer;
  final VoidCallback onStopServer;
  final VoidCallback onStartWeb;
  final VoidCallback onStopWeb;
  final VoidCallback onStartTunnel;
  final VoidCallback onStopTunnel;
  final VoidCallback onCancelTunnel;

  const ActionButtons({
    super.key,
    required this.serverState,
    required this.webState,
    required this.tunnelState,
    required this.settings,
    required this.onStartServer,
    required this.onStopServer,
    required this.onStartWeb,
    required this.onStopWeb,
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
        // API Server button
        _buildServiceButton(
          context: context,
          label: serverState.isRunning ? 'Stop API' : 'Start API',
          icon: serverState.isRunning ? Icons.stop : Icons.play_arrow,
          isLoading: serverState.isStarting || serverState.isStopping,
          isActive: serverState.isRunning,
          onPressed: serverState.isRunning ? onStopServer : onStartServer,
        ),

        // Web UI button
        _buildServiceButton(
          context: context,
          label: webState.isRunning ? 'Stop Web' : 'Start Web',
          icon: webState.isRunning ? Icons.stop : Icons.web,
          isLoading: webState.isStarting || webState.isStopping || webState.isInstallingDeps,
          isActive: webState.isRunning,
          onPressed: webState.isRunning ? onStopWeb : onStartWeb,
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
            tooltip: serverState.isRunning ? null : 'Start API server first',
          ),

        // Start All button
        if (!serverState.isRunning || !webState.isRunning)
          _buildServiceButton(
            context: context,
            label: 'Start All',
            icon: Icons.rocket_launch,
            isLoading: false,
            isActive: false,
            isPrimary: true,
            onPressed: () async {
              if (!serverState.isRunning) {
                onStartServer();
              }
              // Small delay to ensure server starts first
              await Future.delayed(const Duration(milliseconds: 500));
              if (!webState.isRunning) {
                onStartWeb();
              }
            },
          ),

        // Stop All button
        if (serverState.isRunning || webState.isRunning || tunnelState.isConnected)
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
              if (webState.isRunning) {
                onStopWeb();
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
