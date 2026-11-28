import 'package:path/path.dart' as p;

import '../engine/safe_path.dart';
import 'storage_service.dart';

/// Where extracted files go, relative to the archive or a chosen folder.
enum ExtractTarget {
  /// A new folder named after the archive, next to it.
  newFolder,

  /// Directly into the archive's folder.
  sameFolder,

  /// Into a folder the user picked.
  custom,
}

class ResolvedDestination {
  const ResolvedDestination(this.path, {this.usedFallback = false});

  final String path;

  /// True when the wanted folder could not be used and the app's own storage
  /// was chosen instead.
  final bool usedFallback;
}

/// Works out the final extraction folder.
///
/// [exists] is injected for tests. With [ExtractTarget.custom], [customDir] is
/// used as is when writable; [customSubfolder] puts the files in a new folder
/// named after the archive inside it.
ResolvedDestination resolveExtractDestination(
  StorageService storage, {
  required ExtractTarget target,
  required String archivePath,
  String? customDir,
  bool customSubfolder = true,
  bool Function(String path)? exists,
  bool Function(String dir)? isWritable,
}) {
  final baseName = archiveBaseName(p.basename(archivePath));
  final writable = isWritable ?? StorageService.isWritable;
  final taken = exists ?? StorageService.pathExists;
  switch (target) {
    case ExtractTarget.newFolder:
      final r = storage.extractParentFor(archivePath);
      return ResolvedDestination(
        uniquePath(p.join(r.parent, baseName), taken),
        usedFallback: r.usedFallback,
      );
    case ExtractTarget.sameFolder:
      final r = storage.extractParentFor(archivePath);
      return ResolvedDestination(
        r.usedFallback ? p.join(r.parent, baseName) : r.parent,
        usedFallback: r.usedFallback,
      );
    case ExtractTarget.custom:
      if (customDir != null && writable(customDir)) {
        return ResolvedDestination(
          customSubfolder ? uniquePath(p.join(customDir, baseName), taken) : customDir,
        );
      }
      return ResolvedDestination(
        uniquePath(p.join(storage.fallbackExtractRoot, baseName), taken),
        usedFallback: true,
      );
  }
}

/// Full path for a new archive called [fileName] in [dir] (or the app's
/// archive folder), made unique.
String resolveCreatePath(
  StorageService storage, {
  required String fileName,
  String? dir,
  bool Function(String path)? exists,
}) {
  final folder = dir ?? storage.createRoot;
  return uniquePath(p.join(folder, fileName), exists ?? StorageService.pathExists);
}
