import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zipfast/l10n/gen/app_localizations.dart';
import 'package:zipfast/services/external_file_service.dart';
import 'package:zipfast/state/app_state.dart';
import 'package:zipfast/state/storage_service.dart';
import 'package:zipfast/ui/file_browser.dart';

void main() {
  late Directory root;
  late StorageService storage;

  setUp(() {
    root = Directory.systemTemp.createTempSync('zipfast_fb_');
    storage = StorageService.forTesting();
    File(p.join(root.path, 'notes.txt')).writeAsStringSync('hi');
    File(p.join(root.path, 'data.zip')).writeAsBytesSync([0]);
    File(p.join(root.path, '.hidden')).writeAsStringSync('h');
    Directory(p.join(root.path, 'photos')).createSync();
    File(p.join(root.path, 'photos', 'a.jpg')).writeAsBytesSync([1]);
  });
  tearDown(() => root.deleteSync(recursive: true));

  Future<void> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'locale': 'en'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState(prefs)),
        Provider<StorageService>.value(value: storage),
      ],
      child: MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: FileBrowser(root: root.path)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Lets real file I/O started by a handler finish, then rebuilds.
  Future<void> settleIo(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pumpAndSettle();
  }

  testWidgets('lists folders first, hides dotfiles', (tester) async {
    await pump(tester);
    expect(find.text('ZipFast storage'), findsOneWidget);
    final titles = tester.widgetList<Text>(find.descendant(of: find.byType(ListTile), matching: find.byType(Text)))
        .map((t) => t.data)
        .whereType<String>()
        .toList();
    expect(titles.indexOf('photos'), lessThan(titles.indexOf('data.zip')));
    expect(find.text('.hidden'), findsNothing);
    expect(find.text('notes.txt'), findsOneWidget);
  });

  testWidgets('folders can be entered and left', (tester) async {
    await pump(tester);
    await tester.tap(find.text('photos'));
    await tester.pumpAndSettle();
    expect(find.text('a.jpg'), findsOneWidget);
    expect(find.text('photos'), findsOneWidget); // header shows the relative path
    await tester.tap(find.text('Up one level'));
    await tester.pumpAndSettle();
    expect(find.text('notes.txt'), findsOneWidget);
  });

  testWidgets('long press selects and shows the action bar; rename only for one item', (tester) async {
    await pump(tester);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    await tester.longPress(find.text('notes.txt'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Compress 1 selected'), findsOneWidget);
    expect(find.byIcon(Icons.drive_file_rename_outline), findsOneWidget);
    await tester.tap(find.text('data.zip'));
    await tester.pumpAndSettle(); // selection mode: tap toggles instead of opening
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.byIcon(Icons.drive_file_rename_outline), findsNothing);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Compress 2 selected'), findsNothing);
  });

  testWidgets('new folder, rename and delete work on disk', (tester) async {
    await pump(tester);

    await tester.tap(find.byIcon(Icons.create_new_folder_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Unpacked');
    await tester.tap(find.text('OK'));
    await settleIo(tester);
    expect(Directory(p.join(root.path, 'Unpacked')).existsSync(), isTrue);
    expect(find.text('Unpacked'), findsOneWidget);

    await tester.longPress(find.text('notes.txt'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.drive_file_rename_outline));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'renamed.txt');
    await tester.tap(find.text('OK'));
    await settleIo(tester);
    expect(File(p.join(root.path, 'renamed.txt')).existsSync(), isTrue);
    expect(File(p.join(root.path, 'notes.txt')).existsSync(), isFalse);

    await tester.longPress(find.text('renamed.txt'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete 1 items?'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await settleIo(tester);
    expect(File(p.join(root.path, 'renamed.txt')).existsSync(), isFalse);
  });

  testWidgets('renaming onto an existing name shows an error and changes nothing', (tester) async {
    await pump(tester);
    await tester.longPress(find.text('notes.txt'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.drive_file_rename_outline));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'data.zip');
    await tester.tap(find.text('OK'));
    await settleIo(tester);
    expect(find.text('Something with that name already exists.'), findsOneWidget);
    expect(File(p.join(root.path, 'notes.txt')).existsSync(), isTrue);
  });

  testWidgets('move goes through the in-app folder picker', (tester) async {
    await pump(tester);
    await tester.longPress(find.text('notes.txt'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.drive_file_move_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Choose a folder'), findsOneWidget);
    await tester.tap(find.text('photos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move here'));
    await settleIo(tester);
    expect(File(p.join(root.path, 'photos', 'notes.txt')).existsSync(), isTrue);
    expect(File(p.join(root.path, 'notes.txt')).existsSync(), isFalse);
  });

  group('other apps', () {
    final opened = <String>[];
    final shared = <List<String>>[];
    var canOpen = true;
    setUp(() {
      opened.clear();
      shared.clear();
      canOpen = true;
      ExternalFileService.openOverride = (path) async {
        opened.add(path);
        return canOpen;
      };
      ExternalFileService.shareOverride = (files) async => shared.add(files);
    });
    tearDown(() {
      ExternalFileService.openOverride = null;
      ExternalFileService.shareOverride = null;
    });

    testWidgets('tapping a non-archive opens it with another app', (tester) async {
      await pump(tester);
      await tester.tap(find.text('notes.txt'));
      await settleIo(tester);
      expect(opened, [p.join(root.path, 'notes.txt')]);
      expect(find.text('No app can open this file.'), findsNothing);
    });

    testWidgets('no handler app shows a message', (tester) async {
      canOpen = false;
      await pump(tester);
      await tester.tap(find.text('notes.txt'));
      await settleIo(tester);
      expect(find.text('No app can open this file.'), findsOneWidget);
    });

    testWidgets('share sends the selected files; folders are refused', (tester) async {
      await pump(tester);

      await tester.longPress(find.text('photos'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.share_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Folders can’t be shared. Compress them first.'), findsOneWidget);
      expect(shared, isEmpty);

      await tester.pump(const Duration(seconds: 6)); // let the snackbar go away
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('notes.txt'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.share_outlined));
      await settleIo(tester);
      expect(shared.single, [p.join(root.path, 'notes.txt')]);
    });
  });
}
