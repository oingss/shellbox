import 'dart:convert';

/// Direction / kind of one port-forwarding rule.
enum ForwardType { local, remote, dynamic }

/// A single port-forwarding rule attached to a [Server].
class PortForwardRule {
  const PortForwardRule({
    this.id,
    required this.type,
    required this.enabled,
    required this.listenHost,
    required this.listenPort,
    required this.destHost,
    required this.destPort,
  });

  /// Client-generated id (UUID-like string); used as the map key when
  /// editing. null only for brand-new rules not yet assigned.
  final String? id;
  final ForwardType type;
  final bool enabled;
  final String listenHost;
  final int listenPort;
  final String destHost;
  final int destPort;

  /// Deterministic id reused across edits. Loses on copyWith.
  String effectiveId(Set<String> used) => id ?? _generateId(used);

  static String _generateId(Set<String> used) {
    var candidate = '${DateTime.now().microsecondsSinceEpoch}';
    while (used.contains(candidate)) {
      candidate = '${candidate}_';
    }
    return candidate;
  }

  /// Human-readable Chinese label, matching the original app.
  String get label {
    switch (type) {
      case ForwardType.local:
        return '本地 $listenHost:$listenPort → $destHost:$destPort';
      case ForwardType.remote:
        return '远程 $listenHost:$listenPort → $destHost:$destPort';
      case ForwardType.dynamic:
        return '动态代理 (SOCKS) $listenHost:$listenPort';
    }
  }

  PortForwardRule copyWith({
    String? id,
    ForwardType? type,
    bool? enabled,
    String? listenHost,
    int? listenPort,
    String? destHost,
    int? destPort,
  }) {
    return PortForwardRule(
      id: id ?? this.id,
      type: type ?? this.type,
      enabled: enabled ?? this.enabled,
      listenHost: listenHost ?? this.listenHost,
      listenPort: listenPort ?? this.listenPort,
      destHost: destHost ?? this.destHost,
      destPort: destPort ?? this.destPort,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'enabled': enabled,
        'listenHost': listenHost,
        'listenPort': listenPort,
        'destHost': destHost,
        'destPort': destPort,
      };

  factory PortForwardRule.fromJson(Map<String, dynamic> json) {
    return PortForwardRule(
      id: json['id'] as String?,
      type: ForwardType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => ForwardType.local,
      ),
      enabled: json['enabled'] as bool? ?? true,
      listenHost: json['listenHost'] as String? ?? '127.0.0.1',
      listenPort: (json['listenPort'] as num?)?.toInt() ?? 0,
      destHost: json['destHost'] as String? ?? '',
      destPort: (json['destPort'] as num?)?.toInt() ?? 0,
    );
  }

  static List<PortForwardRule> fromJsonListSafely(String jsonString) {
    if (jsonString.isEmpty || jsonString == 'null') {
      return const [];
    }
    try {
      final raw = jsonDecode(jsonString);
      if (raw is! List) {
        return const [];
      }
      return raw
          .whereType<Map<String, dynamic>>()
          .map(PortForwardRule.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String toJsonList(List<PortForwardRule> rules) =>
      jsonEncode(rules.map((r) => r.toJson()).toList());
}

const defaultListenHost = '127.0.0.1';
const defaultListenPort = 8080;
const defaultDestHost = 'localhost';
const defaultDestPort = 22;