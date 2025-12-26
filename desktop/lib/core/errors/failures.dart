/// Base class for all failures in the application.
sealed class Failure {
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  const Failure(this.message, [this.error, this.stackTrace]);

  @override
  String toString() => '$runtimeType: $message';
}

/// Server-related failures.
class ServerFailure extends Failure {
  const ServerFailure(super.message, [super.error, super.stackTrace]);
}

/// Web service-related failures.
class WebFailure extends Failure {
  const WebFailure(super.message, [super.error, super.stackTrace]);
}

/// Tunnel-related failures.
class TunnelFailure extends Failure {
  const TunnelFailure(super.message, [super.error, super.stackTrace]);
}

/// Network-related failures.
class NetworkFailure extends Failure {
  const NetworkFailure(super.message, [super.error, super.stackTrace]);
}

/// Session/Tmux-related failures.
class SessionFailure extends Failure {
  const SessionFailure(super.message, [super.error, super.stackTrace]);
}

/// Authentication-related failures.
class AuthFailure extends Failure {
  const AuthFailure(super.message, [super.error, super.stackTrace]);
}

/// Storage-related failures.
class StorageFailure extends Failure {
  const StorageFailure(super.message, [super.error, super.stackTrace]);
}

/// Unknown/unexpected failures.
class UnknownFailure extends Failure {
  const UnknownFailure(super.message, [super.error, super.stackTrace]);
}
