import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zipfast/state/file_ops.dart';

Matcher fails(FileOpFailure reason) =>
    throwsA(isA<FileOpException>().having((e) => e.reason, 'reason', reason));

void main() {
  late Directory tmp;
  late String root;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('zipfast_ops_');
    root = p.join(tmp.path, 'root')..toString();
    Directory(root).createSync();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  String file(String rel, [String content = 'x']) {
    final f = File(p.join(root, rel))..createSync(recursive: true);
    f.writeAsStringSync(content);
    return f.path;
  }

  test('validateFileName', () {
    expect(validateFileName('ok name.txt'), isNull);
    for (final bad in ['', '  ', '.', '..', 'a/b', r'a\b', 'x' * 256]) {
      expect(validateFileName(bad), FileOpFailure.invalidName, reason: bad);
    }
  });

  test('createFolder', () async {
    final path = await createFolder(root, root, 'New');
    expect(Directory(path).existsSync(), isTrue);
    await expectLater(createFolder(root, root, 'New'), fails(FileOpFailure.nameTaken));
    await expectLater(createFolder(root, root, '../x'), fails(FileOpFailure.invalidName));
    await expectLater(createFolder(root, tmp.path, 'x'), fails(FileOpFailure.outsideRoot));
  });

  group('rename', () {
    test('files and folders', () async {
      final f = file('a.txt', 'hello');
      final renamed = await renamePath(root, f, 'b.txt');
      expect(File(renamed).readAsStringSync(), 'hello');
      expect(File(f).existsSync(), isFalse);
      final d = file('dir/in.txt');
      final dir = await renamePath(root, p.dirname(d), 'dir2');
      expect(File(p.join(dir, 'in.txt')).existsSync(), isTrue);
    });
    test('rejects clashes, bad names, outside paths; same name is a no-op', () async {
      final a = file('a.txt');
      file('b.txt');
      await expectLater(renamePath(root, a, 'b.txt'), fails(FileOpFailure.nameTaken));
      await expectLater(renamePath(root, a, 'x/y'), fails(FileOpFailure.invalidName));
      expect(await renamePath(root, a, 'a.txt'), a);
      final outside = File(p.join(tmp.path, 'out.txt'))..writeAsStringSync('o');
      await expectLater(renamePath(root, outside.path, 'z'), fails(FileOpFailure.outsideRoot));
      await expectLater(renamePath(root, p.join(root, 'ghost'), 'z'), fails(FileOpFailure.missing));
    });
  });

  group('delete', () {
    test('files, folders (recursive), missing ignored', () async {
      final a = file('a.txt');
      file('d/e/f.txt');
      await deletePaths(root, [a, p.join(root, 'd'), p.join(root, 'ghost')]);
      expect(Directory(root).listSync(), isEmpty);
    });
    test('never touches the root or anything outside it', () async {
      await expectLater(deletePaths(root, [root]), fails(FileOpFailure.outsideRoot));
      final outside = File(p.join(tmp.path, 'out.txt'))..writeAsStringSync('o');
      await expectLater(deletePaths(root, [outside.path]), fails(FileOpFailure.outsideRoot));
      expect(outside.existsSync(), isTrue);
      // A path that merely starts with the root's name is not inside it.
      final sibling = Directory('$root-evil')..createSync();
      await expectLater(deletePaths(root, [sibling.path]), fails(FileOpFailure.outsideRoot));
      expect(sibling.existsSync(), isTrue);
    });
  });

  group('move', () {
    test('moves files and folders, renaming on clashes', () async {
      final a = file('a.txt', 'A');
      file('dir/inner.txt', 'I');
      final dest = Directory(p.join(root, 'dest'))..createSync();
      file('dest/a.txt', 'existing');
      final moved = await movePaths(root, [a, p.join(root, 'dir')], dest.path);
      expect(moved, [p.join(dest.path, 'a (1).txt'), p.join(dest.path, 'dir')]);
      expect(File(moved[0]).readAsStringSync(), 'A');
      expect(File(p.join(dest.path, 'a.txt')).readAsStringSync(), 'existing');
      expect(File(p.join(dest.path, 'dir', 'inner.txt')).readAsStringSync(), 'I');
      expect(File(a).existsSync(), isFalse);
    });
    test('moving into the current folder changes nothing', () async {
      final a = file('a.txt');
      expect(await movePaths(root, [a], root), [a]);
      expect(File(a).existsSync(), isTrue);
    });
    test('a folder cannot go into itself or its children', () async {
      file('dir/sub/x.txt');
      final dir = p.join(root, 'dir');
      await expectLater(movePaths(root, [dir], dir), fails(FileOpFailure.intoItself));
      await expectLater(movePaths(root, [dir], p.join(dir, 'sub')), fails(FileOpFailure.intoItself));
      expect(File(p.join(dir, 'sub', 'x.txt')).existsSync(), isTrue);
    });
    test('refuses targets outside the root', () async {
      final a = file('a.txt');
      await expectLater(movePaths(root, [a], tmp.path), fails(FileOpFailure.outsideRoot));
      expect(File(a).existsSync(), isTrue);
    });
  });
}
