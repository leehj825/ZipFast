import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zipfast/core/archive_format.dart';
import 'package:zipfast/encoding/name_encoding.dart';
import 'package:zipfast/engine/archive_engine.dart';
import 'package:zipfast/engine/composite_engine.dart';
import 'package:zipfast/engine/job_runner.dart';
import 'package:zipfast/engine/models.dart';
import 'package:zipfast/engine/native_engine.dart';

/// Records which engine got which call.
class FakeEngine implements ArchiveEngine {
  FakeEngine(this.name, this.readable, [this.writable = const {}]);
  final String name;
  final List<String> calls = [];

  @override
  final Set<ArchiveFormat> readable;
  @override
  final Set<CreateFormat> writable;

  @override
  Future<ArchiveListing> list(String path,
      {NameEncoding encoding = NameEncoding.auto, String? password, String tempDir = ''}) async {
    calls.add('list:${p.basename(path)}');
    return ArchiveListing(format: ArchiveFormat.zip, entries: const [], namesLookGarbled: false);
  }

  @override
  JobHandle<ExtractResult> extract(ExtractRequest request) {
    calls.add('extract:${p.basename(request.archivePath)}');
    final h = JobHandle.manual<ExtractResult>();
    h.complete(const ExtractResult(destinationDir: '', extracted: 0, skipped: 0, blocked: 0));
    return h;
  }

  @override
  Future<Uint8List> readEntry(String path, String entryPath,
      {NameEncoding encoding = NameEncoding.auto,
      String? password,
      String tempDir = '',
      int maxBytes = 0}) async {
    calls.add('read:${p.basename(path)}');
    return Uint8List(0);
  }

