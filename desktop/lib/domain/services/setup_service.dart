import 'dart:io';
import 'dart:convert';

import '../../core/logging/app_logger.dart';

/// Represents the status of a single dependency.
class DependencyStatus {
  final String name;
  final String displayName;
  final bool isInstalled;
  final String? version;
  final String? installCommand;

  const DependencyStatus({
    required this.name,
    required this.displayName,
    required this.isInstalled,
    this.version,
    this.installCommand,
  });

  DependencyStatus copyWith({bool? isInstalled, String? version}) {
    return DependencyStatus(
      name: name,
      displayName: displayName,
      isInstalled: isInstalled ?? this.isInstalled,
      version: version ?? this.version,
      installCommand: installCommand,
    );
  }
}

/// Represents the overall setup status.
/// Note: mkcert and certificates are no longer required since tunnel providers handle HTTPS.
class SetupStatus {
  final DependencyStatus homebrew;
  final DependencyStatus tmux;
  final DependencyStatus node;
  final DependencyStatus devTunnel;

  const SetupStatus({
    required this.homebrew,
    required this.tmux,
    required this.node,
    required this.devTunnel,
  });

  /// Check if all required dependencies are ready.
  bool get isReady =>
      homebrew.isInstalled &&
      tmux.isInstalled &&
      node.isInstalled &&
      devTunnel.isInstalled;

  /// Get list of missing dependencies.
  List<DependencyStatus> get missingDependencies {
    final deps = <DependencyStatus>[];
    if (!homebrew.isInstalled) deps.add(homebrew);
    if (!tmux.isInstalled) deps.add(tmux);
    if (!node.isInstalled) deps.add(node);
    if (!devTunnel.isInstalled) deps.add(devTunnel);
    return deps;
  }

  /// Get all dependencies as a list.
  List<DependencyStatus> get allDependencies => [
        homebrew,
        tmux,
        node,
        devTunnel,
      ];
}

/// Result of a setup operation.
class SetupResult {
  final bool success;
  final String? error;
  final String? output;

  const SetupResult({
    required this.success,
    this.error,
    this.output,
  });

  factory SetupResult.ok([String? output]) =>
      SetupResult(success: true, output: output);

  factory SetupResult.fail(String error) =>
      SetupResult(success: false, error: error);
}

/// Service for checking and setting up the environment.
class SetupService {
  static final SetupService _instance = SetupService._internal();
  factory SetupService() => _instance;
  SetupService._internal();

  String get _homeDir => Platform.environment['HOME'] ?? '/Users';

  /// Check all dependencies and return the setup status.
  /// Note: mkcert and certificates are no longer required (tunnel providers handle HTTPS).
  Future<SetupStatus> checkEnvironment() async {
    AppLogger.info('SetupService: Checking environment...');

    final results = await Future.wait([
      _checkHomebrew(),
      _checkTmux(),
      _checkNode(),
      _checkDevTunnel(),
    ]);

    final status = SetupStatus(
      homebrew: results[0],
      tmux: results[1],
      node: results[2],
      devTunnel: results[3],
    );

    AppLogger.info('SetupService: Environment check complete. Ready: ${status.isReady}');
    return status;
  }

  /// Check if Homebrew is installed.
  Future<DependencyStatus> _checkHomebrew() async {
    final result = await _runCommand('which', ['brew']);
    String? version;

    if (result.success) {
      final versionResult = await _runCommand('brew', ['--version']);
      if (versionResult.success) {
        // Extract version from "Homebrew 4.2.0"
        final match = RegExp(r'Homebrew (\d+\.\d+\.\d+)').firstMatch(versionResult.output ?? '');
        version = match?.group(1);
      }
    }

    return DependencyStatus(
      name: 'homebrew',
      displayName: 'Homebrew',
      isInstalled: result.success,
      version: version,
      installCommand: '/bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"',
    );
  }

  /// Check if tmux is installed.
  Future<DependencyStatus> _checkTmux() async {
    final result = await _runCommand('which', ['tmux']);
    String? version;

    if (result.success) {
      final versionResult = await _runCommand('tmux', ['-V']);
      if (versionResult.success) {
        // Extract version from "tmux 3.4"
        final match = RegExp(r'tmux (\d+\.\d+)').firstMatch(versionResult.output ?? '');
        version = match?.group(1);
      }
    }

    return DependencyStatus(
      name: 'tmux',
      displayName: 'tmux',
      isInstalled: result.success,
      version: version,
      installCommand: 'brew install tmux',
    );
  }

  /// Check if Node.js is installed.
  Future<DependencyStatus> _checkNode() async {
    final result = await _runCommand('which', ['node']);
    String? version;

    if (result.success) {
      final versionResult = await _runCommand('node', ['--version']);
      if (versionResult.success) {
        // Extract version from "v20.10.0"
        final match = RegExp(r'v?(\d+\.\d+\.\d+)').firstMatch(versionResult.output ?? '');
        version = match?.group(1);
      }
    }

    return DependencyStatus(
      name: 'node',
      displayName: 'Node.js',
      isInstalled: result.success,
      version: version,
      installCommand: 'brew install node',
    );
  }

