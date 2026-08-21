/// A host-key record recorded with Trust-On-First-Use.
class KnownHost {
  const KnownHost({
    required this.hostPort,
    required this.keyType,
    required this.fingerprint,
    required this.firstSeenAt,
  });

  /// Primary key, formatted as `host:port`.
  final String hostPort;
  final String keyType;
  final String fingerprint;
  final DateTime firstSeenAt;

  Map<String, Object?> toDb() => {
        'hostPort': hostPort,
        'keyType': keyType,
        'fingerprint': fingerprint,
        'firstSeenAt': firstSeenAt.millisecondsSinceEpoch,
      };

  factory KnownHost.fromDb(Map<String, Object?> map) => KnownHost(
        hostPort: map['hostPort'] as String,
        keyType: map['keyType'] as String,
        fingerprint: map['fingerprint'] as String,
        firstSeenAt: DateTime.fromMillisecondsSinceEpoch(
          (map['firstSeenAt'] as int?) ?? 0,
        ),
      );
}