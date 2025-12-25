/// Application settings model.
enum TerminalApp {
  terminal,
  iterm,
}

class Settings {
  final int apiPort;
  final int webPort;
  final String sessionPrefix;
  final bool autoStartServer;
  final bool launchAtLogin;
  final TerminalApp terminalApp;
  final bool enableTunnel;
  final String? tunnelName;
  final String? tunnelHostname;

  Settings({
    this.apiPort = 8765,
    this.webPort = 5173,
    this.sessionPrefix = 'vibe',
    this.autoStartServer = false,
    this.launchAtLogin = false,
    this.terminalApp = TerminalApp.terminal,
    this.enableTunnel = false,
    this.tunnelName,
    this.tunnelHostname,
  });

  Settings copyWith({
    int? apiPort,
    int? webPort,
    String? sessionPrefix,
    bool? autoStartServer,
    bool? launchAtLogin,
    TerminalApp? terminalApp,
    bool? enableTunnel,
    String? tunnelName,
    String? tunnelHostname,
  }) {
    return Settings(
      apiPort: apiPort ?? this.apiPort,
      webPort: webPort ?? this.webPort,
      sessionPrefix: sessionPrefix ?? this.sessionPrefix,
      autoStartServer: autoStartServer ?? this.autoStartServer,
      launchAtLogin: launchAtLogin ?? this.launchAtLogin,
      terminalApp: terminalApp ?? this.terminalApp,
      enableTunnel: enableTunnel ?? this.enableTunnel,
      tunnelName: tunnelName ?? this.tunnelName,
      tunnelHostname: tunnelHostname ?? this.tunnelHostname,
    );
  }

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      apiPort: json['api_port'] as int? ?? 8765,
      webPort: json['web_port'] as int? ?? 5173,
      sessionPrefix: json['session_prefix'] as String? ?? 'vibe',
      autoStartServer: json['auto_start_server'] as bool? ?? false,
      launchAtLogin: json['launch_at_login'] as bool? ?? false,
      terminalApp: json['terminal_app'] == 'iterm'
          ? TerminalApp.iterm
          : TerminalApp.terminal,
      enableTunnel: json['enable_tunnel'] as bool? ?? false,
      tunnelName: json['tunnel_name'] as String?,
      tunnelHostname: json['tunnel_hostname'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'api_port': apiPort,
      'web_port': webPort,
      'session_prefix': sessionPrefix,
      'auto_start_server': autoStartServer,
      'launch_at_login': launchAtLogin,
      'terminal_app': terminalApp == TerminalApp.iterm ? 'iterm' : 'terminal',
      'enable_tunnel': enableTunnel,
      'tunnel_name': tunnelName,
      'tunnel_hostname': tunnelHostname,
    };
  }
}
