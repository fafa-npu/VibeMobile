import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/models/settings.dart';

/// Provider for settings state management.
class SettingsNotifier extends StateNotifier<Settings> {
  SettingsNotifier() : super(const Settings());

  File? _settingsFile;

  /// Initialize settings from disk.
  Future<void> initialize() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      _settingsFile = File('${appDir.path}/settings.json');

      if (await _settingsFile!.exists()) {
        final content = await _settingsFile!.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        state = Settings.fromJson(json);
      }
    } catch (e) {
      // Use default settings on error
    }
  }

  /// Save settings to disk.
  Future<void> _saveSettings() async {
    if (_settingsFile == null) return;

    try {
      await _settingsFile!.writeAsString(jsonEncode(state.toJson()));
    } catch (e) {
      // Ignore save errors
    }
  }

  /// Update API port.
  void setApiPort(int port) {
    state = state.copyWith(apiPort: port);
    _saveSettings();
  }

  /// Update Web port.
  void setWebPort(int port) {
    state = state.copyWith(webPort: port);
    _saveSettings();
  }

  /// Update session prefix.
  void setSessionPrefix(String prefix) {
    state = state.copyWith(sessionPrefix: prefix);
    _saveSettings();
  }

  /// Update auto-start server setting.
  void setAutoStartServer(bool value) {
    state = state.copyWith(autoStartServer: value);
    _saveSettings();
  }

  /// Update auto-start web setting.
  void setAutoStartWeb(bool value) {
    state = state.copyWith(autoStartWeb: value);
    _saveSettings();
  }

  /// Update launch at login setting.
  void setLaunchAtLogin(bool value) {
    state = state.copyWith(launchAtLogin: value);
    _saveSettings();
  }

  /// Update terminal app setting.
  void setTerminalApp(TerminalApp app) {
    state = state.copyWith(terminalApp: app);
    _saveSettings();
  }

  /// Update enable tunnel setting.
  void setEnableTunnel(bool value) {
    state = state.copyWith(enableTunnel: value);
    _saveSettings();
  }

  /// Update tunnel name.
  void setTunnelName(String? name) {
    if (name == null || name.isEmpty) {
      state = state.copyWith(clearTunnelName: true);
    } else {
      state = state.copyWith(tunnelName: name);
    }
    _saveSettings();
  }

  /// Update tunnel hostname.
  void setTunnelHostname(String? hostname) {
    if (hostname == null || hostname.isEmpty) {
      state = state.copyWith(clearTunnelHostname: true);
    } else {
      state = state.copyWith(tunnelHostname: hostname);
    }
    _saveSettings();
  }

  /// Update proxy URL.
  void setProxyUrl(String? url) {
    if (url == null || url.isEmpty) {
      state = state.copyWith(clearProxyUrl: true);
    } else {
      state = state.copyWith(proxyUrl: url);
    }
    _saveSettings();
  }

  /// Reset all settings to defaults.
  void resetToDefaults() {
    state = const Settings();
    _saveSettings();
  }

  /// Update multiple settings at once.
  void updateSettings({
    int? apiPort,
    int? webPort,
    String? sessionPrefix,
    bool? autoStartServer,
    bool? autoStartWeb,
    bool? launchAtLogin,
    TerminalApp? terminalApp,
    bool? enableTunnel,
    String? tunnelName,
    String? tunnelHostname,
    String? proxyUrl,
  }) {
    state = state.copyWith(
      apiPort: apiPort,
      webPort: webPort,
      sessionPrefix: sessionPrefix,
      autoStartServer: autoStartServer,
      autoStartWeb: autoStartWeb,
      launchAtLogin: launchAtLogin,
      terminalApp: terminalApp,
      enableTunnel: enableTunnel,
      tunnelName: tunnelName,
      tunnelHostname: tunnelHostname,
      proxyUrl: proxyUrl,
    );
    _saveSettings();
  }
}

/// Provider for SettingsNotifier.
final settingsProvider = StateNotifierProvider<SettingsNotifier, Settings>((ref) {
  return SettingsNotifier();
});

/// Provider for API port.
final apiPortProvider = Provider<int>((ref) {
  return ref.watch(settingsProvider).apiPort;
});

/// Provider for Web port.
final webPortProvider = Provider<int>((ref) {
  return ref.watch(settingsProvider).webPort;
});
