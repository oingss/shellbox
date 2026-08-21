/// Platform-agnostic abstraction over "pick a file for [FilePickerService]".
///
/// Kept in core so the SSH key loader never depends on a concrete platform
/// implementation. main() resolves the real backend per OS.
abstract class FilePickerService {
  /// Opens a native file dialog and returns the path of the chosen key file,
  /// or null when the user cancels.
  Future<String?> pickKeyFile();

  /// Reads the textual content of an already-picked key file.
  ///
  /// The key file picker on both platforms copies the file into an app-
  /// readable cache first, so a plain dart:io read through the returned path
  /// works everywhere.
  Future<String> readSelectedFile(String path);
}