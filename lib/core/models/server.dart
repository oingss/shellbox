import 'port_forward_rule.dart';
import 'server_common.dart';

/// A saved SSH server connection.
class Server {
  const Server({
    this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.authType,
    this.password,
    this.privateKeySource,
    this.privateKeyValue,
    this.privateKeyPassphrase,
    required this.createdAt,
    this.lastUsedAt,
    this.portForwardRules = const [],
  });

  /// Database auto-increment id; null until persisted.
  final int? id;
  final String name;
  final String host;
  final int port;
  final String username;
  final AuthType authType;
  final String? password;
  final PrivateKeySource? privateKeySource;
  final String? privateKeyValue;
  final String? privateKeyPassphrase;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final List<PortForwardRule> portForwardRules;

  factory Server.fromDb({
    required int? id,
    required String name,
    required String host,
    required int port,
    required String username,
    required AuthType authType,
    required String? password,
    required PrivateKeySource? privateKeySource,
    required String? privateKeyValue,
    required String? privateKeyPassphrase,
    required DateTime createdAt,
    required DateTime? lastUsedAt,
    required String portForwardRulesJson,
  }) {
    return Server(
      id: id,
      name: name,
      host: host,
      port: port,
      username: username,
      authType: authType,
      password: password,
      privateKeySource: privateKeySource,
      privateKeyValue: privateKeyValue,
      privateKeyPassphrase: privateKeyPassphrase,
      createdAt: createdAt,
      lastUsedAt: lastUsedAt,
      portForwardRules:
          PortForwardRule.fromJsonListSafely(portForwardRulesJson),
    );
  }

  Server copyWith({
    int? id,
    String? name,
    String? host,
    int? port,
    String? username,
    AuthType? authType,
    String? password,
    PrivateKeySource? privateKeySource,
    String? privateKeyValue,
    String? privateKeyPassphrase,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    List<PortForwardRule>? portForwardRules,
  }) {
    return Server(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      authType: authType ?? this.authType,
      password: password ?? this.password,
      privateKeySource: privateKeySource ?? this.privateKeySource,
      privateKeyValue: privateKeyValue ?? this.privateKeyValue,
      privateKeyPassphrase: privateKeyPassphrase ?? this.privateKeyPassphrase,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      portForwardRules: portForwardRules ?? this.portForwardRules,
    );
  }
}