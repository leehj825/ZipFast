import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:material_ui/material_ui.dart';

import '../../services/ads_service.dart';

/// The home-screen banner: an anchored adaptive AdMob banner at the bottom.
///
/// Placement follows AdMob policy: it sits in the scaffold's bottom bar, so it
/// never overlaps content or buttons (the FAB floats above it), and it is only
/// used on the home screen, never over dialogs, progress or while archives are
/// being worked on. Until consent allows ad requests, and whenever an ad fails
/// to load, it takes no space at all.
class AdBannerSlot extends StatelessWidget {
  const AdBannerSlot({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AdsService.isSupported()) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: AdsService.instance.ready,
      builder: (context, ready, _) => ready ? const _Banner() : const SizedBox.shrink(),
    );
  }
}

class _Banner extends StatefulWidget {
  const _Banner();

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> {
  BannerAd? _ad;
  AnchoredAdaptiveBannerAdSize? _size;
  int? _requestedWidth;
  int _retries = 0;
  Timer? _retryTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload when the available width changes (rotation, split screen).
    final width = MediaQuery.sizeOf(context).width.truncate();
    if (width != _requestedWidth) _load(width);
  }

  Future<void> _load(int width) async {
    _requestedWidth = width;
    _retryTimer?.cancel();
    // ignore: deprecated_member_use
    final size = await AdSize.getAnchoredAdaptiveBannerAdSize(Orientation.portrait, width);
    if (size == null) {
      AdsService.instance.report('Ads: no adaptive banner size for width $width');
      return;
    }
    if (!mounted || width != _requestedWidth) return;
    final unit = AdUnits.banner(debug: kDebugMode);
    AdsService.instance.report('Ads: loading banner ${size.width}x${size.height} (${unit == AdUnits.bannerTest ? 'TEST unit' : 'live unit'})');
    final old = _ad;
    final ad = BannerAd(
      adUnitId: unit,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loaded) {
          if (!mounted) {
            loaded.dispose();
            return;
          }
          AdsService.instance.report('Ads: banner loaded');
          setState(() => _size = size);
        },
        onAdFailedToLoad: (failed, error) {
          failed.dispose();
          AdsService.instance.report('Ads: banner failed to load (code ${error.code}): ${error.message}');
          if (!mounted) return;
          setState(() {
            if (_ad == failed) _ad = null;
            _size = null;
          });
          // A few quiet retries (no network, no fill); then give up until the next launch.
          if (_retries++ < 3) {
            _retryTimer = Timer(const Duration(seconds: 60), () {
              if (mounted) _load(_requestedWidth ?? width);
            });
          }
        },
      ),
    );
    setState(() {
      _ad = ad;
      _size = null; // hidden until it has loaded
    });
    old?.dispose();
    await ad.load();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    final size = _size;
    if (ad == null || size == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: size.width.toDouble(),
        height: size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
