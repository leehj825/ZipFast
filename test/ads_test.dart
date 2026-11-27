import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zipfast/services/ads_service.dart';
import 'package:zipfast/ui/widgets/ad_banner.dart';

void main() {
  test('AdMob ids', () {
    expect(AdUnits.appId, 'ca-app-pub-4400173019354346~7131341860');
    expect(AdUnits.bannerRelease, 'ca-app-pub-4400173019354346/9123080380');
    // Debug builds must never request the live unit (policy: no clicking your own ads).
    expect(AdUnits.banner(debug: true), AdUnits.bannerTest);
    expect(AdUnits.banner(debug: true), isNot(AdUnits.bannerRelease));
    expect(AdUnits.banner(debug: false), AdUnits.bannerRelease);
    expect(AdUnits.bannerTest, startsWith('ca-app-pub-3940256099942544/'));
  });

  test('the manifest declares the same app id (the app crashes without it)', () {
    // Run from the project root by `flutter test`.
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('com.google.android.gms.ads.APPLICATION_ID'));
    expect(manifest, contains(AdUnits.appId));
    expect(manifest, contains('android.permission.INTERNET'));
  });

  test('unsupported platforms never start the SDK', () async {
    final previous = AdsService.isSupported;
    AdsService.isSupported = () => false;
    addTearDown(() => AdsService.isSupported = previous);
    await AdsService.instance.initialize();
    expect(AdsService.instance.ready.value, isFalse);
    expect(AdsService.instance.privacyOptionsRequired.value, isFalse);
  });

  testWidgets('the banner slot takes no space without ads', (tester) async {
    final previous = AdsService.isSupported;
    addTearDown(() => AdsService.isSupported = previous);
    for (final supported in [false, true]) {
      AdsService.isSupported = () => supported; // true: supported, but consent hasn't allowed ads yet
      await tester.pumpWidget(const MaterialApp(home: Scaffold(bottomNavigationBar: AdBannerSlot())));
      expect(tester.getSize(find.byType(AdBannerSlot)).height, 0, reason: 'supported=$supported');
    }
  });
}
