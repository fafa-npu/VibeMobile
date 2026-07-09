import 'dart:async';
import 'dart:io';

import '../../core/logging/app_logger.dart';
import '../../data/models/session.dart';
import '../../data/models/settings.dart';

/// Service for managing tmux sessions.
class TmuxService {
  final String _prefix;
  static const _processTimeout = Duration(seconds: 5);

  TmuxService({String prefix = 'vibe'}) : _prefix = prefix;

  String get prefix => _prefix;

  /// Check if tmux is installed.
  Future<bool> isInstalled() async {
    try {
      final result = await Process.run('which', ['tmux'])
          .timeout(_processTimeout);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// List all sessions with the configured prefix.
  Future<List<Session>> listSessions() async {
    try {
      final result = await Process.run('tmux', [
        'list-sessions',
        '-F',
        '#{session_name}:#{session_created}:#{pane_current_path}',
      ]).timeout(_processTimeout);

      if (result.exitCode != 0) {
        // No sessions or tmux not running
        return [];
      }

      final output = result.stdout as String;
      final sessions = <Session>[];

      for (final line in output.trim().split('\n')) {
        if (line.isEmpty) continue;
        final session = Session.fromTmux(line);
        if (session.name.startsWith(_prefix)) {
          sessions.add(session);
        }
      }

      AppLogger.debug('TmuxService: Found ${sessions.length} sessions');
      return sessions;
    } catch (e) {
      AppLogger.warning('TmuxService: Error listing sessions: $e');
      return [];
    }
  }

  /// Create a new tmux session running a supported AI CLI.
  Future<String?> createSession({
    required String workingDir,
    CliAgent agent = CliAgent.claude,
  }) async {
    // Generate session name
    final existing = await listSessions();
    var index = 1;
    var sessionName = '$_prefix-$index';

    while (existing.any((s) => s.name == sessionName)) {
      index++;
      sessionName = '$_prefix-$index';
    }

    final command = agent.command;
    AppLogger.info('TmuxService: Creating ${agent.displayName} session $sessionName in $workingDir');

    try {
      final result = await Process.run('tmux', [
        'new-session',
        '-d',
        '-s',
        sessionName,
        '-c',
        workingDir,
        '/bin/bash',
        '-c',
        command,
      ]).timeout(_processTimeout);

      if (result.exitCode == 0) {
        AppLogger.info('TmuxService: Session $sessionName created');
        return sessionName;
      }

      AppLogger.error('TmuxService: Failed to create session: ${result.stderr}');
      return null;
    } catch (e, stack) {
      AppLogger.error('TmuxService: Error creating session', e, stack);
      return null;
    }
  }

  /// Attach to a session in a terminal app.
  Future<bool> attachSession(String sessionId, TerminalApp terminal) async {
    AppLogger.info('TmuxService: Attaching to session $sessionId using $terminal');

    String script;

    if (terminal == TerminalApp.iterm) {
      script = '''
tell application "iTerm"
  activate
  create window with default profile command "tmux attach -t $sessionId"
end tell
''';
    } else {
      script = '''
tell application "Terminal"
  activate
  do script "tmux attach -t $sessionId"
end tell
''';
    }

    try {
      final result = await Process.run('osascript', ['-e', script])
          .timeout(_processTimeout);
      return result.exitCode == 0;
    } catch (e, stack) {
      AppLogger.error('TmuxService: Error attaching to session', e, stack);
      return false;
    }
  }

  /// Kill a tmux session.
  Future<bool> killSession(String sessionId) async {
    AppLogger.info('TmuxService: Killing session $sessionId');

    try {
      final result = await Process.run('tmux', [
        'kill-session',
        '-t',
        sessionId,
      ]).timeout(_processTimeout);

      if (result.exitCode == 0) {
        AppLogger.info('TmuxService: Session $sessionId killed');
        return true;
      }

      AppLogger.warning('TmuxService: Failed to kill session: ${result.stderr}');
      return false;
    } catch (e, stack) {
      AppLogger.error('TmuxService: Error killing session', e, stack);
      return false;
    }
  }

  /// Check if a session exists.
  Future<bool> sessionExists(String sessionId) async {
    try {
      final result = await Process.run('tmux', [
        'has-session',
        '-t',
        sessionId,
      ]).timeout(_processTimeout);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Send keys to a session.
  Future<bool> sendKeys(String sessionId, String keys) async {
    try {
      final result = await Process.run('tmux', [
        'send-keys',
        '-t',
        sessionId,
        keys,
      ]).timeout(_processTimeout);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Capture output from a session.
  Future<String?> captureOutput(String sessionId, {int lines = 100}) async {
    try {
      final result = await Process.run('tmux', [
        'capture-pane',
        '-t',
        sessionId,
        '-p',
        '-S',
        '-$lines',
      ]).timeout(_processTimeout);

      if (result.exitCode == 0) {
        return result.stdout.toString();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
