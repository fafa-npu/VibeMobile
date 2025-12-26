import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../domain/services/web_service.dart';
import 'settings_provider.dart';

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

/// Provider for WebService instance.
final webServiceProvider = Provider<WebService>((ref) {
  final projectPath = AppConfig.getProjectPath();
  return WebService(projectPath: projectPath);
});

/// Provider for web state management.
class WebNotifier extends StateNotifier<WebState> {
  final WebService _service;
  final Ref _ref;

  WebNotifier(this._service, this._ref) : super(const WebState.initial());

  int get _webPort => _ref.read(settingsProvider).webPort;

  Future<void> start() async {
    if (state.isRunning || state.isStarting) return;

    // Check if node_modules exists
    if (!_service.hasNodeModules()) {
      state = state.copyWith(status: WebStatus.installingDeps, clearError: true);
      final installed = await _service.installDependencies();
      if (!installed) {
        state = state.copyWith(
          status: WebStatus.error,
          errorMessage: 'Failed to install npm dependencies',
        );
        return;
      }
    }

    state = state.copyWith(status: WebStatus.starting, clearError: true);

    // Start with callback - returns immediately, callback updates state
    await _service.start(
      _webPort,
      onStatusChange: (isRunning, error) {
        if (!mounted) return;
        if (isRunning) {
          state = state.copyWith(status: WebStatus.running);
        } else if (error != null) {
          state = state.copyWith(
            status: WebStatus.error,
            errorMessage: error,
          );
        } else {
          state = state.copyWith(status: WebStatus.stopped);
        }
      },
    );
  }

  Future<void> stop() async {
    if (state.isStopped || state.isStopping) return;

    state = state.copyWith(status: WebStatus.stopping, clearError: true);

    try {
      await _service.stop();
      state = state.copyWith(status: WebStatus.stopped);
    } catch (e) {
      state = state.copyWith(
        status: WebStatus.error,
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
    return await _service.healthCheck(_webPort);
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
  final service = ref.watch(webServiceProvider);
  return WebNotifier(service, ref);
});
