import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'state/app_state.dart';
import 'state/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(['7-Zip', '7-Zip-JBinding'], '''
ZipFast uses 7-Zip (Igor Pavlov) through 7-Zip-JBinding for RAR, RAR5, 7Z, ISO and CAB.

7-Zip is licensed under the GNU LGPL. The unRAR code inside 7-Zip is subject to the
unRAR restriction: it may be used to decompress RAR archives, but not to create RAR
archives or to develop a RAR-compatible compressor. ZipFast never creates RAR files.

7-Zip: https://www.7-zip.org/   License: https://www.gnu.org/licenses/lgpl-2.1.html
7-Zip-JBinding: http://sevenzipjbind.sourceforge.net/ (LGPL 2.1)
''');
  });
  final prefs = await SharedPreferences.getInstance();
  final storage = await StorageService.create();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState(prefs)),
        Provider<StorageService>.value(value: storage),
      ],
      child: const ZipFastApp(),
    ),
  );
}
