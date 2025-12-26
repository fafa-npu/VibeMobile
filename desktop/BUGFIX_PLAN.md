# VibeMobile Desktop 卡死问题修复方案

## 问题诊断总结

### 根本原因（多层次）

```
┌─────────────────────────────────────────────────────────────────┐
│  第 0 层（根因）：架构不匹配                                      │
│  VibeMobile.app (x86_64) → spawn → tmux/node/python (arm64)     │
│  Rosetta 翻译边界导致 Process.start() 卡死                       │
└─────────────────────────────────────────────────────────────────┘
                              ↓ 叠加
┌─────────────────────────────────────────────────────────────────┐
│  第 1 层（加速器）：日志风暴                                      │
│  - Level.debug 全开                                              │
│  - 子进程输出逐段 debug                                          │
│  - PrettyPrinter 带颜色/emoji 开销                               │
└─────────────────────────────────────────────────────────────────┘
                              ↓ 叠加
┌─────────────────────────────────────────────────────────────────┐
│  第 2 层（累积）：资源泄漏 + 并发堆积                             │
│  - HttpClient 未正确关闭 (377端口累积)                           │
│  - Session 自动刷新无互斥 (13个挂起线程)                         │
│  - 僵尸线程累积                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 诊断证据

| 来源 | 发现 |
|------|------|
| `sample` 命令 | `io.flutter.ui` 线程 100% 时间卡在 `dart::bin::ProcessStarter::Start()` |
| `file` 命令 | VibeMobile.app 是 x86_64，但 tmux/node/python 是 arm64 |
| `lsof` 命令 | 卡死时累积 377 个端口、13 个挂起线程 |
| 代码审查 | 日志级别 `Level.debug`，子进程输出全量打印 |

---

## 阶段 0：修复架构不匹配（必须首先完成）

### 问题描述

当前 Flutter SDK 和构建产物都是 x86_64 架构：
- `/Users/zhaohua/Documents/flutter/bin/cache/dart-sdk/bin/dart`: x86_64
- `VibeMobile.app`: x86_64
- 但系统外部工具 (tmux, node, python, cloudflared) 都是 arm64

在 Apple Silicon 上，x86_64 进程通过 Rosetta 翻译运行，当它尝试 spawn arm64 进程时，
在某些边界情况下会导致 `Process.start()` 卡死。

### 修复步骤

```bash
# 1. 停止当前运行的应用
# 在 Flutter 终端按 Ctrl+C 或关闭应用

# 2. 清理 Flutter 缓存
cd /Users/zhaohua/Documents/flutter
rm -rf bin/cache

# 3. 重新下载 Flutter artifacts (会自动检测架构并下载 arm64 版本)
flutter doctor

# 4. 清理项目构建缓存
cd /Users/zhaohua/Documents/repos/VibeMobile/desktop
flutter clean

# 5. 重新获取依赖
flutter pub get

# 6. 重新构建并运行
flutter run -d macos
```

### 验证方法

```bash
# 验证 Dart SDK 架构
file /Users/zhaohua/Documents/flutter/bin/cache/dart-sdk/bin/dart
# 应该输出: Mach-O 64-bit executable arm64

# 验证应用架构
file build/macos/Build/Products/Debug/VibeMobile.app/Contents/MacOS/VibeMobile
# 应该输出: Mach-O 64-bit executable arm64
```

---

## 阶段 1：修复日志风暴

### 1.1 修改默认日志级别

**文件**: `lib/core/logging/app_logger.dart`

```dart
import 'package:logger/logger.dart';

/// Application logger with configurable output.
class AppLogger {
  static Level _currentLevel = Level.info;  // 默认 info，不是 debug
  static bool _debugModeEnabled = false;

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: false,  // 关闭 emoji 减少开销
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: Level.info,  // 默认 info
  );

  static final List<String> _logHistory = [];
  static const int _maxHistorySize = 500;  // 减少历史大小

  /// 启用/禁用 debug 模式
  static void setDebugMode(bool enabled) {
    _debugModeEnabled = enabled;
    _currentLevel = enabled ? Level.debug : Level.info;
  }

  static bool get isDebugMode => _debugModeEnabled;

  /// Log debug message - 只在 debug 模式下打印
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    if (!_debugModeEnabled) return;  // 非 debug 模式直接返回
    _logger.d(message, error: error, stackTrace: stackTrace);
    _addToHistory('DEBUG', message);
  }

  // ... 其他方法保持不变
}
```

### 1.2 优化子进程日志输出

**文件**: `lib/domain/services/server_service.dart`

```dart
// 原代码 - 每段输出都 debug
_serverProcess!.stdout.listen(
  (data) {
    final output = String.fromCharCodes(data).trim();
    if (output.isNotEmpty) {
      AppLogger.debug('Server stdout: $output');  // 删除这行
    }
  },
);

