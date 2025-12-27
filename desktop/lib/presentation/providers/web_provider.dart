import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import 'settings_provider.dart';
import 'server_provider.dart';

/// Web service state.
enum WebStatus {
  stopped,
  starting,
  running,
  stopping,
  error,
  installingDeps,
}

class WebState {
  final WebStatus status;
  final String? errorMessage;

  const WebState({
    required this.status,
    this.errorMessage,
  });

  const WebState.initial() : status = WebStatus.stopped, errorMessage = null;

  WebState copyWith({
    WebStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WebState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  bool get isRunning => status == WebStatus.running;
  bool get isStopped => status == WebStatus.stopped;
  bool get isStarting => status == WebStatus.starting;
  bool get isStopping => status == WebStatus.stopping;
  bool get hasError => status == WebStatus.error;
  bool get isInstallingDeps => status == WebStatus.installingDeps;
}

/// Provider for web state management.
///
/// With the unified Node.js backend, Web UI is served by the same server.
/// This provider mirrors the server state for UI compatibility.
class WebNotifier extends StateNotifier<WebState> {
  final Ref _ref;

  WebNotifier(this._ref) : super(const WebState.initial()) {
    // Listen to server state changes
    _ref.listen<ServerState>(serverProvider, (prev, next) {
      if (!mounted) return;

      // Mirror server state
      switch (next.status) {
        case ServerStatus.stopped:
          state = state.copyWith(status: WebStatus.stopped, clearError: true);
          break;
        case ServerStatus.starting:
          state = state.copyWith(status: WebStatus.starting, clearError: true);
          break;
        case ServerStatus.running:
          state = state.copyWith(status: WebStatus.running, clearError: true);
          break;
        case ServerStatus.stopping:
          state = state.copyWith(status: WebStatus.stopping, clearError: true);
          break;
        case ServerStatus.error:
          state = state.copyWith(
            status: WebStatus.error,
            errorMessage: next.errorMessage,
          );
          break;
      }
    });
  }

  int get _apiPort => _ref.read(settingsProvider).apiPort;

  /// Check if web UI is accessible (same as server health check).
  Future<void> checkExistingStatus() async {
    // Mirror server state - the unified server serves both API and Web UI
    final serverState = _ref.read(serverProvider);
    if (serverState.isRunning) {
      state = state.copyWith(status: WebStatus.running);
    }
  }

  Future<void> start() async {
    // Web UI is served by the unified server - just start the server
    await _ref.read(serverProvider.notifier).start();
  }

  Future<void> stop() async {
    // Web UI is served by the unified server - stopping web doesn't stop server
    // In the unified architecture, this is a no-op since we don't want to
    // stop the API server just to stop the web UI
    // If you want to stop both, use server stop
  }

  Future<void> restart() async {
    await _ref.read(serverProvider.notifier).restart();
  }

  Future<bool> healthCheck() async {
    return await _ref.read(serverProvider.notifier).healthCheck();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
    if (state.hasError) {
      state = state.copyWith(status: WebStatus.stopped);
    }
  }
}

/// Provider for WebNotifier.
final webProvider = StateNotifierProvider<WebNotifier, WebState>((ref) {
  return WebNotifier(ref);
});
