import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../engine/models.dart';
import '../services/export_service.dart';
import '../l10n/gen/app_localizations.dart';
import '../state/app_state.dart';
import '../state/storage_service.dart';
import 'file_browser.dart';
import 'folder_picker_page.dart';
import 'viewer_page.dart';

/// Opens [path] in the archive viewer and records it in the history.
Future<void> openArchive(BuildContext context, String path) async {
  final state = context.read<AppState>();
  final navigator = Navigator.of(context);
  await state.addToHistory(path);
  await navigator.push(MaterialPageRoute<void>(builder: (_) => ViewerPage(path: path)));
}

/// Lets the user pick an archive with the system picker and opens it.
Future<void> pickAndOpenArchive(BuildContext context) async {
  final file = await FilePicker.pickFile();
  if (file?.path == null || !context.mounted) return;
  await openArchive(context, file!.path!);
}

/// A user-facing message for [error], localized.
String describeError(AppLocalizations l10n, Object error) {
  if (error is PasswordRequiredException) return l10n.passwordTitle;
  if (error is WrongPasswordException) return l10n.passwordWrong;
  if (error is JobCancelledException) return l10n.cancelled;
  if (error is ExportAccessException) return l10n.exportAccessLost;
  if (error is UnsupportedFormatException) return l10n.unsupportedTitle(error.format.label);
  if (error is ZipFastException) return l10n.genericError(error.message);
  return l10n.genericError('$error');
}

/// Lets the user pick a folder inside ZipFast's storage (see [FolderPickerPage]).
/// Returns `null` if cancelled.
Future<String?> pickAppFolder(BuildContext context, {String? start}) {
  final root = context.read<StorageService>().appFilesDir;
  return Navigator.push<String>(
    context,
    MaterialPageRoute<String>(builder: (_) => FolderPickerPage(root: root, start: start)),
  );
}

/// Opens the file browser on [dir] (or the folder that holds [dir] if it is a file).
Future<void> showFilesIn(BuildContext context, String dir) {
  final storage = context.read<StorageService>();
  return Navigator.push<void>(
    context,
    MaterialPageRoute<void>(builder: (_) => FilesPage(appRoot: storage.appFilesDir, initialDir: dir)),
  );
}
