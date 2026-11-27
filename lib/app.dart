import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'l10n/gen/app_localizations.dart';
import 'services/incoming_file_service.dart';
import 'state/app_state.dart';
import 'ui/actions.dart';
import 'ui/home_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ZipFastApp extends StatefulWidget {
  const ZipFastApp({super.key});

  @override
  State<ZipFastApp> createState() => _ZipFastAppState();
}

class _ZipFastAppState extends State<ZipFastApp> {
  @override
  void initState() {
    super.initState();
    // Archives opened from other apps ("Open with ZipFast").
    IncomingFileService.listen((path) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) openArchive(ctx, path);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      navigatorKey: navigatorKey,
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: state.themeMode,
      locale: state.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: const HomePage(),
    );
  }
}
