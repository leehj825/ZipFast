import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

/// Hands files to other apps: "open with" and the system share sheet.
///
/// Files live in ZipFast's own folder, which other apps cannot read directly,
/// so both go through Android's FileProvider (handled by the plugins).
class ExternalFileService {
  /// Replaces the real "open" (the plugins only use platform channels on
  /// Android/iOS, so tests cannot reach them on a desktop host).
  @visibleForTesting
  static Future<bool> Function(String path)? openOverride;

  /// Replaces the real share sheet in tests.
  @visibleForTesting
  static Future<void> Function(List<String> files)? shareOverride;

  /// Opens [path] with an app that handles its type. Returns `false` if there
  /// is none or the file is missing.
  static Future<bool> open(String path) async {
    if (!File(path).existsSync()) return false;
    if (openOverride != null) return openOverride!(path);
    try {
      final result = await OpenFilex.open(path);
      return result.type == ResultType.done;
    } catch (_) {
      return false;
    }
  }

  /// Shares [paths] (files only; folders cannot be shared) through the share
  /// sheet. Returns `false` if there was nothing to share.
  static Future<bool> share(List<String> paths) async {
    final files = paths.where((p) => FileSystemEntity.isFileSync(p)).toList();
    if (files.isEmpty) return false;
    if (shareOverride != null) {
      await shareOverride!(files);
      return true;
    }
    await SharePlus.instance.share(ShareParams(files: [for (final f in files) XFile(f)]));
    return true;
  }
}
