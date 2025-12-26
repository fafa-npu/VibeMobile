// Device and authentication models

class Device {
  final String id;
  final String name;
  final String browser;
  final String os;
  final String ip;
  final String trustLevel; // 'full', 'partial', 'view_only'
  final bool isActive;
  final DateTime createdAt;
  final DateTime lastActiveAt;

  Device({
    required this.id,
    required this.name,
    required this.browser,
    required this.os,
    required this.ip,
    required this.trustLevel,
    required this.isActive,
    required this.createdAt,
    required this.lastActiveAt,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      browser: json['browser'] as String? ?? 'Unknown',
      os: json['os'] as String? ?? 'Unknown',
      ip: json['ip'] as String? ?? 'Unknown',
      trustLevel: json['trust_level'] as String? ?? 'view_only',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      lastActiveAt: json['last_active'] != null
          ? DateTime.parse(json['last_active'] as String)
          : (json['last_active_at'] != null
              ? DateTime.parse(json['last_active_at'] as String)
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'browser': browser,
      'os': os,
      'ip': ip,
      'trust_level': trustLevel,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'last_active_at': lastActiveAt.toIso8601String(),
    };
  }

  String get trustLevelDisplay {
    switch (trustLevel) {
      case 'full':
        return '完全信任';
      case 'partial':
        return '部分信任';
      case 'view_only':
        return '仅查看';
      default:
        return '未知';
    }
  }
}

class PairingCode {
  final String code;
  final int expiresIn;
  final DateTime createdAt;

  PairingCode({
    required this.code,
    required this.expiresIn,
    required this.createdAt,
  });

  factory PairingCode.fromJson(Map<String, dynamic> json) {
    return PairingCode(
      code: json['code'] as String,
      expiresIn: json['expires_in'] as int,
      createdAt: DateTime.now(),
    );
  }

  bool get isExpired {
    final elapsed = DateTime.now().difference(createdAt).inSeconds;
    return elapsed >= expiresIn;
  }

  int get remainingSeconds {
    final elapsed = DateTime.now().difference(createdAt).inSeconds;
    return (expiresIn - elapsed).clamp(0, expiresIn);
  }
}

class PairingRequest {
  final String approvalId;
  final String fingerprint;
  final String deviceName;
  final String browser;
  final String os;
  final String ip;
  final String userAgent;
  final DateTime timestamp;

  PairingRequest({
    required this.approvalId,
    required this.fingerprint,
    required this.deviceName,
    required this.browser,
    required this.os,
    required this.ip,
    required this.userAgent,
    required this.timestamp,
  });

  factory PairingRequest.fromJson(Map<String, dynamic> json) {
    return PairingRequest(
      approvalId: json['approval_id'] as String,
      fingerprint: json['fingerprint'] as String,
      deviceName: json['device_name'] as String,
      browser: json['browser'] as String? ?? 'Unknown',
      os: json['os'] as String? ?? 'Unknown',
      ip: json['ip'] as String,
      userAgent: json['user_agent'] as String? ?? 'Unknown',
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
