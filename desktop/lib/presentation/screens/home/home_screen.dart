import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/services/setup_service.dart';
import '../../providers/server_provider.dart';
import '../../providers/tunnel_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/settings_provider.dart';
import '../../../data/models/settings.dart';
import '../../providers/device_provider.dart';
import 'widgets/sidebar.dart';
import 'widgets/session_row.dart';
import 'widgets/connect_dialog.dart';

/// Home screen - main page of the application.
/// New layout: Sidebar + Main Content Area
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WindowListener {
  bool _isWindowFocused = true;
  bool _hasCheckedSetup = false;
  bool _isShowingPairingDialog = false;

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

      // If server is already running, connect WebSocket and load devices
      final serverState = ref.read(serverProvider);
      if (serverState.isRunning) {
        ref.read(deviceProvider.notifier).connectWebSocket();
        ref.read(deviceProvider.notifier).refresh();
      }
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
    ref.read(deviceProvider.notifier).disconnectWebSocket();
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

  void _showConnectDialog() {
    showConnectDialog(context);
  }

  void _toggleService() async {
    final serverState = ref.read(serverProvider);

    if (serverState.isRunning) {
      // Stop all services
      ref.read(serverProvider.notifier).stop();
      ref.read(tunnelProvider.notifier).stop();
    } else {
      // Start server
      ref.read(serverProvider.notifier).start();

      // Wait for server to start, then start Tunnel
      _waitAndStartTunnel();
    }
  }

  Future<void> _waitAndStartTunnel() async {
    // Wait up to 10 seconds for server to start
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      final currentServerState = ref.read(serverProvider);
      final currentTunnelState = ref.read(tunnelProvider);

      // If server failed to start or stopped, abort
      if (!currentServerState.isRunning && !currentServerState.isStarting) {
        return;
      }

      // If server is running and tunnel is not already active, start tunnel
      if (currentServerState.isRunning &&
          !currentTunnelState.isConnected &&
          !currentTunnelState.isConnecting) {
        final settings = ref.read(settingsProvider);
        if (settings.tunnelName != null && settings.tunnelName!.isNotEmpty) {
          ref.read(tunnelProvider.notifier).startNamed(settings.tunnelName!);
        } else {
          ref.read(tunnelProvider.notifier).startQuick(settings.apiPort);
        }
        return;
      }

      // If tunnel is already connecting or connected, we're done
      if (currentTunnelState.isConnected || currentTunnelState.isConnecting) {
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverState = ref.watch(serverProvider);
    final sessionState = ref.watch(sessionProvider);
    final settings = ref.watch(settingsProvider);
    final deviceState = ref.watch(deviceProvider);

    // Auto-refresh devices when server starts running
    ref.listen<ServerState>(serverProvider, (previous, next) {
      if (previous?.isRunning != true && next.isRunning) {
        // Server just started, refresh devices and reconnect WebSocket
        ref.read(deviceProvider.notifier).connectWebSocket();
        ref.read(deviceProvider.notifier).refresh();
      }
    });

    // Auto-show pairing dialog when request arrives (only once)
    ref.listen<DeviceListState>(deviceProvider, (previous, next) {
      if (previous?.pendingRequest == null &&
          next.pendingRequest != null &&
          !_isShowingPairingDialog) {
        _isShowingPairingDialog = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (mounted) {
            await showConnectDialog(context, initialStep: PairingStep.confirmPair);
            _isShowingPairingDialog = false;
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: _buildAppBar(context),
      body: Row(
        children: [
          // Sidebar
          Sidebar(
            onQRTap: _showConnectDialog,
            onToggleService: _toggleService,
          ),
          // Main content area
          Expanded(
            child: _buildMainContent(context, sessionState, serverState, settings),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.bgCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.terminal,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'VibeMobile',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.article_outlined, color: AppColors.textSecondary),
          tooltip: '日志',
          onPressed: () => context.push('/logs'),
        ),
        IconButton(
          icon: Icon(Icons.settings, color: AppColors.textSecondary),
          tooltip: '设置',
          onPressed: () => context.push('/settings'),
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: AppColors.border,
        ),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    SessionListState sessionState,
    ServerState serverState,
    Settings settings,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick actions bar
          _buildQuickActionsBar(),
          const SizedBox(height: 24),
          // Session list
          Expanded(
            child: sessionState.isLoading && sessionState.sessions.isEmpty
                ? _buildLoadingState()
                : SessionRowList(
                    sessions: sessionState.sessions,
                    onAttach: (sessionId) =>
                        ref.read(sessionProvider.notifier).attachSession(sessionId),
                    onKill: (sessionId) =>
                        ref.read(sessionProvider.notifier).killSession(sessionId),
                    onRefresh: () => ref.read(sessionProvider.notifier).refresh(),
                  ),
          ),
          // Error display
          if (sessionState.error != null) ...[
            const SizedBox(height: 16),
            _buildErrorBanner(sessionState.error!, () {
              ref.read(sessionProvider.notifier).clearError();
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionsBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppColors.radiusMedium),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Text(
            '会话管理',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          // New session button
          _buildPrimaryButton(
            label: '新建会话',
            icon: Icons.add,
            onPressed: () => _showNewSessionDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppColors.gradientStart.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.gradientStart),
          ),
          const SizedBox(height: 16),
          Text(
            '加载会话中...',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String error, VoidCallback onDismiss) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(AppColors.radiusSmall),
        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: AppColors.danger,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: AppColors.danger,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: AppColors.danger, size: 18),
            onPressed: onDismiss,
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Future<void> _showNewSessionDialog(BuildContext context) async {
    final workingDirController = TextEditingController();
    final commandController = TextEditingController(text: 'claude');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMedium),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Text('新建会话'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: workingDirController,
              decoration: InputDecoration(
                labelText: '工作目录',
                hintText: '/path/to/project',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commandController,
              decoration: InputDecoration(
                labelText: '启动命令',
                hintText: 'claude',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              '取消',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gradientStart,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('创建'),
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
