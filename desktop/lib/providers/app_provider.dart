import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings.dart';
import '../models/session.dart';
import '../services/server_manager.dart';
import '../services/tmux_service.dart';
import '../services/tunnel_service.dart';

/// Main application state provider.
class AppProvider extends ChangeNotifier {
  late SharedPreferences _prefs;
  late Settings _settings;
  late ServerManager _serverManager;
  late TmuxService _tmuxService;
  late TunnelService _tunnelService;

  List<Session> _sessions = [];
  bool _serverRunning = false;
  bool _tunnelConnected = false;
  String? _tunnelUrl;
  Timer? _refreshTimer;

  // Getters
  Settings get settings => _settings;
  List<Session> get sessions => _sessions;
  bool get serverRunning => _serverRunning;
  bool get tunnelConnected => _tunnelConnected;
  String? get tunnelUrl => _tunnelUrl;

  /// Initialize the provider.
  Future<void> init(String projectPath) async {
    _prefs = await SharedPreferences.getInstance();

    // Load settings
    final settingsJson = _prefs.getString('settings');
    if (settingsJson != null) {
      _settings = Settings.fromJson(jsonDecode(settingsJson));
    } else {
      _settings = Settings();
    }

    // Initialize services
    _serverManager = ServerManager(projectPath: projectPath);
    _tmuxService = TmuxService(prefix: _settings.sessionPrefix);
    _tunnelService = TunnelService();

    // Check initial state
    _serverRunning = await _serverManager.healthCheck(_settings.apiPort);
    _tunnelConnected = _tunnelService.isConnected;
    _tunnelUrl = _tunnelService.publicUrl;

    // Load sessions
    await refreshSessions();

    // Start refresh timer
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _periodicRefresh(),
    );

    // Auto-start server if configured
    if (_settings.autoStartServer && !_serverRunning) {
      await startServer();
    }

    notifyListeners();
  }

  void _periodicRefresh() async {
    await refreshSessions();
    _serverRunning = await _serverManager.healthCheck(_settings.apiPort);
    _tunnelConnected = _tunnelService.isConnected;
    _tunnelUrl = _tunnelService.publicUrl;
    notifyListeners();
  }

  /// Save settings.
  Future<void> saveSettings(Settings newSettings) async {
    _settings = newSettings;
    await _prefs.setString('settings', jsonEncode(_settings.toJson()));
    _tmuxService = TmuxService(prefix: _settings.sessionPrefix);
    notifyListeners();
  }

  /// Refresh session list.
  Future<void> refreshSessions() async {
    _sessions = await _tmuxService.listSessions();
    notifyListeners();
  }

  /// Start the backend server.
  Future<bool> startServer() async {
    final success = await _serverManager.start(_settings.apiPort);
    if (success) {
      _serverRunning = true;
      notifyListeners();
    }
    return success;
  }

  /// Stop the backend server.
  Future<void> stopServer() async {
    await _serverManager.stop();
    _serverRunning = false;
    notifyListeners();
  }

  /// Create a new session.
  Future<String?> createSession(String workingDir, {String command = 'claude'}) async {
    final sessionName = await _tmuxService.createSession(
      workingDir: workingDir,
      command: command,
    );
    if (sessionName != null) {
      await refreshSessions();
    }
    return sessionName;
  }

  /// Attach to a session.
  Future<bool> attachSession(String sessionId) async {
    return _tmuxService.attachSession(sessionId, _settings.terminalApp);
  }

  /// Kill a session.
  Future<bool> killSession(String sessionId) async {
    final success = await _tmuxService.killSession(sessionId);
    if (success) {
      await refreshSessions();
    }
    return success;
  }

  /// Start tunnel.
  Future<bool> startTunnel() async {
    final success = await _tunnelService.startQuickTunnel(_settings.apiPort);
    if (success) {
      _tunnelConnected = true;
      _tunnelUrl = _tunnelService.publicUrl;
      notifyListeners();
    }
    return success;
  }

  /// Stop tunnel.
  Future<void> stopTunnel() async {
    await _tunnelService.stop();
    _tunnelConnected = false;
    _tunnelUrl = null;
    notifyListeners();
  }

  /// Check if cloudflared is installed.
  Future<bool> isCloudflaredInstalled() async {
    return _tunnelService.isCloudflaredInstalled();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