// 新代码 - 只记录关键状态
_serverProcess!.stdout.listen(
  (data) {
    final output = String.fromCharCodes(data).trim();
    // 只记录关键状态，不逐段打印
    if (output.contains('Application startup complete') ||
        output.contains('Uvicorn running')) {
      AppLogger.info('Server: Started successfully');
    } else if (output.toLowerCase().contains('error')) {
      AppLogger.warning('Server: $output');
    }
    // 其他输出静默丢弃
  },
  onError: (error) => AppLogger.warning('Server stdout error: $error'),
);

_serverProcess!.stderr.listen(
  (data) {
    final output = String.fromCharCodes(data).trim();
    // stderr 只记录真正的错误
    if (output.toLowerCase().contains('error') ||
        output.toLowerCase().contains('exception') ||
        output.toLowerCase().contains('failed')) {
      AppLogger.warning('Server stderr: $output');
    }
  },
  onError: (error) => AppLogger.warning('Server stderr error: $error'),
);
```

**文件**: `lib/domain/services/web_service.dart`

```dart
// 同样的优化
_webProcess!.stdout.listen(
  (data) {
    final output = String.fromCharCodes(data).trim();
    if (output.contains('ready in') || output.contains('Local:')) {
      AppLogger.info('Web: Vite server ready');
    } else if (output.toLowerCase().contains('error')) {
      AppLogger.warning('Web: $output');
    }
  },
  onError: (error) => AppLogger.warning('Web stdout error: $error'),
);

_webProcess!.stderr.listen(
  (data) {
    final output = String.fromCharCodes(data).trim();
    if (output.toLowerCase().contains('error') ||
        output.toLowerCase().contains('failed')) {
      AppLogger.warning('Web stderr: $output');
    }
  },
  onError: (error) => AppLogger.warning('Web stderr error: $error'),
);
```

**文件**: `lib/domain/services/tunnel_service.dart`

```dart
_stderrSubscription = _tunnelProcess!.stderr
    .transform(utf8.decoder)
    .listen(
  (data) {
    // 只提取 URL 和错误，不打印全部输出
    final urlMatch = RegExp(r'https://[\w-]+\.trycloudflare\.com')
        .firstMatch(data);
    if (urlMatch != null && !_isConnected) {
      _publicUrl = urlMatch.group(0);
      _isConnected = true;
      _isStarting = false;
      _startTimeout?.cancel();
      AppLogger.info('Tunnel: Connected at $_publicUrl');
      onTunnelReady?.call(_publicUrl!);
    }

    // 只记录错误
    if (data.contains('failed') ||
        data.contains('error') ||
        data.contains('EOF') ||
        data.contains('connection refused')) {
      AppLogger.warning('Tunnel error: ${data.trim().split('\n').first}');
      lastError = 'Cloudflare 连接失败';
    }
    // 删除: AppLogger.debug('cloudflared: $data');
  },
  // ...
);
```

---

## 阶段 2：修复并发堆积

### 2.1 Session 自动刷新添加互斥锁

**文件**: `lib/presentation/providers/session_provider.dart`

```dart
class SessionNotifier extends StateNotifier<SessionListState> {
  final TmuxService _service;
  final Ref _ref;
  Timer? _refreshTimer;
  bool _refreshInFlight = false;  // 新增：互斥标志

  // ... 构造函数不变

  /// Refresh sessions in background without blocking UI.
  Future<void> _refreshInBackground() async {
    // 添加互斥检查
    if (state.isLoading || _refreshInFlight) {
      return;  // 已有刷新在进行中，跳过本次
    }

    _refreshInFlight = true;  // 加锁
    try {
      final sessions = await _service.listSessions();
      if (mounted) {
        state = state.copyWith(sessions: sessions);
      }
    } catch (e) {
      // 静默忽略后台刷新错误
    } finally {
      _refreshInFlight = false;  // 解锁
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _refreshInFlight = false;
    super.dispose();
  }

  // ... 其他方法不变
}
```

---

## 阶段 3：修复资源泄漏

### 3.1 修复 AuthService HttpClient 泄漏

**文件**: `lib/domain/services/auth_service.dart`

```dart
class AuthService {
  final int apiPort;
  WebSocketChannel? _wsChannel;
  HttpClient? _wsHttpClient;  // 新增：保存 WebSocket 用的 HttpClient
  // ... 其他字段

