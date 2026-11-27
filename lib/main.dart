import 'dart:async';

import 'package:flutter/widgets.dart';

import 'boot.dart';

void main() {
  // Uncaught errors are logged instead of silently ending the app's isolate.
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('ZipFast: ${details.exceptionAsString()}');
    };
    runApp(const ZipFastBoot());
  }, (error, stack) => debugPrint('ZipFast: uncaught $error\n$stack'));
}
