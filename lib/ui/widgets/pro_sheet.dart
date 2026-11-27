import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../state/app_state.dart';

/// Shows the Pro upsell sheet.
Future<void> showProSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ProSheet(),
  );
}

/// Runs [action] if Pro is active, otherwise shows the upsell sheet.
Future<void> requirePro(BuildContext context, VoidCallback action) async {
  if (context.read<AppState>().isPro) {
    action();
  } else {
    await showProSheet(context);
  }
}

class _ProSheet extends StatelessWidget {
  const _ProSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    Widget feature(String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            const Icon(Icons.check_circle, size: 20, color: Color(0xFF16A34A)),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ]),
        );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.workspace_premium, color: Color(0xFFF59E0B), size: 32),
              const SizedBox(width: 12),
              Text(l10n.proTitle, style: Theme.of(context).textTheme.headlineSmall),
            ]),
            const SizedBox(height: 8),
            Text(l10n.proIntro),
            const SizedBox(height: 16),
            feature(l10n.proFeatureAds),
            feature(l10n.proFeatureAes),
            feature(l10n.proFeatureSplit),
            feature(l10n.proFeatureBatch),
            const SizedBox(height: 16),
            if (state.isPro)
              Text(l10n.proActive, style: const TextStyle(fontWeight: FontWeight.w600))
            else
              Text(l10n.proUnavailable,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            if (kDebugMode)
              FilledButton(
                onPressed: () => state.setPro(!state.isPro),
                child: Text(state.isPro ? l10n.proDebugLock : l10n.proDebugUnlock),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.close),
            ),
          ],
        ),
      ),
    );
  }
}
