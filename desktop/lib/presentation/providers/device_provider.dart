import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/device.dart';
import '../../domain/services/auth_service.dart';
import 'settings_provider.dart';

/// Provider for AuthService instance.
final authServiceProvider = Provider<AuthService>((ref) {
  final settings = ref.watch(settingsProvider);
  return AuthService(apiPort: settings.apiPort);
});

/// Device list state.
class DeviceListState {
  final List<Device> devices;
  final bool isLoading;
  final String? error;
  final PairingCode? currentPairingCode;
  final PairingRequest? pendingRequest;

  const DeviceListState({
    required this.devices,
    this.isLoading = false,
    this.error,
    this.currentPairingCode,
    this.pendingRequest,
  });

  const DeviceListState.initial()
      : devices = const [],
        isLoading = false,
        error = null,
        currentPairingCode = null,
        pendingRequest = null;

  DeviceListState copyWith({
    List<Device>? devices,
    bool? isLoading,
    String? error,
    PairingCode? currentPairingCode,
    PairingRequest? pendingRequest,
    bool clearError = false,
    bool clearPairingCode = false,
    bool clearPendingRequest = false,
  }) {
    return DeviceListState(
      devices: devices ?? this.devices,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      currentPairingCode: clearPairingCode ? null : (currentPairingCode ?? this.currentPairingCode),
      pendingRequest: clearPendingRequest ? null : (pendingRequest ?? this.pendingRequest),
    );
  }
}

/// Provider for device state management.
class DeviceNotifier extends StateNotifier<DeviceListState> {
  final AuthService _service;
  StreamSubscription? _pairingSubscription;
  Timer? _pairingCodeTimer;
  Timer? _countdownTimer;

  DeviceNotifier(this._service) : super(const DeviceListState.initial()) {
    _setupPairingListener();
  }

  void _setupPairingListener() {
    _pairingSubscription?.cancel();
    _pairingSubscription = _service.pairingRequests.listen((request) {
      state = state.copyWith(pendingRequest: request);
    });
  }

  @override
  void dispose() {
    _pairingSubscription?.cancel();
    _pairingCodeTimer?.cancel();
    _countdownTimer?.cancel();
    _service.dispose();
    super.dispose();
  }

  /// Connect to WebSocket for pairing requests.
  Future<void> connectWebSocket() async {
    await _service.connectWebSocket();
  }

  /// Disconnect WebSocket.
  void disconnectWebSocket() {
    _service.disconnectWebSocket();
  }

  /// Load all devices.
  Future<void> refresh() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final devices = await _service.getDevices();
      state = state.copyWith(devices: devices, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Generate a new pairing code.
  Future<void> generatePairingCode() async {
    _pairingCodeTimer?.cancel();
    _countdownTimer?.cancel();

    try {
      final code = await _service.generatePairingCode();
      if (code != null) {
        state = state.copyWith(currentPairingCode: code);

        // Set up timer to clear expired code
        _pairingCodeTimer = Timer(Duration(seconds: code.expiresIn), () {
          _countdownTimer?.cancel();
          state = state.copyWith(clearPairingCode: true);
        });

        // Set up countdown timer to update UI every second
        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (state.currentPairingCode != null) {
            // Trigger state update to refresh countdown display
            state = state.copyWith(currentPairingCode: state.currentPairingCode);
          }
        });
      } else {
        state = state.copyWith(error: 'Failed to generate pairing code');
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Cancel pairing code.
  void cancelPairingCode() {
    _pairingCodeTimer?.cancel();
    _countdownTimer?.cancel();
    state = state.copyWith(clearPairingCode: true);
  }

  /// Approve a pairing request.
  Future<bool> approvePairing(String approvalId) async {
    try {
      final success = await _service.approvePairing(approvalId);
      if (success) {
        state = state.copyWith(clearPendingRequest: true);
        await refresh();
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Reject a pairing request.
  Future<bool> rejectPairing(String approvalId) async {
    try {
      final success = await _service.rejectPairing(approvalId);
      if (success) {
        state = state.copyWith(clearPendingRequest: true);
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Update device trust level.
  Future<bool> updateDeviceTrust(String deviceId, String trustLevel) async {
    try {
      final success = await _service.updateDeviceTrust(deviceId, trustLevel);
      if (success) {
        await refresh();
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Revoke a device.
  Future<bool> revokeDevice(String deviceId) async {
    try {
      final success = await _service.revokeDevice(deviceId);
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

  /// Clear pending request.
  void clearPendingRequest() {
    state = state.copyWith(clearPendingRequest: true);
  }
}

/// Provider for DeviceNotifier.
final deviceProvider = StateNotifierProvider<DeviceNotifier, DeviceListState>((ref) {
  final service = ref.watch(authServiceProvider);
  return DeviceNotifier(service);
});

/// Provider for device count.
final deviceCountProvider = Provider<int>((ref) {
  return ref.watch(deviceProvider).devices.length;
});

/// Provider for active device count.
final activeDeviceCountProvider = Provider<int>((ref) {
  return ref.watch(deviceProvider).devices.where((d) => d.isActive).length;
});
