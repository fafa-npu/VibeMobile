import 'dart:io';
import 'dart:async';

/// Service for managing the backend server.
class ServerManager {
  Process? _serverProcess;
  bool _isRunning = false;
  final String _projectPath;

  ServerManager({required String projectPath}) : _projectPath = projectPath;

  bool get isRunning => _isRunning;

  /// Start the backend server.
  Future<bool> start(int port) async {
    if (_isRunning) return true;

    try {
      // Activate venv and run uvicorn
      _serverProcess = await Process.start(
        '/bin/bash',
        [
          '-c',
          'source .venv/bin/activate && python -m uvicorn server.main:app --host 0.0.0.0 --port $port',
        ],
        workingDirectory: _projectPath,
      );

      // Wait a bit to see if it starts successfully
      await Future.delayed(const Duration(seconds: 2));

      // Check if process is still running
      if (_serverProcess != null) {
        _isRunning = true;

        // Listen for process exit
        _serverProcess!.exitCode.then((_) {
          _isRunning = false;
          _serverProcess = null;
        });

        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Stop the backend server.
  Future<void> stop() async {
    if (_serverProcess != null) {
      _serverProcess!.kill();
      _serverProcess = null;
    }
    _isRunning = false;
  }

  /// Check if server is responding.
  Future<bool> healthCheck(int port) async {
    try {
      final result = await Process.run('curl', [
        '-s',
        '-o',
        '/dev/null',
        '-w',
        '%{http_code}',
        'http://localhost:$port/api/sessions',
      ]);
      return result.stdout.toString().trim() == '200';
    } catch (e) {
      return false;
    }
  }

  /// Find and kill existing server process on port.
  Future<void> killExistingServer(int port) async {
    try {
      final result = await Process.run('lsof', ['-ti', ':$port']);
      final pids = result.stdout.toString().trim().split('\n');
      for (final pid in pids) {
        if (pid.isNotEmpty) {
          await Process.run('kill', ['-9', pid]);
        }
      }
    } catch (e) {
      // Ignore errors
    }
  }
}
