import 'package:flutter/services.dart';

import '../engine/job_runner.dart';
import '../engine/models.dart';

/// The folder was picked earlier but Android no longer lets the app write there.
class ExportAccessException extends ZipFastException {
  const ExportAccessException() : super('Access to the folder was removed');
}

/// "Save a copy to…": copies files out of ZipFast's storage into a folder the
/// user chooses with Android's system folder picker (Storage Access Framework).
///
/// No storage permission is needed. Choosing the folder is the grant, and it is
/// remembered, so [hasAccess] tells whether a stored folder still works. The
/// folder is a `content://` tree URI, not a file path, so the copy is done by the
/// Android side (`ExportPlugin.kt`).
class ExportService {
  static const MethodChannel _channel = MethodChannel('com.zipfast.zipfast/export');

  static int _nextId = 1;
  static final Map<int, JobHandle<int>> _jobs = {};

  /// Registers the progress callback. Cheap and idempotent.
  static void _installHandler() {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'progress') return;
      final args = Map<Object?, Object?>.from(call.arguments as Map);
      _jobs[args['id']]?.reportProgress(JobProgress(
        (args['done'] as num).toInt(),
        (args['total'] as num).toInt(),
        args['current'] as String?,
      ));
    });
  }

  /// Opens the system folder picker. Returns the folder's tree URI, or `null`
  /// if cancelled. Throws [UnsupportedError] where there is no picker.
  static Future<String?> pickFolder() async {
    _installHandler();
    try {
      return await _channel.invokeMethod<String>('pickFolder');
    } on MissingPluginException {
      throw UnsupportedError('Folder picker unavailable');
    } on PlatformException catch (e) {
      throw UnsupportedError(e.message ?? e.code);
    }
  }

  /// Whether [treeUri] is still a folder the app may write to.
  static Future<bool> hasAccess(String treeUri) async {
    try {
      return await _channel.invokeMethod<bool>('hasAccess', {'uri': treeUri}) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Copies [paths] (files and folders, recursively) into [treeUri]. Resolves
  /// to the number of files copied.
  static JobHandle<int> copy(String treeUri, List<String> paths) {
    _installHandler();
    final id = _nextId++;
    final handle = JobHandle.manual<int>(onCancel: () {
      _channel.invokeMethod<void>('cancel', {'id': id}).catchError((Object _) {});
    });
    _jobs[id] = handle;
    () async {
      try {
        final copied = await _channel.invokeMethod<int>('copy', {
          'id': id,
          'uri': treeUri,
          'paths': paths,
        });
        handle.complete(copied ?? 0);
      } on MissingPluginException {
        handle.fail(const ExportAccessException());
      } on PlatformException catch (e) {
        switch (e.code) {
          case 'CANCELLED':
            handle.fail(const JobCancelledException());
          case 'PERMISSION':
            handle.fail(const ExportAccessException());
          default:
            handle.fail(CorruptArchiveException(e.message ?? e.code));
        }
      } catch (e) {
        handle.fail(e);
      } finally {
        _jobs.remove(id);
      }
    }();
    return handle;
  }

  /// A readable name for a tree URI, e.g. `Download/Unpacked`.
  static String describe(String treeUri) {
    final marker = treeUri.indexOf('/tree/');
    if (marker < 0) return treeUri;
    var id = Uri.decodeComponent(treeUri.substring(marker + 6));
    final slash = id.indexOf('/document/');
    if (slash >= 0) id = id.substring(0, slash);
    final colon = id.indexOf(':');
    if (colon < 0) return id;
    final volume = id.substring(0, colon);
    final path = id.substring(colon + 1);
    final prefix = volume == 'primary' ? '' : '$volume:';
    return path.isEmpty ? (volume == 'primary' ? '/' : '$volume:/') : '$prefix$path';
  }
}
