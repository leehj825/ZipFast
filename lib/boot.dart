import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'services/ads_service.dart';
import 'state/app_state.dart';
import 'state/storage_service.dart';

/// Everything the app needs before its first real screen.
class BootResult {
  const BootResult(this.appState, this.storage);
  final AppState appState;
  final StorageService storage;
}

/// Loads settings and folders, registers licenses and starts the ads SDK.
Future<BootResult> defaultInitializer() async {
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
  // Consent first, then the Mobile Ads SDK; nothing waits for it, and it can never
  // stop the app from opening.
  unawaited(AdsService.instance.initialize().catchError((Object _) {}));
  return BootResult(AppState(prefs), storage);
}

/// The app's root. Shows a splash while starting, then the app, or, if a startup
/// step failed, a screen that says what failed (instead of a dead, blank app).
class ZipFastBoot extends StatefulWidget {
  const ZipFastBoot({super.key, this.initializer = defaultInitializer});

  final Future<BootResult> Function() initializer;

  @override
  State<ZipFastBoot> createState() => _ZipFastBootState();
}

class _ZipFastBootState extends State<ZipFastBoot> {
  late Future<BootResult> _boot = widget.initializer();

  void _retry() {
    final next = widget.initializer();
    setState(() {
      _boot = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BootResult>(
      future: _boot,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return StartupErrorApp(
            error: snapshot.error!,
            stack: snapshot.stackTrace,
            onRetry: _retry,
          );
        }
        final boot = snapshot.data;
        if (boot == null) return const _Splash();
        return MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: boot.appState),
            Provider<StorageService>.value(value: boot.storage),
          ],
          child: const ZipFastApp(),
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFF4F46E5),
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
}

/// Shown when startup fails. Plain on purpose: it must work even when settings
/// and localization could not be loaded.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error, this.stack, required this.onRetry});

  final Object error;
  final StackTrace? stack;
  final VoidCallback onRetry;

  String get _details => '$error\n\n${stack ?? ''}'.trim();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ZipFast couldn’t start\nZipFast를 시작하지 못했습니다',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text('Please send a screenshot of this screen.\n이 화면을 캡처해서 보내 주세요.'),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _details,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ),
                Row(children: [
                  FilledButton(onPressed: onRetry, child: const Text('Retry / 다시 시도')),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => Clipboard.setData(ClipboardData(text: _details)),
                    child: const Text('Copy / 복사'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
