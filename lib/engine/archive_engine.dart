import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart' hide ArchiveFormat;
import 'package:path/path.dart' as p;

import '../core/archive_format.dart';
import '../encoding/name_encoding.dart';
import 'job_runner.dart';
import 'models.dart';
import 'safe_path.dart';

/// Reads and writes archives.
///
/// The app talks only to this interface. [DartArchiveEngine] covers the formats
/// pure Dart can handle; a native engine (libarchive + UnRAR through `dart:ffi`)
/// can be added behind the same interface to cover RAR, 7Z, ISO and CAB.
abstract interface class ArchiveEngine {
  /// Formats this engine can open.
  Set<ArchiveFormat> get readable;

  /// Formats this engine can create.
  Set<CreateFormat> get writable;

  /// Lists the entries of an archive.
  Future<ArchiveListing> list(
    String path, {
    NameEncoding encoding = NameEncoding.auto,
    String? password,
    String tempDir = '',
  });

  /// Extracts entries in a background isolate.
  JobHandle<ExtractResult> extract(ExtractRequest request);

  /// Reads one entry into memory for previews. Fails for entries larger than
  /// [maxBytes].
  Future<Uint8List> readEntry(
    String path,
    String entryPath, {
    NameEncoding encoding = NameEncoding.auto,
    String? password,
    String tempDir = '',
    int maxBytes = 25 * 1024 * 1024,
  });

  /// Creates an archive in a background isolate; resolves to the output path.
  JobHandle<String> create(CreateRequest request);
}

/// Pure-Dart engine: ZIP/APK/JAR (incl. AES-256 and CP949/Shift-JIS/GBK name
/// repair), TAR, TAR.GZ/BZ2/XZ and single-file GZ/BZ2/XZ.
class DartArchiveEngine implements ArchiveEngine {
  const DartArchiveEngine();

  @override
  Set<ArchiveFormat> get readable => const {
        ArchiveFormat.zip,
        ArchiveFormat.tar,
        ArchiveFormat.tarGz,
        ArchiveFormat.tarBz2,
        ArchiveFormat.tarXz,
        ArchiveFormat.gz,
        ArchiveFormat.bz2,
        ArchiveFormat.xz,
      };

  @override
  Set<CreateFormat> get writable => const {CreateFormat.zip, CreateFormat.tarGz};

  @override
  Future<ArchiveListing> list(
    String path, {
    NameEncoding encoding = NameEncoding.auto,
    String? password,
    String tempDir = '',
  }) async {
    final format = await ArchiveFormat.detect(path);
    _requireReadable(format);
    return JobHandle.start<ArchiveListing>((_) async {
      final source = await _Source.open(path, format, encoding, password, tempDir);
      try {
        final entries = <EntryInfo>[];
        for (final f in source.archive.files) {
          final name = normalizeEntryName(f.name);
          if (name.isEmpty) continue;
          entries.add(EntryInfo(
            path: name,
            isDirectory: f.isDirectory,
            size: f.isDirectory ? 0 : f.size,
            modified: f.lastModTime > 0
                ? DateTime.fromMillisecondsSinceEpoch(f.lastModTime * 1000)
                : null,
            encrypted: source.encrypted[name] ?? false,
          ));
        }
        return ArchiveListing(
          format: format,
          entries: entries,
          namesLookGarbled: encoding == NameEncoding.auto &&
              NameEncoding.looksGarbled(entries.map((e) => e.path)),
        );
      } finally {
        source.close();
      }
    }).result;
  }

  @override
  JobHandle<ExtractResult> extract(ExtractRequest request) {
    _requireReadable(request.format);
    return JobHandle.start<ExtractResult>((report) => _extract(request, report));
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
    final format = await ArchiveFormat.detect(path);
    _requireReadable(format);
    return JobHandle.start<Uint8List>((_) async {
      final source = await _Source.open(path, format, encoding, password, tempDir);
      try {
        for (final f in source.archive.files) {
          if (normalizeEntryName(f.name) != entryPath || f.isDirectory) continue;
          if (f.size > maxBytes) {
            throw const CorruptArchiveException('Entry too large to preview');
          }
          try {
            return Uint8List.fromList(f.readBytes() ?? Uint8List(0));
          } on ArchivePasswordException {
            throw password == null
                ? const PasswordRequiredException()
                : const WrongPasswordException();
          }
        }
        throw const CorruptArchiveException('Entry not found');
      } finally {
        source.close();
      }
    }).result;
  }

  @override
  JobHandle<String> create(CreateRequest request) =>
      JobHandle.start<String>((report) => _create(request, report));

  void _requireReadable(ArchiveFormat format) {
    if (!readable.contains(format)) throw UnsupportedFormatException(format);
  }
}

// ---------------------------------------------------------------------------
// Reading
// ---------------------------------------------------------------------------

class _Source {
  _Source(this.archive, this.encrypted, this._inputs, this._temps);

