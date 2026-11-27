import 'package:flutter/services.dart';

/// Receives archives that other apps hand to ZipFast ("Open with ZipFast").
///
/// The Android side (`MainActivity`) copies the shared `content://` stream
/// into the app cache and passes the resulting local path here.
class IncomingFileService {
  static const _channel = MethodChannel('com.zipfast.zipfast/incoming');

  /// Calls [onFile] for the file that launched the app (if any) and for every
  /// file delivered while the app is running.
  static void listen(void Function(String path) onFile) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNewFile' && call.arguments is String) {
        onFile(call.arguments as String);
      }
    });
    _channel.invokeMethod<String>('getInitialFile').then((path) {
      if (path != null && path.isNotEmpty) onFile(path);
    }, onError: (_) {
      // Not on Android (tests, desktop): nothing to do.
    });
  }
}
