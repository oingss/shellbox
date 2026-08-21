/// Authentication methods supported per connection.
enum AuthType { password, privateKey }

/// Where the private-key material comes from.
enum PrivateKeySource {
  /// [Server.privateKeyValue] holds a file path selected via the platform file
  /// picker (SAF on Android, native dialog on Windows).
  file,

  /// [Server.privateKeyValue] holds the raw PEM/OpenSSH key text the user
  /// pasted directly into the form.
  text,
}