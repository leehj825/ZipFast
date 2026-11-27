import 'dart:io';

import 'package:path/path.dart' as p;

import '../engine/safe_path.dart';

/// A file operation that cannot be done; [message] is for logs, the UI shows
/// its own localized text.
class FileOpException implements Exception {
  const FileOpException(this.reason, [this.detail = '']);

  final FileOpFailure reason;
  final String detail;

  @override
  String toString() => 'FileOpException($reason, $detail)';
}

enum FileOpFailure {
  /// Empty name, path separators, `.`/`..`, too long.
  invalidName,

  /// Something with that name is already there.
  nameTaken,

  /// The target is outside the folder the browser is allowed to touch.
  outsideRoot,

  /// Moving a folder into itself.
  intoItself,

  /// The file or folder is gone.
  missing,
}

/// Checks a file or folder name typed by the user. Returns `null` if it is OK.
FileOpFailure? validateFileName(String name) {
  final n = name.trim();
  if (n.isEmpty || n == '.' || n == '..') return FileOpFailure.invalidName;
  if (n.contains('/') || n.contains('\\') || n.contains('\u0000')) {
    return FileOpFailure.invalidName;
  }
  if (n.length > 255) return FileOpFailure.invalidName;
  return null;
}

/// Whether [path] is [root] or inside it.
bool isInside(String root, String path) =>
    p.equals(root, path) || p.isWithin(root, path);

void _requireInside(String root, String path) {
  if (!isInside(root, path)) throw FileOpException(FileOpFailure.outsideRoot, path);
}

bool _exists(String path) => FileSystemEntity.typeSync(path, followLinks: false) != FileSystemEntityType.notFound;

/// Creates a folder called [name] in [parent]. Returns its path.
Future<String> createFolder(String root, String parent, String name) async {
  _requireInside(root, parent);
  if (validateFileName(name) != null) throw FileOpException(FileOpFailure.invalidName, name);
  final path = p.join(parent, name.trim());
  if (_exists(path)) throw FileOpException(FileOpFailure.nameTaken, path);
  await Directory(path).create();
  return path;
}

/// Renames [path] to [newName] (same folder). Returns the new path.
Future<String> renamePath(String root, String path, String newName) async {
  _requireInside(root, path);
  if (!_exists(path)) throw FileOpException(FileOpFailure.missing, path);
  if (validateFileName(newName) != null) throw FileOpException(FileOpFailure.invalidName, newName);
  final target = p.join(p.dirname(path), newName.trim());
  if (p.equals(target, path)) return path;
  if (_exists(target)) throw FileOpException(FileOpFailure.nameTaken, target);
  final type = FileSystemEntity.typeSync(path, followLinks: false);
  return (type == FileSystemEntityType.directory
          ? await Directory(path).rename(target)
          : await File(path).rename(target))
      .path;
}

/// Deletes files and folders (folders recursively). Missing items are ignored.
Future<void> deletePaths(String root, List<String> paths) async {
  for (final path in paths) {
    _requireInside(root, path);
    // Never delete the root itself.
    if (p.equals(root, path)) throw FileOpException(FileOpFailure.outsideRoot, path);
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    switch (type) {
      case FileSystemEntityType.directory:
        await Directory(path).delete(recursive: true);
      case FileSystemEntityType.notFound:
        break;
      default:
        await File(path).delete();
    }
  }
}

/// Moves [paths] into [destDir]. Name clashes get ` (1)`, ` (2)`, ... Returns
/// the new paths. Items already in [destDir] are left alone.
Future<List<String>> movePaths(String root, List<String> paths, String destDir) async {
  _requireInside(root, destDir);
  if (!Directory(destDir).existsSync()) throw FileOpException(FileOpFailure.missing, destDir);
  final result = <String>[];
  for (final path in paths) {
    _requireInside(root, path);
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) throw FileOpException(FileOpFailure.missing, path);
    if (p.equals(p.dirname(path), destDir)) {
      result.add(path);
      continue;
    }
    final isDir = type == FileSystemEntityType.directory;
    if (isDir && isInside(path, destDir)) throw FileOpException(FileOpFailure.intoItself, path);
    final target = uniquePath(p.join(destDir, p.basename(path)), _exists);
    try {
      isDir ? await Directory(path).rename(target) : await File(path).rename(target);
    } on FileSystemException {
      // Different file system: copy, then delete the original.
      await _copy(path, target);
      await deletePaths(root, [path]);
    }
    result.add(target);
  }
  return result;
}

Future<void> _copy(String from, String to) async {
  final type = FileSystemEntity.typeSync(from, followLinks: false);
  if (type == FileSystemEntityType.directory) {
    await Directory(to).create(recursive: true);
    await for (final e in Directory(from).list(followLinks: false)) {
      await _copy(e.path, p.join(to, p.basename(e.path)));
    }
  } else {
    await File(from).copy(to);
  }
}

/// The files that make up [path]: all volumes (`.001`, `.002`, ...) when it is
/// the first of a split archive, otherwise just [path].
List<String> volumeSet(String path) {
  if (!path.endsWith('.001')) return [path];
  final base = path.substring(0, path.length - 4);
  final volumes = <String>[];
  for (var i = 1;; i++) {
    final next = '$base.${i.toString().padLeft(3, '0')}';
    if (!File(next).existsSync()) break;
    volumes.add(next);
  }
  return volumes.isEmpty ? [path] : volumes;
}
