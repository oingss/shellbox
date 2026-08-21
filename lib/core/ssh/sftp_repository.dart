import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../models/sftp_file_entry.dart';

/// Body of an SFTP operation result.
sealed class SftpOpResult<T> {
  const SftpOpResult();
}

final class SftpOpSuccess<T> extends SftpOpResult<T> {
  const SftpOpSuccess(this.value);
  final T value;
}

final class SftpOpFailure<T> extends SftpOpResult<T> {
  const SftpOpFailure(this.message);
  final String message;
}

/// Directory listing sorted the same way as the original app: directories
/// first, then alphabetically by lowercase name.
class SftpRepository {
  SftpRepository(this._sftp);

  final SftpClient _sftp;

  Future<SftpOpResult<List<SftpFileEntry>>> list(String path) async {
    try {
      final names = await _sftp.listdir(path);
      final entries = <SftpFileEntry>[];
      for (final n in names) {
        if (n.filename == '.' || n.filename == '..') {
          continue;
        }
        entries.add(SftpFileEntry(
          name: n.filename,
          path: _join(path, n.filename),
          isDirectory: n.attr.isDirectory,
          isSymlink: n.attr.isSymbolicLink,
          size: n.attr.size ?? 0,
          mtimeSeconds: n.attr.modifyTime ?? 0,
        ));
      }
      entries.sort((a, b) {
        if (a.isDirectory != b.isDirectory) {
          return a.isDirectory ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return SftpOpSuccess(entries);
    } catch (e) {
      return SftpOpFailure(e.toString());
    }
  }

  Future<SftpOpResult<void>> sendFile(
    SftpFileEntry remoteDir,
    String localPath, {
    void Function(int sentBytes)? onProgress,
  }) async {
    try {
      final base = localPath.split(Platform.pathSeparator).last;
      final remotePath = _join(remoteDir.path, base);
      var remote = await _sftp.open(
        remotePath,
        mode: SftpFileOpenMode.create |
            SftpFileOpenMode.truncate |
            SftpFileOpenMode.write,
      );
      final writer = remote.write(File(localPath).openRead().cast<Uint8List>());
      await writer.done;
      await remote.close();
      return const SftpOpSuccess(null);
    } catch (e) {
      return SftpOpFailure(e.toString());
    }
  }

  Future<SftpOpResult<void>> receiveFile(
    SftpFileEntry remoteFile,
    String localDir, {
    void Function(int receivedBytes)? onProgress,
    void Function()? onDone,
  }) async {
    try {
      final localPath = '$localDir${Platform.pathSeparator}${remoteFile.name}';
      final sink = File(localPath).openWrite();
      await _sftp.download(
        remoteFile.path,
        sink,
        onProgress: onProgress,
        closeDestination: true,
      );
      onDone?.call();
      return const SftpOpSuccess(null);
    } catch (e) {
      return SftpOpFailure(e.toString());
    }
  }

  Future<SftpOpResult<void>> makeDirectory(String path) async {
    try {
      await _sftp.mkdir(path);
      return const SftpOpSuccess(null);
    } catch (e) {
      return SftpOpFailure(e.toString());
    }
  }

  Future<SftpOpResult<void>> deletePath(String path, {required bool dir}) async {
    try {
      if (dir) {
        await _sftp.rmdir(path);
      } else {
        await _sftp.remove(path);
      }
      return const SftpOpSuccess(null);
    } catch (e) {
      return SftpOpFailure(e.toString());
    }
  }

  Future<SftpOpResult<void>> rename(String from, String to) async {
    try {
      await _sftp.rename(from, to);
      return const SftpOpSuccess(null);
    } catch (e) {
      return SftpOpFailure(e.toString());
    }
  }

  Future<void> close() => _sftp.close();

  static String _join(String dir, String name) =>
      dir == '/' ? '/$name' : '$dir/$name';

  static String display(List<int> bytes) => latin1.decode(bytes);
}