  final Archive archive;

  /// Entry path -> encrypted flag.
  final Map<String, bool> encrypted;
  final List<InputFileStream> _inputs;
  final List<String> _temps;

  static Future<_Source> open(
    String path,
    ArchiveFormat format,
    NameEncoding encoding,
    String? password,
    String tempDir,
  ) async {
    final inputs = <InputFileStream>[];
    final temps = <String>[];
    try {
      switch (format) {
        case ArchiveFormat.zip:
          final input = InputFileStream(path);
          inputs.add(input);
          final decoder = ZipDecoder(filenameEncoding: encoding.codec);
          final archive = decoder.decodeStream(input, password: password);
          final encrypted = <String, bool>{
            for (final h in decoder.directory.fileHeaders)
              if (h.file != null)
                normalizeEntryName(h.file!.filename): h.file!.flags & 1 != 0,
          };
          return _Source(archive, encrypted, inputs, temps);
        case ArchiveFormat.tar:
          final input = InputFileStream(path);
          inputs.add(input);
          return _Source(TarDecoder().decodeStream(input), {}, inputs, temps);
        case ArchiveFormat.tarGz:
        case ArchiveFormat.tarBz2:
        case ArchiveFormat.tarXz:
          final tmp = await _decompressToTemp(path, format, tempDir);
          temps.add(tmp);
          final input = InputFileStream(tmp);
          inputs.add(input);
          return _Source(TarDecoder().decodeStream(input), {}, inputs, temps);
        case ArchiveFormat.gz:
        case ArchiveFormat.bz2:
        case ArchiveFormat.xz:
          final tmp = await _decompressToTemp(path, format, tempDir);
          temps.add(tmp);
          final input = InputFileStream(tmp);
          inputs.add(input);
          final archive = Archive()
            ..add(ArchiveFile.stream(
              p.basenameWithoutExtension(path),
              input,
            ));
          return _Source(archive, {}, inputs, temps);
        default:
          throw UnsupportedFormatException(format);
      }
    } on ArchivePasswordException {
      _closeAll(inputs, temps);
      throw password == null
          ? const PasswordRequiredException()
          : const WrongPasswordException();
    } on ZipFastException {
      _closeAll(inputs, temps);
      rethrow;
    } catch (e) {
      _closeAll(inputs, temps);
      throw CorruptArchiveException(e.toString());
    }
  }

  void close() => _closeAll(_inputs, _temps);

  static void _closeAll(List<InputFileStream> inputs, List<String> temps) {
    for (final i in inputs) {
      try {
        i.closeSync();
      } catch (_) {}
    }
    for (final t in temps) {
      try {
        File(t).deleteSync();
      } catch (_) {}
    }
  }
}

int _tempCounter = 0;

/// Decompresses the gz/bz2/xz layer into a scratch file so the inner tar (or
/// single file) can be streamed from disk instead of held in memory.
Future<String> _decompressToTemp(
  String path,
  ArchiveFormat format,
  String tempDir,
) async {
  final dir = tempDir.isEmpty ? Directory.systemTemp.path : tempDir;
  final out =
      p.join(dir, 'zipfast_${pid}_${DateTime.now().microsecondsSinceEpoch}_${_tempCounter++}.tmp');
  switch (format) {
    case ArchiveFormat.tarGz:
    case ArchiveFormat.gz:
      await File(path).openRead().transform(gzip.decoder).pipe(File(out).openWrite());
    case ArchiveFormat.tarBz2:
    case ArchiveFormat.bz2:
      final output = OutputFileStream(out);
      try {
        BZip2Decoder().decodeStream(InputFileStream(path), output);
      } finally {
        output.closeSync();
      }
    case ArchiveFormat.tarXz:
    case ArchiveFormat.xz:
      final output = OutputFileStream(out);
      try {
        XZDecoder().decodeStream(InputFileStream(path), output);
      } finally {
        output.closeSync();
      }
    default:
      throw UnsupportedFormatException(format);
  }
  return out;
}

// ---------------------------------------------------------------------------
// Extraction
// ---------------------------------------------------------------------------

