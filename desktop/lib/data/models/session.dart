/// Session model representing a tmux Claude session.
class Session {
  final String id;
  final String name;
  final String? workingDir;
  final DateTime createdAt;
  final bool isActive;

  const Session({
    required this.id,
    required this.name,
    this.workingDir,
    required this.createdAt,
    this.isActive = true,
  });

  factory Session.fromTmux(String line) {
    // Parse tmux list-sessions format: name:created:path
    final parts = line.split(':');
    final name = parts[0];

    DateTime created;
    try {
      created = parts.length > 1
          ? DateTime.fromMillisecondsSinceEpoch(int.parse(parts[1]) * 1000)
          : DateTime.now();
    } catch (e) {
      created = DateTime.now();
    }

    final path = parts.length > 2 ? parts[2] : null;

    return Session(
      id: name,
      name: name,
      workingDir: path,
      createdAt: created,
      isActive: true,
    );
  }

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      name: json['name'] as String,
      workingDir: json['working_dir'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'working_dir': workingDir,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive,
    };
  }

  Session copyWith({
    String? id,
    String? name,
    String? workingDir,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return Session(
      id: id ?? this.id,
      name: name ?? this.name,
      workingDir: workingDir ?? this.workingDir,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Session && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Session(id: $id, name: $name, workingDir: $workingDir)';
}
