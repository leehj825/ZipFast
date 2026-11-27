import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/archive_format.dart';

/// A file shown in the recent list or the folder browser.
class FileItem {
  const FileItem({
    required this.path,
    required this.size,
    required this.modified,
    this.isDirectory = false,
  });

  final String path;
  final int size;
  final DateTime modified;
  final bool isDirectory;

  String get name => p.basename(path);
  ArchiveFormat get format => ArchiveFormat.fromName(name);
}

/// Where ZipFast reads and writes on the device.
///
/// Android restricts access to shared storage, so everything here fails soft:
/// unreadable folders yield empty results and unwritable folders fall back to
/// the app's own storage.
class StorageService {
  StorageService._(this.tempDir, this.appFilesDir, this.cacheDir);

  /// Scratch space for tar wrappers and previews. Wiped on start.
  final String tempDir;

  /// App-owned writable storage (always available).
  final String appFilesDir;

  /// The app's cache root. Files picked through the system picker are copied
  /// here, so results must never be written below it.
  final String cacheDir;

  /// A service rooted in the system temp directory, for tests.
  factory StorageService.forTesting() {
    final dir = Directory.systemTemp.createTempSync('zipfast_ui_test_').path;
    return StorageService._(dir, dir, dir);
  }

  /// Finds the app's folders. Every lookup has a fallback, so a failing
  /// `path_provider` (it talks to Android through JNI) can never keep the app
  /// from starting: the cache folder is then the process temp directory (the
  /// Flutter engine points it at the app cache) and the files folder its sibling.
  static Future<StorageService> create() async {
    String cachePath;
    try {
      cachePath = (await getTemporaryDirectory()).path;
    } catch (_) {
      cachePath = Directory.systemTemp.path;
    }
    final cache = Directory(cachePath);
    final temp = Directory(p.join(cache.path, 'zipfast'));
    try {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    } catch (_) {}
    temp.createSync(recursive: true);
    String filesPath;
    try {
      filesPath = (await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory()).path;
    } catch (_) {
      try {
        filesPath = (await getApplicationDocumentsDirectory()).path;
      } catch (_) {
        filesPath = p.join(cache.parent.path, 'files');
      }
    }
    final files = Directory(filesPath)..createSync(recursive: true);
    final service = StorageService._(temp.path, files.path, cache.path);
    for (final dir in [service.fallbackExtractRoot, service.createRoot]) {
      try {
        Directory(dir).createSync(recursive: true);
      } catch (_) {}
    }
    return service;
  }

  /// Deletes preview/scratch files.
  void clearTemp() {
    try {
      final dir = Directory(tempDir);
      for (final e in dir.listSync()) {
        e.deleteSync(recursive: true);
      }
    } catch (_) {}
  }

  /// Folders worth scanning for archives on the home screen.
  List<String> get scanRoots => const [
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Documents',
        '/storage/emulated/0/Android/media',
      ];

  /// Default parent folder for extraction when the archive's folder is not
  /// writable.
  String get fallbackExtractRoot => p.join(appFilesDir, 'Extracted');

  /// Default parent folder for newly created archives.
  String get createRoot => p.join(appFilesDir, 'Archives');

  /// Folder in which "new folder" / "same folder" extraction should happen for
  /// [archivePath]: its own folder when that is writable and durable, otherwise
  /// the app's extraction root. [usedFallback] tells the UI to explain why.
  ({String parent, bool usedFallback}) extractParentFor(String archivePath) {
    final dir = p.dirname(archivePath);
    final inCache = p.isWithin(cacheDir, archivePath);
    if (!inCache && isWritable(dir)) return (parent: dir, usedFallback: false);
    Directory(fallbackExtractRoot).createSync(recursive: true);
    return (parent: fallbackExtractRoot, usedFallback: true);
  }

  /// Whether anything (file, folder, link) exists at [path].
  static bool pathExists(String path) =>
      FileSystemEntity.typeSync(path, followLinks: false) != FileSystemEntityType.notFound;

  /// Returns `true` if files can be created in [dir].
  static bool isWritable(String dir) {
    try {
      Directory(dir).createSync(recursive: true);
      final probe = File(p.join(dir, '.zipfast_probe_${DateTime.now().microsecondsSinceEpoch}'));
      probe.writeAsStringSync('');
      probe.deleteSync();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Lists archive files in the shared scan roots, newest first.
  static List<FileItem> scanArchives(List<String> roots, {int limit = 100}) {
    final found = <FileItem>[];
    for (final root in roots) {
      try {
        final dir = Directory(root);
        if (!dir.existsSync()) continue;
        for (final e in dir.listSync(recursive: true, followLinks: false)) {
          if (e is! File || !ArchiveFormat.looksLikeArchive(p.basename(e.path))) continue;
          try {
            final stat = e.statSync();
            found.add(FileItem(path: e.path, size: stat.size, modified: stat.modified));
          } catch (_) {}
        }
      } catch (_) {
        // Folder not readable (scoped storage) — ignore.
      }
    }
    found.sort((a, b) => b.modified.compareTo(a.modified));
    return found.length > limit ? found.sublist(0, limit) : found;
  }

  /// Runs [scanArchives] in a background isolate. Static on purpose: the
  /// closure must not capture a widget `State`, which cannot be sent.
  static Future<List<FileItem>> scanArchivesInBackground(List<String> roots) =>
      Isolate.run(() => scanArchives(roots));

  /// Turns a path into a [FileItem], or `null` if it no longer exists.
  static FileItem? statPath(String path) {
    try {
      final stat = File(path).statSync();
      if (stat.type != FileSystemEntityType.file) return null;
      return FileItem(path: path, size: stat.size, modified: stat.modified);
    } catch (_) {
      return null;
    }
  }

  /// Lists a directory (folders first, then files by name). Throws if the
  /// directory cannot be read.
  static List<FileItem> listDirectory(String dir) {
    final items = <FileItem>[];
    for (final e in Directory(dir).listSync(followLinks: false)) {
      if (p.basename(e.path).startsWith('.')) continue;
      try {
        final stat = e.statSync();
        items.add(FileItem(
          path: e.path,
          size: stat.size,
          modified: stat.modified,
          isDirectory: stat.type == FileSystemEntityType.directory,
        ));
      } catch (_) {}
    }
    items.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return items;
  }
}
