import 'package:dartssh2/dartssh2.dart';

import '../models/server.dart';
import '../models/server_common.dart';
import '../services/file_picker_service.dart';

/// Resolves the PEM text for public-key authentication and parses it into
/// dartssh2 key pairs.
///
/// Mirrors the original Android app:
///  - [PrivateKeySource.file]: value is a picker path readable via dart:io on
///    Android and Windows (file_picker copies to an app-readable cache file).
///  - [PrivateKeySource.text]: value is the raw PEM pasted by the user.
class KeyLoader {
  KeyLoader(this._filePicker);

  final FilePickerService _filePicker;

  Future<List<SSHKeyPair>> loadFor(Server server) async {
    if (server.authType != AuthType.privateKey) {
      return const [];
    }

    final source = server.privateKeySource ?? PrivateKeySource.text;
    final value = server.privateKeyValue;
    if (value == null || value.trim().isEmpty) {
      return const [];
    }

    late final String pem;
    switch (source) {
      case PrivateKeySource.file:
        pem = await _filePicker.readSelectedFile(value);
      case PrivateKeySource.text:
        pem = value;
    }

    if (pem.trim().isEmpty) {
      return const [];
    }

    // May return several keys (one passphrase-protected file can embed many).
    return SSHKeyPair.fromPem(pem, server.privateKeyPassphrase);
  }

  static bool isEncryptedPem(String pem) => SSHKeyPair.isEncryptedPem(pem);
}