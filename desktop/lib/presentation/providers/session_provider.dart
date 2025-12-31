import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/session.dart';
import '../../data/models/settings.dart';
import '../../domain/services/tmux_service.dart';
import 'settings_provider.dart';

/// Provider for TmuxService instance.
final tmuxServiceProvider = Provider<TmuxService>((ref) {
  final settings = ref.read(settingsProvider);
  return TmuxService(prefix: settings.sessionPrefix);
});

/// Session list state.
class SessionListState {
  final List<Session> sessions;
  final bool isLoading;
  final String? error;

  const SessionListState({
    required this.sessions,
    this.isLoading = false,
    this.error,
  });

  const SessionListState.initial()
      : sessions = const [],
        isLoading = false,
        error = null;

  SessionListState copyWith({
    List<Session>? sessions,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return SessionListState(
      sessions: sessions ?? this.sessions,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Provider for session state management.
class SessionNotifier extends StateNotifier<SessionListState> {
  final TmuxService _service;
  final Ref _ref;
  Timer? _refreshTimer;
  bool _refreshInFlight = false;  // 互斥标志，防止并发刷新堆积

  SessionNotifier(this._service, this._ref) : super(const SessionListState.initial()) {
    // Don't auto-refresh in constructor - let UI trigger refreshes
  }

  /// Start auto-refresh (call this after initial load).
  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _refreshInBackground();
      }
    });
  }

  /// Stop auto-refresh (call this when window loses focus).
  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Refresh sessions in background without blocking UI.
  /// 使用 _refreshInFlight 互斥锁防止并发刷新堆积。
  Future<void> _refreshInBackground() async {
    // 如果已有刷新在进行中，跳过本次（防止堆积）
    if (state.isLoading || _refreshInFlight) return;

    _refreshInFlight = true;
    try {
      final sessions = await _service.listSessions();
      if (mounted) {
        state = state.copyWith(sessions: sessions);
      }
    } catch (e) {
      // Silently ignore background refresh errors
    } finally {
      _refreshInFlight = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  TerminalApp get _terminalApp => _ref.read(settingsProvider).terminalApp;

  /// Load all sessions.
  Future<void> refresh() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final sessions = await _service.listSessions();
      state = state.copyWith(sessions: sessions, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Create a new session.
  Future<bool> createSession({
    required String workingDir,
    String command = 'claude',
  }) async {
    try {
      final sessionName = await _service.createSession(
        workingDir: workingDir,
        command: command,
      );

      if (sessionName != null) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Attach to a session in terminal.
  Future<bool> attachSession(String sessionId) async {
    try {
      return await _service.attachSession(sessionId, _terminalApp);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Kill a session.
  Future<bool> killSession(String sessionId) async {
    try {
      final success = await _service.killSession(sessionId);
      if (success) {
        await refresh();
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Clear error.
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Provider for SessionNotifier.
final sessionProvider = StateNotifierProvider<SessionNotifier, SessionListState>((ref) {
  final service = ref.watch(tmuxServiceProvider);
  return SessionNotifier(service, ref);
});

/// Provider for session count.
final sessionCountProvider = Provider<int>((ref) {
  return ref.watch(sessionProvider).sessions.length;
});
