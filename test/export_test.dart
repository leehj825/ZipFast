import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zipfast/engine/models.dart';
import 'package:zipfast/l10n/gen/app_localizations.dart';
import 'package:zipfast/services/export_service.dart';
import 'package:zipfast/state/app_state.dart';
import 'package:zipfast/state/file_ops.dart';
import 'package:zipfast/ui/export_flow.dart';

const channel = MethodChannel('com.zipfast.zipfast/export');
const uri = 'content://com.android.externalstorage.documents/tree/primary%3ADownload%2FUnpacked';

void main() {
  test('describe makes tree URIs readable', () {
    expect(ExportService.describe(uri), 'Download/Unpacked');
    expect(ExportService.describe('content://x/tree/primary%3A'), '/');
    expect(ExportService.describe('content://x/tree/1234-ABCD%3ADocs%2FZips'), '1234-ABCD:Docs/Zips');
    expect(ExportService.describe('content://x/tree/primary%3ADownload/document/primary%3ADownload'), 'Download');
    expect(ExportService.describe('not a tree uri'), 'not a tree uri');
  });

  test('volumeSet finds every volume of a split archive', () {
    final tmp = Directory.systemTemp.createTempSync('zipfast_vol_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    for (final n in ['a.zip.001', 'a.zip.002', 'a.zip.003', 'a.zip.005', 'b.zip']) {
      File(p.join(tmp.path, n)).writeAsBytesSync([0]);
    }
    expect(volumeSet(p.join(tmp.path, 'a.zip.001')).map(p.basename), ['a.zip.001', 'a.zip.002', 'a.zip.003']);
    expect(volumeSet(p.join(tmp.path, 'b.zip')).map(p.basename), ['b.zip']);
    expect(volumeSet(p.join(tmp.path, 'missing.7z.001')).map(p.basename), ['missing.7z.001']);
  });

  test('exportUri is remembered across restarts and can be cleared', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var state = AppState(prefs);
    expect(state.exportUri, isNull);
    await state.setExportUri(uri);
    expect(AppState(prefs).exportUri, uri);
    await state.setExportUri(null);
    expect(AppState(prefs).exportUri, isNull);
  });

  group('ExportService channel contract', () {
    final calls = <MethodCall>[];
    void mock(Future<Object?> Function(MethodCall) handler) {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (c) {
        calls.add(c);
        return handler(c);
      });
    }

    tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    test('copy sends uri and paths and resolves to the count; progress is relayed', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      mock((call) async {
        if (call.method == 'copy') {
          await Future<void>.delayed(Duration.zero);
          final id = (call.arguments as Map)['id'];
          await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
            channel.name,
            const StandardMethodCodec().encodeMethodCall(
                MethodCall('progress', {'id': id, 'done': 1, 'total': 2, 'current': 'a.txt'})),
            (_) {},
          );
          return 2;
        }
        return null;
      });
      final job = ExportService.copy(uri, ['/a', '/b']);
      final seen = <JobProgress>[];
      job.progress.listen(seen.add);
      expect(await job.result, 2);
      await pumpEventQueue();
      final args = calls.firstWhere((c) => c.method == 'copy').arguments as Map;
      expect(args['uri'], uri);
      expect(args['paths'], ['/a', '/b']);
      expect(seen.single.current, 'a.txt');
    });

    test('error codes map to typed errors; cancel is forwarded', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      mock((_) async => throw PlatformException(code: 'PERMISSION', message: 'm'));
      await expectLater(ExportService.copy(uri, ['/a']).result, throwsA(isA<ExportAccessException>()));
      mock((_) async => throw PlatformException(code: 'CORRUPT', message: 'disk full'));
      await expectLater(ExportService.copy(uri, ['/a']).result, throwsA(isA<CorruptArchiveException>()));

      mock((call) async {
        if (call.method == 'copy') await Future<void>.delayed(const Duration(milliseconds: 30));
        return 0;
      });
      final slow = ExportService.copy(uri, ['/a']);
      slow.cancel();
      await expectLater(slow.result, throwsA(isA<JobCancelledException>()));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(calls.any((c) => c.method == 'cancel'), isTrue);
    });

    test('no plugin: picker is unsupported, access is false', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      await expectLater(ExportService.pickFolder(), throwsA(isA<UnsupportedError>()));
      expect(await ExportService.hasAccess(uri), isFalse);
    });
  });

  group('Save a copy to… flow', () {
    final calls = <MethodCall>[];
    late AppState state;
    var access = true;
    String? picked;
    Object? copyError;

    Future<void> pump(WidgetTester tester, {String? remembered}) async {
      SharedPreferences.setMockInitialValues({'locale': 'en', 'export_uri': ?remembered});
      state = AppState(await SharedPreferences.getInstance());
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => saveCopyTo(context, ['/data/a.zip', '/data/b']),
                child: const Text('save'),
              ),
            ),
          ),
        ),
      ));
    }

    setUp(() {
      calls.clear();
      access = true;
      picked = uri;
      copyError = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (c) async {
        calls.add(c);
        switch (c.method) {
          case 'hasAccess':
            return access;
          case 'pickFolder':
            return picked;
          case 'copy':
            if (copyError != null) throw copyError!;
            return 2;
        }
        return null;
      });
    });
    tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    List<String> methods() => calls.map((c) => c.method).toList();

    testWidgets('first time: pick a folder, copy, remember it', (tester) async {
      await pump(tester);
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      expect(methods(), ['pickFolder', 'copy']);
      expect((calls.last.arguments as Map)['uri'], uri);
      expect((calls.last.arguments as Map)['paths'], ['/data/a.zip', '/data/b']);
      expect(find.text('Copy complete'), findsOneWidget);
      expect(find.textContaining('2 files copied to'), findsOneWidget);
      expect(find.textContaining('Download/Unpacked'), findsOneWidget);
      expect(state.exportUri, uri);
    });

    testWidgets('remembered folder is offered and used without the picker', (tester) async {
      await pump(tester, remembered: uri);
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      expect(find.text('Save to Download/Unpacked'), findsOneWidget);
      await tester.tap(find.text('Save to Download/Unpacked'));
      await tester.pumpAndSettle();
      expect(methods(), ['hasAccess', 'copy']);
    });

    testWidgets('"choose another folder" opens the picker and remembers the new one', (tester) async {
      await pump(tester, remembered: 'content://old/tree/primary%3AOld');
      picked = uri;
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose another folder…'));
      await tester.pumpAndSettle();
      expect(methods(), ['hasAccess', 'pickFolder', 'copy']);
      expect(state.exportUri, uri);
    });

    testWidgets('revoked access: forgets the folder and goes straight to the picker', (tester) async {
      await pump(tester, remembered: 'content://old/tree/primary%3AOld');
      access = false;
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      expect(methods(), ['hasAccess', 'pickFolder', 'copy']);
      expect(find.text('Choose another folder…'), findsNothing);
    });

    testWidgets('cancelling the picker copies nothing', (tester) async {
      await pump(tester);
      picked = null;
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      expect(methods(), ['pickFolder']);
      expect(state.exportUri, isNull);
    });

    testWidgets('permission lost during copy explains it', (tester) async {
      await pump(tester);
      copyError = PlatformException(code: 'PERMISSION', message: 'denied');
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      expect(find.text('Access to that folder was removed. Choose it again.'), findsOneWidget);
    });

    testWidgets('no picker on this platform shows a message', (tester) async {
      await pump(tester);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      await tester.tap(find.text('save'));
      // With no handler the "missing plugin" answer comes from the real engine, not fake time.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(find.text('Saving to another folder isn’t available here.'), findsOneWidget);
    });
  });
}
