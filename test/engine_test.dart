import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zipfast/core/archive_format.dart';
import 'package:zipfast/encoding/name_encoding.dart';
import 'package:zipfast/engine/archive_engine.dart';
import 'package:zipfast/engine/models.dart';
import 'package:zipfast/engine/safe_path.dart';

const engine = DartArchiveEngine();

String fixture(String name) => p.join('test', 'fixtures', name);

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('zipfast_test_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('safe path (Zip Slip)', () {
    test('rejects traversal and absolute names', () {
      expect(resolveSafePath('/out', '../evil'), isNull);
      expect(resolveSafePath('/out', 'a/../../evil'), isNull);
      expect(resolveSafePath('/out', '..\\evil'), isNull);
      expect(resolveSafePath('/out', '/etc/passwd'), isNull);
      expect(resolveSafePath('/out', 'C:\\Windows\\x'), isNull);
      expect(resolveSafePath('/out', '..'), isNull);
    });
    test('accepts nested names', () {
      expect(resolveSafePath('/out', 'a/b.txt'), '/out/a/b.txt');
      expect(resolveSafePath('/out', 'a/../b.txt'), '/out/b.txt');
      expect(resolveSafePath('/out', r'a\b.txt'), '/out/a/b.txt');
    });
    test('uniquePath appends a counter', () {
      final taken = {'/o/a.txt', '/o/a (1).txt'};
      expect(uniquePath('/o/a.txt', taken.contains), '/o/a (2).txt');
    });
  });

  group('format detection', () {
    test('by name', () {
      expect(ArchiveFormat.fromName('a.tar.gz'), ArchiveFormat.tarGz);
      expect(ArchiveFormat.fromName('a.part1.rar'), ArchiveFormat.rar);
      expect(ArchiveFormat.fromName('a.7z.001'), ArchiveFormat.sevenZip);
      expect(ArchiveFormat.fromName('a.z01'), ArchiveFormat.zip);
      expect(ArchiveFormat.fromName('a.txt'), ArchiveFormat.unknown);
    });
    test('by magic bytes beats a wrong extension', () async {
      final f = File(p.join(tmp.path, 'x.dat'))
        ..writeAsBytesSync(File(fixture('korean_cp949.zip')).readAsBytesSync());
      expect(await ArchiveFormat.detect(f.path), ArchiveFormat.zip);
    });
  });

  group('encoding repair', () {
    Future<void> check(String file, NameEncoding enc, String expected) async {
      final auto = await engine.list(fixture(file));
      expect(auto.namesLookGarbled, isTrue, reason: 'auto should look garbled');
      final fixed = await engine.list(fixture(file), encoding: enc);
      expect(fixed.entries.single.path, expected);
      expect(fixed.namesLookGarbled, isFalse);
    }

    test('CP949', () => check('korean_cp949.zip', NameEncoding.cp949, '한글폴더/문서.txt'));
    test('Shift-JIS', () => check('japanese_sjis.zip', NameEncoding.shiftJis, '日本語/テスト.txt'));
    test('GBK', () => check('chinese_gbk.zip', NameEncoding.gbk, '中文/测试.txt'));
  });

  test('Zip Slip entries are blocked on extract', () async {
    final out = p.join(tmp.path, 'out');
    final result = await engine
        .extract(ExtractRequest(
          archivePath: fixture('zip_slip.zip'),
          format: ArchiveFormat.zip,
          destinationDir: out,
          tempDir: tmp.path,
        ))
        .result;
    expect(result.blocked, 4);
    expect(result.extracted, 1);
    expect(File(p.join(out, 'good', 'ok.txt')).existsSync(), isTrue);
    expect(File(p.join(tmp.path, 'evil.txt')).existsSync(), isFalse);
    expect(File(p.join(tmp.path, 'abs_evil.txt')).existsSync(), isFalse);
    expect(File('/abs_evil.txt').existsSync(), isFalse);
  });

  group('create + extract round trip', () {
    late String srcDir;
    setUp(() {
      srcDir = p.join(tmp.path, 'src');
      Directory(p.join(srcDir, 'sub')).createSync(recursive: true);
      File(p.join(srcDir, 'a.txt')).writeAsStringSync('alpha');
      File(p.join(srcDir, 'sub', 'b.txt')).writeAsStringSync('beta' * 1000);
      Directory(p.join(srcDir, 'empty')).createSync();
    });

    for (final format in const [CreateFormat.zip, CreateFormat.tarGz]) {
      test('${format.name} plain', () async {
        final archive = p.join(tmp.path, 'out.${format == CreateFormat.zip ? 'zip' : 'tar.gz'}');
        await engine
            .create(CreateRequest(
              sourcePaths: [srcDir],
              outputPath: archive,
              format: format,
              tempDir: tmp.path,
            ))
            .result;
        final listing = await engine.list(archive, tempDir: tmp.path);
        expect(listing.entries.where((e) => !e.isDirectory).map((e) => e.path).toSet(),
            {'src/a.txt', 'src/sub/b.txt'});
        final dest = p.join(tmp.path, 'dest');
        final r = await engine
            .extract(ExtractRequest(
              archivePath: archive,
              format: listing.format,
              destinationDir: dest,
              tempDir: tmp.path,
            ))
            .result;
        expect(r.extracted, 2);
        expect(File(p.join(dest, 'src', 'a.txt')).readAsStringSync(), 'alpha');
        expect(File(p.join(dest, 'src', 'sub', 'b.txt')).readAsStringSync(), 'beta' * 1000);
        // No scratch files left behind.
        expect(tmp.listSync().whereType<File>().where((f) => f.path.endsWith('.tmp') || f.path.endsWith('.tar')),
            isEmpty);
      });
    }

    test('AES-256 zip needs and validates password', () async {
      final archive = p.join(tmp.path, 'secret.zip');
      await engine
          .create(CreateRequest(
            sourcePaths: [p.join(srcDir, 'a.txt')],
            outputPath: archive,
            password: 's3cret',
            tempDir: tmp.path,
          ))
          .result;
      final listing = await engine.list(archive, password: 's3cret');
      expect(listing.hasEncrypted, isTrue);

      Future<Object?> extractWith(String? pw) async {
        try {
          await engine
              .extract(ExtractRequest(
                archivePath: archive,
                format: ArchiveFormat.zip,
                destinationDir: p.join(tmp.path, 'd_${pw ?? 'none'}'),
                password: pw,
                tempDir: tmp.path,
              ))
              .result;
          return null;
        } catch (e) {
          return e;
        }
      }

      expect(await extractWith(null), isA<PasswordRequiredException>());
      expect(await extractWith('nope'), isA<WrongPasswordException>());
      expect(await extractWith('s3cret'), isNull);
      expect(File(p.join(tmp.path, 'd_s3cret', 'a.txt')).readAsStringSync(), 'alpha');
    });

    test('selective extract and conflict policies', () async {
      final archive = p.join(tmp.path, 'sel.zip');
      await engine
          .create(CreateRequest(sourcePaths: [srcDir], outputPath: archive, tempDir: tmp.path))
          .result;
      final dest = p.join(tmp.path, 'sel');
      ExtractRequest req(ConflictPolicy c) => ExtractRequest(
            archivePath: archive,
            format: ArchiveFormat.zip,
            destinationDir: dest,
            selectedPaths: {'src/sub'},
            conflictPolicy: c,
            tempDir: tmp.path,
          );
      await engine.extract(req(ConflictPolicy.rename)).result;
      expect(File(p.join(dest, 'src', 'sub', 'b.txt')).existsSync(), isTrue);
      expect(File(p.join(dest, 'src', 'a.txt')).existsSync(), isFalse);
      await engine.extract(req(ConflictPolicy.rename)).result;
      expect(File(p.join(dest, 'src', 'sub', 'b (1).txt')).existsSync(), isTrue);
      final skipped = await engine.extract(req(ConflictPolicy.skip)).result;
      expect(skipped.skipped, 1);
      final over = await engine.extract(req(ConflictPolicy.overwrite)).result;
      expect(over.extracted, 1);
    });

    test('readEntry for previews', () async {
      final archive = p.join(tmp.path, 'prev.zip');
      await engine
          .create(CreateRequest(sourcePaths: [srcDir], outputPath: archive, tempDir: tmp.path))
          .result;
      final bytes = await engine.readEntry(archive, 'src/a.txt');
      expect(String.fromCharCodes(bytes), 'alpha');
    });
  });

  test('unsupported formats fail clearly', () async {
    final f = File(p.join(tmp.path, 'x.rar'))
      ..writeAsBytesSync(Uint8List.fromList([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0, 0]));
    expect(engine.list(f.path), throwsA(isA<UnsupportedFormatException>()));
  });

  test('cancel stops a job', () async {
    final big = File(p.join(tmp.path, 'big.bin'))..writeAsBytesSync(Uint8List(40 * 1024 * 1024));
    final job = engine.create(CreateRequest(
      sourcePaths: [big.path],
      outputPath: p.join(tmp.path, 'big.zip'),
      level: CompressionLevel.maximum,
      tempDir: tmp.path,
    ));
    job.cancel();
    expect(job.result, throwsA(isA<JobCancelledException>()));
  });
}
