import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/tunnel_service.dart';
import 'settings_provider.dart';

/// Tunnel connection state.
enum TunnelStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

class TunnelState {
  final TunnelStatus status;
  final String? publicUrl;
  final String? errorMessage;

  const TunnelState({
    required this.status,
    this.publicUrl,
    this.errorMessage,
  });

  const TunnelState.disconnected()
      : status = TunnelStatus.disconnected,
        publicUrl = null,
        errorMessage = null;

  TunnelState copyWith({
    TunnelStatus? status,
    String? publicUrl,
    String? errorMessage,
    bool clearUrl = false,
    bool clearError = false,
  }) {
    return TunnelState(
      status: status ?? this.status,
      publicUrl: clearUrl ? null : (publicUrl ?? this.publicUrl),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  bool get isConnected => status == TunnelStatus.connected;
  bool get isDisconnected => status == TunnelStatus.disconnected;
  bool get isConnecting => status == TunnelStatus.connecting;
  bool get isDisconnecting => status == TunnelStatus.disconnecting;
  bool get hasError => status == TunnelStatus.error;
}

/// Provider for TunnelService instance.
final tunnelServiceProvider = Provider<TunnelService>((ref) {
  return TunnelService();
});

/// Provider for tunnel state management.
class TunnelNotifier extends StateNotifier<TunnelState> {
  final TunnelService _service;
  final Ref _ref;

  TunnelNotifier(this._service, this._ref) : super(const TunnelState.disconnected()) {
    // Set up callbacks
    _service.onTunnelReady = _onTunnelReady;
    _service.onTunnelDisconnected = _onTunnelDisconnected;
    _service.onTunnelError = _onTunnelError;
  }

  void _onTunnelReady(String url) {
    state = state.copyWith(
      status: TunnelStatus.connected,
      publicUrl: url,
      clearError: true,
    );
  }

  void _onTunnelDisconnected() {
    state = state.copyWith(
      status: TunnelStatus.disconnected,
      clearUrl: true,
    );
  }

  void _onTunnelError(String error) {
    state = state.copyWith(
      status: TunnelStatus.error,
      errorMessage: error,
      clearUrl: true,
    );
  }

  /// Start a quick tunnel.
  Future<void> startQuick(int port) async {
    if (state.isConnected || state.isConnecting) return;

    state = state.copyWith(
      status: TunnelStatus.connecting,
      clearError: true,
      clearUrl: true,
    );

    final settings = _ref.read(settingsProvider);
    final proxyUrl = settings.proxyUrl;

    try {
      await _service.startQuickTunnel(port, proxyUrl: proxyUrl);
      // State will be updated via callbacks
    } catch (e) {
      state = state.copyWith(
        status: TunnelStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Start a named tunnel.
  Future<void> startNamed(String tunnelName) async {
    if (state.isConnected || state.isConnecting) return;

    state = state.copyWith(
      status: TunnelStatus.connecting,
      clearError: true,
      clearUrl: true,
    );

    try {
      final success = await _service.startNamedTunnel(tunnelName);
      if (success) {
        // For named tunnels, we don't get the URL from output
        // It's based on the configured hostname
        final settings = _ref.read(settingsProvider);
        state = state.copyWith(
          status: TunnelStatus.connected,
          publicUrl: settings.tunnelHostname != null
              ? 'https://${settings.tunnelHostname}'
              : null,
        );
      } else {
        state = state.copyWith(
          status: TunnelStatus.error,
          errorMessage: 'Failed to start named tunnel',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: TunnelStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Cancel connecting.
  void cancelConnecting() {
    if (state.isConnecting) {
      _service.cancelStarting();
      state = state.copyWith(
        status: TunnelStatus.disconnected,
        clearUrl: true,
      );
    }
  }

  /// Stop the tunnel.
  Future<void> stop() async {
    if (state.isDisconnected || state.isDisconnecting) return;

    state = state.copyWith(status: TunnelStatus.disconnecting);

    try {
      await _service.stop();
      state = state.copyWith(
        status: TunnelStatus.disconnected,
        clearUrl: true,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: TunnelStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Check if cloudflared is installed.
  Future<bool> isInstalled() async {
    return await _service.isCloudflaredInstalled();
  }

  /// Check if logged in to Cloudflare.
  Future<bool> isLoggedIn() async {
    return await _service.isLoggedIn();
  }

  /// List available tunnels.
  Future<List<String>> listTunnels() async {
    return await _service.listTunnels();
  }

  /// Clear error.
  void clearError() {
    state = state.copyWith(clearError: true);
    if (state.hasError) {
      state = state.copyWith(status: TunnelStatus.disconnected);
    }
  }
}

/// Provider for TunnelNotifier.
final tunnelProvider = StateNotifierProvider<TunnelNotifier, TunnelState>((ref) {
  final service = ref.watch(tunnelServiceProvider);
  return TunnelNotifier(service, ref);
});
