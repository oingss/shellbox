/// A single entry returned from an SFTP directory listing.
class SftpFileEntry {
  const SftpFileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.isSymlink,
    required this.size,
    required this.mtimeSeconds,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final bool isSymlink;
  final int size;
  final int mtimeSeconds;

  /// Human-readable size; directories and symlinks get `--`.
  String get displaySize {
    if (isDirectory) {
      return '--';
    }
    if (size < 1024) {
      return '$size B';
    }
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String formatMtime(int seconds) {
    final t = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }
}