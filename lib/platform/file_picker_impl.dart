import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../core/services/file_picker_service.dart';

/// file_picker integration. On both Android and Windows the delegate returns a
/// path inside an app-readable cache directory, so the subsequent dart:io read
/// in [KeyLoader] works identically on every platform.
class PlatformFilePicker implements FilePickerService {
  @override
  Future<String?> pickKeyFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      dialogTitle: '选择 SSH 私钥文件',
    );
    return result?.files.single.path;
  }

  @override
  Future<String> readSelectedFile(String path) async {
    return File(path).readAsString();
  }
}