import 'package:flutter_test/flutter_test.dart';

import 'package:shellbox_flutter/core/models/port_forward_rule.dart';
import 'package:shellbox_flutter/core/models/server.dart';
import 'package:shellbox_flutter/core/models/server_common.dart';

void main() {
  test('Server.copyWith preserves untouched fields', () {
    final base = Server(
      id: 1,
      name: 'node',
      host: '192.168.0.5',
      port: 22,
      username: 'root',
      authType: AuthType.password,
      password: 'secret',
      createdAt: DateTime(2026, 1, 1),
    );
    final renamed = base.copyWith(name: 'edge');
    expect(renamed.id, 1);
    expect(renamed.name, 'edge');
    expect(renamed.host, '192.168.0.5');
    expect(renamed.port, 22);
    expect(renamed.password, 'secret');
    expect(renamed.createdAt, DateTime(2026, 1, 1));
  });

  test('PortForwardRule.fromJsonListSafely is tolerant of bad input', () {
    expect(PortForwardRule.fromJsonListSafely(''), isEmpty);
    expect(PortForwardRule.fromJsonListSafely('not json'), isEmpty);
    expect(PortForwardRule.fromJsonListSafely('null'), isEmpty);

    final decoded =
        PortForwardRule.fromJsonListSafely('[{"type":"local","enabled":true}]');
    expect(decoded, hasLength(1));
    expect(decoded.single.type, ForwardType.local);
    expect(decoded.single.enabled, isTrue);
    expect(decoded.single.listenPort, 0);
  });
}