import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zipfast/app.dart';
import 'package:zipfast/state/app_state.dart';
import 'package:zipfast/state/storage_service.dart';

Future<void> pumpApp(WidgetTester tester, {String? locale}) async {
  SharedPreferences.setMockInitialValues({'locale': ?locale});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState(prefs)),
        Provider<StorageService>.value(value: StorageService.forTesting()),
      ],
      child: const ZipFastApp(),
    ),
  );
  // The recent-archives scan runs in a real isolate; give it real time.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('home screen renders in English', (tester) async {
    await pumpApp(tester, locale: 'en');
    expect(find.text('ZipFast'), findsOneWidget);
    expect(find.text('Recent archives'), findsOneWidget);
    expect(find.text('Browse device'), findsOneWidget);
    expect(find.text('Create archive'), findsOneWidget);
    expect(find.text('Extract archive'), findsOneWidget);
    expect(find.text('Open archive'), findsOneWidget);
  });

  testWidgets('home screen renders in Korean', (tester) async {
    await pumpApp(tester, locale: 'ko');
    expect(find.text('최근 압축 파일'), findsOneWidget);
    expect(find.text('기기 폴더 탐색'), findsOneWidget);
    expect(find.text('압축하기'), findsOneWidget);
    expect(find.text('압축 풀기'), findsOneWidget);
    expect(find.text('압축 파일 열기'), findsOneWidget);
  });

  testWidgets('settings page opens and switches language', (tester) async {
    await pumpApp(tester, locale: 'en');
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('한국어'));
    await tester.pumpAndSettle();
    expect(find.text('언어'), findsOneWidget);
  });

  testWidgets('settings: location options are shown and "ask every time" toggles', (tester) async {
    await pumpApp(tester, locale: 'en');
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Default extract folder'), findsOneWidget);
    expect(find.text('New folder next to the archive'), findsOneWidget);
    expect(find.text('Default save folder for new archives'), findsOneWidget);
    expect(find.text('ZipFast storage'), findsOneWidget);
    await tester.tap(find.text('Ask for a folder every time'));
    await tester.pumpAndSettle();
    final sw = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Ask for a folder every time'));
    expect(sw.value, isTrue);
  });
}
