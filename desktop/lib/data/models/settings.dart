/// Terminal application enum.
enum TerminalApp {
  terminal,
  iterm,
}

/// Application settings model.
class Settings {
  final int apiPort;
  final int webPort;
  final String sessionPrefix;
  final bool autoStartServer;
  final bool autoStartWeb;
  final bool launchAtLogin;
  final TerminalApp terminalApp;
  final bool enableTunnel;
  final String? tunnelName;
  final String? tunnelHostname;
  final String? proxyUrl;

  const Settings({
    this.apiPort = 8765,
    this.webPort = 5173,
    this.sessionPrefix = 'vibe',
    this.autoStartServer = false,
    this.autoStartWeb = false,
    this.launchAtLogin = false,
    this.terminalApp = TerminalApp.terminal,
    this.enableTunnel = false,
    this.tunnelName,
    this.tunnelHostname,
    this.proxyUrl,
  });

  Settings copyWith({
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
    bool clearTunnelName = false,
    bool clearTunnelHostname = false,
    bool clearProxyUrl = false,
  }) {
    return Settings(
      apiPort: apiPort ?? this.apiPort,
      webPort: webPort ?? this.webPort,
      sessionPrefix: sessionPrefix ?? this.sessionPrefix,
      autoStartServer: autoStartServer ?? this.autoStartServer,
      autoStartWeb: autoStartWeb ?? this.autoStartWeb,
      launchAtLogin: launchAtLogin ?? this.launchAtLogin,
      terminalApp: terminalApp ?? this.terminalApp,
      enableTunnel: enableTunnel ?? this.enableTunnel,
      tunnelName: clearTunnelName ? null : (tunnelName ?? this.tunnelName),
      tunnelHostname: clearTunnelHostname ? null : (tunnelHostname ?? this.tunnelHostname),
      proxyUrl: clearProxyUrl ? null : (proxyUrl ?? this.proxyUrl),
    );
  }

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      apiPort: json['api_port'] as int? ?? 8765,
      webPort: json['web_port'] as int? ?? 5173,
      sessionPrefix: json['session_prefix'] as String? ?? 'vibe',
      autoStartServer: json['auto_start_server'] as bool? ?? false,
      autoStartWeb: json['auto_start_web'] as bool? ?? false,
      launchAtLogin: json['launch_at_login'] as bool? ?? false,
      terminalApp: json['terminal_app'] == 'iterm'
          ? TerminalApp.iterm
          : TerminalApp.terminal,
      enableTunnel: json['enable_tunnel'] as bool? ?? false,
      tunnelName: json['tunnel_name'] as String?,
      tunnelHostname: json['tunnel_hostname'] as String?,
      proxyUrl: json['proxy_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'api_port': apiPort,
      'web_port': webPort,
      'session_prefix': sessionPrefix,
      'auto_start_server': autoStartServer,
      'auto_start_web': autoStartWeb,
      'launch_at_login': launchAtLogin,
      'terminal_app': terminalApp == TerminalApp.iterm ? 'iterm' : 'terminal',
      'enable_tunnel': enableTunnel,
      'tunnel_name': tunnelName,
      'tunnel_hostname': tunnelHostname,
      'proxy_url': proxyUrl,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Settings &&
          runtimeType == other.runtimeType &&
          apiPort == other.apiPort &&
          webPort == other.webPort &&
          sessionPrefix == other.sessionPrefix &&
          autoStartServer == other.autoStartServer &&
          autoStartWeb == other.autoStartWeb &&
          launchAtLogin == other.launchAtLogin &&
          terminalApp == other.terminalApp &&
          enableTunnel == other.enableTunnel &&
          tunnelName == other.tunnelName &&
          tunnelHostname == other.tunnelHostname &&
          proxyUrl == other.proxyUrl;

  @override
  int get hashCode => Object.hash(
        apiPort,
        webPort,
        sessionPrefix,
        autoStartServer,
        autoStartWeb,
        launchAtLogin,
        terminalApp,
        enableTunnel,
        tunnelName,
        tunnelHostname,
        proxyUrl,
      );
}
