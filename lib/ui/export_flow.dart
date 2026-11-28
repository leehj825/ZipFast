import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/gen/app_localizations.dart';
import '../services/export_service.dart';
import '../state/app_state.dart';
import 'widgets/job_dialog.dart';

enum _Choice { remembered, another }

/// "Save a copy to…": copies [paths] out of ZipFast's storage into a folder the
/// user picks with the system folder picker.
///
/// The last folder is remembered; if it is still accessible it is offered as a
/// one-tap choice.
Future<void> saveCopyTo(BuildContext context, List<String> paths) async {
  final l10n = AppLocalizations.of(context);
  final state = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  if (paths.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.exportNothing)));
    return;
  }

  var uri = state.exportUri;
  if (uri != null && !await ExportService.hasAccess(uri)) {
    uri = null; // revoked, or not available here
    await state.setExportUri(null);
  }
  if (!context.mounted) return;

  if (uri != null) {
    final choice = await showModalBottomSheet<_Choice>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.folder),
            title: Text(l10n.saveCopyHere(ExportService.describe(uri!))),
            onTap: () => Navigator.pop(ctx, _Choice.remembered),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: Text(l10n.chooseAnotherFolder),
            onTap: () => Navigator.pop(ctx, _Choice.another),
          ),
        ]),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == _Choice.another) uri = null;
  }

  if (uri == null) {
    try {
      uri = await ExportService.pickFolder();
    } on UnsupportedError {
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportUnavailable)));
      return;
    }
    if (uri == null || !context.mounted) return;
    await state.setExportUri(uri);
    if (!context.mounted) return;
  }

  final folder = ExportService.describe(uri);
  final handle = ExportService.copy(uri, paths);
  await showJobDialog<int>(
    context,
    handle,
    title: l10n.copying,
    doneTitle: l10n.copyDoneTitle,
    doneBuilder: (ctx, count) => Text(l10n.copiedSummary(count, folder)),
  );
}
