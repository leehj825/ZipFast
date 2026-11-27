import 'package:flutter/services.dart';

/// Android "All files access" (`MANAGE_EXTERNAL_STORAGE`).
///
/// Without it, Android 11+ only lets an app write inside its own folders, so
/// extracting to a folder the user picked (Downloads, Documents, ...) fails.
/// Off Android the channel is missing and everything counts as granted.
class StorageAccessService {
  static const _channel = MethodChannel('com.zipfast.zipfast/storage');

  /// Whether the app may write to shared storage.
  static Future<bool> hasAllFilesAccess() async {
    try {
      return await _channel.invokeMethod<bool>('hasAllFilesAccess') ?? true;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the system screen where the user grants the access.
  static Future<void> openAllFilesAccessSettings() async {
    try {
      await _channel.invokeMethod<void>('openAllFilesAccessSettings');
    } on MissingPluginException {
      // Not on Android.
    } on PlatformException {
      // Nothing more to do.
    }
  }
}