Future<ExtractResult> _extract(
  ExtractRequest r,
  void Function(JobProgress) report,
) async {
  final source = await _Source.open(
    r.archivePath,
    r.format,
    r.encoding,
    r.password,
    r.tempDir,
  );
  var extracted = 0, skipped = 0, blocked = 0;
  try {
    final files = source.archive.files
        .where((f) => isPathSelected(normalizeEntryName(f.name), r.selectedPaths))
        .toList();
    final total = files.length;
    final root = p.normalize(r.destinationDir);
    Directory(root).createSync(recursive: true);
    var done = 0;
    report(JobProgress(0, total));

    for (final f in files) {
      final name = normalizeEntryName(f.name);
      done++;
      if (name.isEmpty) continue;
      // Zip Slip guard: never write outside the destination folder.
      final target = resolveSafePath(root, name);
      if (target == null) {
        blocked++;
        continue;
      }
      if (f.isSymbolicLink) {
        skipped++; // Symlinks are never materialized.
        continue;
      }
      if (f.isDirectory) {
        Directory(target).createSync(recursive: true);
        continue;
      }
      var outPath = target;
      if (FileSystemEntity.typeSync(outPath, followLinks: false) !=
          FileSystemEntityType.notFound) {
        switch (r.conflictPolicy) {
          case ConflictPolicy.skip:
            skipped++;
            report(JobProgress(done, total, name));
            continue;
          case ConflictPolicy.overwrite:
            break;
          case ConflictPolicy.rename:
            outPath = uniquePath(
              outPath,
              (s) => FileSystemEntity.typeSync(s, followLinks: false) !=
                  FileSystemEntityType.notFound,
            );
        }
      }
      Directory(p.dirname(outPath)).createSync(recursive: true);
      final out = OutputFileStream(outPath);
      try {
        f.writeContent(out);
        out.closeSync();
        extracted++;
        if (f.lastModTime > 0) {
          try {
            File(outPath).setLastModifiedSync(
              DateTime.fromMillisecondsSinceEpoch(f.lastModTime * 1000),
            );
          } catch (_) {}
        }
      } on ArchivePasswordException {
        try {
          out.closeSync();
          File(outPath).deleteSync();
        } catch (_) {}
        throw r.password == null
            ? const PasswordRequiredException()
            : const WrongPasswordException();
      } catch (e) {
        try {
          out.closeSync();
          File(outPath).deleteSync();
        } catch (_) {}
        if (e is ZipFastException) rethrow;
        throw CorruptArchiveException(e.toString());
      }
      report(JobProgress(done, total, name));
    }
    return ExtractResult(
      destinationDir: root,
      extracted: extracted,
      skipped: skipped,
      blocked: blocked,
    );
  } finally {
    source.close();
  }
}

// ---------------------------------------------------------------------------
// Creation
// ---------------------------------------------------------------------------

class _PendingFile {
  const _PendingFile(this.file, this.archiveName);
  final File file;
  final String archiveName;
}

int _deflateLevel(CompressionLevel level) => switch (level) {
      CompressionLevel.store => 0,
      CompressionLevel.fast => 1,
      CompressionLevel.normal => 6,
      CompressionLevel.maximum => 9,
    };

Future<String> _create(
  CreateRequest r,
  void Function(JobProgress) report,
) async {
  final files = <_PendingFile>[];
  final emptyDirs = <String>[];
  for (final source in r.sourcePaths) {
    final type = FileSystemEntity.typeSync(source, followLinks: false);
    final base = p.basename(source);
    if (type == FileSystemEntityType.file) {
      files.add(_PendingFile(File(source), base));
    } else if (type == FileSystemEntityType.directory) {
      var any = false;
      for (final e in Directory(source).listSync(recursive: true, followLinks: false)) {
        if (e is File) {
          any = true;
          final rel = p.relative(e.path, from: source);
          files.add(_PendingFile(e, '$base/${p.posix.joinAll(p.split(rel))}'));
        }
      }
      if (!any) emptyDirs.add('$base/');
    }
  }
  final total = files.length;
  report(JobProgress(0, total));
  File(r.outputPath).parent.createSync(recursive: true);

  try {
    switch (r.format) {
      case CreateFormat.zip:
        final enc = ZipFileEncoder(password: r.password);
        enc.create(r.outputPath, level: _deflateLevel(r.level));
        for (final d in emptyDirs) {
          enc.addArchiveFile(ArchiveFile.directory(d));
        }
        for (var i = 0; i < files.length; i++) {
          await enc.addFile(files[i].file, files[i].archiveName);
          report(JobProgress(i + 1, total, files[i].archiveName));
        }
        await enc.close();
      case CreateFormat.tarGz:
        final dir = r.tempDir.isEmpty ? Directory.systemTemp.path : r.tempDir;
        final tmpTar = p.join(dir, 'zipfast_${pid}_${DateTime.now().microsecondsSinceEpoch}.tar');
        try {
          final enc = TarFileEncoder()..create(tmpTar);
          for (var i = 0; i < files.length; i++) {
            await enc.addFile(files[i].file, files[i].archiveName);
            report(JobProgress(i + 1, total, files[i].archiveName));
          }
          await enc.close();
          final codec = GZipCodec(level: _deflateLevel(r.level));
          await File(tmpTar)
              .openRead()
              .transform(codec.encoder)
              .pipe(File(r.outputPath).openWrite());
        } finally {
          try {
            File(tmpTar).deleteSync();
          } catch (_) {}
        }
    }
  } catch (e) {
    try {
      File(r.outputPath).deleteSync();
    } catch (_) {}
    if (e is ZipFastException) rethrow;
    throw CorruptArchiveException(e.toString());
  }
  return r.outputPath;
}
