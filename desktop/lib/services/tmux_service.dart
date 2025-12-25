import 'dart:io';

import '../models/session.dart';
import '../models/settings.dart';

/// Service for managing tmux sessions.
class TmuxService {
  final String _prefix;

  TmuxService({String prefix = 'vibe'}) : _prefix = prefix;

  /// List all sessions with the configured prefix.
  Future<List<Session>> listSessions() async {
    try {
      final result = await Process.run('tmux', [
        'list-sessions',
        '-F',
        '#{session_name}:#{session_created}:#{pane_current_path}',
      ]);

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

      return sessions;
    } catch (e) {
      return [];
    }
  }

  /// Create a new tmux session running Claude.
  Future<String?> createSession({
    required String workingDir,
    String command = 'claude',
  }) async {
    // Generate session name
    final existing = await listSessions();
    var index = 1;
    var sessionName = '$_prefix-$index';

    while (existing.any((s) => s.name == sessionName)) {
      index++;
      sessionName = '$_prefix-$index';
    }

    try {
      final result = await Process.run('tmux', [
        'new-session',
        '-d',
        '-s',
        sessionName,
        '-c',
        workingDir,
        command,
      ]);

      if (result.exitCode == 0) {
        return sessionName;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Attach to a session in a terminal app.
  Future<bool> attachSession(
    String sessionId,
    TerminalApp terminal,
  ) async {
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
      final result = await Process.run('osascript', ['-e', script]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Kill a tmux session.
  Future<bool> killSession(String sessionId) async {
    try {
      final result = await Process.run('tmux', [
        'kill-session',
        '-t',
        sessionId,
      ]);
      return result.exitCode == 0;
    } catch (e) {
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
      ]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
}
