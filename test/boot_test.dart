import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zipfast/boot.dart';
import 'package:zipfast/state/app_state.dart';
import 'package:zipfast/state/storage_service.dart';

/// Boot finishes (needs a pump), then the home screen scans folders in a real isolate.
Future<void> settleApp(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
  await tester.pumpAndSettle();
}

void main() {
  Future<BootResult> okBoot() async {
    SharedPreferences.setMockInitialValues({'locale': 'en'});
    return BootResult(AppState(await SharedPreferences.getInstance()), StorageService.forTesting());
  }

  testWidgets('shows a splash, then the app', (tester) async {
    await tester.pumpWidget(ZipFastBoot(initializer: okBoot));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await settleApp(tester);
    expect(find.text('Open archive'), findsOneWidget);
  });

  testWidgets('a failing startup step shows what failed instead of a dead app, and can retry', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(ZipFastBoot(initializer: () async {
      attempts++;
      if (attempts == 1) throw StateError('path_provider exploded');
      return okBoot();
    }));
    await tester.pumpAndSettle();
    expect(find.textContaining('couldn’t start'), findsOneWidget);
    expect(find.textContaining('path_provider exploded'), findsOneWidget);

    await tester.tap(find.textContaining('Retry'));
    await settleApp(tester);
    expect(attempts, 2);
    expect(find.text('Open archive'), findsOneWidget);
    expect(find.textContaining('couldn’t start'), findsNothing);
  });

  test('StorageService.create always yields usable folders (path_provider failing must not stop startup)', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final s = await StorageService.create();
    expect(Directory(s.tempDir).existsSync(), isTrue);
    expect(Directory(s.appFilesDir).existsSync(), isTrue);
    expect(Directory(s.createRoot).existsSync(), isTrue);
    expect(Directory(s.fallbackExtractRoot).existsSync(), isTrue);
  });
}
