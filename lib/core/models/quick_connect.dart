import 'server.dart';
import 'server_common.dart';

/// A one-off connection that is not persisted as a [Server].
class QuickConnect {
  const QuickConnect({
    required this.host,
    required this.port,
    required this.username,
    this.authType = AuthType.password,
    this.password,
    this.privateKeySource,
    this.privateKeyValue,
    this.privateKeyPassphrase,
  });

  final String host;
  final int port;
  final String username;
  final AuthType authType;
  final String? password;
  final PrivateKeySource? privateKeySource;
  final String? privateKeyValue;
  final String? privateKeyPassphrase;

  /// Builds a [Server] whose only real purpose is to initialize a terminal
  /// session (marked non-persisted by having no [Server.id]).
  Server toServer() => Server(
        name: '$username@$host:$port',
        host: host,
        port: port,
        username: username,
        authType: authType,
        password: password,
        privateKeySource: privateKeySource,
        privateKeyValue: privateKeyValue,
        privateKeyPassphrase: privateKeyPassphrase,
        createdAt: DateTime.now(),
        portForwardRules: const [],
      );
}