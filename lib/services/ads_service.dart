import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob identifiers.
///
/// The app ID is also declared in `AndroidManifest.xml`
/// (`com.google.android.gms.ads.APPLICATION_ID`); keep the two in sync.
class AdUnits {
  AdUnits._();

  /// AdMob app ID (ZipFast).
  static const appId = 'ca-app-pub-4400173019354346~7131341860';

  /// The real banner ad unit. Only used in release builds.
  static const bannerRelease = 'ca-app-pub-4400173019354346/9123080380';

  /// Google's official test banner unit. AdMob policy forbids clicking your own
  /// live ads (risk of an account ban), so debug builds always show test ads.
  static const bannerTest = 'ca-app-pub-3940256099942544/6300978735';

  /// `--dart-define=ZIPFAST_TEST_ADS=true` makes any build use test ads. The
  /// GitHub prerelease workflow sets it: those APKs are release builds, but
  /// testers must not generate live impressions or clicks.
  static const forceTestAds = bool.fromEnvironment('ZIPFAST_TEST_ADS');

  static String banner({required bool debug}) =>
      (debug || forceTestAds) ? bannerTest : bannerRelease;
}

/// Starts the Google Mobile Ads SDK the way Google requires:
///
///  1. ask for consent first (User Messaging Platform: GDPR / EEA, UK, US states),
///  2. only then initialize the SDK and allow ad requests.
///
/// Banner widgets watch [ready] and show nothing until it is true, so users who
/// decline consent (or whose region needs none until decided) never trigger ad
/// requests. Off Android everything is a no-op.
class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  /// Whether ads are supported here (Android). Tests can replace it.
  static bool Function() isSupported = () => !kIsWeb && Platform.isAndroid;

  /// True once consent allows ad requests and the SDK has been initialized.
  final ValueNotifier<bool> ready = ValueNotifier(false);

  /// True when the app must offer an "Ad privacy settings" entry (UMP rule).
  final ValueNotifier<bool> privacyOptionsRequired = ValueNotifier(false);

  bool _started = false;

  Future<void> initialize() async {
    if (_started || !isSupported()) return;
    _started = true;
    try {
      final done = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          await ConsentForm.loadAndShowConsentFormIfRequired((_) {
            if (!done.isCompleted) done.complete();
          });
        },
        (_) {
          if (!done.isCompleted) done.complete(); // offline etc.: fall back to stored consent
        },
      );
      await done.future;
      await _refresh();
    } catch (_) {
      // Ads are optional; never let them break the app.
    }
  }

  /// Opens the consent form again so the user can change their choice.
  Future<void> showPrivacyOptions() async {
    if (!isSupported()) return;
    final done = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((_) {
      if (!done.isCompleted) done.complete();
    });
    await done.future;
    await _refresh();
  }

  Future<void> _refresh() async {
    privacyOptionsRequired.value =
        await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
            PrivacyOptionsRequirementStatus.required;
    if (!ready.value && await ConsentInformation.instance.canRequestAds()) {
      await MobileAds.instance.initialize();
      ready.value = true;
    }
  }
}