  /// Connect to WebSocket to receive pairing requests.
  Future<void> connectWebSocket() async {
    if (_isConnected) return;

    AppLogger.info('AuthService: Connecting to WebSocket');

    try {
      if (AppConfig.hasSslCerts) {
        _wsHttpClient = AppConfig.createHttpClient();  // 保存引用
        final uri = Uri.parse('$wsUrl/ws?client_type=desktop');
        final socket = await WebSocket.connect(
          uri.toString(),
          customClient: _wsHttpClient,
        ).timeout(_requestTimeout);
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
      // ... 其余代码不变
    } catch (e, stack) {
      AppLogger.error('AuthService: Failed to connect WebSocket', e, stack);
      _isConnected = false;
      _wsChannel = null;
      _wsHttpClient?.close(force: true);  // 出错时关闭
      _wsHttpClient = null;
    }
  }

  /// Disconnect WebSocket.
  void disconnectWebSocket() {
    _shouldReconnect = false;
    _wsChannel?.sink.close();
    _wsChannel = null;
    _wsHttpClient?.close(force: true);  // 关闭 HttpClient
    _wsHttpClient = null;
    _isConnected = false;
  }

  /// Dispose resources.
  void dispose() {
    disconnectWebSocket();
    _pairingRequestController.close();
  }
}
```

### 3.2 所有 HTTP 方法改用 `close(force: true)`

**文件**: `lib/domain/services/auth_service.dart`

在所有 HTTP 请求方法的 `finally` 块中：

```dart
// 原代码
} finally {
  client.close();
}

// 改为
} finally {
  client.close(force: true);  // 强制关闭所有连接
}
```

需要修改的方法：
- `generatePairingCode()`
- `approvePairing()`
- `rejectPairing()`
- `getDevices()`
- `updateDeviceTrust()`
- `revokeDevice()`

### 3.3 修复 device_provider 的 ref.watch 问题

**文件**: `lib/presentation/providers/device_provider.dart`

```dart
// 原代码 - 会导致 settings 变化时重建 AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  final settings = ref.watch(settingsProvider);  // 问题：watch 会触发重建
  return AuthService(apiPort: settings.apiPort);
});

// 改为 - 只读取一次，不响应变化
final authServiceProvider = Provider<AuthService>((ref) {
  final settings = ref.read(settingsProvider);  // 改用 read
  return AuthService(apiPort: settings.apiPort);
});
```

---

## 修复文件清单

| 阶段 | 文件 | 修改内容 |
|------|------|----------|
| 0 | Flutter SDK | 清理缓存，重新下载 arm64 版本 |
| 1.1 | `lib/core/logging/app_logger.dart` | 默认级别改 info，添加 debug 模式开关 |
| 1.2 | `lib/domain/services/server_service.dart` | 优化 stdout/stderr 日志 |
| 1.2 | `lib/domain/services/web_service.dart` | 优化 stdout/stderr 日志 |
| 1.2 | `lib/domain/services/tunnel_service.dart` | 优化 stderr 日志 |
| 2.1 | `lib/presentation/providers/session_provider.dart` | 添加 `_refreshInFlight` 互斥 |
| 3.1 | `lib/domain/services/auth_service.dart` | 保存并关闭 `_wsHttpClient` |
| 3.2 | `lib/domain/services/auth_service.dart` | 所有 `client.close()` 改为 `close(force: true)` |
| 3.3 | `lib/presentation/providers/device_provider.dart` | `ref.watch` 改为 `ref.read` |

---

## 执行顺序

1. **阶段 0**：必须首先完成架构修复
2. **阶段 1-3**：架构修复后，按顺序修复代码问题
3. **验证**：每个阶段修复后运行应用测试

## 验证方法

修复完成后，验证步骤：

1. 启动应用，同时开启 API Server + Web UI + Tunnel
2. 在 Web UI 发起多次请求
3. 观察 30 分钟以上，确认不再卡死
4. 使用 `lsof -p <PID> | wc -l` 监控文件描述符数量，应保持稳定
5. 使用 `sample <PID> 5` 检查 UI 线程状态，应不再卡在 Process.start()
