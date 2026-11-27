import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/gen/app_localizations.dart';

/// Home-screen banner slot.
///
/// This is the single integration point for an adaptive AdMob banner
/// (`google_mobile_ads`). Until that is wired in, debug builds show a labelled
/// placeholder so the layout can be checked, and release builds show nothing.
///  Keep at least 16dp of clearance above it.
class AdBannerSlot extends StatelessWidget {
  const AdBannerSlot({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        height: 56,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          AppLocalizations.of(context).adBannerPlaceholder,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