  /// Check if Microsoft Dev Tunnel CLI is installed.
  Future<DependencyStatus> _checkDevTunnel() async {
    final result = await _runCommand('which', ['devtunnel']);
    String? version;

    if (result.success) {
      final versionResult = await _runCommand('devtunnel', ['--version']);
      if (versionResult.success) {
        version = versionResult.output;
      }
    }

    return DependencyStatus(
      name: 'devtunnel',
      displayName: 'Microsoft Dev Tunnel',
      isInstalled: result.success,
      version: version,
      installCommand: 'brew install microsoft/dev-tunnels/devtunnel',
    );
  }

  /// Install Homebrew.
  Future<SetupResult> installHomebrew({Function(String)? onProgress}) async {
    onProgress?.call('Installing Homebrew...');
    AppLogger.info('SetupService: Installing Homebrew');

    // Homebrew installation requires interactive shell
    // We need to open Terminal for this
    final script = '''
      tell application "Terminal"
        activate
        do script "/bin/bash -c \\"\\\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\\""
      end tell
    ''';

    final result = await _runCommand('osascript', ['-e', script]);

    if (result.success) {
      return SetupResult.ok('Homebrew installation started in Terminal. Please follow the prompts.');
    } else {
      return SetupResult.fail('Failed to start Homebrew installation: ${result.error}');
    }
  }

  /// Install dependencies using Homebrew.
  Future<SetupResult> installDependencies({
    Function(String)? onProgress,
    required List<String> dependencies,
  }) async {
    for (final dep in dependencies) {
      onProgress?.call('Installing $dep...');
      AppLogger.info('SetupService: Installing $dep');

      final packageName = dep == 'devtunnel'
          ? 'microsoft/dev-tunnels/devtunnel'
          : dep;
      final result = await _runCommand('brew', ['install', packageName]);
      if (!result.success) {
        return SetupResult.fail('Failed to install $dep: ${result.error}');
      }
    }

    return SetupResult.ok('All dependencies installed successfully');
  }

  /// Run the full setup process.
  /// Note: Installs Homebrew, tmux, Node.js, and Microsoft Dev Tunnel. Certificates are not needed.
  Future<SetupResult> runFullSetup({Function(String)? onProgress}) async {
    AppLogger.info('SetupService: Starting full setup');

    // Check current status
    final status = await checkEnvironment();

    // Install Homebrew if missing
    if (!status.homebrew.isInstalled) {
      onProgress?.call('Homebrew is required. Opening Terminal for installation...');
      final result = await installHomebrew(onProgress: onProgress);
      if (!result.success) {
        return result;
      }
      // User needs to complete Homebrew installation manually
      return SetupResult.fail(
        'Please complete Homebrew installation in Terminal, then restart VibeMobile.'
      );
    }

    // Install missing dependencies.
    final depsToInstall = <String>[];
    if (!status.tmux.isInstalled) depsToInstall.add('tmux');
    if (!status.node.isInstalled) depsToInstall.add('node');
    if (!status.devTunnel.isInstalled) depsToInstall.add('devtunnel');

    if (depsToInstall.isNotEmpty) {
      final result = await installDependencies(
        onProgress: onProgress,
        dependencies: depsToInstall,
      );
      if (!result.success) {
        return result;
      }
    }

    onProgress?.call('Setup complete!');
    AppLogger.info('SetupService: Full setup completed');
    return SetupResult.ok('Environment setup completed successfully');
  }

  /// Helper to run a command and capture output.
  Future<SetupResult> _runCommand(String command, List<String> args) async {
    try {
      final result = await Process.run(command, args);

      if (result.exitCode == 0) {
        return SetupResult.ok(result.stdout.toString().trim());
      } else {
        return SetupResult.fail(result.stderr.toString().trim());
      }
    } catch (e) {
      return SetupResult.fail(e.toString());
    }
  }

  /// Check if setup has been completed before.
  Future<bool> hasCompletedSetup() async {
    final configFile = File('$_homeDir/.vibemobile/config.json');
    if (!await configFile.exists()) {
      return false;
    }

    try {
      final content = await configFile.readAsString();
      final config = jsonDecode(content) as Map<String, dynamic>;
      return config['setup_completed'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Mark setup as completed.
  Future<void> markSetupCompleted() async {
    final configDir = Directory('$_homeDir/.vibemobile');
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }

    final configFile = File('$_homeDir/.vibemobile/config.json');
    final status = await checkEnvironment();

    final config = {
      'setup_completed': true,
      'setup_date': DateTime.now().toIso8601String(),
      'versions': {
        'tmux': status.tmux.version,
        'node': status.node.version,
        'devtunnel': status.devTunnel.version,
      },
    };

    await configFile.writeAsString(jsonEncode(config));
    AppLogger.info('SetupService: Marked setup as completed');
  }
}
