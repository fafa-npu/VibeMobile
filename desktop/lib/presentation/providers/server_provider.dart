import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../domain/services/server_service.dart';
import 'settings_provider.dart';

/// Server service state.
enum ServerStatus {
  stopped,
  starting,
  running,
  stopping,
  error,
}

class ServerState {
  final ServerStatus status;
  final String? errorMessage;

  const ServerState({
    required this.status,
    this.errorMessage,
  });

  const ServerState.initial() : status = ServerStatus.stopped, errorMessage = null;

  ServerState copyWith({
    ServerStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ServerState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  bool get isRunning => status == ServerStatus.running;
  bool get isStopped => status == ServerStatus.stopped;
  bool get isStarting => status == ServerStatus.starting;
  bool get isStopping => status == ServerStatus.stopping;
  bool get hasError => status == ServerStatus.error;
}

/// Provider for ServerService instance.
final serverServiceProvider = Provider<ServerService>((ref) {
  final projectPath = AppConfig.getProjectPath();
  return ServerService(projectPath: projectPath);
});

/// Provider for server state management.
class ServerNotifier extends StateNotifier<ServerState> {
  final ServerService _service;
  final Ref _ref;

  ServerNotifier(this._service, this._ref) : super(const ServerState.initial());

  int get _apiPort => _ref.read(settingsProvider).apiPort;

  Future<void> start() async {
    if (state.isRunning || state.isStarting) return;

    state = state.copyWith(status: ServerStatus.starting, clearError: true);

    // Start with callback - returns immediately, callback updates state
    await _service.start(
      _apiPort,
      onStatusChange: (isRunning, error) {
        if (!mounted) return;
        if (isRunning) {
          state = state.copyWith(status: ServerStatus.running);
        } else if (error != null) {
          state = state.copyWith(
            status: ServerStatus.error,
            errorMessage: error,
          );
        } else {
          state = state.copyWith(status: ServerStatus.stopped);
        }
      },
    );
  }

  Future<void> stop() async {
    if (state.isStopped || state.isStopping) return;

    state = state.copyWith(status: ServerStatus.stopping, clearError: true);

    try {
      await _service.stop(_apiPort);
      state = state.copyWith(status: ServerStatus.stopped);
    } catch (e) {
      state = state.copyWith(
        status: ServerStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> restart() async {
    await stop();
    await Future.delayed(const Duration(milliseconds: 500));
    await start();
  }

  Future<bool> healthCheck() async {
    return await _service.healthCheck(_apiPort);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
    if (state.hasError) {
      state = state.copyWith(status: ServerStatus.stopped);
    }
  }
}

/// Provider for ServerNotifier.
final serverProvider = StateNotifierProvider<ServerNotifier, ServerState>((ref) {
  final service = ref.watch(serverServiceProvider);
  return ServerNotifier(service, ref);
});
