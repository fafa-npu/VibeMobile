import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

import '../../core/logging/app_logger.dart';
import '../../core/config/app_config.dart';
import '../../data/models/device.dart';

/// Service for device authentication.
class AuthService {
  final int apiPort;
  WebSocketChannel? _wsChannel;
  late final StreamController<PairingRequest> _pairingRequestController;
  bool _isConnected = false;
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  AuthService({required this.apiPort}) {
    _pairingRequestController = StreamController<PairingRequest>.broadcast();
  }

  /// Use centralized config for base URLs
  String get baseUrl => AppConfig.apiBaseUrl(apiPort);
  String get wsUrl => AppConfig.wsUrl(apiPort, '');

  bool get isConnected => _isConnected;

  Stream<PairingRequest> get pairingRequests => _pairingRequestController.stream;

  /// Connect to WebSocket to receive pairing requests.
  Future<void> connectWebSocket() async {
    if (_isConnected) return;

    AppLogger.info('AuthService: Connecting to WebSocket at $wsUrl');

    try {
      if (AppConfig.hasSslCerts) {
        // Use IOWebSocketChannel for secure connections with custom SSL handling
        final uri = Uri.parse('$wsUrl/ws?client_type=desktop');
        final socket = await WebSocket.connect(
          uri.toString(),
          customClient: AppConfig.createHttpClient(),
        );
        _wsChannel = IOWebSocketChannel(socket);
      } else {
        _wsChannel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws?client_type=desktop'));
        await _wsChannel!.ready.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException('WebSocket connection timeout');
          },
        );
      }

      _isConnected = true;
      _reconnectAttempts = 0;
      AppLogger.info('AuthService: WebSocket connected');

      // Register as desktop connection
      _wsChannel!.sink.add(jsonEncode({'type': 'register_desktop'}));

      _wsChannel!.stream.listen(
        (data) {
          try {
            final message = jsonDecode(data as String);
            final type = message['type'] as String?;

            if (type == 'pairing_request') {
              final requestData = message['data'] as Map<String, dynamic>;
              final request = PairingRequest.fromJson(requestData);
              AppLogger.info('AuthService: Received pairing request from ${request.deviceName}');
              _pairingRequestController.add(request);
            }
          } catch (e) {
            AppLogger.warning('AuthService: Error parsing message: $e');
          }
        },
        onDone: () {
          AppLogger.info('AuthService: WebSocket disconnected');
          _isConnected = false;
          _wsChannel = null;

          // Attempt reconnect with exponential backoff
          if (_shouldReconnect && _reconnectAttempts < _maxReconnectAttempts) {
            _reconnectAttempts++;
            final delay = Duration(seconds: _reconnectAttempts * 2);
            AppLogger.info('AuthService: Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)');
            Future.delayed(delay, () {
              if (!_isConnected && _shouldReconnect) {
                connectWebSocket();
              }
            });
          } else if (_reconnectAttempts >= _maxReconnectAttempts) {
            AppLogger.warning('AuthService: Max reconnect attempts reached');
          }
        },
        onError: (error) {
          AppLogger.warning('AuthService: WebSocket error: $error');
          _isConnected = false;
        },
      );
    } catch (e, stack) {
      AppLogger.error('AuthService: Failed to connect WebSocket', e, stack);
      _isConnected = false;
      _wsChannel = null;
    }
  }

  /// Disconnect WebSocket.
  void disconnectWebSocket() {
    _shouldReconnect = false;
    _wsChannel?.sink.close();
    _wsChannel = null;
    _isConnected = false;
  }

  /// Generate a new pairing code.
  Future<PairingCode?> generatePairingCode() async {
    AppLogger.info('AuthService: Generating pairing code from $baseUrl');

    final client = AppConfig.createHttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('$baseUrl/api/auth/pair/initiate'),
      );
      request.headers.set('Content-Type', 'application/json');
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        return PairingCode.fromJson(data);
      } else {
        AppLogger.warning('AuthService: Failed to generate pairing code: ${response.statusCode}');
        return null;
      }
    } catch (e, stack) {
      AppLogger.error('AuthService: Error generating pairing code', e, stack);
      return null;
    } finally {
      client.close();
    }
  }

  /// Approve a pairing request.
  Future<bool> approvePairing(String approvalId) async {
    AppLogger.info('AuthService: Approving pairing $approvalId');

    final client = AppConfig.createHttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('$baseUrl/api/auth/approve'),
      );
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode({
        'approval_id': approvalId,
        'action': 'approve',
      }));
      final response = await request.close();
      await response.drain<void>();

      return response.statusCode == 200;
    } catch (e, stack) {
      AppLogger.error('AuthService: Error approving pairing', e, stack);
      return false;
    } finally {
      client.close();
    }
  }

  /// Reject a pairing request.
  Future<bool> rejectPairing(String approvalId) async {
    AppLogger.info('AuthService: Rejecting pairing $approvalId');

    final client = AppConfig.createHttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('$baseUrl/api/auth/approve'),
      );
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode({
        'approval_id': approvalId,
        'action': 'reject',
      }));
      final response = await request.close();
      await response.drain<void>();

      return response.statusCode == 200;
    } catch (e, stack) {
      AppLogger.error('AuthService: Error rejecting pairing', e, stack);
      return false;
    } finally {
      client.close();
    }
  }

  /// Get list of paired devices.
  Future<List<Device>> getDevices() async {
    final client = AppConfig.createHttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('$baseUrl/api/auth/devices'),
      );
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as List;
        return data.map((d) => Device.fromJson(d)).toList();
      } else {
        AppLogger.warning('AuthService: Failed to get devices: ${response.statusCode}');
        return [];
      }
    } catch (e, stack) {
      AppLogger.error('AuthService: Error getting devices', e, stack);
      return [];
    } finally {
      client.close();
    }
  }

  /// Update device trust level.
  Future<bool> updateDeviceTrust(String deviceId, String trustLevel) async {
    AppLogger.info('AuthService: Updating device $deviceId trust to $trustLevel');

    final client = AppConfig.createHttpClient();
    try {
      final request = await client.openUrl(
        'PUT',
        Uri.parse('$baseUrl/api/auth/devices/$deviceId/trust'),
      );
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode({'trust_level': trustLevel}));
      final response = await request.close();
      await response.drain<void>();

      return response.statusCode == 200;
    } catch (e, stack) {
      AppLogger.error('AuthService: Error updating device trust', e, stack);
      return false;
    } finally {
      client.close();
    }
  }

  /// Revoke a device.
  Future<bool> revokeDevice(String deviceId) async {
    AppLogger.info('AuthService: Revoking device $deviceId');

    final client = AppConfig.createHttpClient();
    try {
      final request = await client.deleteUrl(
        Uri.parse('$baseUrl/api/auth/devices/$deviceId'),
      );
      final response = await request.close();
      await response.drain<void>();

      return response.statusCode == 200;
    } catch (e, stack) {
      AppLogger.error('AuthService: Error revoking device', e, stack);
      return false;
    } finally {
      client.close();
    }
  }

  /// Dispose resources.
  void dispose() {
    disconnectWebSocket();
    _pairingRequestController.close();
  }
}
