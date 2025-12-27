import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/logging/app_logger.dart';
import '../../../domain/services/setup_service.dart';
import '../../providers/server_provider.dart';
import '../../providers/tunnel_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/settings_provider.dart';
import 'widgets/status_card.dart';
import 'widgets/session_list.dart';
import 'widgets/action_buttons.dart';

/// Home screen - main page of the application.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WindowListener {
  bool _isWindowFocused = true;
  bool _hasCheckedSetup = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // Initialize settings and load sessions on first build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(settingsProvider.notifier).initialize();

      // Check if first-time setup is needed
      await _checkFirstTimeSetup();

      // Check if services are already running
      await ref.read(serverProvider.notifier).checkExistingStatus();
      // Load sessions
      await ref.read(sessionProvider.notifier).refresh();
      // Start auto-refresh after initial load
      ref.read(sessionProvider.notifier).startAutoRefresh();
    });
  }

  Future<void> _checkFirstTimeSetup() async {
    if (_hasCheckedSetup) return;
    _hasCheckedSetup = true;

    final setupService = SetupService();

    // Check if setup was already completed
    final hasCompleted = await setupService.hasCompletedSetup();
    if (hasCompleted) {
      AppLogger.info('HomeScreen: Setup already completed');
      return;
    }

    // Check current environment
    final status = await setupService.checkEnvironment();

    if (!status.isReady) {
      // Missing dependencies - redirect to setup screen
      AppLogger.info('HomeScreen: Missing dependencies, redirecting to setup');
      if (mounted) {
        context.go('/setup');
      }
    } else {
      // All dependencies ready - mark as completed
      await setupService.markSetupCompleted();
      AppLogger.info('HomeScreen: Environment ready, marked setup as completed');
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowFocus() {
    AppLogger.debug('HomeScreen: Window focused');
    _isWindowFocused = true;
    // Resume auto-refresh when window gains focus
    ref.read(sessionProvider.notifier).startAutoRefresh();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void onWindowBlur() {
    AppLogger.debug('HomeScreen: Window blurred');
    _isWindowFocused = false;
    // Pause auto-refresh when window loses focus
    ref.read(sessionProvider.notifier).stopAutoRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final serverState = ref.watch(serverProvider);
    final tunnelState = ref.watch(tunnelProvider);
    final sessionState = ref.watch(sessionProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('VibeMobile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.devices),
            tooltip: 'Devices',
            onPressed: () => context.push('/devices'),
          ),
          IconButton(
            icon: const Icon(Icons.article_outlined),
            tooltip: 'Logs',
            onPressed: () => context.push('/logs'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(sessionProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Server Status Card (unified API + Web UI)
              StatusCard(
                title: 'Server',
                subtitle: 'API + Web UI',
                port: settings.apiPort,
                status: _getStatusText(serverState.status),
                statusColor: _getStatusColor(serverState.status),
                isLoading: serverState.isStarting || serverState.isStopping,
                errorMessage: serverState.errorMessage,
              ),
              const SizedBox(height: 16),

              // Tunnel Status Card
              if (tunnelState.isConnected || tunnelState.isConnecting) ...[
                _buildTunnelCard(tunnelState),
                const SizedBox(height: 16),
              ],

              // Action Buttons
              ActionButtons(
                serverState: serverState,
                tunnelState: tunnelState,
                settings: settings,
                onStartServer: () => ref.read(serverProvider.notifier).start(),
                onStopServer: () => ref.read(serverProvider.notifier).stop(),
                onStartTunnel: () {
                  // Use named tunnel if configured, otherwise use quick tunnel
                  if (settings.tunnelName != null && settings.tunnelName!.isNotEmpty) {
                    ref.read(tunnelProvider.notifier).startNamed(settings.tunnelName!);
                  } else {
                    ref.read(tunnelProvider.notifier).startQuick(settings.apiPort);
                  }
                },
                onStopTunnel: () => ref.read(tunnelProvider.notifier).stop(),
                onCancelTunnel: () => ref.read(tunnelProvider.notifier).cancelConnecting(),
              ),
              const SizedBox(height: 24),

              // Sessions Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sessions (${sessionState.sessions.length})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'New Session',
                    onPressed: () => _showNewSessionDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (sessionState.isLoading && sessionState.sessions.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (sessionState.sessions.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.terminal,
                            size: 48,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No sessions',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Click + to create a new Claude session',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SessionList(
                  sessions: sessionState.sessions,
                  onAttach: (sessionId) => ref.read(sessionProvider.notifier).attachSession(sessionId),
                  onKill: (sessionId) => ref.read(sessionProvider.notifier).killSession(sessionId),
                ),

              // Error Display
              if (sessionState.error != null) ...[
                const SizedBox(height: 16),
                _buildErrorBanner(sessionState.error!, () {
                  ref.read(sessionProvider.notifier).clearError();
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText(ServerStatus status) {
    switch (status) {
      case ServerStatus.stopped:
        return 'Stopped';
      case ServerStatus.starting:
        return 'Starting...';
      case ServerStatus.running:
        return 'Running';
      case ServerStatus.stopping:
        return 'Stopping...';
      case ServerStatus.error:
        return 'Error';
    }
  }

  Color _getStatusColor(ServerStatus status) {
    switch (status) {
      case ServerStatus.stopped:
        return Colors.grey;
      case ServerStatus.starting:
      case ServerStatus.stopping:
        return Colors.orange;
      case ServerStatus.running:
        return Colors.green;
      case ServerStatus.error:
        return Colors.red;
    }
  }

  Widget _buildTunnelCard(TunnelState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.cloud,
              color: state.isConnected ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cloudflare Tunnel',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (state.isConnecting)
                    const Text(
                      'Connecting...',
                      style: TextStyle(color: Colors.orange),
                    )
                  else if (state.publicUrl != null)
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: state.publicUrl!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('URL copied to clipboard')),
                        );
                      },
                      child: Text(
                        state.publicUrl!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (state.isConnecting)
              TextButton(
                onPressed: () => ref.read(tunnelProvider.notifier).cancelConnecting(),
                child: const Text('Cancel'),
              )
            else
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Disconnect',
                onPressed: () => ref.read(tunnelProvider.notifier).stop(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String error, VoidCallback onDismiss) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNewSessionDialog(BuildContext context) async {
    final workingDirController = TextEditingController();
    final commandController = TextEditingController(text: 'claude');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: workingDirController,
              decoration: const InputDecoration(
                labelText: 'Working Directory',
                hintText: '/path/to/project',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commandController,
              decoration: const InputDecoration(
                labelText: 'Command',
                hintText: 'claude',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true && workingDirController.text.isNotEmpty) {
      await ref.read(sessionProvider.notifier).createSession(
        workingDir: workingDirController.text,
        command: commandController.text.isEmpty ? 'claude' : commandController.text,
      );
    }
  }
}