  @override
  JobHandle<String> create(CreateRequest request) {
    calls.add('create:${request.format.name}');
    final h = JobHandle.manual<String>();
    File(request.outputPath).writeAsBytesSync(List.filled(2500, 7));
    h.complete(request.outputPath);
    return h;
  }
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('zipfast_comp_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  File touch(String name, [List<int> bytes = const [0]]) =>
      File(p.join(tmp.path, name))..writeAsBytesSync(bytes);

  group('routing', () {
    late FakeEngine dart;
    late FakeEngine native;
    late CompositeEngine engine;
    setUp(() {
      dart = FakeEngine('dart', {ArchiveFormat.zip, ArchiveFormat.tarGz}, {CreateFormat.zip, CreateFormat.tarGz});
      native = FakeEngine('native', {ArchiveFormat.rar, ArchiveFormat.sevenZip}, {CreateFormat.sevenZip});
      engine = CompositeEngine(dart: dart, native: native);
    });

    test('plain formats go to the matching engine', () async {
      await engine.list(touch('a.zip', [0x50, 0x4B, 3, 4]).path);
      await engine.list(touch('b.rar', [0x52, 0x61, 0x72, 0x21, 0x1A, 7, 0]).path);
      await engine.list(touch('c.7z', [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]).path);
      expect(dart.calls, ['list:a.zip']);
      expect(native.calls, ['list:b.rar', 'list:c.7z']);
    });

    test('every split volume set goes to native, even zip-looking ones', () async {
      await engine.list(touch('x.zip.001', [0x50, 0x4B, 3, 4]).path);
      await engine.list(touch('x.part1.rar').path);
      await engine.list(touch('y.z01', [0x50, 0x4B, 3, 4]).path);
      expect(dart.calls, isEmpty);
      expect(native.calls.length, 3);
    });

    test('any volume maps to the first volume', () async {
      touch('v.part01.rar');
      touch('v.part02.rar');
      touch('s.rar');
      touch('s.r00');
      touch('d.7z.001');
      touch('d.7z.002');
      expect(CompositeEngine.firstVolume(p.join(tmp.path, 'v.part02.rar')), p.join(tmp.path, 'v.part01.rar'));
      expect(CompositeEngine.firstVolume(p.join(tmp.path, 's.r00')), p.join(tmp.path, 's.rar'));
      expect(CompositeEngine.firstVolume(p.join(tmp.path, 'd.7z.002')), p.join(tmp.path, 'd.7z.001'));
      // No first volume on disk: leave it alone.
      expect(CompositeEngine.firstVolume(p.join(tmp.path, 'zzz.part2.rar')), p.join(tmp.path, 'zzz.part2.rar'));
      await engine.list(p.join(tmp.path, 'v.part02.rar'));
      expect(native.calls.single, 'list:v.part01.rar');
    });

    test('7z creation goes native, zip goes to the Dart engine', () async {
      String o(String n) => p.join(tmp.path, n);
      await engine.create(CreateRequest(sourcePaths: const [], outputPath: o('a.7z'), format: CreateFormat.sevenZip)).result;
      await engine.create(CreateRequest(sourcePaths: const [], outputPath: o('a.zip'))).result;
      expect(native.calls, ['create:sevenZip']);
      expect(dart.calls, ['create:zip']);
    });

    test('splitting after creation yields .001/.002/.003 and removes the original', () async {
      final out = p.join(tmp.path, 'big.zip');
      final result = await engine
          .create(CreateRequest(sourcePaths: const [], outputPath: out, splitSizeBytes: 1000))
          .result;
      expect(result, '$out.001');
      expect(File(out).existsSync(), isFalse);
      expect(File('$out.001').lengthSync(), 1000);
      expect(File('$out.002').lengthSync(), 1000);
      expect(File('$out.003').lengthSync(), 500);
      expect(File('$out.004').existsSync(), isFalse);
    });
  });

  test('splitFile volumes concatenate back to the original bytes', () async {
    final data = Uint8List.fromList(List.generate(10007, (i) => i % 251));
    final f = touch('data.bin', data);
    final first = await splitFile(f.path, 4096);
    expect(first, '${f.path}.001');
    final joined = BytesBuilder();
    for (var i = 1; File('${f.path}.${i.toString().padLeft(3, '0')}').existsSync(); i++) {
      joined.add(File('${f.path}.${i.toString().padLeft(3, '0')}').readAsBytesSync());
    }
    expect(joined.toBytes(), data);
  });

  test('real Dart engine + split round trip: .zip.001 volumes join into a valid zip', () async {
    final src = touch('hello.txt', 'hello'.codeUnits);
    final out = p.join(tmp.path, 'real.zip');
    final first = await CompositeEngine(native: FakeEngine('n', {}))
        .create(CreateRequest(
          sourcePaths: [src.path],
          outputPath: out,
          level: CompressionLevel.store,
          splitSizeBytes: 64,
          tempDir: tmp.path,
        ))
        .result;
    expect(first, '$out.001');
    final joined = BytesBuilder();
    for (var i = 1; File('$out.${i.toString().padLeft(3, '0')}').existsSync(); i++) {
      joined.add(File('$out.${i.toString().padLeft(3, '0')}').readAsBytesSync());
    }
    File(out).writeAsBytesSync(joined.toBytes());
    final listing = await const DartArchiveEngine().list(out);
    expect(listing.entries.single.path, 'hello.txt');
  });

  group('JobHandle.manual', () {
    test('progress, completion and cancel hook', () async {
      var cancelled = 0;
      final h = JobHandle.manual<int>(onCancel: () => cancelled++);
      final seen = <int>[];
      h.progress.listen((e) => seen.add(e.done));
      h.reportProgress(const JobProgress(1, 2));
      await Future<void>.delayed(Duration.zero);
      h.cancel();
      h.cancel();
      expect(cancelled, 1);
      await expectLater(h.result, throwsA(isA<JobCancelledException>()));
      expect(seen, [1]);
    });
  });

  group('NativeArchiveEngine channel contract', () {
    const channel = MethodChannel('com.zipfast.zipfast/engine');
    final log = <MethodCall>[];

    void mock(Future<Object?> Function(MethodCall) handler) {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) {
        log.add(call);
        return handler(call);
      });
    }

    tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    test('list maps entries', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      mock((call) async => {
            'format': '7z',
            'entries': [
              {'path': 'a/b.txt', 'isDir': false, 'size': 12, 'modified': 1700000000000, 'encrypted': true},
              {'path': 'a', 'isDir': true, 'size': 0, 'modified': 0, 'encrypted': false},
            ],
          });
      final file = touch('x.7z', [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]);
      final listing = await NativeArchiveEngine().list(file.path, password: 'pw');
      expect(log.single.method, 'list');
      expect((log.single.arguments as Map)['password'], 'pw');
      expect(listing.format, ArchiveFormat.sevenZip);
      expect(listing.entries.first.encrypted, isTrue);
      expect(listing.entries.first.size, 12);
      expect(listing.entries.last.isDirectory, isTrue);
      expect(listing.hasEncrypted, isTrue);
    });

