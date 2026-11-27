import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zipfast/l10n/gen/app_localizations.dart';
import 'package:zipfast/state/app_state.dart';
import 'package:zipfast/state/storage_service.dart';
import 'package:zipfast/ui/create_sheet.dart';

void main() {
  testWidgets('create sheet: 7Z, password and split options render and react', (tester) async {
    SharedPreferences.setMockInitialValues({'locale': 'en'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState(prefs)),
        Provider<StorageService>.value(value: StorageService.forTesting()),
      ],
      child: MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCreateSheet(context, ['/tmp/some_file.txt']),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Create archive'), findsOneWidget);
    expect(find.text('7Z'), findsOneWidget);
    expect(find.text('ZIP'), findsOneWidget);
    expect(find.text('TAR.GZ'), findsOneWidget);
    // Everything is free: no Pro labels anywhere.
    expect(find.textContaining('Pro'), findsNothing);

    await tester.tap(find.text('7Z'));
    await tester.pumpAndSettle();
    expect(find.text('.7z'), findsOneWidget); // extension suffix in the name field

    // Password option is usable for 7Z and shows a field when switched on.
    await tester.tap(find.text('Password lock (AES-256)'));
    await tester.pumpAndSettle();
    expect(find.text('Password'), findsOneWidget);

    // TAR.GZ cannot be encrypted: the switch turns off and the field goes away.
    await tester.tap(find.text('TAR.GZ'));
    await tester.pumpAndSettle();
    expect(find.text('Password'), findsNothing);

    // Split options.
    await tester.scrollUntilVisible(find.text('Split archive'), 100, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Split archive'));
    await tester.pumpAndSettle();
    expect(find.text('25 MB'), findsOneWidget);
    expect(find.text('Custom size (MB)'), findsOneWidget);
  });
}
