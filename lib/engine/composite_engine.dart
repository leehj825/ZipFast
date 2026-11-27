import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../core/archive_format.dart';
import '../encoding/name_encoding.dart';
import 'archive_engine.dart';
import 'job_runner.dart';
import 'models.dart';
import 'native_engine.dart';

/// The engine the app uses: routes each archive to the engine that can read it
/// and adds archive splitting on top of creation.
///
/// * [DartArchiveEngine]: ZIP, TAR(+GZ/BZ2/XZ), GZ, BZ2, XZ, with filename
///   encoding repair.
/// * [NativeArchiveEngine] (7-Zip): RAR, RAR5, 7Z, ISO, CAB, every split
///   volume set, plus 7Z creation.
class CompositeEngine implements ArchiveEngine {
  CompositeEngine({ArchiveEngine? dart, ArchiveEngine? native})
      : _dart = dart ?? const DartArchiveEngine(),
        _native = native ?? NativeArchiveEngine();

  final ArchiveEngine _dart;
  final ArchiveEngine _native;

  @override
  Set<ArchiveFormat> get readable => {..._dart.readable, ..._native.readable};

  @override
  Set<CreateFormat> get writable => {..._dart.writable, ..._native.writable};

  /// Split volume sets and formats only 7-Zip reads go to the native engine.
  ArchiveEngine _forPath(String path, ArchiveFormat format) {
    if (ArchiveFormat.isSplitName(p.basename(path))) return _native;
    return _dart.readable.contains(format) ? _dart : _native;
  }

  /// Maps any volume of a set to its first volume (`x.part02.rar` ->
  /// `x.part01.rar`, `x.r00` -> `x.rar`, `x.002` -> `x.001`) when that file
  /// exists; otherwise returns [path] unchanged.
  static String firstVolume(String path) {
    final dir = p.dirname(path);
    final name = p.basename(path);
    String? candidate;
    final part = RegExp(r'^(.*\.part)(\d+)(\.rar)$', caseSensitive: false).firstMatch(name);
    if (part != null) {
      final digits = part.group(2)!;
      candidate = '${part.group(1)}${'1'.padLeft(digits.length, '0')}${part.group(3)}';
    } else if (RegExp(r'\.r\d\d$', caseSensitive: false).hasMatch(name)) {
      candidate = name.replaceFirst(RegExp(r'\.r\d\d$', caseSensitive: false), '.rar');
    } else if (RegExp(r'\.\d{3}$').hasMatch(name)) {
      candidate = name.replaceFirst(RegExp(r'\.\d{3}$'), '.001');
    }
    if (candidate != null && File(p.join(dir, candidate)).existsSync()) {
      return p.join(dir, candidate);
    }
    return path;
  }

  @override
  Future<ArchiveListing> list(
    String path, {
    NameEncoding encoding = NameEncoding.auto,
    String? password,
    String tempDir = '',
  }) async {
    path = firstVolume(path);
    final format = await ArchiveFormat.detect(path);
    return _forPath(path, format).list(path, encoding: encoding, password: password, tempDir: tempDir);
  }

  @override
  JobHandle<ExtractResult> extract(ExtractRequest request) {
    final path = firstVolume(request.archivePath);
    return _forPath(path, request.format).extract(ExtractRequest(
      archivePath: path,
      format: request.format,
      destinationDir: request.destinationDir,
      selectedPaths: request.selectedPaths,
      password: request.password,
      encoding: request.encoding,
      conflictPolicy: request.conflictPolicy,
      tempDir: request.tempDir,
    ));
  }

  @override
  Future<Uint8List> readEntry(
    String path,
    String entryPath, {
    NameEncoding encoding = NameEncoding.auto,
    String? password,
    String tempDir = '',
    int maxBytes = 25 * 1024 * 1024,
  }) async {
    path = firstVolume(path);
    final format = await ArchiveFormat.detect(path);
    return _forPath(path, format).readEntry(
      path,
      entryPath,
      encoding: encoding,
      password: password,
      tempDir: tempDir,
      maxBytes: maxBytes,
    );
  }

  @override
  JobHandle<String> create(CreateRequest request) {
    final inner = request.format == CreateFormat.sevenZip
        ? _native.create(request)
        : _dart.create(request);
    if (request.splitSizeBytes <= 0) return inner;

    // Chain: build the archive, then cut it into volumes.
    JobHandle<String>? splitJob;
    final outer = JobHandle.manual<String>(onCancel: () {
      inner.cancel();
      splitJob?.cancel();
    });
    inner.progress.listen(outer.reportProgress);
    inner.result.then((archivePath) async {
      if (outer.isFinished) return;
      splitJob = _splitJob(archivePath, request.splitSizeBytes);
      try {
        outer.complete(await splitJob!.result);
      } catch (e) {
        outer.fail(e);
      }
    }, onError: outer.fail);
    return outer;
  }
}

/// Top level on purpose: the isolate closure must capture only [path] and
/// [partSize], never the surrounding handles (ports and completers are
/// unsendable).
JobHandle<String> _splitJob(String path, int partSize) =>
    JobHandle.start<String>((_) => splitFile(path, partSize));

/// Cuts [path] into `<path>.001`, `<path>.002`, ... of at most [partSize]
/// bytes, deletes the original and returns the first volume. 7-Zip, and this
/// app, read such sets as one archive.
Future<String> splitFile(String path, int partSize) async {
  if (partSize <= 0) return path;
  final source = await File(path).open();
  final created = <File>[];
  try {
    final length = await source.length();
    var offset = 0;
    var index = 1;
    final buffer = Uint8List(1024 * 1024);
    while (offset < length || index == 1) {
      final part = File('$path.${index.toString().padLeft(3, '0')}');
      created.add(part);
      final sink = await part.open(mode: FileMode.write);
      try {
        var written = 0;
        while (written < partSize && offset < length) {
          final want = (partSize - written) < buffer.length ? partSize - written : buffer.length;
          final read = await source.readInto(buffer, 0, want);
          if (read <= 0) break;
          await sink.writeFrom(buffer, 0, read);
          written += read;
          offset += read;
        }
      } finally {
        await sink.close();
      }
      index++;
      if (offset >= length) break;
    }
    await source.close();
    await File(path).delete();
    return created.first.path;
  } catch (e) {
    for (final f in created) {
      try {
        f.deleteSync();
      } catch (_) {}
    }
    rethrow;
  }
}

/// Used by tests to run [splitFile] without a handle.
Future<String> splitFileInIsolate(String path, int partSize) =>
    Isolate.run(() => splitFile(path, partSize));

/// The engine instance shared by the whole app.
final ArchiveEngine appEngine = CompositeEngine();
