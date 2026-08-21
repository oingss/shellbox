import 'background_keep_alive.dart';
import 'file_picker_service.dart';
import 'secret_storage.dart';

/// Everything the platform layer must provide to the rest of the app.
///
/// Implemented in lib/platform/ and injected via a Riverpod override in
/// main(); core code only ever depends on these interfaces.
abstract interface class AppServices {
  SecretStorage get secretStorage;
  BackgroundKeepAlive get keepAlive;
  FilePickerService get filePicker;
}