    test('native error codes become typed exceptions', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final file = touch('x.7z', [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]);
      for (final entry in {
        'PASSWORD_REQUIRED': isA<PasswordRequiredException>(),
        'WRONG_PASSWORD': isA<WrongPasswordException>(),
        'CORRUPT': isA<CorruptArchiveException>(),
        'UNSUPPORTED': isA<UnsupportedFormatException>(),
      }.entries) {
        mock((_) async => throw PlatformException(code: entry.key, message: 'm'));
        await expectLater(NativeArchiveEngine().list(file.path), throwsA(entry.value));
      }
    });

    test('missing plugin (desktop/tests) reads as unsupported', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      final file = touch('x.rar', [0x52, 0x61, 0x72, 0x21, 0x1A, 7, 0]);
      await expectLater(NativeArchiveEngine().list(file.path), throwsA(isA<UnsupportedFormatException>()));
    });

    test('extract sends arguments, relays progress and result, cancels by id', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      mock((call) async {
        if (call.method == 'extract') {
          final id = (call.arguments as Map)['id'];
          await Future<void>.delayed(Duration.zero); // real native work is never instant
          // Native side pushes progress while the call is pending.
          final data = const StandardMethodCodec().encodeMethodCall(
              MethodCall('progress', {'id': id, 'done': 1, 'total': 2, 'current': 'a.txt'}));
          await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .handlePlatformMessage(channel.name, data, (_) {});
          return {'destinationDir': '/out', 'extracted': 2, 'skipped': 0, 'blocked': 1};
        }
        return null;
      });
      final job = NativeArchiveEngine().extract(ExtractRequest(
        archivePath: '/x.rar',
        format: ArchiveFormat.rar,
        destinationDir: '/out',
        selectedPaths: {'a'},
        password: 'pw',
        conflictPolicy: ConflictPolicy.skip,
      ));
      final progress = <JobProgress>[];
      job.progress.listen(progress.add);
      final result = await job.result;
      await pumpEventQueue();
      expect(result.extracted, 2);
      expect(result.blocked, 1);
      final args = log.firstWhere((c) => c.method == 'extract').arguments as Map;
      expect(args['selected'], ['a']);
      expect(args['conflict'], 'skip');
      expect(args['destination'], '/out');
      expect(progress.single.current, 'a.txt');

      // Cancel: native call stays pending, cancel sends the job id.
      mock((call) async {
        if (call.method == 'extract') await Future<void>.delayed(const Duration(milliseconds: 50));
        return null;
      });
      final slow = NativeArchiveEngine().extract(ExtractRequest(
          archivePath: '/x.rar', format: ArchiveFormat.rar, destinationDir: '/out'));
      slow.cancel();
      await expectLater(slow.result, throwsA(isA<JobCancelledException>()));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(log.any((c) => c.method == 'cancel'), isTrue);
    });
  });
}
