import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zipfast/state/app_state.dart';
import 'package:zipfast/state/destinations.dart';
import 'package:zipfast/state/storage_service.dart';

void main() {
  late Directory root;
  late StorageService storage;
  setUp(() {
    root = Directory.systemTemp.createTempSync('zipfast_dest_');
    storage = StorageService.forTesting();
  });
  tearDown(() => root.deleteSync(recursive: true));

  String archive(String dir, String name) {
    Directory(dir).createSync(recursive: true);
    return (File(p.join(dir, name))..writeAsBytesSync([0])).path;
  }

  group('extract destination', () {
    test('new folder next to the archive, made unique', () {
      final a = archive(p.join(root.path, 'dl'), 'photos.tar.gz');
      Directory(p.join(root.path, 'dl', 'photos')).createSync();
      final r = resolveExtractDestination(storage, target: ExtractTarget.newFolder, archivePath: a);
      expect(r.path, p.join(root.path, 'dl', 'photos (1)'));
      expect(r.usedFallback, isFalse);
    });

    test('same folder extracts straight into the archive folder', () {
      final a = archive(p.join(root.path, 'dl'), 'x.zip');
      final r = resolveExtractDestination(storage, target: ExtractTarget.sameFolder, archivePath: a);
      expect(r.path, p.join(root.path, 'dl'));
    });

    test('custom folder, with and without a subfolder', () {
      final a = archive(p.join(root.path, 'dl'), 'docs.zip');
      final chosen = Directory(p.join(root.path, 'chosen'))..createSync();
      final withSub = resolveExtractDestination(storage,
          target: ExtractTarget.custom, archivePath: a, customDir: chosen.path);
      expect(withSub.path, p.join(chosen.path, 'docs'));
      expect(withSub.usedFallback, isFalse);
      final direct = resolveExtractDestination(storage,
          target: ExtractTarget.custom, archivePath: a, customDir: chosen.path, customSubfolder: false);
      expect(direct.path, chosen.path);
    });

    test('unwritable or missing custom folder falls back to app storage and says so', () {
      final a = archive(p.join(root.path, 'dl'), 'docs.zip');
      final r = resolveExtractDestination(storage,
          target: ExtractTarget.custom,
          archivePath: a,
          customDir: '/definitely/not/writable',
          isWritable: (_) => false);
      expect(r.usedFallback, isTrue);
      expect(p.isWithin(storage.fallbackExtractRoot, r.path), isTrue);
      final none = resolveExtractDestination(storage, target: ExtractTarget.custom, archivePath: a);
      expect(none.usedFallback, isTrue);
    });

    test('an archive in the app cache never extracts next to itself', () {
      final cached = archive(p.join(storage.cacheDir, 'file_picker'), 'x.zip');
      final r = resolveExtractDestination(storage, target: ExtractTarget.newFolder, archivePath: cached);
      expect(r.usedFallback, isTrue);
      expect(p.isWithin(storage.fallbackExtractRoot, r.path), isTrue);
    });
  });

  group('create path', () {
    test('uses the chosen folder, or app storage by default, and avoids clashes', () {
      final dir = Directory(p.join(root.path, 'out'))..createSync();
      expect(resolveCreatePath(storage, fileName: 'a.zip', dir: dir.path), p.join(dir.path, 'a.zip'));
      File(p.join(dir.path, 'a.zip')).writeAsBytesSync([0]);
      expect(resolveCreatePath(storage, fileName: 'a.zip', dir: dir.path), p.join(dir.path, 'a (1).zip'));
      expect(resolveCreatePath(storage, fileName: 'b.7z'), p.join(storage.createRoot, 'b.7z'));
    });
  });

  group('settings persistence', () {
    test('default folders and "ask every time" survive a restart and can be reset', () async {
      SharedPreferences.setMockInitialValues({});
      var prefs = await SharedPreferences.getInstance();
      var state = AppState(prefs);
      expect(state.extractDir, isNull);
      expect(state.createDir, isNull);
      expect(state.askEachTime, isFalse);

      await state.setExtractDir('/sdcard/Download/Unpacked');
      await state.setCreateDir('/sdcard/Documents/Zips');
      await state.setAskEachTime(true);

      state = AppState(prefs); // simulate a restart
      expect(state.extractDir, '/sdcard/Download/Unpacked');
      expect(state.createDir, '/sdcard/Documents/Zips');
      expect(state.askEachTime, isTrue);

      await state.setExtractDir(null);
      await state.setCreateDir(null);
      state = AppState(prefs);
      expect(state.extractDir, isNull);
      expect(state.createDir, isNull);
    });
  });
}
