import 'dart:io';
import 'package:flutter/services.dart';

import '../core/archive_format.dart';
import '../encoding/name_encoding.dart';
import 'archive_engine.dart';
import 'job_runner.dart';
import 'models.dart';

/// Engine backed by 7-Zip on Android (through a platform channel to
/// `EnginePlugin.kt` / `ArchiveBridge.java`).
///
/// Reads RAR, RAR5, 7Z, ISO, CAB and split volumes (`.7z.001`, `.zip.001`,
/// `.part1.rar`, `.r00`), including encrypted archives, and creates 7Z.
/// Outside Android the channel is absent and every call fails with
/// [UnsupportedFormatException].
class NativeArchiveEngine implements ArchiveEngine {
  NativeArchiveEngine();

  static const MethodChannel _channel = MethodChannel('com.zipfast.zipfast/engine');

  static int _nextId = 1;
  static final Map<int, JobHandle<dynamic>> _jobs = {};

  @override
  Set<ArchiveFormat> get readable => const {
        ArchiveFormat.sevenZip,
        ArchiveFormat.rar,
        ArchiveFormat.iso,
        ArchiveFormat.cab,
      };

  @override
  Set<CreateFormat> get writable => const {CreateFormat.sevenZip};

  /// Registers the progress callback. Cheap and idempotent, so it simply runs
  /// before every call.
  static void _installHandler() {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'progress') return;
      final args = Map<Object?, Object?>.from(call.arguments as Map);
      final job = _jobs[args['id']];
      job?.reportProgress(JobProgress(
        (args['done'] as num).toInt(),
        (args['total'] as num).toInt(),
        args['current'] as String?,
      ));
    });
  }

  static Never _rethrow(PlatformException e, ArchiveFormat format) {
    switch (e.code) {
      case 'PASSWORD_REQUIRED':
        throw const PasswordRequiredException();
      case 'WRONG_PASSWORD':
        throw const WrongPasswordException();
      case 'CANCELLED':
        throw const JobCancelledException();
      case 'UNSUPPORTED':
        throw UnsupportedFormatException(format);
      default:
        throw CorruptArchiveException(e.message ?? e.code);
    }
  }

  static Future<T> _invoke<T>(String method, Map<String, Object?> args, ArchiveFormat format) async {
    _installHandler();
    try {
      final result = await _channel.invokeMethod<Object?>(method, args);
      return result as T;
    } on MissingPluginException {
      throw UnsupportedFormatException(format);
    } on PlatformException catch (e) {
      _rethrow(e, format);
    }
  }

  @override
  Future<ArchiveListing> list(
    String path, {
    NameEncoding encoding = NameEncoding.auto,
    String? password,
    String tempDir = '',
  }) async {
    final format = await ArchiveFormat.detect(path);
    final raw = await _invoke<Map<Object?, Object?>>(
      'list',
      {'path': path, 'password': password},
      format,
    );
    final entries = <EntryInfo>[
      for (final e in (raw['entries'] as List<Object?>))
        _entry(Map<Object?, Object?>.from(e as Map)),
    ];
    return ArchiveListing(format: format, entries: entries, namesLookGarbled: false);
  }

  static EntryInfo _entry(Map<Object?, Object?> e) {
    final modified = (e['modified'] as num?)?.toInt() ?? 0;
    return EntryInfo(
      path: e['path'] as String,
      isDirectory: e['isDir'] as bool,
      size: (e['size'] as num).toInt(),
      modified: modified > 0 ? DateTime.fromMillisecondsSinceEpoch(modified) : null,
      encrypted: e['encrypted'] as bool,
    );
  }

  @override
  JobHandle<ExtractResult> extract(ExtractRequest request) {
    final id = _nextId++;
    late final JobHandle<ExtractResult> handle;
    handle = JobHandle.manual<ExtractResult>(onCancel: () {
      _channel.invokeMethod<void>('cancel', {'id': id}).catchError((Object _) {});
    });
    _jobs[id] = handle;
    () async {
      try {
        final raw = await _invoke<Map<Object?, Object?>>(
          'extract',
          {
            'id': id,
            'path': request.archivePath,
            'password': request.password,
            'destination': request.destinationDir,
            'selected': request.selectedPaths?.toList(),
            'conflict': request.conflictPolicy.name,
          },
          request.format,
        );
        handle.complete(ExtractResult(
          destinationDir: raw['destinationDir'] as String,
          extracted: (raw['extracted'] as num).toInt(),
          skipped: (raw['skipped'] as num).toInt(),
          blocked: (raw['blocked'] as num).toInt(),
        ));
      } catch (e) {
        handle.fail(e);
      } finally {
        _jobs.remove(id);
      }
    }();
    return handle;
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
    final bytes = await _invoke<Uint8List>(
      'readEntry',
      {'path': path, 'entry': entryPath, 'password': password, 'maxBytes': maxBytes},
      format,
    );
    return bytes;
  }

  @override
  JobHandle<String> create(CreateRequest request) {
    final id = _nextId++;
    late final JobHandle<String> handle;
    handle = JobHandle.manual<String>(onCancel: () {
      _channel.invokeMethod<void>('cancel', {'id': id}).catchError((Object _) {});
    });
    _jobs[id] = handle;
    () async {
      try {
        Directory(File(request.outputPath).parent.path).createSync(recursive: true);
        final path = await _invoke<String>(
          'create7z',
          {
            'id': id,
            'sources': request.sourcePaths,
            'output': request.outputPath,
            'level': switch (request.level) {
              CompressionLevel.store => 0,
              CompressionLevel.fast => 1,
              CompressionLevel.normal => 5,
              CompressionLevel.maximum => 9,
            },
            'password': request.password,
          },
          ArchiveFormat.sevenZip,
        );
        handle.complete(path);
      } catch (e) {
        handle.fail(e);
      } finally {
        _jobs.remove(id);
      }
    }();
    return handle;
  }
}
